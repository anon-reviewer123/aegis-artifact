import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

os.environ.pop("AEGIS_LLM_MODE", None)
os.environ.pop("AEGIS_LLM_MAX_CALLS", None)
os.environ["AEGIS_LLM_CACHE_DIR"] = tempfile.mkdtemp(prefix="aegis_llm_cache_")

from aegis import synth


def _counting_backend():
    calls = {"n": 0}

    def fake(client, model, sp, u, t):
        calls["n"] += 1
        return synth._CachedReply('{"reply": %d}' % calls["n"])
    synth._robust_create_uncached = fake
    return calls


def test_the_same_prompt_is_paid_for_once():
    calls = _counting_backend()
    first = synth._robust_create(None, "m", "sys", "prompt SAME", 0.2)
    for _ in range(4):
        again = synth._robust_create(None, "m", "sys", "prompt SAME", 0.2)
    assert calls["n"] == 1
    assert again.choices[0].message.content == first.choices[0].message.content


def test_a_different_prompt_is_a_different_question():
    calls = _counting_backend()
    synth._robust_create(None, "m", "sys", "prompt DIFF", 0.2)
    synth._robust_create(None, "m", "sys", "prompt DIFF2", 0.2)
    synth._robust_create(None, "m", "sys", "prompt DIFF", 0.9)   # temperature too
    synth._robust_create(None, "m2", "sys", "prompt DIFF", 0.2)  # and model
    assert calls["n"] == 4


def test_the_cache_can_be_switched_off_for_a_variance_run():
    calls = _counting_backend()
    os.environ["AEGIS_LLM_CACHE"] = "off"
    try:
        for _ in range(3):
            synth._robust_create(None, "m", "sys", "prompt C", 0.2)
        assert calls["n"] == 3
    finally:
        os.environ.pop("AEGIS_LLM_CACHE", None)


if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            fn()
            print("PASS", name)
    print("ALL LLM CACHE TESTS PASSED")
