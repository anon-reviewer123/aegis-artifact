import shutil
P = "aegis/harness_synth.py"
shutil.copy(P, P + ".bak_sumdecl")
s = open(P).read()

# The declaration injection missed because snapPre sits between inFlight and
# exposed, so the original two-line anchor didn't match. Insert the sum-ghost
# declaration right after the inFlight declaration line in the f-string body,
# using a placeholder that is always substituted.
if "{sum_ghost_line}" in s:
    print("already has sum_ghost_line; skip")
else:
    # add a placeholder line after inFlight in the harness template
    old = "    uint256 public inFlight;\n"
    # only the FIRST occurrence inside the f-string template matters; it is the
    # one preceding the snapPre/exposed decls.
    new = "    uint256 public inFlight;\n{sum_ghost_line}"
    # replace only within the template return (first occurrence is the template)
    idx = s.find('return f"""// SPDX-License-Identifier: MIT')
    if idx == -1:
        raise SystemExit("template return not found")
    head, tail = s[:idx], s[idx:]
    tail = tail.replace(old, new, 1)
    s = head + tail

    # compute sum_ghost_line where sum_ghost_decl is computed
    s = s.replace(
        'sum_ghost_decl = f"public {_sg}; // [ghost] sum over {_mvar}"',
        'sum_ghost_decl = f"public {_sg};"\n'
        '        sum_ghost_line = f"    uint256 public {_sg}; '
        '// [ghost] sum over {_mvar}\\n"')
    s = s.replace(
        'sum_ghost_decl = "public __unused_sum; // (no exposed mapping)"',
        'sum_ghost_decl = "public __unused_sum;"\n'
        '        sum_ghost_line = ""')
    open(P, "w").write(s)
    print("patched: _sum ghost declaration line inserted after inFlight")
