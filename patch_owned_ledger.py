import ast as pyast
import io
import os
import sys

TARGET = os.path.join("aegis", "harness_synth.py")

OWNED_DECL = '''
# Ledger variables the ANALYSED CONTRACT declares itself. The harness normally
# supplies its own inFlight/exposed bookkeeping and strips the contract's writes
# to avoid double-counting. When the contract declares these as real storage,
# that substitution replaces the contract's accounting with correct accounting,
# so a contract whose defect IS a missing ledger update verifies vacuously. For
# those variables we keep the contract's own writes and emit none of our own.
_CONTRACT_OWNED_LEDGER: set = set()
'''

STRIP_OLD = '''        is_ledger = False
        for gv in _GHOST_LEDGER_VARS:
            if re.match(rf"{re.escape(gv)}\\b\\s*(\\+=|-=|=)", s):
                is_ledger = True
                break'''

STRIP_NEW = '''        is_ledger = False
        for gv in _GHOST_LEDGER_VARS:
            if gv in _CONTRACT_OWNED_LEDGER:
                continue
            if re.match(rf"{re.escape(gv)}\\b\\s*(\\+=|-=|=)", s):
                is_ledger = True
                break'''

TPL_OLD = '''    function beginExposed(uint256 amount) public {{
{snap_stmt}{begin_body}
        inFlight += amount;
        exposed   = true;
    }}

    /// POST phase of {site.function}: restores the stable invariant.
    function endExposed(uint256 amount) public {{
        require(exposed && inFlight == amount, "phase mismatch");
{end_body}
        inFlight -= amount;
        exposed   = false;
    }}'''

TPL_NEW = '''    function beginExposed(uint256 amount) public {{
{snap_stmt}{begin_body}
{begin_ledger}    }}

    /// POST phase of {site.function}: restores the stable invariant.
    function endExposed(uint256 amount) public {{
        require(exposed && inFlight == amount, "phase mismatch");
{end_body}
{end_ledger}    }}'''

SETUP_OLD = '''    return f"""// SPDX-License-Identifier: MIT
{pragma}'''

SETUP_NEW = '''    _begin_ledger, _end_ledger = "", ""
    if "inFlight" not in _CONTRACT_OWNED_LEDGER:
        _begin_ledger += "        inFlight += amount;\\n"
        _end_ledger += "        inFlight -= amount;\\n"
    if "exposed" not in _CONTRACT_OWNED_LEDGER:
        _begin_ledger += "        exposed   = true;\\n"
        _end_ledger += "        exposed   = false;\\n"
    begin_ledger, end_ledger = _begin_ledger, _end_ledger

    return f"""// SPDX-License-Identifier: MIT
{pragma}'''

DECL_OLD = '''contract {name}H {{
{storage_decls}
    uint256 public inFlight;
{sum_ghost_line}'''

DECL_NEW = '''contract {name}H {{
{storage_decls}
{inflight_decl}{sum_ghost_line}'''

INFLIGHT_SETUP_OLD = '''    _begin_ledger, _end_ledger = "", ""'''

INFLIGHT_SETUP_NEW = '''    inflight_decl = ("" if "inFlight" in _CONTRACT_OWNED_LEDGER
                     else "    uint256 public inFlight;\\n")
    _begin_ledger, _end_ledger = "", ""'''

EXPOSED_DECL_OLD = '''    uint256 public snapPre; // [ghost] entry snapshot for same-variable conservation
    bool    public exposed;'''

EXPOSED_DECL_NEW = '''    uint256 public snapPre; // [ghost] entry snapshot for same-variable conservation
{exposed_decl}'''

EXPOSED_SETUP_OLD = '''    inflight_decl = ("" if "inFlight" in _CONTRACT_OWNED_LEDGER'''

EXPOSED_SETUP_NEW = '''    exposed_decl = ("" if "exposed" in _CONTRACT_OWNED_LEDGER
                    else "    bool    public exposed;")
    inflight_decl = ("" if "inFlight" in _CONTRACT_OWNED_LEDGER'''

POPULATE_ANCHOR = '''    storage_decls = _harness_state_block(contract_src, facts)'''

POPULATE_NEW = '''    _CONTRACT_OWNED_LEDGER.clear()
    _CONTRACT_OWNED_LEDGER.update(
        set(facts.storage_vars) & (_GHOST_LEDGER_VARS - {"snapPre"}))
    storage_decls = _harness_state_block(contract_src, facts)'''

EDITS = [
    (STRIP_OLD, STRIP_NEW, "strip guard"),
    (TPL_OLD, TPL_NEW, "phase template"),
    (SETUP_OLD, SETUP_NEW, "ledger setup"),
    (INFLIGHT_SETUP_OLD, INFLIGHT_SETUP_NEW, "inflight decl setup"),
    (EXPOSED_SETUP_OLD, EXPOSED_SETUP_NEW, "exposed decl setup"),
    (DECL_OLD, DECL_NEW, "inflight declaration"),
    (EXPOSED_DECL_OLD, EXPOSED_DECL_NEW, "exposed declaration"),
    (POPULATE_ANCHOR, POPULATE_NEW, "populate owned set"),
]


def main():
    if not os.path.exists(TARGET):
        print("error: run from the aegis_dist root")
        return 1
    text = io.open(TARGET, encoding="utf-8").read()
    if "_CONTRACT_OWNED_LEDGER" in text:
        print("already patched")
        return 0

    io.open(TARGET + ".bak4", "w", encoding="utf-8").write(text)

    anchor = '_RECEIVER_VARS = {"receiver"}'
    if anchor not in text:
        print("error: could not find _RECEIVER_VARS anchor")
        return 1
    text = text.replace(anchor, anchor + "\n" + OWNED_DECL, 1)

    for old, new, label in EDITS:
        if old not in text:
            print("error: anchor not found (%s)" % label)
            return 1
        text = text.replace(old, new, 1)

    try:
        pyast.parse(text)
    except SyntaxError as e:
        print("error: would not parse (%s)" % e)
        return 1

    io.open(TARGET, "w", encoding="utf-8").write(text)
    print("patched %s (backup %s.bak4)" % (TARGET, TARGET))
    print("  contract-declared inFlight/exposed keep their own writes;")
    print("  the harness emits ledger bookkeeping only for variables it owns")
    return 0


if __name__ == "__main__":
    sys.exit(main())
