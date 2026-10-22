import ast as pyast
import io
import os
import sys

AST_TARGET = os.path.join("aegis", "ast_analysis.py")
RE_TARGET = os.path.join("aegis", "static_analysis.py")

AST_HELPER = '''
_CALL_MEMBERS = {"call", "delegatecall"}
_HOOK_PREFIXES = ("on", "tokensReceived", "executeOperation", "notify")


def _contract_has_external_call(contract: dict) -> bool:
    """True when the contract body performs a low-level call or invokes a
    callback-style hook on another address."""
    for n in _iter_nodes(contract):
        if n.get("nodeType") != "MemberAccess":
            continue
        name = n.get("memberName") or ""
        if name in _CALL_MEMBERS:
            return True
        if name.startswith("on") and len(name) > 2 and name[2].isupper():
            return True
        if name in ("tokensReceived", "executeOperation", "onFlashLoan"):
            return True
    return False


def _pick_target_contract(contracts: list) -> dict:
    """Select the contract that owns the exposure site.

    Flattened sources bundle bases, libraries and interfaces alongside the
    deployed contract. Taking the last definition, or the one with the most
    functions, picks a base library on most real files: the harness then binds
    storage from one contract and splices a function body from another, and the
    result does not compile. The contract performing an external call is the one
    the analysis is about, so prefer it and fall back to the previous rule.
    """
    concrete = [c for c in contracts if c.get("contractKind") == "contract"
                and not c.get("abstract")]
    if not concrete:
        concrete = [c for c in contracts if c.get("contractKind") == "contract"]
    if not concrete:
        return None
    with_call = [c for c in concrete if _contract_has_external_call(c)]
    if with_call:
        return max(with_call, key=lambda c: len(c.get("linearizedBaseContracts", [])))
    return concrete[-1]
'''

AST_OLD = '''    # Pick the last non-interface contract as the target (top of the file).
    target = None
    for c in contracts:
        if c.get("contractKind") == "contract":
            target = c
    if target is None:
        return None'''

AST_NEW = '''    target = _pick_target_contract(contracts)
    if target is None:
        return None'''

RE_OLD = '''    def _pick_main_contract(text: str) -> str:
        best_name, best_fns = None, -1
        for cm in re.finditer(r"\\bcontract\\s+(\\w+)[^{]*\\{", text):
            nm = cm.group(1)
            body = _extract_body(text, cm.end() - 1)
            nfns = len(re.findall(r"\\bfunction\\s+\\w+\\s*\\(", body))
            if nfns > best_fns:
                best_name, best_fns = nm, nfns
        return best_name'''

RE_NEW = '''    def _pick_main_contract(text: str) -> str:
        # Prefer the contract that performs an external call: that is where the
        # exposure site lives. Ranking by function count alone selects the
        # largest base library on flattened sources, which binds storage from
        # one contract while the site function belongs to another.
        call_re = re.compile(r"\\.call\\s*[\\({]|\\.call\\s*\\.\\s*value\\s*\\(|"
                             r"\\.on[A-Z]\\w*\\s*\\(|\\.tokensReceived\\s*\\(|"
                             r"\\.executeOperation\\s*\\(|\\.onFlashLoan\\s*\\(")
        best_name, best_key = None, (-1, -1)
        for cm in re.finditer(r"\\bcontract\\s+(\\w+)[^{]*\\{", text):
            nm = cm.group(1)
            body = _extract_body(text, cm.end() - 1)
            nfns = len(re.findall(r"\\bfunction\\s+\\w+\\s*\\(", body))
            key = (1 if call_re.search(body) else 0, nfns)
            if key > best_key:
                best_name, best_key = nm, key
        return best_name'''


def patch_file(path, edits, marker):
    text = io.open(path, encoding="utf-8").read()
    if marker in text:
        print("  %s already patched" % path)
        return True, text
    io.open(path + ".bak2", "w", encoding="utf-8").write(text)
    for old, new in edits:
        if old not in text:
            print("  error: anchor not found in %s" % path)
            return False, text
        text = text.replace(old, new, 1)
    try:
        pyast.parse(text)
    except SyntaxError as e:
        print("  error: %s would not parse (%s)" % (path, e))
        return False, text
    io.open(path, "w", encoding="utf-8").write(text)
    print("  patched %s (backup %s.bak2)" % (path, path))
    return True, text


def main():
    if not os.path.exists(AST_TARGET) or not os.path.exists(RE_TARGET):
        print("error: run from the aegis_dist root")
        return 1

    text = io.open(AST_TARGET, encoding="utf-8").read()
    anchor = "def _state_var_names("
    if "_pick_target_contract" not in text and anchor in text:
        text = text.replace(anchor, AST_HELPER.strip() + "\n\n\n" + anchor, 1)
        io.open(AST_TARGET, "w", encoding="utf-8").write(text)

    ok1, _ = patch_file(AST_TARGET, [(AST_OLD, AST_NEW)], "_pick_target_contract(contracts)")
    ok2, _ = patch_file(RE_TARGET, [(RE_OLD, RE_NEW)], "call_re.search(body)")

    if ok1 and ok2:
        print("\ncontract selection now prefers the contract containing the")
        print("external call on both the AST and regex analyzer paths")
        return 0
    print("\none or more edits failed; check anchors")
    return 1


if __name__ == "__main__":
    sys.exit(main())
