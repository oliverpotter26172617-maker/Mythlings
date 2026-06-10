# Blockers

Log of issues that blocked progress for more than 30 minutes, attempted
fixes, and the workaround shipped.

## Blocker #1: Wally registry unreachable

- **Symptom:** `wally install` fails with `403 Forbidden Host not in allowlist`
  for `api.wally.run`.
- **Attempts:** direct install; registry index clones fine but the package
  download API is blocked by the environment network policy.
- **Workaround:** dependencies vendored into `Packages/` from upstream GitHub
  raw sources. `wally.toml` kept as the source of truth for intended versions.
- **Follow-up:** re-pin via Wally when building in an environment with
  registry access.

## Blocker #2: No Roblox Studio runtime for TestEZ

- **Symptom:** TestEZ requires a Roblox runtime; none exists on Linux CI.
- **Workaround:** `tools/run-tests.luau` (Lune) implements the TestEZ API
  surface used by our specs. Specs stay TestEZ-compatible for Studio runs.

## Blocker #3: selene cannot generate the Roblox std

- **Symptom:** `selene generate-roblox-std` fails with a TLS certificate
  error against the API dump host.
- **Workaround:** hand-maintained `roblox.yml` std in repo root with
  `lua_versions: [luau]`.
