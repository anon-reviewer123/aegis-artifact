import re
import shutil

PATH = "aegis/harness_synth.py"
shutil.copy(PATH, PATH + ".bak_payable")
src = open(PATH).read()

# Insert a sanitizer helper right after _clean_chunk is defined, and route
# fragment text through it. We hook at the two call sites that copy source
# fragments into the harness: the closure wrapper bodies and the phase bodies.

helper = '''
def _sanitize_payable(text: str) -> str:
    """Rewrite payable-related constructs so a copied source fragment compiles
    inside the isolated, non-payable harness. `address payable` declarations
    become plain `address`; `payable(x)` casts collapse to `x`; `.transfer(` and
    `.send(` on an address become no-ops modeled by the ETH ghost elsewhere, so
    we leave the call shape but drop the payable cast that precedes it. This is
    safe because the harness models ETH via the amount ghost, not real transfers.
    """
    if not text:
        return text
    # address payable  ->  address   (declarations and casts of the type name)
    text = re.sub(r"\\baddress\\s+payable\\b", "address", text)
    # payable(expr)  ->  (expr)      (value cast; balance/transfer semantics are
    # modeled by the ETH ghost, so the cast is not needed for the invariant)
    def _strip_cast(m):
        return "(" + m.group(1) + ")"
    # handle simple, non-nested payable(...) casts
    prev = None
    while prev != text:
        prev = text
        text = re.sub(r"payable\\s*\\(([^()]*)\\)", _strip_cast, text)
    return text

'''

anchor = "def _param_bindings(src: str, fname: str) -> str:"
if anchor not in src:
    raise SystemExit("param_bindings anchor missing")
src = src.replace(anchor, helper + "\n" + anchor)

# Route the closure wrapper body through the sanitizer.
old_wrap = '''        cleaned = _clean_chunk(body, keep_requires=True)
        # msg.value is illegal in a non-payable wrapper; the harness models the
        # ETH amount via the uniform `amount` param, so rewrite msg.value->amount.
        cleaned = cleaned.replace("msg.value", "amount")'''
new_wrap = '''        cleaned = _clean_chunk(body, keep_requires=True)
        # msg.value is illegal in a non-payable wrapper; the harness models the
        # ETH amount via the uniform `amount` param, so rewrite msg.value->amount.
        cleaned = cleaned.replace("msg.value", "amount")
        cleaned = _sanitize_payable(cleaned)'''
if old_wrap not in src:
    raise SystemExit("closure-wrapper anchor missing")
src = src.replace(old_wrap, new_wrap)

# Also sanitize the param binding type strings (address payable -> address).
old_bind = "        base = ptype.split()[0]  # strip 'memory'/'calldata'/'payable'"
new_bind = ("        ptype = _sanitize_payable(ptype)\n"
            "        base = ptype.split()[0]  "
            "# strip 'memory'/'calldata'/'payable'")
if old_bind not in src:
    raise SystemExit("param-binding anchor missing")
src = src.replace(old_bind, new_bind)


# Route the pre/post phase bodies through the sanitizer too (the OBL_pre /
# OBL_post compile errors come from payable casts inside these fragments).
old_phase = '''    begin_body = _phase_body(contract_src, site, "pre").replace("msg.value", "amount")
    end_body = _phase_body(contract_src, site, "post").replace("msg.value", "amount")'''
new_phase = '''    begin_body = _phase_body(contract_src, site, "pre").replace("msg.value", "amount")
    end_body = _phase_body(contract_src, site, "post").replace("msg.value", "amount")
    begin_body = _sanitize_payable(begin_body)
    end_body = _sanitize_payable(end_body)'''
if old_phase not in src:
    raise SystemExit("phase anchor missing")
src = src.replace(old_phase, new_phase)

open(PATH, "w").write(src)
print("patched aegis/harness_synth.py (backup at .bak_payable)")
print("routed closure wrappers + param bindings through _sanitize_payable")
