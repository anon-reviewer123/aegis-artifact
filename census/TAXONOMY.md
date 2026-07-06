# Callback Taxonomy

Each contract in `contract_labels.csv` is labeled with the callback-related
classes it exhibits. Labels are assigned from the contract source. A contract
may fall into more than one class, so its `classes` field can list several
entries separated by semicolons. A contract that is callback-capable but shows
no specific callback-desync pattern is marked `none`.

The taxonomy groups callback-related issues along three dimensions.

## State corruption

These classes cover cases where a callback can observe or change accounting
state while an operation is still in progress.

- **cross_function_reentrancy** — a state variable left inconsistent during a
  callback is also used by another public or external function, which can act on
  it during the callback window.
- **classic_reentrancy** — a function makes an external call and then updates
  contract state after the call returns, so a re-entrant call runs before the
  update takes effect.
- **readonly_reentrancy** — a state variable left inconsistent during a callback
  is exposed through a view function or a public getter, so an external observer
  reads stale accounting.
- **cross_contract_oracle_desync** — a callback-exposed function also depends on
  an external price or oracle value, so a callback can act while that value is
  out of sync.
- **token_hook_desync** — a token receiver hook runs while contract accounting
  is mid-update, allowing the hook to observe or disturb the in-progress state.

## Control and liveness

These classes cover cases where a callback blocks progress or changes the
intended control flow.

- **forced_revert_griefing** — an external call inside a loop lets a single
  reverting recipient block the whole operation.
- **unexpected_callback_eoa** — value is sent to an address that the code treats
  as a plain account, but the recipient may be a contract that takes control.
- **gas_griefing** — a callee can consume or withhold gas to disrupt the calling
  operation.

## Callback timing

These classes cover cases where the callback happens in the wrong protocol
phase.

- **phase_ordering_desync** — a function updates state both before and after an
  external call, leaving a distinct intermediate phase visible during the
  callback.
- **flashloan_callback** — the contract hands control to borrower code through a
  flash-loan callback entry point.
