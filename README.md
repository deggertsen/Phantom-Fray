# Phantom Fray: Resonance Rising

A stationary VR fitness-combat game for Meta Quest, built in Godot 4.7.1 with OpenXR and godot-xr-tools. You stand at a breach site in a dead city, wearing Dr. Chen's Ethereal Resonance Matrix (ERM) gauntlets, and physically punch, block, and dodge phantoms pouring out of dimensional rifts until every rift is sealed and every phantom is gone.

The goal of the project is a workout you want to come back to because the world needs saving, not because a timer told you to. Everything below describes the game as it exists in this repository today. Plans live in [development/Production_Roadmap.md](development/Production_Roadmap.md); ideas not yet scheduled live in [development/Ideas_Backlog.md](development/Ideas_Backlog.md).

## How it plays

- **Stationary, physical.** No artificial locomotion. You turn, duck, and take a step to the side. Everything comes to you.
- **Grip, then strike.** Hold grip and punch. A strike counts once a phantom is in reach, which is also when it lunges. Jabs, hooks, and uppercuts all work, and the Angler's glowing lure hangs where the matching punch lands.
- **Four phantom rules, each a different movement.**

| Color | Species | Rule | What the body does |
|---|---|---|---|---|
| Yellow | Angler | Left hand only. Strike the lure for a resonance crit. | Left jabs, hooks, uppercuts |
| Blue | Angler | Right hand only. Strike the lure for a resonance crit. | Right jabs, hooks, uppercuts |
| Green | Carapace | Catch it with both hands inside a short window. | Two-hand block |
| Pink | Spearfin | Cannot be punched. Paints a lane on the floor, then charges it. | Side-step or duck out of the lane |

- **Rifts are the objective.** Each phantom you resolve damages the rift it came from. Sealing a rift stops its spawning, but the phantoms it already released keep coming. The operation is won when every rift is sealed and the last straggler is dealt with. There is no time limit: the wrist clock counts up from 0:00 and your fastest victory per operation is kept.
- **Life force is the stakes.** The gauntlets run on your own life force. A phantom that reaches your head possesses you: it vanishes, drains 20 of 100, and your vision frosts and distorts. Life force recovers after three clear seconds. At zero the gauntlets' failsafe fires, the recovery team pulls you out, and the operation is failed. Operators are never consumed; you go back in and try again.
- **Score and chain.** Every resolve adds to a chain multiplier up to 3x. Resonance crits and on-arrival hits grow it faster. A wrong hand or a possession resets it. Your best score per operation is kept.
- **Dr. Chen on comms.** Fully voiced callouts for rift bearings, first contact with each species, wrong-hand corrections, chain milestones, life force warnings, possession, and debriefs that know whether this is your first attempt, a retry after the failsafe, a replay, a flawless seal, or a new best. Captioned on the wrist panel.
- **Your own music.** A settings switch silences the soundtrack so a playlist from any music app plays through the mission while Chen stays audible.

## The campaign today

Six operations, unlocked in order. Each is a wave table in [Scripts/Core/mission_catalog.gd](Scripts/Core/mission_catalog.gd).

| Op | Title | Rifts | Card estimate | What it introduces |
|---|---|---|---|---|
| OP-01 | First Light | 4 | 2 to 4 min | Yellow and blue |
| OP-02 | Widen the Ring | 12 | 6 to 8 min | Green and pink in the mix |
| OP-03 | Chen's Gambit | 12 | 6 to 8 min | Shorter tells, faster lunges |
| OP-04 | Double Breach | 16 paired | 6 to 10 min | Two rifts open side by side |
| OP-05 | Open Arc | 16 paired | 6 to 10 min | Paired rifts spread across the front arc |
| OP-06 | The Maw | 1 | 4 to 6 min | One double-size rift that spawns fast, with double health |

Each Operations card shows its expected time ("6 TO 8 MIN") and, once the player has won it, their best time beside it. The ranges are estimates from the wave tables until timed headset runs replace them. A clean run through all six takes roughly 40 minutes. They work as an extended tutorial for the combat system, and that is what they will become: the on-ramp that teaches every mechanic before the world map opens. Replay value and narrative hooks are the next things to build; see the roadmap.

## Controls

| Action | Quest controller | Desktop fallback |
|---|---|---|
| Strike | Hold grip and punch | none |
| Menu select | Point and pull trigger | Enter or Space |
| Pause | Menu button | Esc |
| Training | Button on the panel | T |
| Settings | Button on the panel | S |
| Recenter | Hold Meta button | none |

Debug builds also accept `H` to take a hit and `R` to reset life force.

## Running and validating

Godot 4.7.1 exactly. The desktop fallback runs without a headset for menu, flow, and art review.

```bash
godot --path .
```

Automated validation (resource loading, SFX takes, variant rules, life force arithmetic, strike window, mission catalog, rift stragglers, elapsed timer and best time, expected mission times, menu surfaces and footers, own-music settings, pink dodge, squat detector prototype):

```bash
tools/validate_project.sh
```

Art and play-through stills for review, written to the gitignored `reports/` folder:

```bash
godot --path . --xr-mode off --resolution 1600x900 res://Scenes/Debug/art_capture.tscn
```

```bash
godot --path . --xr-mode off --resolution 1600x900 res://Scenes/Debug/play_capture.tscn
```

Chen's lines are generated from `Assets/Audio/VO/chen/chen_lines.json` with `tools/generate_elevenlabs_vo.ps1` and checked against the script with `tools/check_vo.ps1`.

Quest builds: [development/Quest_Export_Guide.md](development/Quest_Export_Guide.md).

## Project layout

- `Scripts/Core/` mission catalog, round controller, game flow, settings
- `Scripts/Phantoms/` phantom base arc, Angler (yellow, blue), Carapace (green), Spearfin (pink)
- `Scripts/Rifts/` rift director (which rifts open where) and rift manager (spawning, health, closure, stragglers)
- `Scripts/Player/` XR origin, hands and strike detection, life force and its feedback
- `Scripts/Presentation/` creature meshes, breach city, arena, gauntlets, VFX, compass and bearings
- `Scripts/Audio/` Chen comms, music intensity, SFX takes
- `Scripts/UI/` world-space menu panel and presenter, wrist HUD
- `Scripts/Debug/` performance monitor and capture scenes
- `Assets/Audio/VO/chen/` Chen's script (`chen_lines.json`), takes, and the ElevenLabs manifest
- `development/` design, production, and release documents
- `tools/` Quest build scripts, validation, VO generation and checking

## Where this is going

The design intent, in priority order. Details and status in the roadmap.

1. **Fitness first.** Session stats, missions of five to ten minutes, workout-length sessions, and a reason to sweat that is bigger than a score.
2. **Replay value.** Best scores shown and medals per operation, an endless hold mode, and leaderboards.
3. **Narrative hooks.** A shared war against the Overseer, with a world map in the spirit of Helldivers 2 where every operator's seals push the front line. The six operations become the tutorial; after it, the player picks missions from the map by difficulty rather than working through a numbered list.
4. **Location variety.** Different breach sites, skies, and lighting per operation.
5. **Difficulty per mission.** Assist, Standard, and Operator, plus Full Resonance: an opt-in movement difficulty, the only place bosses appear, where their attacks have to be answered with squats, jumps, and push-ups. See [development/Exercise_Mechanics_Exploration.md](development/Exercise_Mechanics_Exploration.md).

## Lore

Title: "Phantom Fray: Resonance Rising"

In 2142, humanity's reach exceeded its grasp. Our experiments with interdimensional energy, meant to revolutionize space travel, instead tore the fabric of reality. On the day known as "The Breach," ethereal entities we called "Phantoms" began pouring through microscopic rifts, impervious to conventional weapons and hungry for life force.

Dr. Elara Chen, the brilliant mind behind the ill-fated experiments, had created a revolutionary technology called the "Ethereal Resonance Matrix" (ERM). Originally designed to safely interact with interdimensional energies, ERM became humanity's unexpected salvation.

As cities fell silent and governments crumbled, Dr. Chen made a startling discovery. By inverting the ERM's energy signature, it could negate Phantom energy, effectively destroying them. However, this came with a catch: the ERM required a direct connection to a living being's life force to function. Projectile weapons were impossible; the fight against the Phantoms would have to be up close and personal.

Enter the Resonance Strike Force (RSF), a desperate initiative to turn the tide. You are one of the newest recruits, chosen for your exceptional physical abilities and mental fortitude. Your mission: master the ERM gauntlets and take the fight to the Phantoms.

As you progress through training and into active duty, you'll uncover crucial information:

1. The Phantoms aren't just random invaders, but pawns of a greater intelligence dubbed "The Overseer."
2. Each Phantom has a "resonance point" where its connection to The Overseer is strongest. Striking these points causes maximum disruption to the Phantom network.
3. Your actions aren't just defeating individual Phantoms, but systematically weakening the entire invasion force.

Your missions with the RSF will be twofold: closing the dimensional rifts scattered across the globe and gathering crucial intelligence on the Phantoms and their mysterious Overseer. Each successful operation not only pushes back the invasion but also pieces together the puzzle of the Phantoms' origin and nature.

Throughout the story, we can explore:
- The ethical implications of using life force-powered technology
- The camaraderie and rivalries within the RSF
- The weight of being humanity's last, best hope

This setup maintains the epic scale of our conflict while focusing on the player's personal journey from recruit to humanity's champion. It also leaves room for future expansions - perhaps discovering other dimensions affected by The Breach or exploring the long-term effects of ERM use.

Rift-closing missions: These could be intense, time-pressured battles where you need to fight off waves of Phantoms while Dr. Chen's team works to seal a rift.
Intelligence-gathering missions: These might involve capturing specific Phantom types or targeting Phantoms that seem to be relaying information.
Escalating challenge: As you close more rifts and learn more about the Phantoms, they could adapt their strategies, introducing new types of enemies or behaviors.
Story progression: Each bit of intel could reveal more about the Phantoms' hierarchy, the nature of the Overseer, and potentially ways to strike at the heart of the invasion.
Final confrontation: All of this could build up to a climactic mission where you use everything you've learned to open a rift to the Phantoms' dimension and take the fight to the Overseer.

### The Phantom Threat

1. Phantom Physiology:
   - Phantoms are energy beings composed of negative life force.
   - They exist in a state of constant hunger, driven to consume positive life energy to maintain their form in our dimension.

2. The Consumption Process:
   - When a Phantom touches a living being, it begins to siphon life force through a process we could call "ethereal osmosis."
   - The victim experiences a sensation of extreme cold, followed by weakness, disorientation, and eventually, total systemic failure.
   - The process can take anywhere from seconds to minutes, depending on the size and power of the Phantom.

3. Visible Effects:
   - As life force is drained, victims develop a pale, almost translucent appearance.
   - Glowing, vein-like patterns may appear on the skin, tracing the path of energy extraction.
   - In the final stages, victims may emit a faint, ghostly glow before collapsing.

4. Environmental Impact:
   - Areas with high Phantom activity become cold and lifeless.
   - Plants wither, animals flee, and the very air seems to become thin and hard to breathe.
   - In severe cases, the laws of physics may begin to break down, causing localized reality distortions.

5. Phantom Evolution:
   - As Phantoms consume more life force, they grow larger and more powerful.
   - Some may evolve specialized abilities, like faster movement or the power to drain life force from a distance.
   - The most powerful Phantoms can drain entire crowds simultaneously.
   - The largest cannot come through a rift at all until they have drained a city's worth of life force, which is why they rise at dead cities. Holding that shape in our world burns them out: such a Phantom drains away on its own, and an operator who outlasts it forces it back through its rift before the rift closes. These Phantoms are not destroyed; each crossing is an attempt to gather enough energy to hold a permanent presence in our world, and every operator it drains buys it more time.

6. The Hive Mind Effect:
   - The Overseer uses the consumed life force to create more Phantoms and strengthen its control over Earth's dimension.
   - This creates a feedback loop: more consumption leads to more Phantoms, which leads to more consumption.

7. Humanity's Desperate Measures:
   - Conventional weapons are useless, leading to panic and mass exoduses from cities.
   - Some humans, in desperation, have formed cults that worship the Phantoms, offering themselves as willing sacrifices.
   - Governments resort to extreme measures like scorched earth tactics, hoping to deprive Phantoms of life force to consume.

8. The ERM Advantage:
   - The ERM gauntlets don't just destroy Phantoms; they can also temporarily reverse the life force drain in recently affected victims.
   - This makes RSF operators not just warriors, but potential saviors, adding an extra layer of urgency to their missions.

9. The Failsafe and the Recovery Team:
   - The gauntlets draw on the operator's own life force, so Dr. Chen reads the operator's vitals live through them. That is how she knows, over comms, the moment an operator starts to fade.
   - If an operator's life force collapses, the gauntlets' failsafe inverts the ERM and dumps its whole charge at once. The burst throws every Phantom off the operator and stops the drain, but it knocks the operator out and leaves the gauntlets spent.
   - An RSF recovery team waits at the pylon line on every deployment. When the failsafe fires, they go in and drag the operator clear. The operator survives, but the breach stays open, and the failsafe has to recharge before the next attempt.
   - Operators are never consumed in the field. Failing a mission means being pulled out, not dying, which is why an operator can go back into the same breach and try again.
