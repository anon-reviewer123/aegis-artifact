"""
Gap 1 Slice 3: LLM-proposed loop invariants (generative, like read-only).

The step-harness STRUCTURE (re-entrant callback + before/after ordering) carries
the discriminating power; the LLM proposes the SAFETY ASSERTION the step must
preserve. We then VALIDATE that the proposed assertion actually discriminates:
it must FAIL on the structurally-unsafe variant and HOLD on the safe one. An
assertion that verifies both (e.g. the conservation sum, which does not
discriminate double-pay) is rejected and the LLM is asked again.

This mirrors read-only: LLM proposes, SMT verifies, and a validation gate rejects
vacuous / non-discriminating proposals before they are trusted.

Falls back to the proven per-shape template assertion if the LLM is unavailable
or never proposes a discriminating one within the budget -- so the pipeline stays
sound either way.
"""
import os, json, re

# proven discriminating assertions per shape (the fallback + the validation oracle)
_TEMPLATE_ASSERT = {
    "conserve_loop": "paidForC <= wInit",
    "mutex_loop":    "totalPaid <= poolAtStart",
    "progress_loop": "advanced",
}

_SYSTEM = (
    "You are helping verify a smart-contract loop that makes an external call "
    "inside the loop body (a pattern sound verifiers like RAVEN exclude). Propose "
    "the single Solidity boolean SAFETY ASSERTION that one loop iteration must "
    "preserve so that the loop is safe under re-entrancy for an arbitrary number "
    "of iterations. Respond ONLY as JSON: {\"assertion\": \"<solidity bool expr>\"}. "
    "Use only the harness variables named in the user message. The assertion must "
    "be VIOLATED by a double-effect (re-entrant) iteration and HOLD otherwise -- "
    "a conservation identity that stays balanced under double-effect is WRONG."
)

def _harness_vars(kind):
    if kind == "conserve_loop":
        return "ownedC (uint), paidForC (uint), wInit (uint) = owed at iteration start"
    if kind == "mutex_loop":
        return "pool (uint), totalPaid (uint), poolAtStart (uint)"
    if kind == "progress_loop":
        return "advanced (bool), ownedC (uint)"
    return ""

def _llm_assertion(kind, contract, function):
    if not os.environ.get("OPENAI_API_KEY"):
        return None
    try:
        from openai import OpenAI
        from aegis.synth import _robust_create
    except Exception:
        return None
    client = OpenAI(api_key=os.environ["OPENAI_API_KEY"])
    model = os.environ.get("AEGIS_OPENAI_MODEL", "gpt-4o")
    user = (f"Contract {contract}, function {function}, loop shape {kind}.\n"
            f"Harness variables: {_harness_vars(kind)}.\n"
            f"Give the safety assertion as JSON.")
    try:
        resp = _robust_create(client, model, _SYSTEM, user, 0.2)
        txt = resp.choices[0].message.content
        m = re.search(r'\{.*\}', txt, re.S)
        if not m:
            return None
        a = json.loads(m.group(0)).get("assertion", "").strip()
        return a or None
    except Exception:
        return None


def propose_and_validate(kind, contract, function, build_harness, check_fn, say):
    """Return a discriminating assertion for this shape.
    build_harness(assertion, unsafe) -> harness source (uses the assertion).
    check_fn(harness_source) -> "verified"|"failed"|"unknown".
    Validation: the assertion must HOLD on the safe structure and FAIL on the
    unsafe structure. Try the LLM proposal first; fall back to the template."""
    candidates = []
    a = _llm_assertion(kind, contract, function)
    if a:
        candidates.append(("llm", a))
    candidates.append(("template", _TEMPLATE_ASSERT.get(kind)))

    for origin, assertion in candidates:
        if not assertion:
            continue
        # discrimination gate: build both structural variants and check the
        # assertion holds on safe and fails on unsafe.
        try:
            safe_src = build_harness(assertion, unsafe=False)
            unsafe_src = build_harness(assertion, unsafe=True)
        except Exception as e:
            say(f"[loop-inv] {origin} assertion build failed: {e}")
            continue
        safe_res = check_fn(safe_src)
        unsafe_res = check_fn(unsafe_src)
        if safe_res == "verified" and unsafe_res == "failed":
            say(f"[loop-inv] {origin} assertion accepted (discriminates): {assertion}")
            return assertion, origin
        say(f"[loop-inv] {origin} assertion rejected "
            f"(safe={safe_res}, unsafe={unsafe_res}): {assertion}")
    # nothing discriminated -> None (caller keeps the fixed template path)
    return None, None
