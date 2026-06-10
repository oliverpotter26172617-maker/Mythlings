# Mythlings Security Notes

Red-team log per THE LOOP step 4. Every RemoteEvent/RemoteFunction gets an
entry: what the client can send, how it is validated, and its rate limit.

Standing rules enforced across all modules:

- The server never trusts a client-supplied identity. The acting player is
  always taken from the remote invocation, never from arguments.
- All currency mutations, random rolls (hatching, breeding, loot) and battle
  resolution happen on the server.
- Every remote has a per-player rate limit and strict argument validation;
  violations are logged and excess traffic is dropped.
- Config values are deep-frozen at load so no script can mutate tunables at
  runtime.

(Entries are appended per module from 0.3 onward.)
