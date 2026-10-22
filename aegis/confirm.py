"""
confirm.py - reproduce a bug candidate on the original contract.

An assume-guarantee refutation is not a bug witness. A failed callback or
post-phase obligation says that some state satisfying the exposure invariant
breaks the property; when that invariant is not what the contract actually
reaches at the call -- and on deployed code it usually is not -- the state may
be one the contract never enters. So a refutation is treated as a candidate,
and reported as a bug only when this module reproduces it on the contract
itself, not the harness.

It runs the target property on the original source twice, with external calls
untrusted so a callback may call back in:

  blocked   every function of the target contract refuses to be entered while
            another is running, so no callback can re-enter it
  open      nesting allowed, except for privileged functions, which a callback
            may never re-enter -- the trust assumption the closure also makes

If the property fails when blocked, it is not an invariant of the contract even
without callbacks, and no reentrancy bug is claimed. If it holds when blocked
and fails when open, the violation needs a callback: confirmed.

The property is asserted by a view function at depth zero only, between
transactions. Asserting it mid-transaction would flag the torn state a safe
contract passes through inside its own window.

A mapping sum `_sum_<m>` in the property is tracked by a ghost declared in the
contract that owns the mapping and updated inside every statement writing it,
as one block with the write, so a write under a brace-less `if` updates the sum
under the same guard.
"""
from __future__ import annotations

import re

VERDICTS = ("confirmed", "not_reproduced", "not_invariant", "undecided")


def _contracts(src):
    out = []
    for m in re.finditer(r"(?<![\w.])(abstract\s+)?(contract|library|interface)\s+"
                         r"([A-Za-z_]\w*)[^{;]*\{", src):
        start = m.end()
        depth, i = 1, start
        while i < len(src) and depth:
            depth += src[i] == "{"
            depth -= src[i] == "}"
            i += 1
        out.append((m.group(3), m.group(2), start, i - 1))
    return out


def _span(src, name):
    spans = [c for c in _contracts(src) if c[0] == name and c[1] == "contract"]
    return spans[-1] if spans else None


_IX = r"\[(?:[^\[\]]|\[[^\[\]]*\])+\]"


def instrument_sum(body: str, m: str, ghost: str) -> str:
    """Wrap every statement writing m[...] in a block that also moves ghost."""
    em = re.escape(m)

    def plus(x):
        return f"{{ {x.group(0)} {ghost} += {x.group(1)}; }}"

    def minus(x):
        return f"{{ {x.group(0)} {ghost} -= {x.group(1)}; }}"

    def assign(x):
        lhs = x.group(1)
        return (f"{{ uint256 __p = {lhs}; {x.group(0)} "
                f"{ghost} = {ghost} - __p + {lhs}; }}")

    def incdec(x):
        op = "+=" if x.group(2) == "++" else "-="
        return f"{{ {x.group(0)} {ghost} {op} 1; }}"

    def delete(x):
        return f"{{ {ghost} -= {x.group(1)}; {x.group(0)} }}"

    body = re.sub(rf"\b{em}\s*{_IX}\s*\+=\s*([^;]+);", plus, body)
    body = re.sub(rf"\b{em}\s*{_IX}\s*-=\s*([^;]+);", minus, body)
    body = re.sub(rf"(\b{em}\s*{_IX})\s*=(?!=)\s*[^;]+;", assign, body)
    body = re.sub(rf"(\b{em}\s*{_IX})\s*(\+\+|--)\s*;", incdec, body)
    body = re.sub(rf"\bdelete\s+(\b{em}\s*{_IX})\s*;", delete, body)
    return body


def _declaring_contract(src, m):
    for name, kind, s, e in _contracts(src):
        if kind != "contract":
            continue
        if re.search(rf"\bmapping\s*\((?:[^()]|\([^()]*\))*\)\s*"
                     rf"(?:\w+\s+)*{re.escape(m)}\s*;", src[s:e]):
            return name
    return None


def _edit_contract(src, name, fn):
    sp = _span(src, name)
    if sp is None:
        return src
    _n, _k, s, e = sp
    return src[:s] + fn(src[s:e]) + src[e:]


def _add_modifiers(body: str, privileged, block_all: bool) -> str:
    def repl(x):
        name, tail = x.group(1), x.group(3)
        if name and (re.search(r"\b(view|pure)\b", tail)
                     or not re.search(r"\b(public|external)\b", tail)):
            return x.group(0)
        mod = "__aegisTop" if (block_all or (name in privileged)) else "__aegisTx"
        r = re.search(r"\breturns\s*\(", tail)
        if r:
            tail = tail[:r.start()] + f"{mod} " + tail[r.start():]
        else:
            tail = tail.rstrip() + f" {mod} "
        return f"{x.group(0)[:x.start(3) - x.start(0)]}{tail}{{"
    body = re.sub(r"\bfunction\s+([A-Za-z_]\w*)\s*(\([^)]*\))([^{;]*)\{", repl, body)
    body = re.sub(r"\b(receive|fallback)\s*\(\s*\)\s*([^{;]*)\{",
                  lambda x: f"{x.group(1)}() {x.group(2).rstrip()} "
                            f"{'__aegisTop' if block_all else '__aegisTx'} {{",
                  body)
    return body


def build(src: str, contract: str, target: str, privileged=(),
          block_all: bool = False):
    """The instrumented source, or None when it cannot be built."""
    src = src.replace("\r\n", "\n")
    if _span(src, contract) is None:
        return None

    for m in sorted(set(re.findall(r"\b_sum_([A-Za-z_]\w*)", target))):
        ghost = f"_sum_{m}"
        owner = _declaring_contract(src, m)
        if owner is None:
            return None
        src = _edit_contract(src, owner, lambda b: f"\n    uint256 internal {ghost};" + b)
        for c in {owner, contract}:
            src = _edit_contract(src, c, lambda b: instrument_sum(b, m, ghost))

    header = f"""
    uint256 private __aegis_depth;
    modifier __aegisTx() {{ __aegis_depth += 1; _; __aegis_depth -= 1; }}
    modifier __aegisTop() {{ require(__aegis_depth == 0); __aegis_depth += 1; _; __aegis_depth -= 1; }}
    function __aegis_check() public view {{ require(__aegis_depth == 0); assert({target}); }}
"""

    def edit(b):
        return header + _add_modifiers(b, set(privileged), block_all)
    return _edit_contract(src, contract, edit)


_CACHE: dict = {}


def confirm(src: str, contract: str, target: str, privileged, site_function: str,
            timeout_ms: int, say=lambda s: None):
    """(verdict, detail) for the property on the original contract."""
    key = (contract, target, hash(src), tuple(sorted(privileged)))
    if key in _CACHE:
        return _CACHE[key]
    from . import backend

    sp = _span(src.replace("\r\n", "\n"), contract)
    if sp is None or not re.search(
            rf"\bfunction\s+{re.escape(site_function)}\s*\(",
            src.replace("\r\n", "\n")[sp[2]:sp[3]]):
        res = ("undecided", f"exposure function {site_function} is not defined "
                            f"in {contract} itself; confirmation cannot reach it")
        _CACHE[key] = res
        return res

    def run(block_all, label):
        s = build(src, contract, target, privileged, block_all)
        if s is None:
            return "undecided", "instrumentation could not be built"
        r = backend.check_obligation(f"CONFIRM_{label}", "confirm", s,
                                     timeout_ms=timeout_ms, ext_calls="untrusted")
        state = {"failed": "violated", "verified": "holds"}.get(r.status, "undecided")
        return state, r.detail

    open_state, open_detail = run(False, "open")
    say(f"[confirm] callbacks may re-enter: {open_state}")
    if open_state == "holds":
        res = ("not_reproduced", "the property holds on the original contract "
                                 "with callbacks allowed to re-enter")
    elif open_state == "undecided":
        res = ("undecided", f"open run undecided: {open_detail[:120]}")
    else:
        blocked_state, blocked_detail = run(True, "blocked")
        say(f"[confirm] re-entry blocked:       {blocked_state}")
        if blocked_state == "holds":
            res = ("confirmed", "violated only when a callback may re-enter")
        elif blocked_state == "violated":
            res = ("not_invariant", "violated even with re-entry blocked: the "
                                    "property is not an invariant of the contract")
        else:
            res = ("undecided", f"blocked run undecided: {blocked_detail[:120]}")
    _CACHE[key] = res
    return res
