# Phoenix chocobo breeding and target-color research

## Five-point summary

- Same-color pure parents guarantee that color in the genetic helper; matching appearance alone is insufficient.
- Parent-card genes and bred-egg genes travel in normal item exdata, so runtime prediction need not query the database.
- Finbarr matchmaking and gene-bearing parent-card issuance are not wired into player gameplay at this revision.
- Ordinary zero-exdata eggs bypass the intended founder RNG and become yellow; fix the marker contract before promising founder colors.
- Exhaustive isolated Lua checks passed, but no native client capture, live breeding loop, server deployment, or retail validation was performed.

## Authority and validation boundary

- Research date: 2026-10-03.
- Semantic authority: `C:\Users\Russell\ffxi\phoenix-local`, pinned commit `ec6661210c4a188cfb04f62e7ea7a7866a278656`.
- All semantic citations below refer to that commit, read through `git show <revision>:<path>`, not working-tree instrumentation. Line references are inclusive.
- This is source research, not proof that a running map server has this code loaded, not a live player breeding run, and not retail parity. Retail captures were not used.
- Initial checkout: branch `codex/conquest-ties-keep-owner`; pre-existing untracked fixture/telemetry commands and `settings/main.lua.before-20261002` were left untouched. No server mechanics were changed.

## Decision summary

**A deterministic target-color strategy exists in the genetic helper, but the player breeding workflow is not implemented at this revision.** Two opposite-sex parents carrying three copies each of the desired color would produce that color on every helper call. Appearance alone does not prove those genes. The right Fantasy World feature is therefore a source-profile-aware genetic planner plus guarded lifecycle orchestration, not a promise that Finbarr currently accepts a color-directed breeding request.

The helper has three material limitations that must remain visible:

1. `breedEgg` and `chocoStateToCardDna` have no callers in the pinned repository. Finbarr's trade handler is empty and his trigger only opens the generic introduction event, not dates or purchases. There is no implemented wait-for-next-day/egg-retrieval lifecycle to automate. [S1, S2]
2. Ordinary zero-exdata eggs decode to three yellow genes, and `rollEggAlleles` accepts those genes without checking `isBred`. Therefore the helper's intended 70% yellow / 30% colored non-bred distribution must not be advertised as the outcome of the ordinary item path at this revision. [S3, S4, S5]
3. Raising is separately gated by `ENABLE_CHOCOBO_RAISING`; a helper being present does not make trainers accept eggs. Deployment/configuration evidence must be attached to any operational support claim. [S6]

## Implemented genetic model

The raising color IDs are yellow `0`, black `1`, blue `2`, red `3`, green `4`. These are raising/egg/card IDs, not the doubled mount color enum. Each bird has three ordered alleles. [S7]

`allelesToColor(dna)` applies these rules:

- Missing DNA argument means yellow.
- Any yellow allele means a yellow bird, even if its other two alleles are colored.
- With no yellow, the most frequent allele wins.
- Three distinct non-yellow alleles tie; **the first allele wins**. Iteration over `pairs(counts)` does not make this tie random, because a winner only replaces the initial first allele on a strictly greater count. [S3]

Examples:

| Ordered DNA | Expressed color | What appearance does not reveal |
| --- | --- | --- |
| Y/Y/Y | Yellow | No hidden non-yellow gene |
| Y/R/R | Yellow | Two red alleles are hidden |
| R/R/R | Red | Pure red, breeds true with another pure-red parent |
| R/R/B | Red | Carries a blue allele |
| R/B/G | Red | Only the first allele chooses red; not a majority or pure-red bird |

A red appearance rules out yellow genes in this helper's model but **does not establish R/R/R**. A yellow appearance could be any genotype containing at least one yellow allele. The order of genes also matters when predicting the already-created egg's phenotype. [S3]

## Exact offspring probabilities

`inheritDna` pools up to three maternal and three paternal alleles, pads missing/short DNA with yellow until the pool has six, Fisher-Yates shuffles the six positions, then takes the first three. There is no mutation, no independent gene-color roll, and no guarantee of taking at least one gene from each parent. The chick can receive all three positions from one parent. Each of the 20 unordered three-position subsets is equally likely; each of 120 ordered three-position draws is equally likely. The shuffle has five integer RNG calls. `math.randomInt` uses closed integer bounds. [S8, S9]

The following are exact mathematical consequences of that algorithm, assuming valid genes and unbiased RNG. `R` can be replaced with any desired non-yellow color, and `B` with another non-yellow color.

| Maternal DNA | Paternal DNA | Exact visible-color distribution | Chance of pure R/R/R offspring |
| --- | --- | --- | --- |
| Y/Y/Y | Y/Y/Y | 100% yellow | 0% |
| R/R/R | R/R/R | 100% red | 100% |
| Y/Y/Y | R/R/R | 95% yellow, 5% red | 5% |
| Y/R/R | R/R/R | 50% yellow, 50% red | 50% |
| Y/R/R | Y/R/R | 80% yellow, 20% red | 20% |
| R/R/R | R/R/B | 100% red | 50% |
| R/R/R | B/B/B | 50% red, 50% blue | 5% |
| R/R/B | R/B/G | 60% red, 30% blue, 10% green | 5% |

### General formula

Let `y` be the number of yellow alleles in the combined six-position pool. Then:

- `P(non-yellow phenotype) = choose(6 - y, 3) / 20`.
- `P(yellow phenotype) = 1 - choose(6 - y, 3) / 20`.

For a desired non-yellow color with pool count `t`, and the counts `c_i` of each other non-yellow color:

`P(target) = [choose(t, 3) + choose(t, 2) * sum(c_i) + (t / 3) * sum_{i < j}(c_i * c_j)] / 20`.

Treat `choose(n, k)` as zero when `n < k`. The last term covers three-distinct-color draws; the target occupies the first position with probability one third. `P(pure target/target/target) = choose(t, 3) / 20`.

For implementation, enumerating all 120 ordered draws avoids special-case formulas and correctly handles the first-gene tie break. Exact rational counts can be retained instead of rounding probabilities too early.

### Necessary and sufficient deterministic conditions

For valid five-color genes in the six-position pool:

- **Guaranteed yellow:** at least four of the six alleles are yellow. Every three-position draw then includes yellow.
- **Guaranteed desired non-yellow color:** zero yellow alleles and at least five of the six alleles equal the desired color. Every draw then contains at least two target alleles.
- Both parents pure for the same target color are the simplest guarantee and preserve purity in every offspring.
- A pure target parent paired with target/target/other also guarantees the target appearance, but only half the offspring are pure target. Keep that distinction in the UI and breeding inventory.
- Four target genes out of six are **not** enough to guarantee the target, even if there is no yellow. A possible draw contains one target and both other genes; the others either form a competing majority or a three-way tie which may select a different first gene.
- A pure yellow parent crossed with a pure target parent cannot be made deterministic by choosing a date plan. Its target-color chance is 5%.

These guarantees are deductions from [S3, S8], not an implemented user-facing promise or a claim of live success.

## Founder acquisition: intention versus actual supported-item path

The standalone `rollNonBredEggAlleles` helper intends to return:

- Y/Y/Y on integer rolls 1 through 70: 70%.
- Otherwise one of black, blue, red or green, uniformly, with all three genes set to that color: 7.5% each.

Consequently, if the fallback were reached, every colored founder from it would be genetically pure and suitable for deterministic same-color breeding. Egg warmth/item variant is not consulted by this helper. [S3]

However, `rollEggAlleles(egg)` uses any `exdata.dna` table containing at least three entries, including `{ 0, 0, 0 }` with `isBred == false`. It never checks `isBred`. All ordinary supported egg IDs are mapped to `Exdata::ChocoboEgg`, whose decoder unconditionally exposes DNA1/DNA2/DNA3; fresh items initialize all extra bytes to zero. Hence a fresh ordinary egg yields Y/Y/Y and bypasses the intended random-color fallback. This is a source-derived integration defect, not evidence that the running server has produced a specific bird. [S3, S4, S5]

The eventual implementation needs an explicit contract for non-bred eggs (for example, use the bred marker to decide whether inheritance DNA is authoritative) and a native/item-boundary regression test. A Lua test with a fake `getExData()` returning an empty table is insufficient to prove the ordinary C++ item path.

## Lifecycle and RNG ledger

| Phase | Actual implementation at the pinned revision | RNG boundary / persistence | Evidence |
| --- | --- | --- | --- |
| Parent-card issuance | `chocoStateToCardDna` copies saved alleles or defaults missing values to yellow, but has no production caller | No RNG in helper; no player card issuance path through this helper | S1, S3 |
| Finbarr matchmaking | `onTrade` does nothing; `onTrigger` starts 10103; all date/egg/purchase starts are comments | No parent validation, no breeding roll, no wait timer, no egg commit | S2 |
| Ticket purchase handler | Event-finish handler for 10108/options 1-4 checks 3,500 gil, free slot, and no existing ticket; stores plan on ticket | No color RNG; ordinary NPC trigger does not initiate 10108 | S2 |
| Hypothetical helper call | `breedEgg(motherCard, fatherCard, plan)` returns DNA, one ability, plan and `isBred=true` | Five DNA shuffle RNG calls, then conditional ability rolls; this helper does not give an item or consume parents/ticket | S8, S10 |
| Egg hand-in | Enabled trainer accepts one supported egg if no raised chocobo; trade event finish option 252 invokes `newChocobo(player, egg)` | Gender and, only if DNA fallback is reached, founder DNA resolved **at hand-in**, not hatch; save success confirms trade | S6, S11, S12 |
| Incubation and growth | `created` is hand-in system time; `age = floor((now-created)/dayLength)+1` | Saved genes/color are not rerolled at a hatch event | S12, S13 |
| Client color appearance | Egg and chick event appearance is forced yellow; adolescent/adult event appearance uses saved `chocoState.color` | Seeing a yellow chick does not prove its final color is yellow | S14 |
| Retirement | Main event finish deletes the raised-chocobo record when `retiring`; registration-card/plaque handover remain TODOs | Destructive retirement is not a demonstrated recoverable parent-card acquisition workflow | S6 |

**No reseeding, egg-name inspection, food choice, date timing, moon phase, weather, day of week, or raising care plan is read by `inheritDna` or `allelesToColor`.** The helper reads only the two cards' genes for color. Once a bred egg's DNA is serialized, its final color is a deterministic decode, not another color roll at hand-in or hatch. The current ordinary zero-exdata path is also deterministic, but deterministically yellow because of the defect above. [S3, S8, S10, S12]

Default source raising durations are one Earth day per age unit, chick threshold 4, adolescent threshold 19, first adult threshold 29, subsequent thresholds 43, 64, 129. A custom QoL module changes some scalar thresholds to 2/7/14, but its presence is not proof it is enabled. Do not predict real completion timestamps without verifying enabled modules, loader behavior, actual stage transitions and server time. [S13, S15]

## Honeymoon plans and non-color inheritance

Plans do **not** change DNA or color probabilities. [S8, S10]

| Plan | Value | Intended gender at new-chocobo creation | Ability preference |
| --- | --- | --- | --- |
| Gourmet / A | 1 | 70% male, 30% female | None |
| Sports / B | 2 | 50% male, 50% female | Gallop, Canter, Auto-Regen |
| Hiking / C | 3 | 30% male, 70% female | None |
| Jeuno Tour / D | 4 | 50% male, 50% female | Burrow, Bore, Treasure Finder |

`inheritAbility` deduplicates non-NONE parental abilities. With none, the result is NONE without an inheritance RNG roll. Otherwise inheritance chance is `60 + floor(3 * average(receptivity.rank))` percent: 60-81% for valid rank 0-7. If inheritance succeeds and the selected plan has any favored abilities in the pool, 70% of the subsequent preference branch selects uniformly from the favored subset; the remaining branch still selects uniformly from the full pool, which includes favored abilities. Thus the total chance of a favored ability is **not simply 70%**. Conditional on inheritance, if there are `f` favored abilities among `n` unique abilities, it is `70% + 30% * f/n`. [S7, S10]

Gender is a separate random roll in `newChocobo`, after retrieving the plan from the egg. The function initializes all four stats to zero: this path does not inherit starting stat values from the parents. One inherited ability is copied from egg exdata; the second ability starts NONE. Sex/ability guarantees must not be inferred from a color guarantee. [S3, S12]

## Requirements for a Fantasy World feature

1. **Pin a server mechanic profile.** The planner's Phoenix profile needs a revision/capability receipt. It must distinguish genetic-helper support, raising enabled, matchmaking enabled, card issuance enabled and egg-marker correctness. Fail closed on currently missing player lifecycle stages.
2. **Separate observations from inference.** Represent observed appearance, raw card/egg genes when legitimately available through the existing native item observation layer, saved ancestry, unknown genes, and model-predicted probabilities as different fields. Never infer pure genotype solely from a colored appearance.
3. **Provide exact selection metrics.** Show target-color probability and pure-target-offspring probability separately. If parent genes are unknown, show uncertainty or genotype bounds, not a fabricated exact percentage. Search candidate male/female cards by the desired color objective; date plan is a sex/ability preference, not a color optimizer.
4. **Make the server own outcome settlement.** The long-running workflow should use the real parent-card/ticket trade, persisted server incubation state and actual egg receipt. Fantasy World must not invent an egg or locally reroll damage-style receipts into a presumed server outcome.
5. **Persist lineage and immutable receipts.** Record parent-card identities/genes, chosen plan, submitted trade, created egg identity/exdata, trainer hand-in, saved raising state, adolescent color and final card receipt. Recover after restart without replaying a breeding submission.
6. **Keep safe rejection paths.** Validate target NPC identity/range, opposite-sex usable parents, exact trade items, inventory space, costs, slot capacity and no existing incubation/raising conflict. Do not sacrifice an existing raised bird merely to create room; retirement currently deletes the record and has incomplete item handover.
7. **Prove the real route before advertising execution.** Native item decoder tests, source probability tests and browser planner validation are useful but lower than a live client date/trade/egg/raising/color/card loop. The dormant lifecycle and non-bred marker defect require server work before that full loop can succeed.

## Source index

Every source reference below is at `ec6661210c4a188cfb04f62e7ea7a7866a278656`.

- **S1**: Whole-repository pinned search for `breedEgg` and `chocoStateToCardDna`; results are definitions/comments only in `scripts/globals/hobbies/chocobo_raising/breeding.lua`. No matchmaking/card caller or module override was found. Reproduce with `git grep -n -e breedEgg -e chocoStateToCardDna <revision> -- .`.
- **S2**: `scripts/zones/Upper_Jeuno/npcs/Finbarr.lua:20-55` (empty trade, only generic trigger, commented event starts), `:57-81` (ticket purchase finish branch).
- **S3**: `scripts/globals/hobbies/chocobo_raising/breeding.lua:60-89` (phenotype), `:91-98` (state-to-card genes), `:107-122` (non-bred intended founder roll), `:128-141` (DNA-presence test/fallback), `:146-168` (gender), `:176-189` (inherited ability unpacking).
- **S4**: `src/map/items/exdata/chocobo_egg.cpp:26-36` (unconditional DNA/marker decode), `src/map/items/exdata.cpp:133-137` (supported egg IDs map to egg decoder), `:244-246` (dispatch).
- **S5**: `src/map/items/item.cpp:49-66` (new item extra bytes zeroed).
- **S6**: `scripts/globals/chocobo_raising.lua:104-135` (enable guards), `:143-154` (hand-in creation/save/confirm trade), `:164-170` (retirement deletes state; item handovers TODO).
- **S7**: `scripts/enum/chocobo_raising.lua:7-24` (colors/plans), `:26-49` (ranks/abilities), `:61-66` (gender).
- **S8**: `scripts/globals/hobbies/chocobo_raising/breeding.lua:226-252` (parent pool/padding/Fisher-Yates draw).
- **S9**: `src/map/lua/luautils.cpp:281-288` (`math.randomInt` closed integer bounds).
- **S10**: `scripts/globals/hobbies/chocobo_raising/breeding.lua:195-211` (plan ability categories), `:255-276` (deduplicated ability pool), `:284-302` (average receptivity rank), `:305-334` (ability rolls), `:339-347` (egg object construction).
- **S11**: `scripts/globals/hobbies/chocobo_raising/event_playout.lua:12-40` (one supported egg accepted only with no raising record), `scripts/globals/hobbies/chocobo_raising/constants.lua:8-22` (trainer events/locations).
- **S12**: `scripts/globals/hobbies/chocobo_raising/choco_data.lua:12-55` (creation, genes/color, gender, zero stats, ability), `:60-71` (save/update), `:112-119` (age reconstruction).
- **S13**: `scripts/globals/chocobo_raising.lua:48-59` (default timing thresholds), `scripts/globals/hobbies/chocobo_raising/constants.lua:586-605` (stage-boundary table), `scripts/globals/hobbies/chocobo_raising/choco_data.lua:148-207` (elapsed report/stage event construction).
- **S14**: `scripts/globals/hobbies/chocobo_raising/event_vm.lua:451-465` (egg/chick yellow, adolescent/adult stored color).
- **S15**: `modules/custom/lua/chocobo_raising_qol.lua:12-22` (conditional startup override changes scalar growth thresholds).

## Client-only observability and the existing Fantasy World owner

The server sends the complete 24-byte item attribute using `memcpy(packet.Attr, PItem->m_extra, sizeof(PItem->m_extra))` in `src/map/packets/s2c/0x020_item_attr.cpp:65-77`; the packet's attribute array is declared in `0x020_item_attr.h:36-45`. This is ordinary inventory data, not a database-only secret. Decoding it is source-confirmed feasible; receipt in the current client and its exact native memory representation have not been captured for a real chococard/egg in this research.

The packed layouts at the pinned Phoenix revision are:

| Item payload | Byte/bit layout relative to the 24-byte attribute | Source |
| --- | --- | --- |
| Chocobo egg | Little-endian word at byte 0: DNA1 bits 0-2, DNA2 3-5, DNA3 6-8, ability 9-12, reserved bit 13, plan 14-15, reserved 16-30, bred marker bit 31 | `src/map/items/exdata/chocobo_egg.h:29-43` |
| Chococard | Stats bytes 0-3; little-endian word at byte 4: DNA1 bits 0-2, DNA2 3-5, DNA3 6-8, ability1 9-12, ability2 13-16, temperament 17-19, weather 20-23, gender 24, visible color 25-27, size 28-30, reserved 31; padding bytes 8-11, signature bytes 12-23 | `src/map/items/exdata/chocobo_card.h:29-63` |

The typed decoders expose both genes and the separate visible-color field (`chocobo_card.cpp:47-75`) and always expose all three egg genes plus the marker (`chocobo_egg.cpp:26-36`). `CLuaItem::getExData` invokes that typed decoder (`src/map/lua/lua_item.cpp:366-380`), proving the zero-egg path is not an empty DNA table.

A stock visible bird color does not reveal its genotype. An eventual Fantasy World item inspector can reveal genotype from the normal native inventory observation and predict a **bred** egg's final color immediately. Non-bred eggs must remain profile-dependent: after the intended marker fix, their color would not exist until hand-in, so client inspection before hand-in cannot predict the future RNG roll. Egg warmth is not a color selector. Early egg/chick presentation is yellow, although report event updates may carry stored color separately (`event_playout.lua:138-145`); do not equate visual presentation with all packet knowledge or claim those report values have been decoded live.

FantasyAi was independently inspected at commit `f3e1ad448974d2ce7631b61faea28ca5e0b96c8c`:

- `products/fantasy-world/fantasy-world/docs/architecture/inventory-item-instance-data.md:3-28` identifies `InventorySurface` as the sole item-instance owner and preserves the raw 28-byte client `extra`, with the first 24 bytes being the server payload.
- `products/fantasy-world/fantasy-world/src/game_world/inventory/item_instance.rs:29-34,165-179` supports enchantment, signatures and standard augments; its decoder accepts only `extra`, not an item ID. It has no chocobo format today.
- Extend this existing additive item-instance projection with item-semantic dispatch for recognized egg/card IDs. Do not identify a chocobo format from byte 0 alone: a black gene value can collide with the enchanted-item header `1`. Retain all raw bytes, validate gene IDs 0-4 and marker/profile meaning, and surface invalid/unknown layouts rather than treating unknown genes as pure yellow.
- Feed observed genotype into a deterministic Phoenix-profile breeding planner. Separate `targetColorChance`, `pureTargetChance`, `knownEggColor`, observed phenotype, and unknown genotype. A plan can prefer male/female founders but cannot guarantee sex. Never issue a database mutation or a GM mount-color command as normal breeding.

## Deployment/configuration limits and additional serialization issue

The checkout's `settings/default/main.lua:310` defaults `ENABLE_CHOCOBO_RAISING` to false. The local ignored `settings/main.lua` inspected on 2026-10-03 contains no override for it. Settings loading fills missing values from defaults (`src/common/settings.cpp:72-100,240`) and allows environment overrides (`:269-299`); process environment/runtime effective settings were not verified. This supports a **configured-default disabled** caveat, not a claim of a live server query. The inspected local `modules/init.txt` enables `phoenix/lua` and `era/lua`, but not `custom/lua/chocobo_raising_qol.lua`; whole pinned module searches found no breeding helper/NPC override. Do not assume the QoL timing from the file's existence.

Live process enumeration returned blank executable paths and command lines for the server processes under the current access context. The lifecycle state JSON has older PID records; those were not substituted for fresh runtime identity. No service was restarted, no database was queried or modified, and no protected player state was touched.

A separate source-level serialization defect: egg `Plan` is only two bits (`chocobo_egg.h:40`) while `JEUNO_TOUR` is enum value 4 (`scripts/enum/chocobo_raising.lua:17-24`); assigning 4 through `chocobo_egg.cpp:49` cannot preserve it and encodes zero. The ticket's plan is a full byte (`src/map/items/exdata/honeymoon_ticket.h:31-35`). This does not alter color, and Jeuno/zero both currently give 50/50 gender, but a future receipt must not claim the selected plan survived the egg round-trip unchanged. Repair the wire encoding deliberately rather than silently widening fields into other bits.

The publicly readable original genetic helper is [the Phoenix breeding addition](https://github.com/phoenixffxi/Phoenix/blob/6db292dde7b7613cf2520badd5f6aef5ef6050c7/scripts/globals/hobbies/chocobo_raising/breeding.lua). A local diff from that revision to the pinned semantic HEAD showed only `math.random` to `math.randomInt` replacements in this file; the DNA and phenotype rules are unchanged. The local pinned HEAD itself was not fetchable through the unauthenticated web tool, so public links are corroboration rather than a substitute revision.

## Executed validation receipt

Date: 2026-10-03. Semantic revision: `ec6661210c4a188cfb04f62e7ea7a7866a278656`. Runtime: installed `luajit.exe`, with temporary run-owned scripts outside the repository, removed by literal path after execution. Source bodies were extracted with `git show HEAD:<path>` after checking the pinned HEAD. Two isolated runs exited 0.

### Genetic helper run

Loaded the pinned enum and breeding helper, marked the constants require as loaded, and replaced only the RNG seam with enumerated valid outcomes.

- Enumerated all 125 ordered three-gene combinations from IDs 0-4 against independently stated yellow/majority/first-gene expectations: passed.
- Enumerated all 720 valid Fisher-Yates index sequences for each of seven parent pairs. Observed red counts out of 720: YYY x YYY = 0; RRR x RRR = 720; YYY x RRR = 36; YRR x RRR = 360; YRR x YRR = 144; RRR x RRB = 720; RRB x RRB = 576. All assertions passed; these are exhaustive helper outcomes, not Monte Carlo estimates.
- A fake ordinary item's `getExData()` returned the exact typed zero-field shape `{ dna={0,0,0}, ability=0, plan=0, isBred=false }`. `rollEggAlleles` returned YYY with zero RNG calls: passed. The C++ mapping/decoder path was source-traced, not executed in this harness.
- A fake bred egg with RRR genes preserved red without a DNA roll: passed.
- Directly enumerated the standalone founder fallback's 100 integer rolls and four equiprobable color choices: yellow 280/400, each non-yellow 30/400. Passed. This validates the helper's intended distribution, not its reachability from ordinary eggs.

### Hand-in and NPC flow run

Loaded the pinned enum, breeding helper, `choco_data.lua`, and `globals/chocobo_raising.lua` with minimal mocked settings/constants/player/item services. Called the actual `onEventFinishVCSTrainer` at its egg-trade finish branch, using option 252 and a fake bred red egg. The mock persistence call observed age 0, stage EGG, RED color and RRR genes; trade confirmation occurred once. Passed. This demonstrates Lua call ordering, not a real database commit.

Loaded the actual pinned Finbarr NPC script with a mock player. `onTrade` performed no action; `onTrigger` started exactly event 10103. Passed. This is isolated NPC-handler execution, not live menu validation.

### Not run / required future acceptance

No C++ exdata integration test, real item packet capture, native egg/card inventory inspection, browser UI, server deployment, live NPC/date/egg lifecycle, adolescent appearance capture, or retail comparison was performed. There was no new product UI or gameplay behavior to validate. Before claiming a working Fantasy World feature, execute those relevant boundaries through the actual product CLI/TestApp and native client, including failure/restart recovery and a complete receipt through egg creation, raising, visible target color and reusable parent-card issuance.

Only this research note was created. The current branch has no configured upstream (`git rev-parse '@{upstream}'` fails); no new upstream was invented and no unrelated conquest commit was pushed. The note remains uncommitted under that git-preference exception. All pre-existing fixture commands and the settings backup remain untouched.
