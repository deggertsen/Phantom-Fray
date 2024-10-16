## **Phantom Enemy System Breakdown**

### 1. **Phantom Base Setup**
   - **Create Base `Phantom` Scene**
     - **Nodes Structure:**
       - `KinematicBody3D` *(preferred for controlled movement)*
       - `CollisionShape3D` *(defines physical boundaries)*
       - `MeshInstance3D` *(placeholder or detailed models)*
       - `AnimationPlayer` *(handles animations: idle, attack, death)*
       - `Area3D` *(for detecting player interactions)*
     - **Extensibility:**
       - Design the base `Phantom` to be inheritable for various types:
         - `YellowPhantom`
         - `BluePhantom`
         - `GreenPhantom`
         - `PinkPhantom`
       - Ensure each subclass can override or extend behaviors and properties seamlessly.

### 2. **Phantom Variants Definition**
   - **Identify and Define Variants:**
     - **Yellow Phantom**
       - **Behavior:** Basic movement and attack.
       - **Defeat Mechanism:** Left hand collision.
       - **Scoring:** Points for hitting the sweet spot.
     - **Blue Phantom**
       - **Behavior:** Basic movement and attack.
       - **Defeat Mechanism:** Right hand collision.
       - **Scoring:** Points for hitting the sweet spot.
     - **Green Phantom**
       - **Behavior:** Faster movement.
       - **Defeat Mechanism:** Block with both hands.
       - **Scoring:** Fixed points per successful block.
     - **Pink Phantom**
       - **Behavior:** Projectile-like, requiring dodging.
       - **Defeat Mechanism:** Successful dodge.
       - **Scoring:** Fixed points per successful dodge.
   - **Create Individual Scenes:**
     - Inherit each variant from the base `Phantom` scene.
     - Customize properties (speed, attack patterns) and scripts per type.

### 3. **Collision and Interaction System**
   - **Hitbox and Hurtbox Setup:**
     - **Hitboxes:**
       - Use `Area3D` with `CollisionShape3D` for detecting player punches.
       - Implement "sweet spot" areas for Yellow and Blue Phantoms to encourage varied attacks.
     - **Hurtboxes:**
       - Define areas on the player to detect phantom collisions.
       - Utilize `Area3D` for detecting when phantoms reach the player, triggering damage.
   - **Signal Connections:**
     - Connect collision signals to handlers for:
       - Calculating damage.
       - Updating scores based on hit quality (e.g., velocity, direction).

### 4. **AI Behavior Development**
   - **Movement Patterns:**
     - Implement AI to approach the player from diverse angles and heights.
     - Utilize pathfinding or scripted movement for varied behaviors.
   - **Sweet Spot Targeting:**
     - Define optimal hit areas and velocities to maximize damage or score.
   - **State Management:**
     - Use Godot’s `StateMachine` or Behavior Trees for managing AI states (e.g., idle, attacking, retreating).

### 5. **Phantom Spawning System (Rift System)**
   - **Rift Manager Node:**
     - Create a central `RiftManager` node responsible for spawning phantoms.
     - Attach scripts to handle spawn intervals and conditions.
   - **Spawn Randomization:**
     - Randomize spawn timings and phantom types to increase unpredictability.
   - **Rift Mechanics:**
     - Implement visual indicators for rift activity.
     - **Rift Closure:**
       - Close rift upon reaching certain score milestones.
       - Display rift weakening effects as player scores points.
       - Declare player victory when rift is fully closed.

### 6. **Health, Damage, and Scoring System**
   - **Phantom Health Management:**
     - Implement health properties for phantoms if partial damage is required.
     - For this design, phantoms are destroyed upon successful player actions.
   - **Scoring Mechanism:**
     - **Yellow & Blue Phantoms:**
       - Points awarded based on hit velocity and accuracy within the sweet spot.
     - **Green & Pink Phantoms:**
       - Fixed points awarded upon successful block or dodge.
   - **Player Life Force Management:**
     - Track player’s life force.
     - Deplete life force when phantoms reach the player.
     - **Visual Indicators:**
       - Implement glowing veins or similar effects to represent life force.
     - **Audio Cues:**
       - Intensify heartbeat sounds as life force depletes.
   - **Death and Destruction Effects:**
     - Trigger appropriate animations and particle effects upon phantom defeat or player death.

### 7. **Integration with Core Systems**
   - **Weapon System Interaction:**
     - Ensure phantoms respond to player’s energy gloves and melee attacks.
     - Handle different punch types (uppercut, jab, left hook, right hook) within attack scripts.
   - **Progression System Alignment:**
     - Tie phantom encounters to game progression milestones.
     - Adjust difficulty based on player’s advancement.
   - **Combo and Scoring System:**
     - Incorporate successful hits into combo mechanics.
     - Multiply scores based on consecutive successful actions.

### 8. **Testing and Optimization**
   - **Unit Testing AI Behaviors:**
     - Test each AI behavior individually to ensure consistency.
   - **Performance Optimization:**
     - Optimize phantom scripts and collision detection for smooth VR experiences.
     - Use Godot’s profiling tools to identify and address performance bottlenecks.
   - **Playtesting:**
     - Conduct playtests to gather feedback on phantom difficulty and behavior.
     - Adjust AI parameters based on player feedback to balance challenge and fun.

### 9. **Documentation and Support**
   - **Code Documentation:**
     - Comment scripts thoroughly using Godot’s documentation standards.
     - Maintain a README for the Phantom Enemy System outlining setup and customization.
   - **User Guides:**
     - Create tutorials or in-engine help guides detailing how the Phantom Enemy System operates.
     - Include examples of extending the base `Phantom` scene for new variants.

### 10. **Future Enhancements**
   - **Advanced Phantom Abilities:**
     - Introduce phantoms with unique abilities (e.g., teleportation, area-of-effect attacks).
   - **Phantom Variety Expansion:**
     - Continuously add new phantom types to keep gameplay engaging.
   - **Adaptive AI:**
     - Implement AI that learns and adapts to player strategies, enhancing replayability.

### **Best Practices Alignment**
- **Scene Organization:**
  - Maintain a clean hierarchy by separating phantoms into their own scenes.
  - Use inheritance to promote reusability and reduce redundancy.
- **Modular Design:**
  - Keep the `RiftManager` separate from individual phantoms to adhere to single responsibility.
- **Signal Utilization:**
  - Leverage Godot’s signal system for decoupled communication between nodes.
- **Performance Considerations:**
  - Optimize phantom scripts and collision areas to ensure VR performance is not hindered.
- **Documentation:**
  - Keep all systems well-documented to facilitate team collaboration and future enhancements.

### **References and Resources**
- [Godot XR Tools Documentation](https://godotvr.github.io/godot-xr-tools/docs/home/)
- [Godot 4 Official Documentation](https://docs.godotengine.org/en/stable/)
- [Godot Behavior Trees](https://docs.godotengine.org/en/stable/tutorials/ai/behavior_tree.html)
- [Godot State Machine Tutorial](https://docs.godotengine.org/en/stable/tutorials/ai/state_machine.html)
