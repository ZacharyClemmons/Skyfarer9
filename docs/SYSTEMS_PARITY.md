# Systems parity audit

Reference: TG commit `0ca21df41030235520a3fec699f23cc6e8350238`.
This records implemented comparisons and outstanding work, not a full-game parity claim.

## Implemented in this pass

| Area | Source comparison and regression coverage |
| --- | --- |
| Riot shotgun | Starts with six rubber-shot shells and a live chamber. Six-shell tube can be topped up with one additional chambered shell. Firing requires a pump before the next shot; pumping ejects a spent casing or recoverable live ammunition. An empty gun must be pumped after loading. Fire delay is 0.8 seconds. |
| Ammunition | Rubber shot supplies six pellets with 3 brute and 10 stamina per pellet. Pellet damage and rubber-shot stamina lose 0.25 per traveled tile. Buckshot has six pellets and 15-degree total spread; slug armor penetration is 30. |
| Projectile blocking | Ballistic and energy shots use the damage/penetration block modifier. Transparent riot shields let PASSGLASS beams through. This includes both laser and disabler beams. |
| Armor | Separate bullet, laser and energy ratings. Standard vest has 35 melee, 30 bullet, 30 laser and 40 energy; job outfits use the same stats. Chest vests no longer protect arms. Riot suits cover limbs, hands and feet, including wound protection. Disablers use energy armor. |
| Defibrillation | Baseline help action takes five seconds. A repaired corpse receives oxygen loss to reach -50 health; a badly damaged corpse has all four damage types reduced proportionally to that health. Generic revival remains separate. |
| Recharger lifecycle | Charging respects elapsed time, pauses when broken/unpowered, stops active power draw when complete, resets its interval on replacement, and releases the inserted device on destruction. These are verified lifecycle fixes; its charge units remain a port adaptation. |
| Locker occupants | Closing encloses up to three eligible people and clears pulls. Unlocked occupants can leave; locked/welded breakout has a 120-second base duration. Moving/destructing lockers preserves/releases occupants. Crate lids reject standing people. Drag stuffing takes four seconds and applies four seconds of paralysis before closure. |
| Locker locks and tools | Authorized hand clicks unlock before opening; unauthorized unlocking fails, while anyone outside can lock a closed secure locker. Broken locks stay unusable and bursting clears welds. Welding, unwelding and cutting take four seconds and recheck the door state before consuming fuel. Secondary wrench use toggles anchoring. |
| Locker contents | Capacity counts objects, including occupants, rather than item weight. Anchored objects, no-drop items and nested lockers are rejected; bags are accepted. Moving a locker updates contained item positions without exposing them on the map. NPC retrieval unlocks before opening and stops when access is denied. |
| Secure locker durability | Secure lockers have 250 integrity, 20 damage deflection, 30 melee armor, 50 bullet/laser armor, 100 energy armor and 80 fire/acid armor. Ordinary lockers retain their separate 200-integrity profile. |
| Scanner confinement | Closing stops incoming/outgoing pulls and movement. Occupants are excluded from world picking and cannot be pulled out through movement calls. |

The inventory/projectile polish, combat, and station suites exercise these changes.
Genetics is rerun because it shares projectile, armor, damage and revival code.

## Remaining dependencies and adaptations

- Projectiles still use an immediate tile ray. TG flight timing, angle-based multi-bounce
  ricochets, bullet penetration and the complete casing/magazine library remain incomplete.
- Rubber shot and empty casings reuse existing port artwork. Rubber shot's ricochet
  parameters are not implemented. Revolver cylinder/spent-round handling is still simplified.
- Shield durability, worn-item blocking, reflector-vest reflection and equipment-granted
  riot-suit shove resistance require further implementation.
- Defibrillator paddles, wielding, thick-clothing checks, mounts and the complete revival
  eligibility system are not yet reproduced. Medical skill adjusts action speed in the port.
- Rechargers still use shot-count batteries and allow defibrillators as a port adaptation.
  TG stock-part scaling, cell units and the full allowed-device list need implementation.
- Crate climbing/elevation, dense-when-open behavior, the full object admission
  system, secure-locker electronics and personal ID registration, hacking,
  animations and occupant-view effects remain incomplete.

## Sources

- [Locker enclosure and escape](https://github.com/tgstation/tgstation/blob/0ca21df41030235520a3fec699f23cc6e8350238/code/game/objects/structures/crates_lockers/closets.dm), [crates](https://github.com/tgstation/tgstation/blob/0ca21df41030235520a3fec699f23cc6e8350238/code/game/objects/structures/crates_lockers/crates.dm), [DNA scanner](https://github.com/tgstation/tgstation/blob/0ca21df41030235520a3fec699f23cc6e8350238/code/game/machinery/dna_scanner.dm)
- [Secure locker durability](https://github.com/tgstation/tgstation/blob/0ca21df41030235520a3fec699f23cc6e8350238/code/game/objects/structures/crates_lockers/closets/secure/secure_closets.dm)

- [Shotguns](https://github.com/tgstation/tgstation/blob/0ca21df41030235520a3fec699f23cc6e8350238/code/modules/projectiles/guns/ballistic/shotgun.dm), [chamber/racking](https://github.com/tgstation/tgstation/blob/0ca21df41030235520a3fec699f23cc6e8350238/code/modules/projectiles/guns/ballistic.dm), [tube capacities](https://github.com/tgstation/tgstation/blob/0ca21df41030235520a3fec699f23cc6e8350238/code/modules/projectiles/boxes_magazines/internal/shotgun.dm)
- [Shotgun ammunition](https://github.com/tgstation/tgstation/blob/0ca21df41030235520a3fec699f23cc6e8350238/code/modules/projectiles/ammunition/ballistic/shotgun.dm), [pellet spread](https://github.com/tgstation/tgstation/blob/0ca21df41030235520a3fec699f23cc6e8350238/code/modules/projectiles/ammunition/_firing.dm), [projectile stats](https://github.com/tgstation/tgstation/blob/0ca21df41030235520a3fec699f23cc6e8350238/code/modules/projectiles/projectile/bullets/shotgun.dm)
- [Blocking](https://github.com/tgstation/tgstation/blob/0ca21df41030235520a3fec699f23cc6e8350238/code/modules/mob/living/carbon/human/human_defense.dm), [shields](https://github.com/tgstation/tgstation/blob/0ca21df41030235520a3fec699f23cc6e8350238/code/game/objects/items/weaponry/shields.dm), [beams](https://github.com/tgstation/tgstation/blob/0ca21df41030235520a3fec699f23cc6e8350238/code/modules/projectiles/projectile/beams.dm), [armor](https://github.com/tgstation/tgstation/blob/0ca21df41030235520a3fec699f23cc6e8350238/code/modules/clothing/suits/armor.dm)
- [Defibrillation](https://github.com/tgstation/tgstation/blob/0ca21df41030235520a3fec699f23cc6e8350238/code/game/objects/items/tools/medical/defib.dm), [recharger](https://github.com/tgstation/tgstation/blob/0ca21df41030235520a3fec699f23cc6e8350238/code/game/machinery/recharger.dm)
