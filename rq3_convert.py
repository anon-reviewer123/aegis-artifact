#!/usr/bin/env python3
"""Convert prose target relations into formulas a verifier can check.

Annotators described each contract's intended relation in their own words, and
many wrote prose -- `LAST_SUPPLY == the token supply already paid through
completed withdrawal stages` -- which no verifier can take as a property. This
asks a model to restate each one as a formula, under three safeguards that keep
the property the annotator's rather than the model's:

  1. The output is constrained. The model must answer with a JSON object and a
     formula drawn from a fixed grammar: this contract's storage variables,
     `_sum_<m>` for its single-level mappings, integer literals,
     `address(this).balance`, comparison and arithmetic operators. No function
     calls, no free variables, no prose, no temporal phrasing. It may -- and is
     told to -- answer `expressible: false` when no such formula states the
     relation faithfully.

  2. The formula is checked by a parser, not trusted. Anything outside the
     grammar is rejected here and never run.

  3. A person confirms it. The output is a review sheet with the prose and the
     proposed formula side by side and a `confirm` column; only rows marked
     `yes` are used. Confirmation must be done before running the tool and
     without looking at any verdict.

  python3 rq3_convert.py
  python3 rq3_convert.py --apply     # fold confirmed rows into the targets

Model: AEGIS_CONVERT_MODEL (default gpt-4o), at temperature 0. Using a
different model from the proof proposer (AEGIS_OPENAI_MODEL) avoids the same
model writing both the property and the proof.
"""
import argparse
import csv
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

SYSTEM = """You translate an informal description of a smart contract's \
intended invariant into a formal expression, or report that it cannot be \
expressed.

Respond with ONLY a JSON object, nothing else:
  {"expressible": true|false, "formula": "<expression or empty>", \
"reason": "<one short sentence>"}

The formula must be a single boolean expression built ONLY from:
  - the storage variable names listed, exactly as spelled
  - _sum_<m>, meaning the sum of all values of mapping m, for a mapping m
    listed as single-level with an integer value
  - m[address(this)] for a listed mapping m
  - integer literals, optionally followed by ether, gwei or wei
  - address(this).balance
  - operators: == != <= >= < > + - * / % && || ! and parentheses
  - true, false

It must NOT contain function calls, free variables such as `account` or \
`i`, quantifiers, the words before or after, or any prose.

Answer expressible=false when:
  - the relation is about ordering in time ("after X happens", "while an \
auction is open")
  - it is about each user or each index separately rather than a single \
global quantity
  - it needs a quantity the contract does not store
  - you would have to guess at, or change, what the description says

Do not invent a relation. Only restate the one described. If in doubt, \
answer expressible=false."""

_TOK = re.compile(
    r"\s*(address\(this\)\.balance|address\(this\)|==|!=|<=|>=|&&|\|\||"
    r"[<>+\-*/%()!\[\]]|\d+(?:\.\d+)?(?:e\d+)?|[A-Za-z_]\w*)")
_UNITS = {"ether", "gwei", "wei"}


def allowed_names(facts, src):
    """Identifiers a formula may use for this contract, and its mappings."""
    storage = set(facts.storage_vars)
    maps = {v for v in storage
            if (facts.var_types.get(v, "") or "").startswith("mapping")}
    for m in re.finditer(r"\bmapping\s*\([^;]*?\)\s*(?:public\s+|private\s+|"
                         r"internal\s+)*([A-Za-z_]\w*)\s*;", src):
        if m.group(1) in storage:
            maps.add(m.group(1))
    scalars = storage - maps
    return storage, scalars, maps


def check_formula(formula, storage, maps):
    """None if the formula is inside the grammar, otherwise the reason."""
    f = formula.strip()
    if not f:
        return "empty"
    pos, toks = 0, []
    while pos < len(f):
        m = _TOK.match(f, pos)
        if not m or m.end() == pos:
            return f"unrecognised text at `{f[pos:pos + 15]}`"
        toks.append(m.group(1))
        pos = m.end()
    for i, t in enumerate(toks):
        if re.fullmatch(r"[A-Za-z_]\w*", t):
            if t in ("true", "false") or t in _UNITS:
                continue
            if t.startswith("_sum_") and t[5:] in maps:
                continue
            if t in storage:
                if t in maps and not (i + 1 < len(toks) and toks[i + 1] == "["):
                    return f"mapping `{t}` used without an index"
                continue
            return f"`{t}` is not a storage variable of this contract"
        if t == "(" and i > 0 and re.fullmatch(r"[A-Za-z_]\w*", toks[i - 1]) \
                and toks[i - 1] not in ("true", "false"):
            return f"function call `{toks[i - 1]}(...)`"
    # an index may only be address(this) or a literal: a free variable would
    # make the formula a family of properties, not one invariant
    for m in re.finditer(r"\[([^\]]*)\]", f):
        inner = m.group(1).strip()
        if inner != "address(this)" and not re.fullmatch(r"\d+", inner):
            return f"index `{inner}` is a free variable"
    depth = 0
    for t in toks:
        depth += t == "("
        depth -= t == ")"
        if depth < 0:
            return "unbalanced parentheses"
    return None if depth == 0 else "unbalanced parentheses"


def ask(client, model, prose, contract, scalars, maps, types):
    lines = [f"Contract: {contract}",
             f"Informal description: {prose}", "",
             "Storage variables you may use:"]
    for v in sorted(scalars):
        lines.append(f"  {v}  ({types.get(v, '?')})")
    for v in sorted(maps):
        lines.append(f"  {v}  ({types.get(v, 'mapping')}) -- mapping; "
                     f"use _sum_{v} or {v}[address(this)]")
    resp = client.chat.completions.create(
        model=model, temperature=0,
        response_format={"type": "json_object"},
        messages=[{"role": "system", "content": SYSTEM},
                  {"role": "user", "content": "\n".join(lines)}])
    return json.loads(resp.choices[0].message.content)


FIELDS = ["contract", "path", "prose_target", "formula", "model_says",
          "grammar_check", "reason", "confirm"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--targets", default="results/rq3_formal_targets.csv")
    ap.add_argument("--out", default="results/rq3_converted_targets.csv")
    ap.add_argument("--apply", action="store_true",
                    help="fold rows marked confirm=yes into --targets")
    args = ap.parse_args()

    tpath = os.path.join(HERE, args.targets)
    opath = os.path.join(HERE, args.out)

    if args.apply:
        conv = {r["path"]: r for r in csv.DictReader(open(opath))
                if (r.get("confirm") or "").strip().lower() == "yes"
                and r.get("grammar_check") == "ok"}
        rows = list(csv.DictReader(open(tpath)))
        n = 0
        for r in rows:
            c = conv.get(r["path"])
            if c and r["status"] == "not_expressible":
                r["target_formal"] = c["formula"]
                r["status"] = "auto"
                r["note"] = "converted from prose and confirmed by annotator"
                n += 1
        with open(tpath, "w", newline="") as fh:
            w = csv.DictWriter(fh, fieldnames=list(rows[0]))
            w.writeheader()
            w.writerows(rows)
        print(f"applied {n} confirmed conversion(s) to {args.targets}")
        return

    from openai import OpenAI
    from aegis import static_analysis
    client = OpenAI(api_key=os.environ["OPENAI_API_KEY"])
    model = os.environ.get("AEGIS_CONVERT_MODEL", "gpt-4o")

    todo = [r for r in csv.DictReader(open(tpath))
            if r["status"] == "not_expressible"]
    print(f"{len(todo)} prose target(s) to convert with {model}")
    out = []
    for r in todo:
        try:
            facts = static_analysis.analyze(r["path"])
            src = open(r["path"]).read()
            storage, scalars, maps = allowed_names(facts, src)
            ans = ask(client, model, r["target"], r["contract"], scalars,
                      maps, facts.var_types)
        except Exception as exc:
            out.append(dict(contract=r["contract"], path=r["path"],
                            prose_target=r["target"], formula="",
                            model_says="error", grammar_check="",
                            reason=str(exc)[:120], confirm=""))
            continue
        formula = (ans.get("formula") or "").strip()
        says = "expressible" if ans.get("expressible") else "not expressible"
        check = (check_formula(formula, storage, maps)
                 if ans.get("expressible") else "")
        out.append(dict(contract=r["contract"], path=r["path"],
                        prose_target=r["target"], formula=formula,
                        model_says=says,
                        grammar_check="ok" if (says == "expressible" and
                                               check is None)
                        else (check or "-"),
                        reason=(ans.get("reason") or "")[:160], confirm=""))
        print(f"  {r['contract'][:26]:26s} {says:16s} "
              f"{formula[:50] if says == 'expressible' else ''}")

    with open(opath, "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=FIELDS)
        w.writeheader()
        w.writerows(out)

    ok = sum(1 for r in out if r["grammar_check"] == "ok")
    print(f"\n{ok} of {len(out)} passed the grammar check")
    print(f"wrote {args.out}")
    print("\nnext: open it, and for each row with grammar_check=ok put `yes` "
          "in `confirm`\n      ONLY if the formula says what the prose says. "
          "Then: python3 rq3_convert.py --apply")


if __name__ == "__main__":
    main()
