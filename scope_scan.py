import argparse
import collections
import csv
import hashlib
import os
import re
import sys

CALLBACK_PATTERNS = [
    (r"\.onAssetReceived\s*\(", "erc777_asset_hook"),
    (r"\.tokensReceived\s*\(", "erc777_tokens_received"),
    (r"\.onTokensReceived\s*\(", "token_receiver_hook"),
    (r"\.onERC1155Received\s*\(", "erc1155_received"),
    (r"\.onERC1155BatchReceived\s*\(", "erc1155_batch_received"),
    (r"\.onERC721Received\s*\(", "erc721_received"),
    (r"\.call\s*\{", "low_level_call"),
    (r"\.call\s*\(", "low_level_call"),
    (r"\.send\s*\(", "send"),
    (r"\.transfer\s*\(", "transfer"),
    (r"\.executeOperation\s*\(", "flashloan_execute"),
    (r"\.onFlashLoan\s*\(", "erc3156_flashloan"),
    (r"\.onCallback\s*\(", "generic_callback"),
    (r"\.on[A-Z]\w*Received\s*\(", "generic_on_received"),
    (r"\.on[A-Z]\w*Hook\s*\(", "generic_on_hook"),
    (r"\.notify[A-Z]\w*\s*\(", "notify_callback"),
    (r"\.on[A-Z]\w*\s*\(", "generic_on"),
]
CALLBACK_RE = [(re.compile(p), n) for p, n in CALLBACK_PATTERNS]

GAS_FORWARDING = re.compile(r"\.call\s*\{|\.call\s*\(|\.call\s*\.\s*value\s*\(")
LOOP = re.compile(r"\b(for|while)\s*\(")
WRITE = re.compile(
    r"([A-Za-z_]\w*)\s*(?:\[[^\]]*\]|\.[A-Za-z_]\w*)*\s*(?:=(?!=)|\+=|-=|\*=|/=)")
LINE_COMMENT = re.compile(r"//[^\n]*")
BLOCK_COMMENT = re.compile(r"/\*.*?\*/", re.S)
STRING_LIT = re.compile(r'"(?:[^"\\]|\\.)*"|\'(?:[^\'\\]|\\.)*\'')
CONTRACT = re.compile(r"\b(contract|library|interface)\s+([A-Za-z_]\w*)")
PRAGMA = re.compile(r"pragma\s+solidity\s+([^;]+);")


def strip(src):
    src = BLOCK_COMMENT.sub(" ", src)
    src = LINE_COMMENT.sub(" ", src)
    return STRING_LIT.sub('""', src)


def match_block(src, i):
    d = 0
    for j in range(i, len(src)):
        if src[j] == "{":
            d += 1
        elif src[j] == "}":
            d -= 1
            if d == 0:
                return j
    return -1


def pragma_major(src):
    m = PRAGMA.search(src)
    if not m:
        return None
    hits = re.findall(r"(\d+)\.(\d+)", m.group(1))
    return ".".join(hits[0]) if hits else None


def contracts_in(src):
    out = []
    for m in CONTRACT.finditer(src):
        if m.group(1) == "interface":
            continue
        b = src.find("{", m.end())
        if b == -1:
            continue
        e = match_block(src, b)
        if e == -1:
            continue
        out.append((m.group(2), src[b + 1:e]))
    return out


def functions_in(body):
    out = []
    for m in re.finditer(r"\bfunction\s+([A-Za-z_]\w*)\s*\(", body):
        d, j = 0, m.end() - 1
        while j < len(body):
            if body[j] == "(":
                d += 1
            elif body[j] == ")":
                d -= 1
                if d == 0:
                    break
            j += 1
        brace = body.find("{", j)
        semi = body.find(";", j)
        if brace == -1 or (semi != -1 and semi < brace):
            continue
        end = match_block(body, brace)
        if end == -1:
            continue
        out.append({"name": m.group(1), "header": body[j + 1:brace],
                    "body": body[brace + 1:end]})
    return out


def state_vars(body, fns):
    spans = []
    for f in fns:
        i = body.find(f["body"])
        if i != -1:
            spans.append((i, i + len(f["body"])))
    names = set()
    for m in re.finditer(
            r"^[ \t]*(mapping\s*\(|u?int\d*|address|bool|bytes\d*|string|"
            r"[A-Z]\w*)[^;=\n]*?\b([A-Za-z_]\w*)\s*(?:=[^;]*)?;", body, re.M):
        if any(a <= m.start() < b for a, b in spans):
            continue
        if m.group(1).split()[0] in ("return", "require", "emit", "revert",
                                     "using", "import"):
            continue
        names.add(m.group(2))
    return names


def writes_in(text, state):
    return {m.group(1) for m in WRITE.finditer(text) if m.group(1) in state}


def loop_bodies(fn_body):
    out = []
    for m in LOOP.finditer(fn_body):
        c = fn_body.find(")", m.end())
        if c == -1:
            continue
        b = fn_body.find("{", c)
        if b == -1 or b - c > 4:
            continue
        e = match_block(fn_body, b)
        if e == -1:
            continue
        out.append(fn_body[b + 1:e])
    return out


def is_exposed(header):
    return bool(re.search(r"\bpublic\b|\bexternal\b", header))


def is_view(header):
    return bool(re.search(r"\bview\b|\bpure\b", header))


def analyse_contract(cname, body):
    """Return the in-scope classification for one contract."""
    fns = functions_in(body)
    if not fns:
        return None
    state = state_vars(body, fns)
    if not state:
        return None

    exposure = []      # (function, kind, writes_after)
    loops = []         # (function, kind, per-iteration writes)

    for fn in fns:
        fb = fn["body"]
        hit = None
        for rx, kind in CALLBACK_RE:
            m = rx.search(fb)
            if m:
                hit = (m, kind)
                break
        if hit:
            m, kind = hit
            after = writes_in(fb[m.end():], state)
            if after and not is_view(fn["header"]):
                exposure.append((fn["name"], kind, after))
        for lb in loop_bodies(fb):
            lm = GAS_FORWARDING.search(lb)
            if not lm:
                continue
            w = writes_in(lb, state)
            if w:
                loops.append((fn["name"], "loop_call", w))

    if not exposure and not loops:
        return None

    # conservative closure: some public/external function WRITES exposed storage
    exposed_storage = set()
    for _, _, w in exposure:
        exposed_storage |= w
    closure = set()
    for fn in fns:
        if not is_exposed(fn["header"]) or is_view(fn["header"]):
            continue
        if writes_in(fn["body"], state) & exposed_storage:
            closure.add(fn["name"])

    # view-observable: a public view reading exposed storage
    views = 0
    for fn in fns:
        if is_view(fn["header"]) and is_exposed(fn["header"]):
            if any(re.search(r"\b%s\b" % re.escape(v), fn["body"])
                   for v in exposed_storage):
                views += 1

    return {
        "contract": cname,
        "exposure_sites": len(exposure),
        "loop_sites": len(loops),
        "closure_size": len(closure),
        "views_observing": views,
        "kinds": "|".join(sorted({k for _, k, _ in exposure} |
                                 {k for _, k, _ in loops})),
        "exposed_vars": "|".join(sorted(exposed_storage)[:8]),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("root")
    ap.add_argument("--out", default="results/scope_scan.csv")
    ap.add_argument("--pragma", default="0.8")
    ap.add_argument("--limit", type=int, default=0)
    args = ap.parse_args()

    allow = None
    if args.pragma != "all":
        allow = set()
        for p in args.pragma.split(","):
            p = p.strip()
            if re.fullmatch(r"\d+\.\d+", p):
                allow.add(p)
            else:
                allow |= {"%s.%d" % (p, i) for i in range(0, 40)}

    files = []
    for dp, _, ns in os.walk(args.root):
        for n in ns:
            if n.endswith(".sol"):
                files.append(os.path.join(dp, n))
    files.sort()
    if args.limit:
        files = files[:args.limit]

    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    rows, seen = [], set()
    scanned = in_pragma = callback_capable = 0
    kinds = collections.Counter()

    for i, p in enumerate(files):
        try:
            raw = open(p, errors="ignore").read()
        except Exception:
            continue
        scanned += 1
        src = strip(raw)
        pm = pragma_major(src)
        if allow and (pm is None or pm not in allow):
            continue
        in_pragma += 1
        if not any(rx.search(src) for rx, _ in CALLBACK_RE):
            continue
        callback_capable += 1
        for cname, body in contracts_in(src):
            rec = analyse_contract(cname, body)
            if not rec:
                continue
            if rec["closure_size"] == 0 and rec["loop_sites"] == 0:
                continue
            h = hashlib.sha1(re.sub(r"\s+", "", body).encode()).hexdigest()
            if h in seen:
                continue
            seen.add(h)
            rec["file"] = os.path.relpath(p)
            rec["pragma"] = pm or ""
            rec["hash"] = h
            rows.append(rec)
            for k in rec["kinds"].split("|"):
                if k:
                    kinds[k] += 1
        if scanned % 20000 == 0:
            print("  %d/%d scanned, %d in scope" % (scanned, len(files),
                                                    len(rows)),
                  file=sys.stderr)

    cols = ["file", "contract", "pragma", "exposure_sites", "loop_sites",
            "closure_size", "views_observing", "kinds", "exposed_vars", "hash"]
    with open(args.out, "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=cols)
        w.writeheader()
        for r in rows:
            w.writerow({c: r.get(c, "") for c in cols})

    print("\nfiles scanned              %d" % scanned)
    print("in pragma range            %d" % in_pragma)
    print("callback-capable           %d" % callback_capable)
    print("IN SCOPE (distinct)        %d" % len(rows))
    print("  with exposure window     %d" %
          sum(1 for r in rows if r["exposure_sites"]))
    print("  with loop site           %d" %
          sum(1 for r in rows if r["loop_sites"]))
    print("  view-observable          %d" %
          sum(1 for r in rows if r["views_observing"]))
    print("\ncallback kind distribution")
    for k, v in kinds.most_common(20):
        print("  %-26s %6d" % (k, v))
    cl = [r["closure_size"] for r in rows]
    if cl:
        cl.sort()
        print("\nclosure size  median %d   p90 %d   max %d" %
              (cl[len(cl)//2], cl[int(len(cl)*0.9)], cl[-1]))
    print("\nwrote %s" % args.out)


if __name__ == "__main__":
    main()
