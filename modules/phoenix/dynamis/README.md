# Phoenix-era Dynamis run supervision

- The Dynamis zone owns retained run timers; the 400 ms zone tick does not poll SQL.
- Reservations are supervised before the first player enters; idle occupants still undergo hourglass enforcement.
- Timer mutations retain ordinary synchronous persistence, not the volatile server-variable cache.
- **First installation requires a cold map/zone initialization. Do not hot-copy this change into a running server.** Subsequent file reloads preserve zone-owned state.
- The entry zone and its Dynamis destination must be loaded on the same map process. Offline checks below are not live gameplay or performance acceptance.

## Ownership and lifecycle

The era module routes each Dynamis `onZoneTick` to
[`dynamisTick`](../../../scripts/globals/dynamis/dynamis_system.lua).
[`run_state.lua`](../../../scripts/globals/dynamis/run_state.lua) retains
`StartTime`, `ExpirationTime` and `NoPlayerTimer` in the owning `CZone`'s local
variables, alongside the existing `ReservationExpires` and `PlayersEntered`.
There is no new global SQL cache and no new background timer. Other zone timers,
400 ms gameplay cadence, debug-mode behavior, 180-second reservation window,
595-second abandonment deadline, 90-second cooldown and existing ejection rules
are unchanged.

| Transition | Owner / retained state effect |
| --- | --- |
| Cold zone initialization | `clearOnInit` establishes initialized-idle and reads the persistent start/expiry keys. A stale run is cleaned, never restored. |
| Successful timeless registration | `entryNpcOnEventUpdate` checks destination readiness before consuming the glass. `registerDynamis` persists and retains start/expiry/no-player timers, establishes the existing reservation and arms warnings. |
| First observed occupant | `handleNoPlayers` marks entered and clears the reservation. Merely registering is not entry. |
| Last occupant leaves | Existing abandonment conditions persist/retain a deadline. Return clears it before testing that deadline. |
| Time extension | `addMinutesToDynamis` updates persistent and retained expiry, refreshes glasses and re-arms all warning thresholds, including ones already due. Tavnazia and mob/QM extension callers still use this owner. |
| Expiry / abandoned / unused reservation | Existing predicates call `cleanupDynamis`. SQL keys and local state are reset; an initialized-idle marker is reestablished. |
| Cleanup inside a tick | `handleNoPlayers` takes a new retained-state read after possible cleanup, not the tick's pre-cleanup expiry/timer snapshot. |
| Empty initialized-idle zone | No SQL read or supervision work. An idle zone with non-GM occupants still validates their glass with zero run times and uses the existing ejection path. |
| Unexpected owner-state loss | A tick raises a clear initialization error; entry is denied. Missing state is not interpreted as idle and cannot be silently reconstructed from stale SQL. |

The per-zone 600/180/30-second warning sent flags replace file-local callback
queues. Registration and extension re-arm them. Reloading either Lua global does
not recreate the `CZone`, reset timers or lose/double-fire a warning. The previous
queue's iteration order was unspecified; the warning thresholds, messages and
repeat-on-extension behavior are retained.

### Initialization, reload and unsupported mutations

`clearOnInit` is the existing zone initialization hook, not a reload handler.
Ordinary globals reload re-requires the Lua file; it does not call this hook.
The initialized marker therefore survives normal script reload. Full zone/map
recreation runs cold initialization and cleans stale persisted runs. Intentional
cleanup resets local variables and restores the marker immediately. Unrelated
manual `resetLocalVars` loses the marker and fails closed rather than losing an
active run silently.

There is deliberately **no first-tick hydration** and no automatic migration from
the old file-local warning table. Install the files together on a safely stopped,
owned test server, cold-start it, and validate there first. Live deployment is a
separate gated operation, not part of the offline tests.

This module already uses process-local `GetZone` lookups, parent-zone local
cooldowns and in-memory participant lists. Splitting an entry/Dynamis pair across
map workers is unsupported. Admission now rejects an unavailable/uninitialized
destination even for GM entry. There is no IPC coherence protocol. Do not treat
a persistent SQL key as sufficient evidence that a remote run can be admitted.
Co-locate each pair before considering a multi-map deployment.

Arbitrary SQL edits, raw `SetServerVariable` calls for these timer keys from other
processes or `!exec`, and direct timer-local edits are unsupported while the owner
is active. Future timer writers must route through the run owner (or add explicit
invalidation/coherence with tests), not bypass it. Read-only SQL consumers remain
supported. No general native binding was wrapped or replaced.

### Persistence boundary

`runState.set` keeps ordinary `SetServerVariable` persistence at lifecycle
mutations and then updates the owning zone's retained value. Cleanup keeps its
existing persistent clears and participant cleanup. It does not use
`SetVolatileServerVariable`, defer writes for a minute, or cache arbitrary server
variables. Existing persistence ordering remains synchronous, but the native
setter returns **no success acknowledgement**. This change does not introduce a
transaction or a durability guarantee beyond that API. Database-failure behavior
still requires separate fault-injection/integration validation; no database was
contacted by the offline harness.

## Writer and consumer audit

Audited at Phoenix base `ec6661210c4a188cfb04f62e7ea7a7866a278656`, including
dynamically assembled timer key names in the era scripts.

| Surface | Treatment |
| --- | --- |
| `npc_handlers.lua` initial start/expiry writes | Moved into `registerDynamis`, the run owner; readiness checked before consuming the Timeless Hourglass. |
| `registerDynamis` timer reset/creation | Uses retained/persistent setter; participants, capacity, lockout and spawn rules remain in their existing owners. |
| `handleNoPlayers` abandonment/return writes | Uses retained/persistent setter. |
| `addMinutesToDynamis`, `addTimeToDynamis`, `zonemechs/tavnazia.lua` | Extension delegates to the same owner; no independent timer writer remains. |
| `cleanupDynamis`, `clearOnInit` | Persistently clear stale/finished timers, then publish initialized-idle, never resurrect a run. |
| `dynareset`, zone-cleaning `rdyna` branches | Already call `cleanupDynamis`; they now reset retained state as well. |
| `dynastart` | Still only spawns/debugs through `onNewDynamis`; it is not a persistent era reservation creator. No behavior redesign. |
| `adddynatime` | Existing retail status-effect command, not a writer of these shared era timer keys; untouched. |
| `dynamisTick` / `handleNoPlayers` | Retained reads only. `hasHourglass` already receives the tick's run times and does not read SQL. |
| `hourglass.lua` trade validation, use/check refresh, glass updates | Existing synchronous SQL reads remain at interactions; see mutations through unchanged persistence keys. |
| `npc_handlers.lua` admission, `isZoneAbandoned` | Existing SQL interaction reads remain, with destination-owner readiness gating admission. |
| `onRunEntry`, `zoneOnZoneInEra`, `registerPlayer`, `dynavars` | Existing SQL event/read-only diagnostic consumers remain. Registered count/instance identity are not moved into this small timer owner. |
| `participants.lua` | Existing global table is already retained across reload and is reset by the existing cleanup owner. |

## Executable offline checks

[`tools/tests/dynamis_run_state.lua`](../../../tools/tests/dynamis_run_state.lua)
loads the **real** era system, NPC, hourglass, participant, entry and ejection Lua
files. Only native/SQL/time/world boundaries and unrelated mob/lockout effects are
test doubles. This separate entry point is necessary because the repository's
`xi_test` embeds the server and requires a populated schema; it is not safe to
point that executable at a live database for this check. The harness opens no
socket and calls no database driver or server executable.

From the repository root, with LuaJIT 2.1 (also checked with Lua 5.4):

```powershell
luajit tools/tests/dynamis_run_state.lua
```

The 16 regression cases cover idle zero reads/writes, real NPC reservation,
never-entered timeout, delayed entry, abandonment/return, extension near expiry,
re-armed elapsed warnings, invalid-hourglass delayed ejection, idle trespass and
GM exemption, cleanup's post-expiry state, occupant expiry, cleanup/reentry glass
identity, cold state recreation, globals reload, unexpected state loss and
missing-destination admission, and unchanged GM debug/cleanup behavior.

### Matched baseline/candidate checks

Extract only the baseline Lua files to ignored task-local scratch, without
checking out or running another server:

```powershell
New-Item -ItemType Directory -Force tmp-dynamis | Out-Null
Set-Content tmp-dynamis/.gitignore '*'
git archive --format=zip --output=tmp-dynamis/baseline.zip ec6661210c4a188cfb04f62e7ea7a7866a278656 scripts/globals/dynamis
Expand-Archive tmp-dynamis/baseline.zip -DestinationPath tmp-dynamis/baseline -Force
luajit tools/tests/dynamis_run_state.lua benchmark tmp-dynamis/baseline
luajit tools/tests/dynamis_run_state.lua benchmark .
luajit tools/tests/dynamis_run_state.lua trace tmp-dynamis/baseline | Out-File -Encoding utf8 tmp-dynamis/baseline-trace.txt
luajit tools/tests/dynamis_run_state.lua trace . | Out-File -Encoding utf8 tmp-dynamis/candidate-trace.txt
if (Compare-Object (Get-Content tmp-dynamis/baseline-trace.txt) (Get-Content tmp-dynamis/candidate-trace.txt)) { throw 'Lifecycle trace mismatch' }
```

Check each interpreter invocation's exit code as well as its output. Benchmark
mode asserts the expected read count itself. It runs five trials of each
idle/reserved/occupied case: ten fixture zones, 300 ticks/zone at the unchanged
400 ms cadence, 120 simulated seconds, after identical initialization and real
NPC registration where applicable. It excludes transition/startup SQL and does
not claim all Dynamis SQL was eliminated.

Observed on this candidate:

| Workload (five trials each) | Baseline mocked reads / trial | Candidate mocked reads / trial | Tick writes in either arm |
| --- | ---: | ---: | ---: |
| Initialized idle | 12,000 | 0 | 0 |
| Reserved, not yet entered | 12,000 | 0 | 0 |
| Occupied, valid hourglass | 12,000 | 0 | 0 |

Trace mode matches **14 lifecycle checkpoints** byte-for-byte between baseline
and candidate. It covers registration, entry, warning, extension, departure,
return, expiry, ejection grace/cutscene/fallback, unused-reservation timeout,
cooldown denial and new registration. Snapshots compare durable timer keys,
reservation/abandonment/cooldown state, participant/lockout effects, glass exdata,
player state, messages, pending timer deadlines and entry/ejection outputs. Only
implementation-private new fields and query counts are excluded. Warning message
order is normalized because the baseline uses unordered `pairs`; duplicates and
message values are retained.

These counts prove removal of calls through mocked native SQL bindings in real
Lua control flow. They are **not MariaDB query-duration measurements, CPU
benchmarks, a server tick-latency measurement, native entity integration, retail
capture evidence, or live gameplay proof**. No performance percentage beyond the
specified call-count workload should be inferred.

## Remaining live gates

Before production deployment or an upstream contribution:

1. Cold-start an explicitly owned isolated Phoenix test instance/database with
   matching source/config identity; do not run server tests against populated
   live databases. Verify native zone-local persistence across globals reload
   and the startup marker/cleanup behavior, not only fixture tables.
2. Replay actual NPC trade/cutscene entry, delayed/unused reservation, valid and
   invalid hourglass checks, extensions, departure/return, cleanup/reentry and GM
   reset on dedicated permitted actors. Inspect real game-client outcomes and
   the in-app browser where that is the user-facing workflow.
3. Correlate actual SQL counts and map scheduling tails with database waits and
   OS scheduling under matched 6/12/18 active-character same-/multi-zone
   workloads. Retain at least five valid trials per comparison arm and a soak;
   use Fantasy World's existing performance capture/compare contract rather than
   treating this deterministic counter harness as the latency decision runner.
4. Validate database error handling and cross-zone ownership assumptions. Do not
   enable split entry/Dynamis topology without a deliberately tested coherence
   design. Do not change 400 ms gameplay cadence, flush durability or watchdog
   settings to make a measurement pass.

No live server, populated database, active character, runtime setting or plugin
was changed for these offline results. No upstream PR or deployment is implied.
