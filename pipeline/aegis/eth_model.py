"""eth_model.py -- model address(this).balance as a ghost storage variable.

SMTChecker/Aegis track declared storage; the special expression
address(this).balance is the contract's live ETH balance, which the harness
cannot model. We introduce a ghost uint256 _ethBal that mirrors ETH flow:
credited by msg.value on payable functions, debited by .transfer()/.send().
The target property's address(this).balance is rewritten to _ethBal.

This unlocks the classic-reentrancy class whose safety property is
  address(this).balance >= totalDeposits
"""
import re

GHOST = "_ethBal"

def needs_eth_model(src: str, prop: str) -> bool:
    return "address(this).balance" in src or "address(this).balance" in prop

def transform(src: str, prop: str):
    """Return (new_src, new_prop, changed)."""
    if not needs_eth_model(src, prop):
        return src, prop, False

    # 1. declare the ghost right after 'contract X {'
    m = re.search(r"contract\s+\w+\s*(?:is\s+[^{]+)?\{", src)
    if not m:
        return src, prop, False
    decl = f"\n    uint256 public {GHOST}; // [ghost] models address(this).balance"
    src = src[:m.end()] + decl + src[m.end():]

    # 2. credit ghost with msg.value at the start of every payable function body
    src = re.sub(r"(function\s+\w+\s*\([^)]*\)[^{]*\bpayable\b[^{]*\{)",
                 r"\1 " + GHOST + " += msg.value;", src)

    # 3. debit ghost before transfer/send of a named amount
    src = re.sub(r"(payable\([^)]*\)\.(?:transfer|send)\(\s*(\w+)\s*\)\s*;)",
                 GHOST + r" -= \2; \1", src)

    # 4. rewrite the special expression everywhere (do comments-safe replace last)
    src = src.replace("address(this).balance", GHOST)
    # fix the comment we may have clobbered
    src = src.replace(f"// [ghost] models {GHOST}",
                      "// [ghost] models address(this).balance")
    prop = prop.replace("address(this).balance", GHOST)
    return src, prop, True
