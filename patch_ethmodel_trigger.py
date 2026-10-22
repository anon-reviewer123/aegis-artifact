import shutil
P = "aegis/eth_model.py"
shutil.copy(P, P + ".bak_trigger")
s = open(P).read()

# Only fire the eth-model transform when the TARGET PROPERTY references the ETH
# balance. Previously it fired whenever the source contained the string anywhere
# (true for most flattened token files via unrelated bundled code), spuriously
# rewriting the source and breaking AST compilation -> regex fallback.
old = '''def needs_eth_model(src: str, prop: str) -> bool:
    return "address(this).balance" in src or "address(this).balance" in prop'''
new = '''def needs_eth_model(src: str, prop: str) -> bool:
    # Fire only when the property itself is about the ETH balance. A source that
    # merely mentions address(this).balance in unrelated bundled code must not
    # trigger the transform, which would corrupt AST compilation.
    return "address(this).balance" in prop or "_ethBal" in prop'''
if old not in s:
    raise SystemExit("needs_eth_model anchor missing")
s = s.replace(old, new)
open(P, "w").write(s)
print("patched eth_model.py: transform triggers on property, not source")
