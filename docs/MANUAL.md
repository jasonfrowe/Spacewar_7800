# ATARI 7800™ Game Program™ Instructions

# SPACEWAR 7800
### FEATURING THE ASTROCART™ CORDIC CO-PROCESSOR

---

## MISSION BRIEFING: THE BATTLE FOR KEPLER-78

Deep within the uncharted frontier of Sector 12, two dreadnoughts encounter one another caught inside the inescapable gravitational well of a blazing yellow dwarf star. Both ships are low on dilithium, their communication arrays damaged, and their automated target lock systems engaged.

Only one vessel will survive the gravitational slingshots, scorching solar flares, and relentless plasma barrages to achieve escape velocity. 

Welcome to **SPACEWAR 7800**, the definitive Atari 7800 recreation of Bill Seiler's 1985 classic.

---

## 1. GETTING STARTED

1. Insert your **SPACEWAR 7800** cartridge into your Atari 7800 ProSystem console with the label facing away from you.
2. Connect one or two Atari ProLine™ or compatible two-button controllers into the joystick ports:
   - **Player 1 (The Needle)** uses **Left Controller**.
   - **Player 2 (The Wedge)** uses **Right Controller** (or selects 1-Player vs. CPU mode).
3. Turn on your television and slide the console **POWER** switch to **ON**.
4. Press **GAME SELECT** or move Joystick 1 to configure your match options, then press **FIRE** or **RESET** to commence combat!

---

## 2. CONSOLE SWITCHES

- **POWER**: Turns the console on and off.
- **GAME SELECT**: Cycles through game options on the title screen:
  - **Game Mode**: 2 Players (Head-to-Head) or 1 Player (Human vs. Autopilot CPU).
  - **Gravity Field**: Normal Sun ($1/r^2$ Newtonian pull), Repulsor Sun (Anti-gravity field), or Zero-G (Deep space drift).
  - **Arena Boundary**: Toroidal Wrap-around (re-enter on opposite edge) or Elastic Wall Bounce.
- **GAME RESET**: Restarts the current match or returns to the Title Screen.
- **LEFT DIFFICULTY (P1)**:
  - **Position A (Pro)**: Normal ship inertia; slower shield recovery.
  - **Position B (Novice)**: Enhanced thruster response; faster shield recovery.
- **RIGHT DIFFICULTY (P2 / CPU)**:
  - **Position A (Pro)**: Expert AI piloting; aggressive lead firing.
  - **Position B (Novice)**: Defensive AI piloting.

---

## 3. FLIGHT CONTROLS

Spacewar 7800 utilizes the full capability of the Atari 7800 ProLine two-button joystick:

```
                      [ PUSH FORWARD: THRUST ]
                                 ▲
                                 │
     [ PULL LEFT: ROTATE CCW ] ◄──┼──► [ PUSH RIGHT: ROTATE CW ]
                                 │
                                 ▼
                     [ PULL BACK: SHIELDS UP ]

          ┌─────────────┐               ┌─────────────┐
          │  BUTTON 1   │               │  BUTTON 2   │
          │ (FIRE TORP) │               │(FIRE PHASER)│
          └─────────────┘               └─────────────┘
```

- **Rotate Left / Right**: Turns your ship in 16 discrete heading angles ($22.5^\circ$ per step).
- **Thrust Forward**: Ignites your main plasma drive, accelerating your ship along its current heading. Consumes reactor energy.
- **Shields (Pull Back)**: Projects an electromagnetic deflector shield bubble. Absorbs phasers and deflects torpedoes, but rapidly drains energy and prevents firing.
- **Button 1 (Left Button)**: Launches a high-explosive **Photon Torpedo**. Torpedoes curve under the star's gravity!
- **Button 2 (Right Button)**: Discharges a high-velocity **Phaser Bolt**. Rapid and deadly at close range.
- **Both Buttons Together**: Activates the emergency **Hyperspace Drive**, instantly teleporting your ship to a random sector coordinate.

---

## 4. COCKPIT INSTRUMENTATION (HUD)

The top of your screen displays critical tactical telemetry for both commanders:

```
 P1: 03  E:84 S:OK      Kepler Sun       P2: 02  E:76 S:OK
```

- **P1 / P2 Score**: Number of round victories won in the current match (First pilot to reach 5 victories wins the match).
- **E: [00 - 99]**: Reactor Energy remaining.
  - Regenerates continuously when systems are offline.
  - If your energy hits 00, your shields collapse, thrusters cut out, and weapons lock until power recovers!
- **S: [OK / HIT / OFF]**: Deflector shield integrity.
  - **OK**: Shields primed and ready to engage.
  - **HIT**: Shields absorbing an incoming strike.
  - **OFF**: Shields inactive or drained.

---

## 5. SHIPS OF THE FLEET

### The Needle (Cruiser)
- **Hull Design**: Elongated, needle-shaped vector profile.
- **Flight Characteristics**: High top velocity, sharp angular acceleration.
- **Tactical Profile**: Excels at perimeter harassment, wide orbital sweeps, and sniping enemies across the solar core with slingshot torpedoes.

### The Wedge (Interceptor)
- **Hull Design**: Broad, delta-wing arrowhead vector profile.
- **Flight Characteristics**: Heavy inertia, solid directional stability.
- **Tactical Profile**: Devastating close-range dogfighter. Uses phaser spreads to burn through enemy shields and bull-rush opponents into the sun.

---

## 6. STARFLEET TACTICAL MANUAL (TIPS FROM THE ACADEMY)

1. **Master the Slingshot**: Firing your thrusters at the closest point of approach to the sun (*periapsis*) will maximize your orbital speed (the Oberth effect). Use this speed boost to escape the dogfight arc or whip around the rear of your opponent!
2. **Beware the Corona**: Grazing the sun's outer corona will heat your shields; crossing inside the event boundary means instant vaporization!
3. **Leading Your Shots**: Because torpedoes inherit your ship's velocity vector, launching while rotating creates a sweeping spread of fire. Combine your orbital drift with your target's bearing to lead them into your barrage.
4. **Conserve Reactor Energy**: Do not hold the thrusters down continuously. Space is a frictionless vacuum: once accelerated, your ship will coast indefinitely until gravity or counter-thrust alters your vector.
5. **Hyperspace as a Last Resort**: When pinned against the sun or cornered by torpedoes, hyperspace can save your vessel—but beware: the sub-ether jump has a 15% chance of misjump catastrophically disabling your ship!

---

*ATARI and the ATARI logo are registered trademarks of Atari Interactive, Inc.*
*AstroCart is a trademark of Jason Rowe.*
*Spacewar 7800 (c) 2026. All Rights Reserved.*
