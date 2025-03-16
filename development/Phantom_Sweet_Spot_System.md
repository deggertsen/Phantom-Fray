# Phantom Sweet Spot System Design

## Overview
While phantoms can be destroyed by any hand contact, the rift-closing mechanic requires precise hits to sweet spots for maximum effectiveness.

## Core Mechanics

### Sweet Spot Types
1. **Jab Sweet Spot**
   - Located at phantom's center mass
   - Requires forward straight punch

2. **Uppercut Sweet Spot**
   - Located under phantom's form
   - Requires upward punch motion

3. **Hook Sweet Spot**
   - Located on phantom's sides
   - Requires hook punch motion

### Implementation Checklist
- [ ] Add sweet spot collision areas to phantom base class (We might want this different for each phantom so maybe there should be a general implementaiton on the base class that can be extended for each different phantom?)
- [ ] Implement punch type detection based on controller velocity and orientation (Velocity is already implemented but may need adjustment based on orientation)
- [ ] Create visual feedback for successful sweet spot hits (The current visual feedback for when a phantom is hit is probably what we want for when the sweet spot is hit. We probably want to decrease the visual feedback effect when it is not hit in the sweet spot)
- [ ] Modify rift damage system to only accept sweet spot hits
- [ ] Add particle effects for different types of successful hits

### Scoring System
- Basic hit: 0 points
- Sweet spot hit: Range based on velocity of the hit. Perhaps equal to the velocity rounded?
- Combo multiplier: Increases by 0.5x for each consecutive sweet spot hit with a max of 10x
- Combo reset: Missing a sweet spot or taking damage resets multiplier

## Visual Feedback
- Sweet spots should have subtle visual indicators
- Successful hits should trigger distinct particle effects
- UI should show current combo multiplier 