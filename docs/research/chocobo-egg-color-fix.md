# Chocobo egg colors: Phoenix upstream integration

## Summary

- The local Phoenix baseline mistakes ordinary eggs' zero-filled DNA for inherited yellow genes.
- Current LandSandBoat and Phoenix beta already distinguish bred eggs by their existing marker.
- At the user's request, this test branch merges current Phoenix beta, including the newer Finbarr breeding rules.
- Regression coverage uses real native items, trainer trade packets, and an isolated test database.
- Existing raised chocobos are not recolored, and branch publication does not deploy the fix.

Researched 2026-10-03. This is a source comparison, not a claim that the running
server was updated or that native-client raising was tested. No retail captures
were independently acquired or inspected for this work.

## Revision boundaries

| Authority | Pinned revision | Result |
| --- | --- | --- |
| Local Phoenix baseline | `ec6661210c4a188cfb04f62e7ea7a7866a278656` | Ordinary zero-exdata eggs incorrectly reuse yellow genes. |
| Phoenix `origin/beta`, freshly fetched | `0f016c5c7b1639d16233fddb93db48e9a51222de` | Already has the bred-egg guard and a much larger breeding rewrite. |
| LandSandBoat `base`, GitHub API at research time | `d99f8106e66d932030936f2751e96cd401c50749` | Already has the same guard and breeding rewrite. |

The current Phoenix and LandSandBoat `breeding.lua` have identical Git blob
`5b69b35c9eb91e100822a38f07ce6884c0a36cb3`. The old local Phoenix checkout must not
be described as current upstream Phoenix or current upstream LandSandBoat.
The baseline is a local-only commit; public links for its four relevant source
files use `e1cab1c89448fe786895f121ad04e203f973d7be`, against which those files
have no diff.

## Root cause and lifecycle

`Exdata::ChocoboEgg::toTable` always emits three DNA entries and a boolean
`isBred`, including for an all-zero ordinary egg. Such an egg decodes to
`dna = { 0, 0, 0 }, isBred = false`. Zero is the yellow color enum. This is a valid
typed decoding, not evidence that the item was produced by breeding.
([Decoder](https://github.com/phoenixffxi/Phoenix/blob/e1cab1c89448fe786895f121ad04e203f973d7be/src/map/items/exdata/chocobo_egg.cpp#L26-L36))

The old `rollEggAlleles` only checks for a DNA table with three entries. It
therefore never reaches the ordinary-egg random-color path for a normal typed
egg. `newChocobo` calls this when constructing the raising record, stores all
three alleles, and computes the adult color. The roll occurs on initialization,
not when the chick's feathers become visible. Existing raising records are not
rerolled by changing this function.
([Old guard](https://github.com/phoenixffxi/Phoenix/blob/e1cab1c89448fe786895f121ad04e203f973d7be/scripts/globals/hobbies/chocobo_raising/breeding.lua#L125-L141),
[state construction](https://github.com/phoenixffxi/Phoenix/blob/e1cab1c89448fe786895f121ad04e203f973d7be/scripts/globals/hobbies/chocobo_raising/choco_data.lua#L12-L32))

The correct discriminator is `isBred`, not whether any gene is nonzero: a
legitimate bred yellow/yellow/yellow egg must retain its genes. The existing
packed format places that marker at bit 31 of the first word. Upstream tests
assert captured-item byte sequences ending in `0x80` for two bred eggs.
([Layout](https://github.com/phoenixffxi/Phoenix/blob/e1cab1c89448fe786895f121ad04e203f973d7be/src/map/items/exdata/chocobo_egg.h#L33-L46),
[upstream byte fixtures](https://github.com/LandSandBoat/server/blob/ff52c6f0f760c780622a89a96a881fdb2c67df8a/scripts/tests/systems/chocobo_raising/breeding.lua#L150-L160))

## Was LandSandBoat affected?

Yes, historically; not by this specific missing guard at the current pinned
revision. The chronology is important:

1. [Exdata definitions, `1b3e4abe`](https://github.com/LandSandBoat/server/commit/1b3e4abe823a394b6f6a30ab2fda32d8492bd57a), committed
   2026-04-03 02:02:19 UTC, introduced the typed DNA and bred flag.
2. [Breeding helper, `6db292dd`](https://github.com/LandSandBoat/server/commit/6db292dde7b7613cf2520badd5f6aef5ef6050c7), committed
   2026-04-29 10:21:53 UTC, introduced the guard that ignored that existing flag.
   This was not caused by a later typed-decoder migration.
3. [Breeding at Finbarr, `ff52c6f0`](https://github.com/LandSandBoat/server/commit/ff52c6f0f760c780622a89a96a881fdb2c67df8a), committed
   2026-09-27 23:25:21 UTC, added `bredExdata`, which rejects unbred eggs, and used
   it in `rollEggAlleles`. It was merged in
   [PR 11644](https://github.com/LandSandBoat/server/pull/11644) on
   2026-09-28 01:02:01 UTC. The same commit is in fetched Phoenix beta.

The current implementation explicitly documents zero-exdata eggs as unbred and
uses the marker before copying DNA.
([Marker guard](https://github.com/LandSandBoat/server/blob/ff52c6f0f760c780622a89a96a881fdb2c67df8a/scripts/globals/hobbies/chocobo_raising/breeding.lua#L134-L148),
[consumer](https://github.com/LandSandBoat/server/blob/ff52c6f0f760c780622a89a96a881fdb2c67df8a/scripts/globals/hobbies/chocobo_raising/breeding.lua#L417-L426))

## Safe scope and accuracy limits

The initial narrow backport was replaced at the user's request by merging
Phoenix `origin/beta` at the pinned revision above into
`codex/fix-phoenix-chocobo-colors`. Both upstream fixes are included:

- `ff52c6f0f760c780622a89a96a881fdb2c67df8a`: Finbarr breeding and the bred-egg marker guard.
- `b744ceaa86`: remove the raising UPSERT's trailing semicolon, which the
  prepared-query safety check rejects; drop stale gene columns via migration.

This is a full beta integration, not a color-only patch. It also brings current
schema/data and unrelated upstream features. The live checkout, database, and
server processes were not updated. Existing saved birds are not recolored.

Two merge conflicts were resolved: preserve local Windows-compatible account
variable registration while taking upstream's factored database helpers and
const-reference parameters; use upstream's more detailed zone-retry logging in
place of the older diagnostic-only logging. Local pending-zone handoff and
test-server session-cleanup protection remain present. The old local Wild Rabbit
fixture overrides were retired in favor of upstream tests matching current data
(60-second respawn, 150/1000 hare-meat drop rate).

The imported breeding implementation changes majority-color rules, ordinary-egg
probabilities by item warmth, and pooled-gene selection to per-slot inheritance
plus mutation. These differences matter to a Fantasy World planner.
([New color model and distributions](https://github.com/LandSandBoat/server/blob/ff52c6f0f760c780622a89a96a881fdb2c67df8a/scripts/globals/hobbies/chocobo_raising/breeding.lua#L348-L413),
[new inheritance](https://github.com/LandSandBoat/server/blob/ff52c6f0f760c780622a89a96a881fdb2c67df8a/scripts/globals/hobbies/chocobo_raising/breeding.lua#L214-L230))

The upstream PR describes capture-based reconfirmation, but that is upstream's
reported evidence, not this investigation's live proof. Its code explicitly
labels the 5% per-gene mutation chance as a guess. Source proves the implemented
odds; it does not prove exact retail odds. The old flat 30% non-yellow rate is
also an existing source policy, not newly validated retail probability.
([Mutation qualifier](https://github.com/LandSandBoat/server/blob/ff52c6f0f760c780622a89a96a881fdb2c67df8a/scripts/globals/hobbies/chocobo_raising/breeding.lua#L24-L25),
[old distribution](https://github.com/phoenixffxi/Phoenix/blob/e1cab1c89448fe786895f121ad04e203f973d7be/scripts/globals/hobbies/chocobo_raising/breeding.lua#L99-L122))

Fantasy World must identify which genetics version it targets. The older
same-color pure-parent guarantee does not carry over to the new model with
mutation. An unbred egg's blank DNA cannot reveal its eventual color before the
raising roll; a marked bred egg's encoded genes can be interpreted using the
server version's phenotype rules. Do not promise one universal color planner
across these two implementations.

## Validation and deployment receipts

Implementation and test receipts are recorded below. Neither publishing a
branch nor isolated tests establish that the live Phoenix server uses the fix.

### Reproduction before integration

On the old native build, 20 regression cases produced 7 passes and 13 failures.
Six exposed the unbred-DNA boundary (five egg types plus unmarked nonzero DNA).
Seven trainer trades exposed the rejected UPSERT: no persisted bird and no egg
consumption. The old-model test and logs are retained only in ignored `.deps/`;
they are not the acceptance suite for the new genetics.

### Test environment

- Own worktree and native `xi_test` build; never the live binary.
- Disposable MariaDB on `127.0.0.1:3449`, schema `chocobo_color_test`.
- Full core SQL import, Phoenix/era SQL modules, and migration checks. The first
  express update attempt was unsuitable during an uncommitted merge: HEAD still
  identified the old revision, leaving baseline tables absent or stale. A full
  import corrected this; the initially deferred fishing-rod module was then
  imported successfully. No upstream SQL patch was needed.
- Needed navmeshes/ximeshes copied from the existing local installation.
- The optional private `phoenix_ac` submodule was unavailable and was not built.
  These tests do not establish compatibility with that private module.
- New `egg_colors.lua` regression: all five colors through all five real ordinary
  egg types (25 cases), plus all five marked bred colors. Only RNG is controlled;
  native item decoding, trainer trade/update/finish packets, and SQL reload are real.

### Acceptance result

- Native MSVC `xi_test` build passed. The first incremental pass used a stale
  generated Species enum; rerunning the normal build rebuilt its dependent
  dataset and schema verifier successfully. No schema validation was bypassed.
- C++ startup suite: all 90 test cases passed (9,032,030 assertions).
- Focused native egg color suite: **30/30 passed**, including trainer packet
  completion, egg consumption, and persisted color/genes for every egg/color.
- Wider raising suite: **175/192 passed**. All 17 failures are digging setup
  failures: `setAccountVar` is missing on the test player. They are not color
  assertion failures, but this is not a clean whole-raising acceptance result.
- Lua style check passed for the added test. Imported upstream patch files have
  existing whitespace warnings; those unrelated patches were not reformatted.

Per the user's instruction, the upstream integration is retained on the test
branch and work continues on Fantasy World's read-only color inspection rather
than expanding into the digging harness. Publication is not live deployment or
retail-client validation; no retail captures were independently inspected.
