# Dry Creek — Game Design Document

> "Dry Creek" is a working title. Engine: Godot 4.7, GDScript, 2D top-down, 16x16 pixel art, keyboard + mouse.

## 1. Pitch

A farming/life sim set in the American Old West. You inherit a run-down ranch outside a small desert town, restore it, farm dry-climate crops, raise animals, and explore the badlands for valuables. You can draw a gun at any time, and the world reacts: witnesses run for the sheriff, bounties bring posses, and jail time costs you your crops. Deep in the canyons and the old silver mine, the frontier turns strange.

Pillars:

1. **The ranch is the anchor.** Every other system feeds back into it or threatens it.
2. **Freedom with consequences.** Nothing stops you from shooting; the simulation makes you pay for it.
3. **Nobody spawns from thin air.** Lawmen, posses, and witnesses are real NPCs who physically travel.
4. **Water is the desert's currency.** Water limits how much you can farm, so water upgrades are the main ranch progression.

## 2. Core loop

**Daily:** wake → water and tend crops/animals → spend the remaining daylight and stamina on one of: clearing land, town errands, or a badlands trip → ship or sell goods → sleep (day advances, crops grow, shipments pay out).

**Weekly-ish:** save money → buy an upgrade (well, tools, weapons, buildings) → the upgrade opens more land, more crops, or deeper exploration.

**Long term:** overgrown lot → working ranch → prosperous spread, while your reputation with the law and the factions settles into whoever you chose to be.

## 3. Systems

### 3.1 Ranch restoration
- The ranch is open dirt, not sand: all bare ground can be tilled. It starts overgrown, with rocks, trees, weeds, and grass covering most of it, so usable land is whatever has been cleared.
- Debris is cleared with tools (pickaxe for rocks, axe for trees, scythe or hands for weeds and grass) and costs stamina. Rocks and trees block movement; weeds and grass only block tilling.
- Broken structures (fence, barn, coop, well) are repaired or rebuilt through the carpenter for money plus materials.
- Land expands in tiers; each tier is gated by a carpenter job or a cleared obstacle.

### 3.2 Water
- The watering can holds a limited number of uses (20 to start) and refills at a water source.
- A river crosses the north edge of the ranch. It is the first refill point, a long walk from the fields, and later the place to fish.
- The starting well is broken. Repairing it puts water next to the fields, and deepening it raises how much it gives per day.
- Irrigation (ditches, later a windmill pump) auto-waters tiles near it, which is what lets the farm scale past what one can will cover.
- Unwatered crops do not grow. After several dry days in a row they wither (M2).

### 3.3 Farming
- Till → plant → water daily → harvest. Crops: corn, beans, squash, cotton, peppers, and others by season.
- Crops are data (`CropData`): days to mature, growth sprites, yield, optional regrow.
- Seasons change which crops grow and how fast soil dries (summer is harsh).

### 3.4 Time, stamina, sleep
- A day runs on a clock (roughly 6am to 2am). Night is darker and more dangerous.
- Tool use and combat rolls cost stamina. Sleeping restores it and advances the day. Passing out costs money and stamina.
- Calendar: 4 seasons of 28 days.

### 3.5 Animals
- Chickens (eggs) and cattle (milk, later sale) need a repaired coop/barn, daily feed, and water.
- Unfed animals stop producing and lose condition.
- The horse is mountable: faster travel, saddlebag storage later. It can be spooked by gunfire.

### 3.6 Exploration
- Badlands and canyons hold forageables and valuables: gold nuggets, relics, ore, bones.
- Deeper zones need better gear and carry more risk. Valuables sell in town; some are faction-sensitive (see 3.10).

### 3.7 Town
- **General store:** seeds, supplies, buys goods.
- **Blacksmith:** tool and weapon upgrades, ammo.
- **Carpenter:** ranch repairs and buildings.
- **Sheriff's office:** pay bounties, bounty board, jail.
- **Saloon:** card minigame (blackjack first, poker later), shows and events, rumors.
- Townsfolk are data-driven NPCs (`NPCData`) with daily schedules and a home.

### 3.8 Combat
Central, not optional. Aiming is inspired by Desperados 3.
- Draw or holster a weapon at any time. A drawn weapon is itself a world event that NPCs see.
- Hold right-click to aim: a visible aim line shows the shot path and what it will hit. Left-click fires.
- Reloading takes time. Weapons are data (`WeaponData`): revolver (balanced), rifle (long, slow), shotgun (short cone).
- Weapons upgrade at the blacksmith.

### 3.9 Enemies
- **Wildlife:** snakes, coyotes, wolves, mountain lions.
- **Outlaws:** bandit gangs and named bounty targets in the badlands.
- **Deep canyons (late, horror tone):** a deranged cannibal settler gang.
- **Abandoned silver mine:** procedurally varied floors. Upper floors are ordinary hazards; deeper floors turn supernatural (cursed miners, skeletons, stranger things).

### 3.10 Factions
- Local tribes are factions with their own reputation: friendly, wary, or hostile.
- Reputation moves on player actions: trespassing, looting sacred sites, siding with the railroad or army, and fair trade.
- They are people with motives: named individuals, their own schedules, trade, and grievances. Hostility is a consequence that can be repaired, never a default "monster" state.
- The railroad/army is a second faction whose interests conflict with the tribes'. Helping one costs standing with the other.

### 3.11 Inventory, economy, saving
- Slot inventory with a 9-slot hotbar. Items are data (`ItemData` and subclasses).
- Income: shipping crate (paid overnight), direct sales in shops, bounties, cards.
- Save on sleep. One save file per ranch.

## 4. How the systems connect

### Ranch restoration ↔ water ↔ farming
```
clear debris ──► tillable land ──► more crops ──► more water needed
                                                     │
money from crops ──► well / irrigation upgrades ◄────┘
        ▲                         │
        └──── bigger harvests ◄───┘
```
Land is never the real limit; water is. Clearing more ground than your water budget can serve is wasted stamina, so the player alternates between clearing land and upgrading water. This is the main progression rhythm of the first two seasons.

### Combat ↔ law ↔ NPCs ↔ factions
```
player action (draw, shoot, steal, trespass)
        │  emits a WorldEvent (type, actor, position)
        ▼
NPCs in sight/hearing range perceive it
        ├─ townsfolk: flee, hide, or become a witness running to the sheriff
        ├─ lawmen: respond directly
        └─ faction members: adjust faction reputation
        ▼
a report that reaches the sheriff's office becomes bounty
        ▼
bounty drives responses: deputies → posse → bounty hunters at the ranch
        ▼
arrest → jail → skipped days → dry crops, unfed animals
```
Everything hangs off one mechanism: **actions emit world events, and only NPCs who perceive an event can act on it.** That single rule gives unwitnessed badlands crimes, stoppable witnesses, and faction reactions without special cases.

## 5. Law and wanted system (detailed)

**Rules**

1. **Lawmen are real.** The sheriff and each deputy are NPCs with homes and schedules. There is a fixed roster. Nobody spawns in response to a crime.
2. **A crime only counts when it is reported.** A witness NPC who perceives a crime physically runs to the sheriff's office. The report lands when they arrive.
3. **Witnesses can be stopped** before they arrive: blocked/caught and then bribed (money, scales with crime), intimidated (works on timid NPCs, costs reputation, may fail on brave ones), or killed (a worse crime, if witnessed).
4. **Townsfolk react to what they see.** A drawn weapon makes them nervous and they back away. Gunfire or violence makes them flee, hide indoors, or run to report, based on a per-NPC bravery trait.
5. **Deputies are finite.** A killed deputy leaves the town short-handed (slower, weaker response) until a replacement arrives by stage some days later.
6. **No witness, no crime.** Violence in the badlands with nobody around goes unpunished.
7. **Bounty escalation:**
   - Low: deputies confront you when they see you in town. You can surrender, pay, or resist.
   - High: a posse forms at the sheriff's office and physically rides toward your **last known location**. You can see them coming and hide, flee, or fight.
   - Very high: bounty hunters turn up at your ranch as events.
8. **Paying off:** bounties can be paid at the sheriff's office (walking in armed with a high bounty is its own risk).
9. **Getting caught:** jail skips days in proportion to the bounty. The farm keeps simulating while you are gone: crops go unwatered, animals unfed.

**Data model (planned)**
- `WorldEvent` (exists in M1): type, actor, position, data, day.
- `CrimeData` resource: severity, base bounty, whether it needs line of sight or is audible (gunshots carry).
- `NPCData`: bravery, role (townsfolk, deputy, sheriff), schedule, home.
- `LawState` (saved): bounty, pending reports in transit, last known player location, deputy roster with replacement timers.

**Which milestone each piece lands in**

| Piece | Milestone |
|---|---|
| `WorldEvent` bus that actions report through | M1 (done, used for farm events) |
| Farm simulation that advances without the player present (needed for jail) | M1 (done: farm state lives outside the scene) |
| Sheriff and deputies as scheduled NPCs living in town | M3 |
| Draw/holster as a world event; gunfire as an audible world event | M4 |
| NPC perception (sight cone, hearing radius) and reactions: nervous, flee, hide | M5 |
| Witnesses run to the sheriff's office; report creates bounty on arrival | M5 |
| Stop, bribe, or intimidate a witness | M5 |
| Deputies confront and arrest; surrender or resist | M5 |
| Pay off bounty at the sheriff's office | M5 |
| Jail skips days with farm consequences | M5 |
| Deputy death leaves town short-handed; replacement arrives later | M5 |
| Unwitnessed badlands crimes go unpunished (falls out of perception rules) | M5, verified in M7 when bandits exist |
| Posse travels from town to last known location | M7 |
| Bounty hunters arrive at the ranch as events | M7 |
| Bounty board with named outlaw targets | M7 |
| Faction members as witnesses feeding faction reputation instead of bounty | M8 |

## 6. Technical architecture

- **Folders:** `scenes/`, `scripts/`, `resources/`, `assets/`, plus `tools/` for dev-only scripts.
- **Data-driven:** items, crops, and later weapons and NPCs are custom `Resource` files in `resources/`. `ItemDB` indexes them by id, so saves store ids, never object references.
- **State lives outside scenes.** `GameState` (money, inventory, farm plots, shipping bin) and `GameClock` (day) are autoloads. Scenes are views over that state. This is what lets the farm keep simulating while the player is in town or in jail, and it makes save/load a matter of serializing plain data.
- **EventBus autoload** carries cross-system signals (day rollover, money, UI) and `WorldEvent`s (things that happened in the world that NPCs may later perceive).
- **Scene layout:** `main.tscn` holds a `World` slot (currently the farm) and a persistent `UI` layer, so areas can be swapped without rebuilding the HUD.
- **Pixel art:** 480x270 base resolution (30 tiles across, the same framing as Stardew Valley), viewport stretch with integer scaling, nearest-neighbor filtering, pixel snapping.
- **Physics layers:** 1 world, 2 player, 3 interactable (more added with NPCs and projectiles).
- **Placeholder art** lives in `assets/placeholder/` and is generated by `tools/gen_placeholder_art.gd`. Real packs go elsewhere in `assets/` and are credited in `CREDITS.md`.

## 7. Milestone roadmap

| # | Name | Scope |
|---|---|---|
| **M1** | Farming vertical slice | Movement and camera, farm map, till/plant/water/harvest two crops, inventory and hotbar, day counter, sleep, shipping crate. |
| **M2** | The working day | Clock and day/night tint, stamina, the broken well, debris clearing (axe, pickaxe, scythe), crop withering, save/load on sleep, title/new-game flow. Watering can capacity and river refill are already in. |
| **M3** | Town and economy | Area transitions, town map, general store (buy seeds, sell goods), carpenter (first well and fence repairs), NPCs with schedules and basic dialogue, sheriff and deputies present as residents. |
| **M4** | Combat core | Draw/holster, aim line, firing, reloading, revolver, player health, first wildlife (snake, coyote), first badlands map with valuables. |
| **M5** | Law and wanted v1 | Perception, townsfolk reactions, witnesses and reporting, bribe/intimidate, bounty, arrest, jail day-skip, pay-off, deputy replacement. |
| **M6** | Animals and seasons | Coop and barn, chickens, cattle, feed, horse and mounting, full season calendar, irrigation. |
| **M7** | Outlaws and escalation | Bandit gangs, bounty board, rifle and shotgun, blacksmith upgrades, posse travel, bounty hunters at the ranch. |
| **M8** | Factions | Tribal and railroad/army reputation, sacred sites, trade, faction-aware witnesses. |
| **M9** | Saloon | Blackjack, then poker; shows and events; rumors that point at content. |
| **M10** | Weird West | Silver mine with procedural floors, supernatural enemies, cannibal gang in the deep canyons. |
| **M11** | Polish | Real art pass, audio, UI pass, balance, settings, export builds. |

Each milestone ends in a playable build and a commit.
