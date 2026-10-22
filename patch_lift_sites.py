import re
import shutil

PATH = "aegis/ast_analysis.py"
shutil.copy(PATH, PATH + ".bak_lift")
src = open(PATH).read()

anchor = """    return ContractFacts(contract=target.get("name", "Contract"),
                         storage_vars=sorted(state_names),
                         functions=functions,
                         exposure_sites=exposure_sites,
                         var_types=state_types)"""

lifting = """    def _stmt_calls(stmts):
        out = []
        for i, st in enumerate(stmts):
            for sub in _iter_nodes(st):
                if sub.get("nodeType") != "FunctionCall":
                    continue
                ex = sub.get("expression", {}) or {}
                if ex.get("nodeType") == "Identifier" and ex.get("name") in fn_nodes:
                    out.append((i, ex.get("name")))
                elif (ex.get("nodeType") == "MemberAccess"
                      and (ex.get("expression", {}) or {}).get("nodeType") == "Identifier"
                      and (ex.get("expression", {}) or {}).get("name") == "this"
                      and ex.get("memberName") in fn_nodes):
                    out.append((i, ex.get("memberName")))
        return out

    lifted = []
    lifted_keys = set()
    for s in list(exposure_sites):
        fi = functions.get(s.function)
        if fi is None or fi.visibility in ("public", "external"):
            continue
        frontier = [(s.function, set(s.write_before_call), set(s.write_after_call))]
        seen = {s.function}
        for _ in range(3):
            nxt = []
            for helper, hb, ha in frontier:
                for name, node in fn_nodes.items():
                    if name in seen:
                        continue
                    stmts = _ordered_statements(node.get("body", {}))
                    hit = None
                    for idx, callee in _stmt_calls(stmts):
                        if callee == helper:
                            hit = idx
                            break
                    if hit is None:
                        continue
                    _, wb = _referenced_state({"statements": stmts[:hit]},
                                              state_ids, state_names)
                    _, wa = _referenced_state({"statements": stmts[hit + 1:]},
                                              state_ids, state_names)
                    wbc = wb | hb
                    wac = wa | ha
                    seen.add(name)
                    info = functions[name]
                    if info.visibility in ("public", "external"):
                        key = (name, s.call)
                        if key in lifted_keys or not (wbc or wac):
                            continue
                        lifted_keys.add(key)
                        info.external_calls.append(s.call)
                        info.write_before_call |= wbc
                        info.write_after_call |= wac
                        lifted.append(ExposureSite(
                            function=name, call=s.call, callback_capable=True,
                            reason=s.reason + " via " + s.function,
                            exposed_storage=set(wbc | wac | (info.reads & info.writes)),
                            write_before_call=set(wbc),
                            write_after_call=set(wac)))
                    else:
                        nxt.append((name, wbc, wac))
            frontier = nxt
            if not frontier:
                break
    exposure_sites.extend(lifted)
    exposure_sites.sort(key=lambda s: (
        bool(s.write_before_call) and bool(s.write_after_call),
        (functions[s.function].visibility in ("public", "external"))
        if s.function in functions else False,
        len(s.write_before_call | s.write_after_call)), reverse=True)

""" + anchor

if anchor not in src:
    raise SystemExit("anchor not found; ast_analysis.py differs from expected")
src = src.replace(anchor, lifting)
open(PATH, "w").write(src)
print("patched aegis/ast_analysis.py (backup at .bak_lift)")
