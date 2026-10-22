import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

os.environ.pop("AEGIS_LLM_MODE", None)
os.environ.pop("AEGIS_LLM_MAX_CALLS", None)
os.environ["AEGIS_LLM_CACHE_DIR"] = tempfile.mkdtemp(prefix="aegis_llm_cache_")
os.environ["AEGIS_PLAN_STORE_DIR"] = tempfile.mkdtemp(prefix="aegis_plan_store_")

from aegis import synth


class _Facts:
    def __init__(self, src):
        self.path = os.path.join(tempfile.mkdtemp(), "C.sol")
        open(self.path, "w").write(src)
        self.contract = "C"


def _counting_backend():
    calls = {"n": 0}

    def fake(client, model, sp, u, t):
        calls["n"] += 1
        return synth._CachedReply('{"reply": %d}' % calls["n"])
    synth._robust_create_uncached = fake
    return calls


def _ask(prompt):
    return lambda: synth._robust_create(None, "m", "sys", prompt, 0.2).choices[0].message.content


def test_reuse_ignores_prompt_changes_for_the_same_contract_and_target():
    calls = _counting_backend()
    f = _Facts("contract C { uint x; }")
    a = synth._plan_text("m", f, "x == 0", 0, [], "none", _ask("facts v1"))
    b = synth._plan_text("m", f, "x == 0", 0, [], "none", _ask("facts v2 after a code change"))
    assert calls["n"] == 1 and a == b


def test_a_different_target_or_variant_is_asked_again():
    calls = _counting_backend()
    f = _Facts("contract C { uint y; }")
    synth._plan_text("m", f, "y == 0", 0, [], "none", _ask("p1"))
    synth._plan_text("m", f, "y <= 1", 0, [], "none", _ask("p2"))
    synth._plan_text("m", f, "y == 0", 1, [], "none", _ask("p3"))
    synth._plan_text("m", f, "y == 0", 0, ["closure"], "none", _ask("p4"))
    assert calls["n"] == 4


def test_offline_never_pays_and_returns_none_on_a_miss():
    calls = _counting_backend()
    os.environ["AEGIS_LLM_MODE"] = "offline"
    try:
        f = _Facts("contract C { uint z; }")
        assert synth._plan_text("m", f, "z == 0", 0, [], "none", _ask("q")) is None
        assert calls["n"] == 0
    finally:
        os.environ.pop("AEGIS_LLM_MODE", None)


def test_the_cap_stops_paid_calls():
    calls = _counting_backend()
    before = synth._paid_calls_so_far()
    os.environ["AEGIS_LLM_MAX_CALLS"] = str(before + 1)
    try:
        f = _Facts("contract C { uint w; }")
        synth._plan_text("m", f, "w == 0", 0, [], "none", _ask("r1"))
        assert synth._plan_text("m", f, "w == 1", 0, [], "none", _ask("r2")) is None
        assert calls["n"] == 1
    finally:
        os.environ.pop("AEGIS_LLM_MAX_CALLS", None)


if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            fn()
            print("PASS", name)
    print("ALL LLM BUDGET TESTS PASSED")
