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

## Module 0.3: Remote framework

- Remotes can only exist if declared in `RemoteConfig` with an explicit
  burst and per-minute rate. `Net.HandleEvent`/`Net.HandleFunction` reject
  unregistered names at boot, so a rogue remote cannot ship unnoticed.
- Spam: token bucket per `remote:userId`. Throttled calls are dropped
  (Events) or answered with a polite refusal (Functions), and counted via
  `Net.GetViolationCounts()` for the hardening audit in 6.4.
- Garbage payloads: Guard validators reject wrong types, NaN/infinity,
  out-of-range numbers, oversized strings/tables/arrays and extra arguments
  before any handler runs.
- Spoofed identity: the acting player is the first parameter from
  OnServerEvent/OnServerInvoke. Handlers never accept a player or UserId
  from the argument list as the actor.
- Handler crashes are caught; RemoteFunctions return a generic error so
  internal messages never leak to clients. Intentional refusals use
  Net.Refuse, which is the only path for player-visible reasons.
- ProfileSync: server to client push only; the server attaches no
  OnServerEvent listener, so client sends on it are inert.

## Module 1.1: Egg purchases

- `BuyEgg(tierId)`: tier must be a string of 32 chars max and exist in
  EggConfig. Cost comes from config only; the client cannot name a price.
  Insufficient funds and full storage refuse before any mutation. No yields
  between validation and debit, so double-spend racing is impossible.
- Rate limit: burst 4, 30/min. Spam is throttled and counted.
- Hidden Potential and server ledgers never reach the client: ProfileSync
  payloads pass through ProfileSanitiser (unit tested).
