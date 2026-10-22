import shutil
P = "aegis/harness_synth.py"
shutil.copy(P, P + ".bak_views")
s = open(P).read()

if "_emit_view_functions" in s:
    print("view emitter already present; skip")
    raise SystemExit(0)

# Helper: extract and emit full source of public views reading exposed state, so
# the OBL_view obligation can call v.<view>(...). Views are side-effect free, so
# copying them verbatim is sound; they read the harness's own storage/ghosts.
helper = '''
def _emit_view_functions(contract_src, facts, site):
    """Emit verbatim copies of public/external view functions that read state
    exposed at `site`, so OBL_view_<g> can invoke them on the harness. Views are
    side-effect-free; copying them is sound. Returns a string of full function
    definitions (may be empty)."""
    from .static_analysis import view_closure
    views = view_closure(facts, site.function)
    out = []
    for g in views:
        m = re.search(
            rf"function\\s+{re.escape(g)}\\s*\\([^)]*\\)[^{{]*{{", contract_src,
            re.DOTALL)
        if not m:
            continue
        start = m.start()
        depth, i = 0, m.end() - 1
        while i < len(contract_src):
            if contract_src[i] == "{":
                depth += 1
            elif contract_src[i] == "}":
                depth -= 1
                if depth == 0:
                    i += 1
                    break
            i += 1
        fn_src = contract_src[start:i]
        # views may be declared `override`; strip override/virtual for the harness
        fn_src = re.sub(r"\\b(override|virtual)\\b", "", fn_src)
        out.append("    " + fn_src.strip())
    return "\\n".join(out)

'''
anchor = "def synthesize_harness("
s = s.replace(anchor, helper + "\n" + anchor, 1)

# compute view functions next to callback_stubs and inject into the template
s = s.replace(
    "    callback_stubs = _emit_callback_wrappers(contract_src, facts, site)",
    "    callback_stubs = _emit_callback_wrappers(contract_src, facts, site)\n"
    "    view_funcs = _emit_view_functions(contract_src, facts, site)")

# add view_funcs to _resolve_unbound so its identifiers resolve too
s = s.replace(
    "    _extra_decls, (begin_body, end_body, callback_stubs) = _resolve_unbound(\n"
    "        [begin_body, end_body, callback_stubs], _known, _omitted)",
    "    _extra_decls, (begin_body, end_body, callback_stubs, view_funcs) = _resolve_unbound(\n"
    "        [begin_body, end_body, callback_stubs, view_funcs], _known, _omitted)")

# inject {view_funcs} into the template right after {callback_stubs}
s = s.replace("{callback_stubs}", "{callback_stubs}\n{view_funcs}", 1)

open(P, "w").write(s)
print("patched: view functions copied into harness so v.<view>() resolves")
