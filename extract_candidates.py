import argparse
import csv
import os
import re
import sys


def match_block(src, open_idx):
    depth = 0
    for i in range(open_idx, len(src)):
        if src[i] == "{":
            depth += 1
        elif src[i] == "}":
            depth -= 1
            if depth == 0:
                return i
    return -1


def contract_body(src, name):
    for m in re.finditer(r"\b(?:abstract\s+)?(?:contract|library)\s+" +
                         re.escape(name) + r"\b[^{]*\{", src):
        end = match_block(src, m.end() - 1)
        if end != -1:
            return src[m.end():end]
    return ""


def find_function(body, name):
    for m in re.finditer(r"function\s+" + re.escape(name) + r"\s*\(", body):
        brace = body.find("{", m.end())
        semi = body.find(";", m.end())
        if brace == -1 or (semi != -1 and semi < brace):
            continue
        end = match_block(body, brace)
        if end != -1:
            return body[m.start():end + 1]
    return ""


def state_decls(body):
    out = []
    for line in body.splitlines():
        s = line.strip()
        if not s or s.startswith("//") or s.startswith("*"):
            continue
        if re.match(r"^(mapping\s*\(|uint|int|address|bool|bytes|string|"
                    r"[A-Z]\w*(\[\])?)\s+[\w\s]*;$", s) and "function" not in s:
            out.append("    " + s)
        if len(out) > 30:
            break
    return "\n".join(out)


def views_reading(body, vars_):
    out = []
    for m in re.finditer(r"function\s+(\w+)\s*\([^)]*\)\s*([^{;]*)\{", body):
        header = m.group(2)
        if "view" not in header and "pure" not in header:
            continue
        if "public" not in header and "external" not in header:
            continue
        end = match_block(body, m.end() - 1)
        if end == -1:
            continue
        fn = body[m.start():end + 1]
        if any(re.search(r"\b%s\b" % re.escape(v), fn) for v in vars_):
            out.append(fn)
        if len(out) >= 2:
            break
    return out


def clip(text, limit):
    lines = text.splitlines()
    if len(lines) <= limit:
        return text
    return "\n".join(lines[:limit]) + f"\n    ... [{len(lines)-limit} more lines]"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("scan_csv")
    ap.add_argument("--kind", choices=["loop", "readonly"], required=True)
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--max-lines", type=int, default=60)
    ap.add_argument("--out", default="")
    args = ap.parse_args()

    rows = [r for r in csv.DictReader(open(args.scan_csv))
            if r["kind"] == args.kind]
    if args.kind == "loop":
        rows = [r for r in rows if r["shape"] != "no_effect"]
    seen, uniq = set(), []
    for r in rows:
        if r["hash"] in seen:
            continue
        seen.add(r["hash"])
        uniq.append(r)
    if args.limit:
        uniq = uniq[:args.limit]

    out = args.out or f"results/review_{args.kind}.md"
    os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
    fh = open(out, "w")
    fh.write(f"# {args.kind} candidates for manual scope review\n")
    fh.write(f"source: {args.scan_csv} | {len(uniq)} distinct\n\n")

    for i, r in enumerate(uniq, 1):
        try:
            src = open(r["file"], errors="ignore").read()
        except Exception as e:
            fh.write(f"## {i}. {r['contract']} -- READ ERROR {e}\n\n")
            continue
        body = contract_body(src, r["contract"])
        # For read-only rows the scanner stores the VIEW in `function` and the
        # function performing the external call in `call`; the exposure site is
        # the latter.
        expo_name = (r.get("call") or r["function"]) if args.kind == "readonly" \
            else r["function"]
        fn = find_function(body, expo_name) if body else ""
        if args.kind == "readonly":
            fh.write(f"## {i}. {r['contract']}: "
                     f"{r.get('call','?')}() -> view {r['function']}()\n")
        else:
            fh.write(f"## {i}. {r['contract']}.{r['function']}\n")
        fh.write(f"- file: `{os.path.basename(r['file'])}`\n")
        fh.write(f"- pragma: {r.get('pragma','')} | shape: {r.get('shape','')}\n")
        fh.write(f"- writes_before: {r.get('writes_before','')}\n")
        fh.write(f"- writes_after: {r.get('writes_after','')}\n\n")
        st = state_decls(body)
        if st:
            fh.write("state:\n```solidity\n" + clip(st, 20) + "\n```\n\n")
        if fn:
            label = ("loop function" if args.kind == "loop"
                     else "exposure function")
            fh.write(f"{label}:\n```solidity\n" +
                     clip(fn, args.max_lines) + "\n```\n\n")
        else:
            fh.write(f"_function `{expo_name}` not located in "
                     f"`{r['contract']}`_\n\n")
        if args.kind == "readonly":
            vs = [v for v in (r.get("writes_after") or "").split("|") if v]
            v_only = find_function(body, r["function"])
            if v_only:
                fh.write("flagged view:\n```solidity\n" +
                         clip(v_only, 30) + "\n```\n\n")
            for v_fn in []:
                fh.write("view reading desynced state:\n```solidity\n" +
                         clip(v_fn, 30) + "\n```\n\n")
        fh.write("---\n\n")

    fh.close()
    print(f"wrote {out} ({os.path.getsize(out)//1024} KB, {len(uniq)} entries)")


if __name__ == "__main__":
    main()
