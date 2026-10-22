#!/usr/bin/env python3
"""Generate the missing general-arm twins so every family reaches Table III.

Six families sit at half strength or less. Each pair produced here follows one
rule: the two members declare identical state and identical functions, and
differ only in where the external call sits relative to the writes. The safe
member settles the relation before yielding control; the unsafe member splits
it across the call, leaving the relation broken while an adversary runs.

Because the members are otherwise identical, both are checked against the same
bare target property. That matters: a pair whose safe member is verified
against a weaker target than its partner is refuted against is not a controlled
comparison, and nine of the existing pairs have that defect.

  python3 gen_corpus_twins_v2.py --dry-run
  python3 gen_corpus_twins_v2.py --out contracts/corpus --manifest benchmark_50.json
"""
import argparse
import json
import os

HEADER = """// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface ICallback { function onCallback() external; }
interface IOracle { function peek() external view returns (uint256); }
interface ITokenReceiver { function tokensReceived(address from, uint256 amount) external; }
interface IFlashBorrower { function onFlashLoan(uint256 amount) external; }
"""


def contract(name, state, funcs, inv):
    """Emit the contract. `inv` is the target relation; where it names a
    mapping-sum ghost (_sum_x) it is not a Solidity expression, so the
    declared invariant() falls back to a trivial body. The ghost is supplied
    by the harness, which is where the relation is actually checked."""
    body = "\n".join("    " + f for f in funcs)
    inv_expr = "true" if "_sum_" in inv else inv
    return (f"{HEADER}\ncontract {name} {{\n    {state}\n{body}\n"
            f"    function invariant() public view returns(bool) {{ return {inv_expr}; }}\n}}\n")


# ---------------------------------------------------------------- families
# Each entry yields (state, seed_fn, exposure_fn_safe, exposure_fn_unsafe,
# extra_fns, property). `held` is the relation both members maintain.

def classic(i, led, tot, back):
    state = (f"mapping(address=>uint256) public {led}; "
             f"uint256 public {tot}; uint256 public {back};")
    seed = (f"function deposit(uint256 amt) external {{ "
            f"{led}[msg.sender]+=amt; {tot}+=amt; {back}+=amt; }}")
    # safe: both sides of the relation are settled before control leaves
    safe = (f"function withdraw(uint256 amt, address cb) external {{ "
            f"require({led}[msg.sender] >= amt, \"bal\"); "
            f"{led}[msg.sender]-=amt; {tot}-=amt; {back}-=amt; "
            f"if (cb != address(0)) ICallback(cb).onCallback(); }}")
    # unsafe: the backing is written only after the callback returns
    unsafe = (f"function withdraw(uint256 amt, address cb) external {{ "
              f"require({led}[msg.sender] >= amt, \"bal\"); "
              f"{led}[msg.sender]-=amt; {tot}-=amt; "
              f"if (cb != address(0)) ICallback(cb).onCallback(); "
              f"{back}-=amt; }}")
    extra = [f"function claimSurplus() external {{ "
             f"require({back} > {tot}, \"no surplus\"); "
             f"uint256 s = {back} - {tot}; "
             f"{led}[msg.sender]+=s; {tot}+=s; }}"]
    return state, seed, safe, unsafe, extra, f"{tot} == {back}"


def cross_function(i, a, b, led):
    state = (f"mapping(address=>uint256) public {led}; "
             f"uint256 public {a}; uint256 public {b};")
    seed = (f"function open(uint256 amt) external {{ "
            f"{led}[msg.sender]+=amt; {a}+=amt; {b}+=amt; }}")
    safe = (f"function reduce(uint256 amt, address cb) external {{ "
            f"require({led}[msg.sender] >= amt, \"pos\"); "
            f"{led}[msg.sender]-=amt; {a}-=amt; {b}-=amt; "
            f"if (cb != address(0)) ICallback(cb).onCallback(); }}")
    unsafe = (f"function reduce(uint256 amt, address cb) external {{ "
              f"require({led}[msg.sender] >= amt, \"pos\"); "
              f"{led}[msg.sender]-=amt; {b}-=amt; "
              f"if (cb != address(0)) ICallback(cb).onCallback(); "
              f"{a}-=amt; }}")
    # the cross-function surface an adversary re-enters through
    extra = [f"function mint() external {{ "
             f"require({a} > {b}, \"no surplus\"); "
             f"uint256 s = {a} - {b}; "
             f"{led}[msg.sender]+=s; {b}+=s; }}"]
    return state, seed, safe, unsafe, extra, f"{a} == {b}"


def token_hook(i, cr, crs, liab):
    state = (f"mapping(address=>uint256) public {cr}; "
             f"uint256 public {crs}; uint256 public {liab};")
    seed = (f"function fund(uint256 amt) external {{ "
            f"{cr}[msg.sender]+=amt; {crs}+=amt; {liab}+=amt; }}")
    safe = (f"function issue(address to, uint256 amt) external {{ "
            f"{liab}+=amt; {cr}[to]+=amt; {crs}+=amt; "
            f"if (to.code.length>0) ITokenReceiver(to).tokensReceived(msg.sender, amt); }}")
    unsafe = (f"function issue(address to, uint256 amt) external {{ "
              f"{liab}+=amt; "
              f"if (to.code.length>0) ITokenReceiver(to).tokensReceived(msg.sender, amt); "
              f"{cr}[to]+=amt; {crs}+=amt; }}")
    extra = [f"function mintSurplus() external {{ "
             f"require({liab} > {crs}, \"no surplus\"); "
             f"uint256 s = {liab} - {crs}; "
             f"{cr}[msg.sender]+=s; {crs}+=s; }}",
             f"function redeem(uint256 amt) external {{ "
             f"require({cr}[msg.sender] >= amt, \"credit\"); "
             f"{cr}[msg.sender]-=amt; {crs}-=amt; {liab}-=amt; }}"]
    return state, seed, safe, unsafe, extra, f"{crs} == {liab}"


def flash_loan(i, cash, loans, assets):
    state = (f"uint256 public {cash}; uint256 public {loans}; "
             f"uint256 public {assets};")
    seed = (f"function supply(uint256 amt) external {{ "
            f"{cash}+=amt; {assets}+=amt; }}")
    # safe: cash and loans move together, so the sum never leaves its relation
    safe = (f"function borrow(uint256 amt, address b) external {{ "
            f"require({cash} >= amt, \"cash\"); "
            f"{cash}-=amt; {loans}+=amt; "
            f"IFlashBorrower(b).onFlashLoan(amt); "
            f"{loans}-=amt; {cash}+=amt; }}")
    # unsafe: the loan is booked only after the borrower returns, so the sum is
    # short for the whole window
    unsafe = (f"function borrow(uint256 amt, address b) external {{ "
              f"require({cash} >= amt, \"cash\"); "
              f"{cash}-=amt; "
              f"IFlashBorrower(b).onFlashLoan(amt); "
              f"{cash}+=amt; }}")
    extra = [f"function topUp() external {{ "
             f"require({assets} > {cash} + {loans}, \"no shortfall\"); "
             f"uint256 s = {assets} - {cash} - {loans}; "
             f"{cash}+=s; }}"]
    return state, seed, safe, unsafe, extra, f"{cash} + {loans} == {assets}"


def phase_ordering(i, debit, credit, led):
    state = (f"mapping(address=>uint256) public {led}; "
             f"uint256 public {debit}; uint256 public {credit};")
    seed = (f"function post(uint256 amt) external {{ "
            f"{led}[msg.sender]+=amt; {debit}+=amt; {credit}+=amt; }}")
    safe = (f"function rotate(uint256 amt, address cb) external {{ "
            f"require({led}[msg.sender] >= amt, \"entry\"); "
            f"{led}[msg.sender]-=amt; {debit}-=amt; {credit}-=amt; "
            f"if (cb != address(0)) ICallback(cb).onCallback(); }}")
    unsafe = (f"function rotate(uint256 amt, address cb) external {{ "
              f"require({led}[msg.sender] >= amt, \"entry\"); "
              f"{led}[msg.sender]-=amt; {debit}-=amt; "
              f"if (cb != address(0)) ICallback(cb).onCallback(); "
              f"{credit}-=amt; }}")
    extra = [f"function adjust() external {{ "
             f"require({credit} > {debit}, \"no gap\"); "
             f"uint256 s = {credit} - {debit}; "
             f"{led}[msg.sender]+=s; {debit}+=s; }}"]
    return state, seed, safe, unsafe, extra, f"{debit} == {credit}"


def eoa_assumption(i, rew, debt, accrued):
    state = (f"mapping(address=>uint256) public {rew}; "
             f"uint256 public {debt}; uint256 public {accrued};")
    seed = (f"function accrue(uint256 amt) external {{ "
            f"{rew}[msg.sender]+=amt; {debt}+=amt; {accrued}+=amt; }}")
    safe = (f"function claim(address cb) external {{ "
            f"uint256 x = {rew}[msg.sender]; require(x > 0, \"none\"); "
            f"{rew}[msg.sender]=0; {debt}-=x; {accrued}-=x; "
            f"if (cb != address(0)) ICallback(cb).onCallback(); }}")
    unsafe = (f"function claim(address cb) external {{ "
              f"uint256 x = {rew}[msg.sender]; require(x > 0, \"none\"); "
              f"{rew}[msg.sender]=0; {debt}-=x; "
              f"if (cb != address(0)) ICallback(cb).onCallback(); "
              f"{accrued}-=x; }}")
    extra = [f"function sweep() external {{ "
             f"require({accrued} > {debt}, \"no gap\"); "
             f"uint256 s = {accrued} - {debt}; "
             f"{rew}[msg.sender]+=s; {debt}+=s; }}"]
    return state, seed, safe, unsafe, extra, f"{debt} == {accrued}"


# family -> (prefix, class, builder, first index, count, name tuples)
PLAN = [
    ("ClassicReentrancy", "classic_reentrancy", classic, 6, 5,
     [("bal", "totalDeposits", "backing"), ("held", "totalHeld", "reserves"),
      ("owed", "totalOwed", "funded"), ("stake", "totalStaked", "bonded"),
      ("escrowed", "totalEscrowed", "custody")]),
    ("CrossFunctionDesync", "cross_function_desync", cross_function, 6, 5,
     [("aum", "trackedValue", "shares"), ("pool", "booked", "units"),
      ("assets", "tracked", "positions"), ("backing", "issued", "claims"),
      ("reserve", "recorded", "lots")]),
    ("TokenHookAccounting", "token_hook_accounting", token_hook, 5, 4,
     [("credit", "credits", "liabilities"), ("voucher", "vouchers", "owedTotal"),
      ("note", "notes", "obligations"), ("coupon", "coupons", "dues")]),
    ("FlashLoanCallback", "flash_loan_callback", flash_loan, 4, 3,
     [("cash", "loans", "totalAssets"), ("idle", "lent", "poolSize"),
      ("liquid", "borrowed", "bookValue")]),
    ("PhaseOrderingDesync", "griefing_liveness", phase_ordering, 2, 4,
     [("debit", "credit", "entries"), ("charged", "settled", "tickets"),
      ("billed", "cleared", "invoices"), ("drawn", "repaid", "lines")]),
    ("UnexpectedEOACallback", "unexpected_eoa_callback", eoa_assumption, 2, 3,
     [("reward", "rewardDebt", "accruedTotal"),
      ("bonus", "bonusDebt", "bonusTotal"),
      ("rebate", "rebateDebt", "rebateTotal")]),
]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="contracts/corpus")
    ap.add_argument("--manifest", default="benchmark_50.json")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    here = os.path.dirname(os.path.abspath(__file__))
    outdir = os.path.join(here, args.out)
    mpath = os.path.join(here, args.manifest)
    manifest = json.load(open(mpath)) if os.path.exists(mpath) else {}

    written, entries = 0, 0
    for prefix, cls, build, first, count, names in PLAN:
        for n in range(count):
            idx = f"{first + n:02d}"
            state, seed, safe, unsafe, extra, prop = build(n, *names[n])
            for tag, exposure in (("S", safe), ("U", unsafe)):
                cname = f"{prefix}_{tag}{idx}"
                src = contract(cname, state, [seed, exposure] + extra, prop)
                path = os.path.join(outdir, cname + ".sol")
                if not args.dry_run:
                    os.makedirs(outdir, exist_ok=True)
                    with open(path, "w") as fh:
                        fh.write(src)
                written += 1
                manifest[cname + ".sol"] = {
                    "class": cls,
                    "property": prop,
                    "verdict": "VERIFIED" if tag == "S" else "BUG_FOUND",
                    "bug_site": (None if tag == "S" else
                                 "relation split across the external call"),
                    "provenance": "synthetic",
                    "solc": "0.8.20",
                    "_note": ("generated pair; members differ only in where the "
                              "external call sits relative to the writes, and "
                              "share one target property"),
                }
                entries += 1
            if args.dry_run and n == 0:
                print(f"\n--- sample: {prefix}_S{idx} (property: {prop})")
                print(contract(f"{prefix}_S{idx}", state,
                               [seed, safe] + extra, prop))

    if args.dry_run:
        print(f"\ndry run: would write {written} contract(s) and "
              f"{entries} manifest entries")
        return

    json.dump(manifest, open(mpath, "w"), indent=1)
    print(f"wrote {written} contract(s) to {args.out}/")
    print(f"manifest {args.manifest} now has {len(manifest) - 1} entries")


if __name__ == "__main__":
    main()
