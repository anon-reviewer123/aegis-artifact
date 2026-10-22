import shutil

P = "aegis/ast_analysis.py"
shutil.copy(P, P + ".bak_stubs")
s = open(P).read()

old = '''            if node.get("kind") == "constructor":
                continue
            name = node.get("name") or "<fallback>"
            if name in functions:
                continue  # most-derived wins (linearized order)'''
new = '''            if node.get("kind") == "constructor":
                continue
            # Skip interface / abstract declarations (no body). These have
            # implemented == False and a null body; collecting them lets an
            # interface stub shadow the real implementation and become a bogus
            # empty-window exposure site (observed on swap contracts whose
            # transferFrom interface stub was picked over the real _transfer).
            if node.get("implemented") is False or not node.get("body"):
                continue
            name = node.get("name") or "<fallback>"
            if name in functions:
                continue  # most-derived wins (linearized order)'''

if old not in s:
    raise SystemExit("stub-filter anchor missing")
s = s.replace(old, new)
open(P, "w").write(s)
print("patched ast_analysis.py: skip unimplemented (interface/abstract) functions")
