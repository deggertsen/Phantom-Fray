# Life Force System Design

## Overview
The Life Force System represents the player's vital energy and their resistance to phantom corruption. Using an Iron Man-style HUD interface, players can monitor their life force status through visual and audio cues.

## Core Mechanics

### Life Force Properties
- **Maximum Life Force**: 100 units
- **Drain Rate**: 
  - Basic phantom touch: -5 units when hit
  - Elite phantom touch: -10 units when hit
  - Boss phantom touch: -20 units when hit
- **Recovery Rate**: 
  - Natural recovery: +1 unit/second when no phantom contact for 3 seconds
  - Future power-up potential: Temporary recovery boost items

### Visual Representation

#### Body Aura System
- **Healthy State (100-70%)**
  - Bright blue aura
  - Minimal particle emission
  - Clear, crisp HUD elements
  
- **Cautionary State (69-40%)**
  - Blue-purple transitioning aura
  - Increased particle turbulence
  - HUD begins showing interference patterns
  
- **Danger State (39-10%)**
  - Purple-red aura
  - Violent particle emissions
  - HUD displays warning messages and glitch effects
  
- **Critical State (<10%)**
  - Deep red aura
  - Maximum particle density
  - HUD severely distorted with emergency warnings

### Iron Man-Style HUD Elements
1. **Life Force Meter**
   - Arc reactor-style circular gauge
   - Position: Upper left peripheral vision
   - Color shifts match aura states
   
2. **Warning System**
   - Directional damage indicators
   - Phantom proximity alerts
   - Critical status warnings

### Audio Feedback
1. **Heartbeat System**
   - Normal State: No audible heartbeat
   - Below 70%: Subtle heartbeat
   - Below 40%: Pronounced heartbeat
   - Below 10%: Rapid, intense heartbeat + alarm

2. **Environmental Effects**
   - Life force drain creates spatial audio distortion
   - Recovery produces a "clearing" sound effect
   - Critical state triggers emergency warning sounds

## Implementation Checklist
- [ ] Create base Life Force manager class
- [ ] Implement aura shader system
  - [ ] Color transition logic
  - [ ] Particle emission scaling
  - [ ] Aura intensity control
- [ ] Design HUD elements
  - [ ] Arc reactor meter
  - [ ] Warning system
  - [ ] Directional indicators
- [ ] Set up audio system
  - [ ] Heartbeat manager
  - [ ] Spatial audio effects
  - [ ] Warning sounds
- [ ] Add phantom interaction detection
- [ ] Implement recovery system
- [ ] Create debug controls/visualization

## Future Enhancements
- Power-up system integration
- Special abilities tied to life force levels
- Multiplayer life force sharing mechanics 