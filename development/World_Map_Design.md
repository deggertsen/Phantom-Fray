# World Map Design

**Decided:** 2026-10-25, from the interactive mock-up (Phantom Fury World Map artifact, version 8) and David's answers.
**Status:** In build on `claude/world-map`. This document is the spec the code follows; where the code and this text disagree, fix one and say which.

## The idea in one paragraph

Strikers fight a war with a direction. The Breach opened at Jakarta on day zero and a Second Tear opened at Chicago on day 31. Everything behind those fronts is consumed. Every city's state comes from its distance to the nearest front, and the state decides what missions it offers and how hard they are. Picking a city zooms into one section of it: a handful of districts joined into a short path. Three missions along a connected path make an operation, which pushes the line back and moves the city's liberation bar. New ground opens behind it, and a Striker can keep going until the city is liberated. Nothing is ever permanently lost.

## City states

State is computed, never assigned. In projected map units (`WorldMap.project`, 1000 by 560, equirectangular with latitude cropped to [-58, 84]):

| State | Rule | Missions | Tier | Shown |
|---|---|---|---|---|
| Consumed | inside a front polygon | none, out of reach | none | hatched, dim marker |
| Overrun | within 16 units of a front | hard, with bosses | Full Resonance | magenta |
| In danger | within 42 units | medium, hold the line | Operator | amber |
| Threatened | within 80 units | easy | Standard, or Assist as the session choice | cyan |
| Safe | farther | none, no threat detected | none | small dim dot |

Cities far from a front are not under attack, which is what fixes "random cities around the world." When the fronts move, the states follow.

The difficulty buttons leave the Operations screen. The city's state is the tier. The one choice left to the player inside a threatened city is Assist against Standard, offered as a session toggle that changes the body's load and never the city.

## Fronts

Two polygons in longitude and latitude (`WorldMap.ZONES`), one around the Jakarta tear covering South and Southeast Asia and Australia, one around the Chicago tear covering the Midwest to the East Coast and the Gulf. Arrows along the edge show where each is pushing. Until there is a server, the fronts are fixed authored shapes; liberation moves per city, not the polygon. When the server exists, the polygon follows aggregate liberation.

## Liberation

Each city has a resistance: the number of operations it takes to liberate it (`ops`). Liberation is operations completed over operations needed. The bar moves only when an operation completes, so a single mission cannot be farmed for war progress; the operation in progress shows as a dashed segment. Rift counts are never shown: a mission opens and closes many rifts, so a count would lie.

World liberation on the header is the mean of city liberation, with safe cities at 100 and consumed at 0.

## City view: one section at a time

A section is a small directed graph in three columns, generated from a seed of city id and section index so it is stable for that city until it is completed:

- Each column has one to three districts; every district links forward to at least one in the next column.
- District kinds: single rift, dual rift, hold the line, Maw rift. A column with one district is never a Maw, and a column is never all Maws, so a path around the boss always exists.
- District names come from a fixed pool (Harbor, Rail Yards, Junction, Stadium, Reservoir, Old Town, Civic Ring, Foundry, Airport, Docks, University, Bluffs, Quarry, Northgate, Eastbank, Riverside). Each name maps to an environment; the environment session is adding the missing ones.
- The player picks any district in the first column, then any linked district, then any linked district. Three seals complete the operation. The front line across the city map sits one column right of the last sealed district.
- On completion the section is replaced by the next one and the city's `ops_done` increments. The player can continue or leave. A liberated city has no sections; Chen says she will call when the front turns back toward it.
- Sections are not labeled or numbered on screen.

## Missions from districts

A district's kind, the city's tier, and the district's environment produce the mission dictionary the round plays, built from the catalog's wave vocabulary:

- **Single rift**: one rift, the First Light shape at the city's tier.
- **Dual rift**: two rifts in one view, the Double Breach pair.
- **Hold the line**: one rift whose health also drains on its own while Chen's team seals it; the player survives the interval. New wave field `hold_seconds`; the rift closes when its health reaches zero from either source.
- **Maw rift**: The Maw's single large rift. At Full Resonance it carries the boss block and the break odds; below, the flood and the glimpse.

Best score and time are kept per city, district kind, and tier, so a player sees that a dual rift in Tokyo at Operator has a best.

## Persistence (`GameSettings`)

```
world/home_city = "portland"
world/progress = { city_id: { "ops_done": int, "section": int, "sealed": ["node ids in the current section"] } }
world/assist = false
```

Reset Progress clears world progress and keeps audio and training.

## What happens to the six operations

They stay as they are on `main` for now and remain reachable as Breach Night from the home city's left panel. The plan on the roadmap is for them to become the tutorial arc; that restructure is a separate piece of work.

## Build order

1. Model: `Scripts/Core/world_map.gd` (cities, zones, projection, states, tiers, section generator, mission builder) and `GameSettings` world progress, with validation.
2. World screen: a drawn map (`Scripts/UI/world_map_view.gd` over `WorldCoastline`), the right-panel city card, the tier filter as a dimmer, Chen's priority card, and the Open action.
3. City screen: `Scripts/UI/city_operations_map.gd` replacing the fixed six-site map for world missions, the liberation bar, and Deploy into a generated mission.
4. Round and results: `hold_seconds` in `RiftManager`, results that mark the district sealed and move the line, operation completion.
5. Docs, Menu UX test plan, playtest.

## Open

- Whether to reveal only the next column's district kinds (Path of Exile's trial does this) once there are more than four kinds to choose between.
- Whether the home city should get Chen's priority pull as well as the world.
- Offline tide: no until there is a server, by decision.
