import argparse
import csv
import hashlib
import os
import re
import sys

PRAGMA = re.compile(r"pragma\s+solidity\s+([^;]+);")
CONTRACT = re.compile(r"\b(contract|library|interface)\s+([A-Za-z_]\w*)")
FUNCTION = re.compile(
    r"\bfunction\s+([A-Za-z_]\w*)\s*\(([^)]*)\)\s*([^{;]*)")
LOOP = re.compile(r"\b(for|while)\s*\(")
STATE_WRITE = re.compile(
    r"([A-Za-z_]\w*)\s*(?:\[[^\]]*\]|\.[A-Za-z_]\w*)*\s*(?:=(?!=)|\+=|-=|\*=|/=)")
GAS_FORWARDING = re.compile(r"\.call\s*\{|\.call\s*\(|\.call\s*\.\s*value\s*\(")
NON_FORWARDING = re.compile(r"\.transfer\s*\(|\.send\s*\(")
DELEGATE = re.compile(r"\.delegatecall\s*\(|\.staticcall\s*\(")
CALLBACK_HOOK = re.compile(
    r"\.on[A-Z]\w*\s*\(|\.tokensReceived\s*\(|\.executeOperation\s*\(|"
    r"\.onFlashLoan\s*\(|\.notify[A-Z]\w*\s*\(")
LINE_COMMENT = re.compile(r"//[^\n]*")
BLOCK_COMMENT = re.compile(r"/\*.*?\*/", re.S)
STRING_LIT = re.compile(r'"(?:[^"\\]|\\.)*"|\'(?:[^\'\\]|\\.)*\'')


def strip_noise(src):
    src = BLOCK_COMMENT.sub(" ", src)
    src = LINE_COMMENT.sub(" ", src)
    return STRING_LIT.sub('""', src)


def match_block(src, open_idx):
    depth = 0
    for i in range(open_idx, len(src)):
        c = src[i]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return i
    return -1


def pragma_major(src):
    m = PRAGMA.search(src)
    if not m:
        return None
    v = m.group(1)
    hits = re.findall(r"(\d+)\.(\d+)", v)
    if not hits:
        return None
    return ".".join(hits[0])


def split_contracts(src):
    out = []
    for m in CONTRACT.finditer(src):
        brace = src.find("{", m.end())
        if brace == -1:
            continue
        end = match_block(src, brace)
        if end == -1:
            continue
        out.append((m.group(1), m.group(2), src[brace + 1:end]))
    return out


def split_functions(body):
    out = []
    for m in FUNCTION.finditer(body):
        header = m.group(3)
        brace = body.find("{", m.end())
        semi = body.find(";", m.end())
        if brace == -1 or (semi != -1 and semi < brace):
            continue
        end = match_block(body, brace)
        if end == -1:
            continue
        out.append({
            "name": m.group(1),
            "params": m.group(2),
            "header": header,
            "body": body[brace + 1:end],
        })
    return out


def state_vars(body, functions):
    spans = []
    for f in functions:
        idx = body.find(f["body"])
        if idx != -1:
            spans.append((idx, idx + len(f["body"])))
    names = set()
    for m in re.finditer(
            r"^\s*(mapping\s*\([^;]*?\)|[A-Za-z_]\w*(?:\s*\[\s*\])?)\s+"
            r"(?:public\s+|private\s+|internal\s+|constant\s+|immutable\s+)*"
            r"([A-Za-z_]\w*)\s*(?:=[^;]*)?;", body, re.M):
        pos = m.start()
        if any(a <= pos < b for a, b in spans):
            continue
        kw = m.group(1).split()[0]
        if kw in ("return", "require", "emit", "revert", "using", "import"):
            continue
        names.add(m.group(2))
    return names


def writes_in(text, state):
    return {m.group(1) for m in STATE_WRITE.finditer(text) if m.group(1) in state}


def reads_in(text, state):
    return {v for v in state if re.search(r"\b%s\b" % re.escape(v), text)}


def loop_bodies(fn_body):
    out = []
    for m in LOOP.finditer(fn_body):
        close = fn_body.find(")", m.end())
        if close == -1:
            continue
        brace = fn_body.find("{", close)
        if brace == -1 or brace - close > 4:
            continue
        end = match_block(fn_body, brace)
        if end == -1:
            continue
        out.append(fn_body[brace + 1:end])
    return out


def is_view(header):
    return bool(re.search(r"\bview\b|\bpure\b", header))


def is_exposed(header):
    return bool(re.search(r"\bpublic\b|\bexternal\b", header))


def scan_loop(cname, fn, state):
    hits = []
    for lb in loop_bodies(fn["body"]):
        call = GAS_FORWARDING.search(lb) or CALLBACK_HOOK.search(lb)
        if not call:
            continue
        if DELEGATE.search(lb) and not GAS_FORWARDING.search(lb):
            continue
        pre = lb[:call.start()]
        post = lb[call.end():]
        w_pre = writes_in(pre, state)
        w_post = writes_in(post, state)
        hits.append({
            "contract": cname,
            "function": fn["name"],
            "kind": "loop",
            "call": lb[call.start():call.start() + 24].strip(),
            "writes_before": "|".join(sorted(w_pre)),
            "writes_after": "|".join(sorted(w_post)),
            "shape": "effect_after_call" if w_post else
                     ("effect_before_call" if w_pre else "no_effect"),
        })
    return hits


def scan_readonly(cname, functions, state):
    sites = []
    for fn in functions:
        if is_view(fn["header"]) or not is_exposed(fn["header"]):
            continue
        call = GAS_FORWARDING.search(fn["body"]) or CALLBACK_HOOK.search(fn["body"])
        if not call:
            continue
        after = writes_in(fn["body"][call.end():], state)
        if after:
            sites.append((fn["name"], after))
    if not sites:
        return []
    hits = []
    for fn in functions:
        if not (is_view(fn["header"]) and is_exposed(fn["header"])):
            continue
        r = reads_in(fn["body"], state)
        if not r:
            continue
        for site_fn, desynced in sites:
            shared = r & desynced
            if not shared:
                continue
            hits.append({
                "contract": cname,
                "function": fn["name"],
                "kind": "readonly",
                "call": site_fn,
                "writes_before": "",
                "writes_after": "|".join(sorted(shared)),
                "shape": "view_reads_desynced",
            })
            break
    return hits


def norm_hash(body):
    return hashlib.sha1(re.sub(r"\s+", "", body).encode()).hexdigest()


def scan_file(path, allow_pragma):
    try:
        raw = open(path, errors="ignore").read()
    except Exception:
        return [], None
    src = strip_noise(raw)
    pm = pragma_major(src)
    if allow_pragma and (pm is None or pm not in allow_pragma):
        return [], pm
    rows = []
    for kind, cname, body in split_contracts(src):
        if kind == "interface":
            continue
        fns = split_functions(body)
        if not fns:
            continue
        st = state_vars(body, fns)
        if not st:
            continue
        h = norm_hash(body)
        found = []
        for fn in fns:
            found += scan_loop(cname, fn, st)
        found += scan_readonly(cname, fns, st)
        for r in found:
            r["file"] = os.path.relpath(path)
            r["pragma"] = pm or ""
            r["hash"] = h
            rows.append(r)
    return rows, pm


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("root")
    ap.add_argument("--out", default="results/scan_sanctuary.csv")
    ap.add_argument("--pragma", default="0.8",
                    help="comma-separated major.minor prefixes, or 'all'")
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
                allow |= {f"{p}.{i}" for i in range(0, 40)}

    files = []
    for dirpath, _, names in os.walk(args.root):
        for n in names:
            if n.endswith(".sol"):
                files.append(os.path.join(dirpath, n))
    files.sort()
    if args.limit:
        files = files[:args.limit]

    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    seen = set()
    kept = []
    scanned = in_range = 0
    pragma_hist = {}

    for i, p in enumerate(files):
        rows, pm = scan_file(p, allow)
        scanned += 1
        if pm:
            pragma_hist[pm] = pragma_hist.get(pm, 0) + 1
        if rows:
            in_range += 1
        for r in rows:
            key = (r["hash"], r["kind"], r["function"])
            if key in seen:
                continue
            seen.add(key)
            kept.append(r)
        if scanned % 5000 == 0:
            print(f"  {scanned}/{len(files)} files, {len(kept)} unique hits",
                  file=sys.stderr)

    cols = ["file", "contract", "function", "kind", "call", "pragma",
            "writes_before", "writes_after", "shape", "hash"]
    with open(args.out, "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=cols)
        w.writeheader()
        for r in kept:
            w.writerow({c: r.get(c, "") for c in cols})

    loops = [r for r in kept if r["kind"] == "loop"]
    ro = [r for r in kept if r["kind"] == "readonly"]
    loop_c = len({r["hash"] for r in loops})
    ro_c = len({r["hash"] for r in ro})
    genuine = [r for r in loops if r["shape"] == "effect_after_call"]

    print(f"files scanned           {scanned}")
    print(f"unique hits             {len(kept)}")
    print(f"loop sites              {len(loops)}  ({loop_c} distinct contracts)")
    print(f"  effect after call     {len(genuine)}")
    print(f"  effect before call    {len([r for r in loops if r['shape'] == 'effect_before_call'])}")
    print(f"  no state effect       {len([r for r in loops if r['shape'] == 'no_effect'])}")
    print(f"read-only sites         {len(ro)}  ({ro_c} distinct contracts)")
    print(f"wrote                   {args.out}")
    top = sorted(pragma_hist.items(), key=lambda x: -x[1])[:8]
    if top:
        print("pragma histogram        " +
              "  ".join(f"{k}:{v}" for k, v in top))


if __name__ == "__main__":
    main()
