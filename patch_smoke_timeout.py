import shutil

PATH = "smoke10_v2.py"
shutil.copy(PATH, PATH + ".bak_timeout")
src = open(PATH).read()

# 1. Drop the tautology: same-variable window must not emit `v == v`.
#    Without a ghost the target is trivially true and sends CHC into an
#    unbounded search. Skip it -> reported NO_WINDOW.
old = '''        # same-variable window: conservation over the single exposed variable
        return f"{after[0]} == {after[0]}"
    return None'''
new = '''        # same-variable window: a conservation target needs a ghost the
        # pipeline only introduces for ETH-balance patterns. Without it, the
        # only well-typed target would be the tautology `v == v`, which is
        # trivially true and drives the CHC solver into an unbounded search.
        # Skip here; these are reported NO_WINDOW until ghost support is added.
        return None
    return None'''
if old not in src:
    raise SystemExit("tautology anchor missing")
src = src.replace(old, new)

# 2. Pass a real SMT timeout to run_aegis so no single obligation can hang.
old_cmd = '''        cmd = [sys.executable, "run_aegis.py", sol, "--property", prop,
               "--llm", args.llm, "--json"]'''
new_cmd = '''        cmd = [sys.executable, "run_aegis.py", sol, "--property", prop,
               "--llm", args.llm, "--json",
               "--smt-timeout-ms", str(args.smt_timeout_ms)]'''
if old_cmd not in src:
    raise SystemExit("cmd anchor missing")
src = src.replace(old_cmd, new_cmd)

# 3. Add the CLI arg (default 30s per obligation).
old_arg = '''    ap.add_argument("--out", default="smoke_out")'''
new_arg = '''    ap.add_argument("--out", default="smoke_out")
    ap.add_argument("--smt-timeout-ms", type=int, default=30000)'''
if old_arg not in src:
    raise SystemExit("arg anchor missing")
src = src.replace(old_arg, new_arg)

open(PATH, "w").write(src)
print("patched smoke10_v2.py: dropped tautology + 30s SMT timeout (backup .bak_timeout)")
