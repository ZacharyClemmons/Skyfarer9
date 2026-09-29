# Genetics parity audit

Baseline: TG revision `0ca21df41030235520a3fec699f23cc6e8350238`, inspected on
2026-09-28. This audit checks specific workflows; it does not certify the entire TG
genetics implementation or every mutation power.

| Workflow | Source behavior and regression coverage |
| --- | --- |
| Catalog | All 84 mutation IDs, 12 combination recipes and four chromosome types are represented. This is a catalog comparison, not proof that every gameplay effect works. |
| Chameleon | Both variants acquire at alpha 204/255, fade by 12.5 alpha units per second scaled by power, reset after an unarmed attack, and restore full opacity on removal. These lifecycle/effect checks supplement the catalog audit. |
| Scramble DNA | Removes standard mutation sources, rerolls eight genes, preserves identity/enzymes and nonstandard sources, adds 50 damage adjusted by scanner upgrades, starts a 60-second cooldown. |
| Monkey transformations | Losing Monkified humanizes living monkeys; dead monkeys remain monkeys. Transforming preserves scanner occupancy, enclosure and lock. Humanized born monkeys retain their primate brain. |
| Species mutation lifecycle | Species is assigned before loss/gain hooks, as in TG. Species-restricted mutations lose all sources when incompatible, restoring their physiological modifiers while retaining unrestricted genes. Skeletons use the actual geneless trait and reject mutators without consuming the injector. |
| Cosmetic transformation lifecycle | Applying and reapplying cosmetic DNA runs the native gene check. Overlapping shorter/longer disguises restore remaining effects and eventually the original name, enzymes, identity, features and blood type; forensic blood identity follows the active disguise. |
| Sequencer entry | Checks discovery of active genome mutations. A monkey's default selection opens the editable Monkified gene. |
| Gene edit dose | Baseline edit adds 1 damage. Console reports 0.2%, including visible bar text and nonzero fill. |
| Genetic poisoning | Threshold 500 damage; two-second ticks decay damage by 2/3 and cause 2/3 toxin loss while above threshold. Tested immediately below and at the threshold. |
| Identity/feature pulse | Delayed makeup edit, no genetic damage dose in this TG revision. Opening/replacing the subject cancels the pending operation. |
| Advanced injector admission | New candidate counts at raw instability; existing entries use their stabilizer coefficient. |
| Cosmetic injector backend | Uses enzyme-copy readiness as its guard and sets injector cooldown after printing. Player UI also respects injector readiness. |
| Handheld analyzer | Copies sequences, requires literacy and a held item to analyze, recharges for 20 seconds, exports makeup to an explicitly chosen buffer slot. |
| Scanner upgrades | Physical tier 1–4 parts set damage/precision/module coefficients; upgrade replacement, downgrade refusal, maintenance gating, fabrication and tier 4 bad-DNA access are tested. Manual part installation and research costs are port adaptations. |
| Elastic arms | Two-tile unobstructed reach, large-item restrictions, glove restrictions and two-handed wielding guard. Pickup and range limits tested. |
| Telekinesis | Remote object focus up to 15 tiles, a hand proxy, item use/throw and machine interaction. Focus creation, drop, mutation loss and forbidden storage/equipment tested. Existing port interaction rules still apply to focused tools and guns. |
| Laser eyes | Combat ranged clicks fire through the port's laser projectile path; damage and cooldown tested. This uses existing armor, shield, wall and hit-location rules. |
| Vision | X-ray bypasses wall occlusion and removal restores it, verified on actual station tiles. Night vision lights visible terrain; thermal vision draws living heat signatures above the lightmap. These visuals use the port's renderer. |
| Beginner lesson | Isolated four-pair practice uses the real letter controls and demonstrates complementary-but-wrong guesses. Tests cover editing, correct activation, resetting, no patient effects, all five rendered pages and fixed window dimensions. |

The regression suite also covers gene-button input, Joker/cooldown state, active/stored
mutation references, injector activation, mutation instability, mutation powers, CRISPR
form submission, scanner drag insertion, destruction, and disk write protection. Its
coverage is useful evidence of functionality, rather than proof of complete TG parity.

Port adaptations: Godot mouse/keyboard controls replace BYOND input dialogs; handheld
makeup destinations appear in the console. The pulse emitter has a permanent progress
row, and its settings cannot change during a pending pulse. Live
readouts update in place to retain hovered controls, scroll position and window geometry.
The console uses a stable scroll viewport, with tall content clipped inside it. Duplicate advanced injector
copies with the same chromosome and empty injector prints are rejected. The port has its
own power, disease, NPC and species systems. Human, monkey, skeleton, corgi, crab and gorilla
bodies are defined. The new world integration covers mineral consumption and timed
absorption, skillchips and Biotech capacity, physical petrified statues, living animal
transformations, and brain-linked psyker powers and echolocation. The regression suite
checks actual consumption, damage coefficients, buff expiry and mutation loss, chip
activation and cooldowns, capacity failsafes, brain extraction, station cancellation,
statue release and transformed bodies. Rendered checks also cover Skillsoft controls
remaining in place during countdown updates.

Remaining adaptations: animal bodies use the port's anatomy and a simple NPC controller,
rather than TG's entire basic-mob behavior tree. Echolocation draws nearby geometry with
the port renderer; focus controls select blood, items and floor objects, and the psyker
head has a procedural appearance rather than TG sprite artwork. Psychic Booster uses faster shots and nearby-target aim assistance through
the port's instant projectile path. Ricochets use a return path with TG's initial laser
chance (80%) and damage decay (0.7), rather than continuous angle-based multi-bounce physics.
Skillsoft reuses scanner art, research costs follow the port's economy, and the provided
skillchip library includes Self Surgery, Entrails Reader, Musical, Useless Adapter,
Engineering Circuitry, True Strength and Taunt 2 Dodge; TG's complete job and novelty chip
library and the rod suplex behavior are not included. Stone material tracking and transfer
through limb reattachment affect mineral absorption duration, and titanium grants the
standing mining/boss faction damage bonus. Golem fabrication and the full TG disease/species
system remain outside this audit. Dormant DNA Activator and Accelerating Virus are CRISPR
samples; DNA activation uses stage, resistance and stealth thresholds with cure cleanup.
Handheld analysis checks hands, sight, literacy, held-item reach and light, and tints its
sprite during recharge. The catalog checks acquisition and removal for every mutation;
this does not certify every mutation's complete behavior.
Olfaction now supports choosing among multiple fingerprint-derived scents in a working
window, including selection during its sniff cooldown. Antimagic gates mental powers
rather than every genetic action. These flows have regression coverage.
These checks establish the implemented behavior, not complete TG-wide parity.

Sources:

- [DNA console](https://github.com/tgstation/tgstation/blob/0ca21df41030235520a3fec699f23cc6e8350238/code/game/machinery/computer/dna_console.dm)
- [DNA scanner](https://github.com/tgstation/tgstation/blob/0ca21df41030235520a3fec699f23cc6e8350238/code/game/machinery/dna_scanner.dm)
- [Monkey/human transformations](https://github.com/tgstation/tgstation/blob/0ca21df41030235520a3fec699f23cc6e8350238/code/modules/mob/living/carbon/transform_procs.dm)
- [Monkified mutation](https://github.com/tgstation/tgstation/blob/0ca21df41030235520a3fec699f23cc6e8350238/code/datums/mutations/body.dm)
- [Genetic damage status effect](https://github.com/tgstation/tgstation/blob/0ca21df41030235520a3fec699f23cc6e8350238/code/datums/status_effects/debuffs/genetic_damage.dm)
- [Mutation acquisition and species-change cleanup](https://github.com/tgstation/tgstation/blob/0ca21df41030235520a3fec699f23cc6e8350238/code/datums/mutations/_mutations.dm)
- [DNA and species assignment](https://github.com/tgstation/tgstation/blob/0ca21df41030235520a3fec699f23cc6e8350238/code/datums/dna/dna.dm)
- [Temporary DNA transformations](https://github.com/tgstation/tgstation/blob/0ca21df41030235520a3fec699f23cc6e8350238/code/datums/status_effects/debuffs/dna_transformation.dm)
- [Skeleton mutation eligibility](https://github.com/tgstation/tgstation/blob/0ca21df41030235520a3fec699f23cc6e8350238/code/modules/mob/living/carbon/human/species_types/skeletons.dm)
- [Handheld sequence scanner](https://github.com/tgstation/tgstation/blob/0ca21df41030235520a3fec699f23cc6e8350238/code/game/objects/items/devices/scanners/sequence_scanner.dm)
- [Chameleon mutation](https://github.com/tgstation/tgstation/blob/0ca21df41030235520a3fec699f23cc6e8350238/code/datums/mutations/chameleon.dm)
