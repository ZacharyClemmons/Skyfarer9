# Genetics

Open a DNA scanner, then drag yourself or a patient you are pulling onto it. The scanner
closes on that person. Use the adjacent DNA console to unlock/open it and let them out.

Select **Sequencer**, then choose a mutation in the list. Left-click a base to cycle
forward, right-click to cycle backward, and Ctrl+click to clear it to X. Orange outlines
mark cleared bases. Red connectors mark noncomplementary pairs. Completing the correct
sequence activates and discovers the mutation. Each edit adds genetic damage, shown
above the sequencer. The Joker reveals one base when its cooldown is ready.

**Getting started** opens a five-step, interactive lesson focused on solving genes.
It uses a small practice puzzle with the same click controls, separate from patient DNA.
The lesson demonstrates that complementary pairs are not necessarily the correct code:
`ATCGATCG` fits the pairing rules but is OFF, while the example's `ATCGTACG` is ON.
It explains single-X repairs, X/X guesses, whole-code activation, and using Joker.
Practice has no genetic damage or cooldown cost, can be reset, and stays readable away
from the console. Real bases also have partner hints in their tooltips.

Read pairs **vertically**, not across the row. The four possible pairs are AT, TA, CG,
and GC. Fill single missing letters from their visible partner first. For a pair that
started as X/X, try a possible pair; if the entire mutation remains OFF, another guess
may be needed. Red connectors flag invalid pairing only, not incorrect guesses.

**Scramble DNA** rerolls the eight genome slots and removes mutations from standard
genetics sources. Removing Monkified humanizes a living monkey, including a born monkey;
it does not open the scanner or release its occupant. A dead monkey does not humanize.
The operation adds 50 genetic damage at baseline scanner upgrades and has a 60-second
cooldown. Mutations from other sources are retained. It does not copy somebody else's
identity or enzymes.

Scanner upgrades are installable: empty and unlock the scanner, use a screwdriver to
open maintenance, then use a higher-tier micro-laser, matter bin or scanning module on
it. Close maintenance with the screwdriver afterward. Removed parts are returned;
downgrades are refused. Research unlocks fabrication of the analyzer, disks and stock
parts at a protolathe. These research costs and manual installation controls are port
adaptations. Lasers reduce doses, bins improve accuracy/Joker recharge, and tier 3 or 4
modules permit work on subjects with bad DNA.

The **Genetic Damage** bar measures accumulated damage relative to the toxin threshold,
with one decimal place: a baseline gene edit adds 1 damage, displayed as **0.2%**.
At **100%** (500 damage), it causes toxin loss. Every two seconds, genetic damage
decays by 2/3 of a point; while at or above the threshold, it also causes 2/3 toxin
damage per tick. Scanner upgrades reduce doses. TG's identity/feature emitter pulses
change makeup without adding a genetic damage dose in the referenced revision.
The permanent **Pulse Emitter** row shows the active target, progress and countdown;
starting a pulse does not add a panel or enlarge the window. Emitter settings are locked
until the pulse finishes or the scanner opens.

An active mutation can be saved to console or disk storage and printed as an activator
or mutator. An activator needs the gene in its recipient's genome; a mutator can add it
from outside their genome. Stored mutations display their complete sequence for reference.
Insert a DNA disk by using it on the console. Its write-protect tab blocks disk changes.

Create an advanced injector in **Storage > Adv. Injector**, then add mutations from their
detail panels. The panel shows its mutation count and instability budget. Duplicate
copies with the same chromosome are rejected. Existing mutations use their stabilizer
coefficient for admission; TG counts a newly added mutation at its raw instability.
The displayed total reflects the stored mutations' effective instability.

**CRISPR** edits an active gene in the scanner's subject. Its form takes a 32-base code:
for each pair, enter the first base of the original pair followed by the first base of
the replacement pair. Repeat for all 16 pairs. Only A/T/C/G are accepted. This procedure
spends a charge; an incorrect code can cause harmful mutations, and the procedure may
cause disease. Stored sequences provide the reference needed to construct the code.

The handheld sequence scanner links to the research database when used on the console.
Use its context actions to analyze a buffered gene; each analysis needs a 20-second
recharge. **Z** switches between sequence scanning and makeup scanning. Makeup scanning
takes three seconds. Using the handheld on a console in makeup mode opens **Enzymes**;
choose **Import from handheld** in one of the three slots. Existing buffers remain intact
until you explicitly select a destination.

**Enzymes** and **Features** provide identity pulses and three makeup buffers. Save a
subject into a buffer, then transfer its identity, features, enzymes, or full makeup to
another subject. Transfers and printing have cooldowns. A delayed transfer applies when
the next viable subject enters the scanner. Makeup injectors make temporary changes.

Run `Artic9.exe --headless --path . -- --autotest=240 --seed=42 --speed=4 --genetest`
for the genetics regression suite. A failed check produces a nonzero exit status.

Rock Eater lets you eat a mineral sheet by using it on yourself outside combat mode
or using its **Eat one mineral** context action. Rock Absorber also grants its mineral
effect: iron heals, plasma converts burn damage into local APC power, titanium hardens
the body, plasteel protects against space, uranium pauses hunger, silver repels magic,
gold can reflect lasers, diamond improves concealment and speed, and bananium makes a
fallen body slippery. These effects last 30 seconds in a body without stone limbs;
different exclusive mineral effects cannot stack. Mutation loss removes the effects.
Bluespace creates a hand action: click within seven tiles, wait two seconds, and land
near the destination. Gibtonite creates a fist that launches the ore with a two-second
fuse; holding it for two minutes releases and primes it instead. Cargo supplies mineral samples.

The lab's **Skillsoft station** implants physical skillchips. Insert a chip, drag yourself
onto the open station, and use **Implant**. Implantation and removal take 15 seconds;
opening the station or losing power cancels the operation. Activate installed chips
inside the station. A brain has five physical slots and three active complexity units.
**Biotech Compatibility** adds one complexity unit. Losing it deactivates excess chips
even during recharge; gaining it again does not reactivate them. Activation/deactivation
and extraction impose a five-minute chip recharge. Research fabricates additional chips
and stations. Chip effects belong to the brain and travel with it during extraction.

Petrification contains the original body in a solid statue for eight minutes. Damage
to an intact statue transfers to the body when released; shattering it destroys the
body and leaves its brain. Animal transformations retain control of a living corgi,
crab, or gorilla, drop carried equipment, and prevent human tool use. Psykers lose their
eyes but can echolocate nearby geometry while able to hear, and receive Psychic Projection,
Psychic Booster, and Psychic Wall actions from their brain.

The source comparison is pinned to TG revision
`0ca21df41030235520a3fec699f23cc6e8350238`; see [the parity audit](GENETICS_PARITY.md)
for checked behaviors and remaining scope.
