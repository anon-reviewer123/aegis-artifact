import argparse
import collections
import csv
import hashlib
import os
import re
import sys

CALLBACK_PATTERNS = [
    (r"\.onAssetReceived\s*\(", "erc777_hook", True),
    (r"\.tokensReceived\s*\(", "erc777_hook", True),
    (r"\.onTokensReceived\s*\(", "token_hook", True),
    (r"\.onERC1155Received\s*\(", "erc1155_hook", True),
    (r"\.onERC1155BatchReceived\s*\(", "erc1155_hook", True),
    (r"\.onERC721Received\s*\(", "erc721_hook", True),
    (r"\.call\s*\{", "low_level_call", True),
    (r"\.call\s*\(", "low_level_call", True),
    (r"\.executeOperation\s*\(", "flashloan", True),
    (r"\.onFlashLoan\s*\(", "flashloan", True),
    (r"\.onCallback\s*\(", "generic_callback", True),
    (r"\.on[A-Z]\w*Received\s*\(", "generic_hook", True),
    (r"\.on[A-Z]\w*Hook\s*\(", "generic_hook", True),
    (r"\.notify[A-Z]\w*\s*\(", "notify_hook", True),
    (r"\.on[A-Z]\w*\s*\(", "generic_hook", True),
    (r"\.send\s*\(", "send", False),
    (r"\.transfer\s*\(", "transfer", False),
]
CB = [(re.compile(p), n, g) for p, n, g in CALLBACK_PATTERNS]

LOOP = re.compile(r"\b(for|while)\s*\(")
GAS_FWD = re.compile(r"\.call\s*\{|\.call\s*\(|\.call\s*\.\s*value\s*\(")
WRITE = re.compile(
    r"([A-Za-z_]\w*)\s*(?:\[[^\]]*\]|\.[A-Za-z_]\w*)*\s*(?:=(?!=)|\+=|-=|\*=|/=)")
LINE_C = re.compile(r"//[^\n]*")
BLOCK_C = re.compile(r"/\*.*?\*/", re.S)
STR_L = re.compile(r'"(?:[^"\\]|\\.)*"|\'(?:[^\'\\]|\\.)*\'')
CONTRACT = re.compile(r"\b(contract|library|interface)\s+([A-Za-z_]\w*)")
PRAGMA = re.compile(r"pragma\s+solidity\s+([^;]+);")

NUMERIC = re.compile(r"^u?int\d*$")
EOA_GUARD = re.compile(r"msg\.sender\s*==\s*tx\.origin|tx\.origin\s*==\s*msg\.sender"
                       r"|extcodesize\s*\(")
REQUIRE_OK = re.compile(r"require\s*\(\s*(?:ok|success|sent|s)\b|"
                        r"require\s*\(\s*\w*[Ss]uccess")


def strip(s):
    s = BLOCK_C.sub(" ", s)
    s = LINE_C.sub(" ", s)
    return STR_L.sub('""', s)


def block_end(s, i):
    d = 0
    for j in range(i, len(s)):
        if s[j] == "{":
            d += 1
        elif s[j] == "}":
            d -= 1
            if d == 0:
                return j
    return -1


def pragma_major(s):
    m = PRAGMA.search(s)
    if not m:
        return None
    h = re.findall(r"(\d+)\.(\d+)", m.group(1))
    return ".".join(h[0]) if h else None


def contracts_in(s):
    out = []
    for m in CONTRACT.finditer(s):
        if m.group(1) == "interface":
            continue
        b = s.find("{", m.end())
        if b == -1:
            continue
        e = block_end(s, b)
        if e != -1:
            out.append((m.group(2), s[b + 1:e]))
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
        br = body.find("{", j)
        sc = body.find(";", j)
        if br == -1 or (sc != -1 and sc < br):
            continue
        e = block_end(body, br)
        if e == -1:
            continue
        out.append({"name": m.group(1), "header": body[j + 1:br],
                    "body": body[br + 1:e]})
    return out


def state_types(body, fns):
    """name -> declared type for contract-level storage."""
    spans = []
    for f in fns:
        i = body.find(f["body"])
        if i != -1:
            spans.append((i, i + len(f["body"])))
    out = {}
    for m in re.finditer(
            r"^[ \t]*(mapping\s*\([^;]*?\)|u?int\d*|address(?:\s+payable)?|"
            r"bool|bytes\d*|string|[A-Z]\w*)((?:\s*\[[^\]]*\])*)"
            r"((?:\s+(?:public|private|internal|override))*)"
            r"\s+([A-Za-z_]\w*)\s*(?:=[^;]*)?;", body, re.M):
        if any(a <= m.start() < b for a, b in spans):
            continue
        out[m.group(4)] = (m.group(1) + m.group(2)).strip()
    return out


def is_numeric_type(t):
    t = t.strip()
    if NUMERIC.match(t):
        return True
    if t == "bool":
        return True
    if t.startswith("mapping"):
        inner = t[t.rfind("=>") + 2:].strip().rstrip(")").strip()
        return bool(NUMERIC.match(inner)) or inner == "bool"
    return False


def writes_in(txt, state):
    return {m.group(1) for m in WRITE.finditer(txt) if m.group(1) in state}


def nonlinear_on(txt, vars_):
    """True when an exposed variable participates in multiplication/division."""
    for v in vars_:
        if re.search(r"\b%s\b\s*[*/]|[*/]\s*\b%s\b" % (re.escape(v),
                                                       re.escape(v)), txt):
            return True
        if re.search(r"\b%s\s*\[[^\]]*\]\s*[*/]" % re.escape(v), txt):
            return True
    return False


def loop_bodies(fb):
    out = []
    for m in LOOP.finditer(fb):
        c = fb.find(")", m.end())
        if c == -1:
            continue
        b = fb.find("{", c)
        if b == -1 or b - c > 4:
            continue
        e = block_end(fb, b)
        if e != -1:
            out.append(fb[b + 1:e])
    return out


def exposed(h):
    return bool(re.search(r"\bpublic\b|\bexternal\b", h))


def view(h):
    return bool(re.search(r"\bview\b|\bpure\b", h))


def classify(cname, body):
    fns = functions_in(body)
    if not fns:
        return None
    st = state_types(body, fns)
    if not st:
        return None
    names = set(st)

    sites = []
    loops = []
    for fn in fns:
        fb = fn["body"]
        if view(fn["header"]):
            continue
        hit = None
        for rx, kind, gas in CB:
            m = rx.search(fb)
            if m:
                hit = (m, kind, gas)
                break
        if hit:
            m, kind, gas = hit
            after = writes_in(fb[m.end():], names)
            before = writes_in(fb[:m.start()], names)
            if after:
                sites.append({"fn": fn["name"], "kind": kind, "gas": gas,
                              "after": after, "before": before,
                              "body": fb, "header": fn["header"]})
        for lb in loop_bodies(fb):
            if GAS_FWD.search(lb) and writes_in(lb, names):
                loops.append({"fn": fn["name"], "body": lb})

    if not sites and not loops:
        return None

    exp_vars = set()
    for s in sites:
        exp_vars |= s["after"]

    closure = set()
    for fn in fns:
        if not exposed(fn["header"]) or view(fn["header"]):
            continue
        if writes_in(fn["body"], names) & exp_vars:
            closure.add(fn["name"])

    if not closure and not loops:
        return None

    # template expressibility: exposed state must be numeric or boolean
    typed = [st.get(v, "") for v in exp_vars]
    expressible = bool(exp_vars) and all(is_numeric_type(t) for t in typed)
    linear = not any(nonlinear_on(s["body"], s["after"]) for s in sites)
    gas_fwd = any(s["gas"] for s in sites) or bool(loops)

    fam = set()
    if loops:
        fam.add("in_loop_call")
    for s in sites:
        if s["fn"] in closure:
            fam.add("classic_reentrancy")
        if closure - {s["fn"]}:
            fam.add("cross_function")
        if s["kind"] in ("erc777_hook", "token_hook", "erc721_hook",
                         "erc1155_hook"):
            fam.add("token_hook")
        if s["kind"] == "flashloan":
            fam.add("flash_loan")
        if REQUIRE_OK.search(s["body"]):
            fam.add("forced_revert")
        if EOA_GUARD.search(s["body"]):
            fam.add("eoa_assumption")
        for v in s["after"] | s["before"]:
            if st.get(v, "") == "bool" and v in s["before"] and v in s["after"]:
                fam.add("phase_ordering")
    for fn in fns:
        if view(fn["header"]) and exposed(fn["header"]):
            if any(re.search(r"\b%s\b" % re.escape(v), fn["body"])
                   for v in exp_vars):
                fam.add("read_only")
                break
    if not fam:
        fam.add("deferred_update")

    return {
        "contract": cname, "sites": len(sites), "loops": len(loops),
        "closure": len(closure), "gas_forwarding": int(gas_fwd),
        "expressible": int(expressible), "linear": int(linear),
        "families": "|".join(sorted(fam)),
        "exposed_vars": "|".join(sorted(exp_vars)[:6]),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("root")
    ap.add_argument("--out", default="results/scope_full.csv")
    ap.add_argument("--pragma", default="0.8")
    ap.add_argument("--limit", type=int, default=0)
    args = ap.parse_args()

    allow = None
    if args.pragma != "all":
        allow = set()
        for p in args.pragma.split(","):
            p = p.strip()
            allow |= ({p} if re.fullmatch(r"\d+\.\d+", p)
                      else {"%s.%d" % (p, i) for i in range(40)})

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
    scanned = inrange = cbcap = 0

    for p in files:
        try:
            raw = open(p, errors="ignore").read()
        except Exception:
            continue
        scanned += 1
        src = strip(raw)
        pm = pragma_major(src)
        if allow and (pm is None or pm not in allow):
            continue
        inrange += 1
        if not any(rx.search(src) for rx, _, _ in CB):
            continue
        cbcap += 1
        for cname, body in contracts_in(src):
            rec = classify(cname, body)
            if not rec:
                continue
            h = hashlib.sha1(re.sub(r"\s+", "", body).encode()).hexdigest()
            if h in seen:
                continue
            seen.add(h)
            rec["file"] = os.path.relpath(p)
            rec["pragma"] = pm or ""
            rec["hash"] = h
            rows.append(rec)
        if scanned % 25000 == 0:
            print("  %d/%d  in-scope %d" % (scanned, len(files), len(rows)),
                  file=sys.stderr)

    cols = ["file", "contract", "pragma", "sites", "loops", "closure",
            "gas_forwarding", "expressible", "linear", "families",
            "exposed_vars", "hash"]
    with open(args.out, "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=cols)
        w.writeheader()
        for r in rows:
            w.writerow({c: r.get(c, "") for c in cols})

    ver = [r for r in rows if r["gas_forwarding"] and r["expressible"]
           and r["linear"]]
    fam = collections.Counter()
    famv = collections.Counter()
    for r in rows:
        for f in r["families"].split("|"):
            fam[f] += 1
    for r in ver:
        for f in r["families"].split("|"):
            famv[f] += 1

    print("\nfiles scanned                 %d" % scanned)
    print("in pragma range               %d" % inrange)
    print("callback-capable              %d" % cbcap)
    print("exposed window + closure      %d" % len(rows))
    print("  gas-forwarding              %d" %
          sum(1 for r in rows if r["gas_forwarding"]))
    print("  template-expressible        %d" %
          sum(1 for r in rows if r["expressible"]))
    print("  linear arithmetic           %d" %
          sum(1 for r in rows if r["linear"]))
    print("\nVERIFIABLE SCOPE (all three)  %d" % len(ver))
    print("\nfamily            in-scope   verifiable")
    for f, c in fam.most_common():
        print("  %-20s %6d     %6d" % (f, c, famv.get(f, 0)))
    print("\nwrote %s" % args.out)


if __name__ == "__main__":
    main()
