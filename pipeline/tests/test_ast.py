"""Tests for the real solc-AST analyzer's walker logic, using a hand-built
compact-AST fixture so they run even without solc installed. These lock in the
properties the regex analyzer could NOT provide: inherited state, modifier
reads/writes, and per-call-site ordering."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from aegis import ast_analysis as A


def _fixture_ast():
    return {
     "nodeType":"SourceUnit","nodes":[
       {"nodeType":"ContractDefinition","id":10,"name":"Base","contractKind":"contract",
        "linearizedBaseContracts":[10],
        "nodes":[{"nodeType":"VariableDeclaration","id":11,"name":"totalAssets","stateVariable":True}]},
       {"nodeType":"ContractDefinition","id":30,"name":"V","contractKind":"contract",
        "linearizedBaseContracts":[30,10],
        "nodes":[
          {"nodeType":"VariableDeclaration","id":31,"name":"totalShares","stateVariable":True},
          {"nodeType":"VariableDeclaration","id":32,"name":"exposed","stateVariable":True},
          {"nodeType":"ModifierDefinition","id":40,"name":"guard","body":{"statements":[
             {"nodeType":"ExpressionStatement","expression":{"nodeType":"Assignment","operator":"=",
                "leftHandSide":{"nodeType":"Identifier","name":"exposed","referencedDeclaration":32},
                "rightHandSide":{"nodeType":"Literal","value":"true"}}}]}},
          {"nodeType":"FunctionDefinition","id":50,"name":"f","kind":"function","visibility":"public",
           "modifiers":[{"nodeType":"ModifierInvocation","modifierName":{"name":"guard"}}],
           "body":{"statements":[
             {"nodeType":"ExpressionStatement","expression":{"nodeType":"FunctionCall",
                "expression":{"nodeType":"MemberAccess","memberName":"onAssetReceived",
                   "expression":{"nodeType":"Identifier","name":"recv"}}}},
             {"nodeType":"ExpressionStatement","expression":{"nodeType":"Assignment","operator":"-=",
                "leftHandSide":{"nodeType":"Identifier","name":"totalShares","referencedDeclaration":31},
                "rightHandSide":{"nodeType":"Literal","value":"1"}}}]}}]}]}


def _patched():
    A._get_ast = lambda p: _fixture_ast()
    A.ast_available = lambda: True
    return A.analyze_ast("dummy.sol")


def test_inherited_state_included():
    facts = _patched()
    assert "totalAssets" in facts.storage_vars


def test_modifier_writes_attributed_to_function():
    facts = _patched()
    assert "exposed" in facts.functions["f"].writes


def test_call_ordering():
    facts = _patched()
    site = facts.exposure_sites[0]
    assert site.function == "f"
    assert "totalShares" in site.write_after_call


if __name__ == "__main__":
    for n, fn in sorted(globals().items()):
        if n.startswith("test_") and callable(fn):
            fn(); print("PASS", n)
    print("ALL AST TESTS PASSED")
