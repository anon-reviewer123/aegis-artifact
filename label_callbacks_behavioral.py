import json
import re
import sys
import collections

CALL_RE = re.compile(
    r"\.call\s*[\({]|\.send\s*\(|\.transfer\s*\(|"
    r"safeTransferFrom\s*\(|_safeMint\s*\(|safeMint\s*\(|"
    r"onERC721Received|onERC1155Received|onERC1155BatchReceived|"
    r"tokensReceived|onFlashLoan|executeOperation|onTokenTransfer|"
    r"tokenFallback|onTransferReceived"
)
VALUE_CALL_RE = re.compile(r"\.call\s*\{\s*value|\.send\s*\(|\.transfer\s*\(")
WRITE_RE = re.compile(
    r"\b([A-Za-z_]\w*)\s*(\[[^\]]*\]\s*)*(\+=|-=|\*=|/=|\|=|&=|=(?!=))"
)
FUNC_RE = re.compile(r"\bfunction\s+([A-Za-z_]\w*)\s*\(")
FLAG_NAME_RE = re.compile(
    r"\b(finalized|ended|started|claimed|settled|launched|opened|closed|"
    r"locked|paused|active|phase|stage|state|round|epoch|status)\w*\b",
    re.IGNORECASE,
)
ORACLE_RE = re.compile(
    r"\.latestAnswer\s*\(|\.latestRoundData\s*\(|\.getPrice\w*\s*\(|"
    r"\.getReserves\s*\(|\.getAmountsOut\s*\(|"
    r"\.consult\s*\(|\.observe\s*\("
)
EOA_RE = re.compile(
    r"tx\.origin\s*==\s*msg\.sender|msg\.sender\s*==\s*tx\.origin|"
    r"extcodesize\s*\(\s*msg\.sender\s*\)|"
    r"msg\.sender\.code\.length\s*==\s*0"
)
FLASH_RE = re.compile(r"onFlashLoan|executeOperation|flashLoan\s*\(|IERC3156")
REQ_OK_RE = re.compile(r"require\s*\(\s*(ok|success|sent|result)\b")
HOOK_MECHS = {"erc721_hook", "erc1155_hook", "generic_received", "notify_style"}
TYPE_START = re.compile(
    r"^\s*(mapping\s*\(|uint\d*\b|int\d*\b|bool\b|address\b|bytes\d*\b|"
    r"string\b|struct\s+\w+|\w+\[\]\s)"
)


def strip(src):
    src = re.sub(r"/\*.*?\*/", " ", src, flags=re.S)
    src = re.sub(r"//[^\n]*", " ", src)
    src = re.sub(r'"(?:\\.|[^"\\])*"', '""', src)
    src = re.sub(r"'(?:\\.|[^'\\])*'", "''", src)
    return src


def brace_span(src, start):
    depth = 0
    j = start
    while j < len(src):
        if src[j] == "{":
            depth += 1
        elif src[j] == "}":
            depth -= 1
            if depth == 0:
                return j
        j += 1
    return len(src) - 1


def functions(src):
    out = []
    for m in FUNC_RE.finditer(src):
        i = src.find("{", m.end())
        semi = src.find(";", m.end())
        if i == -1 or (semi != -1 and semi < i):
            continue
        j = brace_span(src, i)
        out.append((m.group(1), src[m.start():i], src[i:j + 1], m.start(), j))
    return out


def storage_vars(src, funcs):
    skel = list(src)
    for kw in (r"\bconstructor\s*\(", r"\bmodifier\s+\w+", r"\breceive\s*\(",
               r"\bfallback\s*\("):
        for m in re.finditer(kw, src):
            i = src.find("{", m.end())
            semi = src.find(";", m.end())
            if i == -1 or (semi != -1 and semi < i):
                continue
            j = brace_span(src, i)
            for k in range(i, j + 1):
                skel[k] = " "
    for _, _, _, a, b in funcs:
        for k in range(a, b + 1):
            skel[k] = " "
    skel = "".join(skel)
    out = set()
    for line in skel.split(";"):
        line = line.strip()
        if not TYPE_START.match(line):
            continue
        line = line.split("=")[0]
        toks = re.findall(r"[A-Za-z_]\w*", line)
        drop = {"mapping", "uint", "uint256", "uint128", "uint64", "uint32",
                "uint8", "int", "int256", "bool", "address", "bytes",
                "bytes32", "bytes4", "string", "public", "private",
                "internal", "constant", "immutable", "override", "payable",
                "memory", "storage", "struct"}
        cand = [t for t in toks if t not in drop and not t[0].isupper()]
        if cand:
            out.add(cand[-1])
    return out


def label(src, mechs):
    src = strip(src)
    tags = set()
    funcs = functions(src)
    svars = storage_vars(src, funcs)
    call_funcs = []
    other_pub = []
    view_pub = []
    for name, header, body, a, b in funcs:
        vis_pub = ("internal" not in header and "private" not in header)
        if CALL_RE.search(body):
            call_funcs.append((name, header, body))
        elif vis_pub and ("view" in header or "pure" in header):
            view_pub.append((name, body))
        elif vis_pub:
            other_pub.append((name, body))

    touched = set()
    for name, header, body in call_funcs:
        w = {m.group(1) for m in WRITE_RE.finditer(body)} & svars
        touched |= w
        for cm in CALL_RE.finditer(body):
            tail = body[cm.end():]
            wa = {m.group(1) for m in WRITE_RE.finditer(tail)} & svars
            if wa:
                tags.add("deferred_write")
            for wm in WRITE_RE.finditer(tail):
                if wm.group(1) in svars and FLAG_NAME_RE.match(wm.group(1)):
                    tags.add("phase_flag")
        for lb_m in re.finditer(r"\b(for|while)\s*\(", body):
            i = body.find("{", lb_m.end())
            if i == -1:
                continue
            j = brace_span(body, i)
            lb = body[i:j + 1]
            if CALL_RE.search(lb):
                tags.add("loop_call")
        if re.search(r"\.transfer\s*\(", body) or REQ_OK_RE.search(body):
            tags.add("revert_coupled")

    if touched:
        for name, body in other_pub:
            if any(re.search(r"\b%s\b" % re.escape(v), body)
                   for v in touched):
                tags.add("cross_function")
                break
        for name, body in view_pub:
            if any(re.search(r"\b%s\b" % re.escape(v), body)
                   for v in touched):
                tags.add("readonly")
                break

    if ORACLE_RE.search(src):
        tags.add("oracle_read")
    if EOA_RE.search(src):
        tags.add("eoa_guard")
    if FLASH_RE.search(src) or "flashloan" in mechs:
        tags.add("flashloan")
    if mechs & HOOK_MECHS:
        tags.add("token_hook")
    return tags


def main():
    root = sys.argv[1]
    counts = collections.Counter()
    prone = 0
    per_contract = {}
    nlab = collections.Counter()
    for line in open(root + "/census.jsonl"):
        r = json.loads(line)
        if not r.get("callback_prone"):
            continue
        prone += 1
        path = root + "/contracts/" + r["address"] + ".sol"
        try:
            src = open(path, errors="ignore").read()
        except OSError:
            continue
        tags = label(src, set(r.get("mechanisms", {})))
        per_contract[r["address"]] = sorted(tags)
        nlab[len(tags)] += 1
        for t in tags:
            counts[t] += 1
    order = [
        ("State exposure", "Cross-function state exposure", "cross_function"),
        ("State exposure", "Deferred state update after call",
         "deferred_write"),
        ("State exposure", "View-observable exposure", "readonly"),
        ("State exposure", "External price/state read", "oracle_read"),
        ("State exposure", "Token-hook handoff", "token_hook"),
        ("Ctrl./liveness", "Revert-coupled external call", "revert_coupled"),
        ("Ctrl./liveness", "External call inside loop", "loop_call"),
        ("Ctrl./liveness", "EOA-assumption guard", "eoa_guard"),
        ("Callback timing", "Phase-flag transition around call",
         "phase_flag"),
        ("Callback timing", "Flash-loan interface", "flashloan"),
    ]
    print("callback-prone contracts:", prone)
    for dim, cls, key in order:
        c = counts[key]
        print(f"{dim:15s} {cls:36s} {c:5d} {100*c/prone:5.1f}")
    atleast1 = prone - nlab[0]
    print("zero labels:", nlab[0], f"{100*nlab[0]/prone:.1f}%")
    print("at least one:", atleast1, f"{100*atleast1/prone:.1f}%")
    with open(root + "/labels_behavioral.json", "w") as f:
        json.dump(per_contract, f, indent=0)


if __name__ == "__main__":
    main()
