# Spacewar 7800: Design & Heritage

A technical and gameplay design specification for the Atari 7800 port of Bill Seiler's 1985 MS-DOS classic *Spacewar*.

---

## 1. Lineage & Historical Context

*Spacewar* has one of the richest ancestries in interactive computing:

1. **1962 - Spacewar! (Steve Russell, Martin Graetz, Wayne Wiitanen)** on the DEC PDP-1 at MIT: The original two-player space duel featuring the *Needle* and the *Wedge*, a central star with Newtonian gravity, torpedoes, and hyperspace.
2. **1971 - Computer Space (Nolan Bushnell & Ted Dabney)**: The first commercial coin-operated video game, implementing custom TTL logic without a microprocessor.
3. **1977 - Space Wars (Cinematronics / Larry Rosenthal)**: The landmark vector arcade cabinet featuring sharp vector graphics and selectable flight rules.
4. **1985 - Spacewar (Bill Seiler)** for MS-DOS: Released for IBM PC and compatibles. Seiler's edition introduced refined physics, selectable gravity configurations (Normal, Zero, Anti-gravity), bounce vs. wrap-around arena borders, and a sophisticated single-player autopilot AI with lead-target vector computation.
5. **2026 - Spacewar 7800**: Built for the Atari 7800 ProSystem, using the AstroCart FPGA MathUnit & CORDIC co-processor to deliver cycle-exact 60 Hz Newtonian orbital calculations and high-resolution 320A graphics.

---

## 2. Feature Comparison Matrix

| Feature | 1985 DOS Spacewar (Bill Seiler) | Spacewar 7800 (Atari 7800) |
|---|---|---|
| **Platform** | IBM PC/XT/AT (MS-DOS) | Atari 7800 ProSystem |
| **Graphics Mode** | CGA / EGA 320x200 (4 or 16 colors) | MARIA 320A (320x240, 160x240 color-mapped) |
| **Frame Rate** | ~18-36 Hz (Timer interrupt dependent) | Locked 60 Hz NTSC (50 Hz PAL) |
| **Ship Classes** | Needle (slender) & Wedge (triangular) | Needle (16 frames) & Wedge (16 frames) |
| **Rotational Headings** | 16 discrete angles (22.5° steps) | 16 discrete angles with sub-degree 16-bit accumulator |
| **Gravity Models** | Normal Sun ($1/r^2$), Repulsor, Zero-G | Normal Sun ($1/r^2$), Repulsor, Zero-G |
| **Boundary Modes** | Toroidal Wrap-around, Elastic Bounce | Toroidal Wrap-around, Elastic Bounce |
| **Weapons** | Photon Torpedoes, Continuous Phasers | Photon Torpedoes, Pulsed High-Speed Phasers |
| **Defenses** | Deflector Shields, Cloaking, Hyperspace | Deflector Shields, Hyperspace |
| **Energy System** | 99 Energy Units (Regenerating Reactor) | 99 Energy Units (Regenerating Reactor) |
| **AI Opponent** | Yes (Single-player Autopilot) | Yes (Autopilot running on 6502 + CORDIC co-processor) |
| **Math Engine** | 8087 FPU or integer lookup tables | AstroCart Hardware 32-bit Div/Mul + 16-bit CORDIC |

---

## 3. Flight Dynamics & Orbital Physics

### 3.1 Fixed-Point Coordinate System
Coordinates and velocities are maintained as 16-bit signed fixed-point values:
- **Positions ($P_x, P_y$)**: 8-bit integer screen pixel, 8-bit fractional subpixel (`8.8 fixed-point`).
  - Screen resolution: 320 horizontal $\times$ 240 vertical.
  - Subpixel resolution: $1/256$ of a pixel per step.
- **Velocities ($V_x, V_y$)**: 16-bit signed delta added to position every frame (60 Hz).
  - Maximum linear velocity: Clamped to prevent phase-through tunneling during collision checks.
- **Ship Heading ($\theta$)**: 16-bit angular accumulator ($0 \dots 65535$ spanning a full $360^\circ$ circle).
  - High 4 bits (`ang >> 12`) select one of the 16 visual rotational sprite frames ($0 \dots 15$).

### 3.2 Newtonian Gravitational Acceleration
In normal gravity mode, the central star exerts a radial acceleration towards the solar center $(X_\odot, Y_\odot)$:

$$\vec{r} = (X_\odot - P_x) \, \hat{i} + (Y_\odot - P_y) \, \hat{j}$$

$$r = \|\vec{r}\| = \sqrt{\Delta x^2 + \Delta y^2}$$

$$a_{\text{grav}} = \frac{G \cdot M_\odot}{r^2}$$

$$\vec{a}_{\text{grav}} = a_{\text{grav}} \cdot \frac{\vec{r}}{r} = \frac{G \cdot M_\odot}{r^3} \cdot \vec{r}$$

On traditional 8-bit microprocessors without multiplication or division hardware, calculating inverse-square gravity at 60 Hz for multiple bodies requires extensive lookup tables or coarse approximations.

In **Spacewar 7800**, the AstroCart MathUnit performs this in hardware:
1. **CORDIC Cartesian-to-Polar**: Feeding $(\Delta x, \Delta y)$ into `M_X` and `M_Y` yields exact distance $r$ in `M_LEN` and angle $\phi$ in `M_ANG` within 16 co-processor clock cycles.
2. **First Hardware Division**: $\frac{K}{r}$ is computed via the 32-bit hardware divider.
3. **Second Hardware Division**: $\frac{K/r}{r} = \frac{K}{r^2}$ produces the exact scalar acceleration magnitude.
4. **CORDIC Polar-to-Cartesian Rotation**: The acceleration magnitude is projected along angle $\phi$ to produce $(\Delta V_x, \Delta V_y)$, which are directly summed into the ship's velocity vector.

### 3.3 Solar Capture & Corona Collision
If a ship's orbital radius $r$ falls below the solar threshold ($R_{\text{sun}} \approx 12$ pixels), the vessel is pulled into the solar furnace and immediately destroyed, triggering a secondary shockwave explosion.

---

## 4. Combat & Energy Mechanics

### 4.1 Reactor & Energy Allocation
Each ship is equipped with a matter-antimatter reactor holding up to **99 Energy Units**. Energy slowly regenerates when systems are idle (+1 unit every 8 frames).

Operating systems impose direct demands on this energy reserve:
- **Main Thrusters**: Consumes 1 energy unit per 4 frames of continuous burn.
- **Photon Torpedoes**: Consumes 15 energy units per launch.
- **Phasers**: Consumes 8 energy units per burst.
- **Deflector Shields**: Consumes 1 energy unit every 3 frames while active.
- **Hyperspace Jump**: Consumes 30 energy units instantly.

If energy drops to zero, shields drop and weapons lock out until the reactor recovers minimal charge.

### 4.2 Weapons Arsenal

#### Photon Torpedoes
- **Behavior**: Ballistic projectiles fired along the ship's forward vector.
- **Inertia**: Inherits the parent ship's launch velocity plus torpedo launch speed ($V_t = V_{\text{ship}} + V_0$).
- **Gravity Interaction**: Torpedoes are affected by the central sun's gravity, allowing pilots to sling shots around the star to hit enemies concealed behind it.
- **Lifetime**: Self-destructs after 90 frames (~1.5 seconds) if no target is impacted.

#### Phasers
- **Behavior**: High-velocity coherent energy bolts designed for close-to-medium range dogfighting.
- **Velocity**: Traverses space at triple the speed of a torpedo.
- **Shield Piercing**: Rapid shield drain on impact; if shields are down, deals lethal damage to hull structure.

### 4.3 Defenses

#### Deflector Shields
- Engaged by pulling back on the flight stick (`Joystick Down`).
- A protective electromagnetic bubble deflects incoming torpedoes and absorbs phaser energy at the cost of rapid reactor drain.
- When active, ship thrusters and weapons are inhibited.

#### Hyperspace Drive
- Emergency evasion system.
- Instantly dematerializes the ship and translates it into a random coordinate in space.
- **Risk**: 15% probability of reactor blowout upon reentry, emerging with disabled controls or dangerously close to the sun.

---

## 5. Autopilot AI Architecture

The single-player computer opponent uses a hierarchical decision tree powered by the co-processor:

```
                    [ AI Cycle (60 Hz) ]
                             │
                  Is ship alive & active?
                             ├── No  --> RTS
                             └── Yes
                                  │
                 Check Distance to Central Sun
                  (via CORDIC M_X/M_Y -> M_LEN)
                             │
              r < Solar Hazard Radius (45 px)?
                 ├── Yes: [ EMERGENCY SUN ESCAPE ]
                 │        • Calculate vector away from sun (M_ANG + 180°)
                 │        • Turn towards escape vector
                 │        • Full burn thrusters
                 └── No
                      │
           Evaluate Target (Player 1) Position & Velocity
                      │
               Calculate Intercept Angle & Lead
                      │
           Turn towards target lead angle (Clockwise / CCW)
                      │
          In firing arc & distance < 100 px?
             ├── Yes: Fire Torpedo / Phaser
             └── No:  Pulse thrusters to maintain pursuit orbit
```

Thanks to the hardware co-processor, the AI calculates true trigonometric lead angles without consuming CPU time that would otherwise starve MARIA display list generation.
