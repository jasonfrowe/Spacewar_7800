# Spacewar 7800: Engine & Graphics Architecture

A comprehensive technical manual describing the display engine, MARIA DMA budget, TIA sound generation, and 6502/AstroCart integration in *Spacewar 7800*.

---

## 1. Video Architecture & MARIA Graphics

### 1.1 Resolution and Display Mode: 320A
*Spacewar 7800* utilizes MARIA's **320A mode** (320 $\times$ 240 pixels), the highest horizontal resolution available on the Atari 7800 ProSystem:
- **Pixel Aspect Ratio**: 1:1 on standard CRT displays.
- **Pixel Depth**: 1-bit per pixel (2 colors per 8-pixel tile byte: Background Color + 1 Selected Palette Color).
- **Advantage**: Provides crisp, vector-like ship contours, sharp torpedo dots, and readable alphanumeric HUD displays, capturing the authentic aesthetic of the 1985 DOS version and the classic Cinematronics vector arcade cabinets.

### 1.2 Palette Allocation
MARIA provides 8 palettes of 3 colors plus background color. In 320A mode, each sprite references one palette index, where non-zero bits display Color 2 of the assigned palette:

| Palette | Assigned Objects | Atari Hue / Lum | Visual Representation |
|---|---|---|---|
| **P0** | Text, Menu, Starfield, HUD | `$0F` (White) | High-contrast characters |
| **P1** | Central Sun & Solar Corona | `$1E` (Bright Solar Gold) | Radiating solar disc |
| **P2** | Needle Ship (Player 1) | `$9C` (Cyan / Electric Blue) | Sleek cruiser hull |
| **P3** | Wedge Ship (Player 2 / AI) | `$3A` (Vermillion / Red-Orange) | Heavy armored fighter |
| **P4** | Torpedoes & Phaser Bolts | `$CA` (Lime Green / Neon) | High-energy projectiles |
| **P5** | Explosions & Thrust Flames | `$36` (Fiery Amber / Yellow) | Plasma combustion |

### 1.3 Sprite Generation & 16-Heading Rotation
Ships are rendered across **16 discrete directional frames** spaced at $22.5^\circ$ increments ($360^\circ / 16$):
- Generated programmatically at build time by `tools/mkgfx.py` using Python `Pillow`.
- Each frame is an optimized 1-bit 16x16 pixel matrix (`needle_00.png` ... `needle_15.png`, `wedge_00.png` ... `wedge_15.png`).
- High-order nibble of the 16-bit ship angle (`sw_ang >> 12`) directly indexes the frame lookup table.
- Subpixel fractional position is retained in the lower 8 bits of position for smooth linear drift across the screen.

```
                  Heading Frame Map (0 - 15)
                             00 (Up)
                     15               01
                14                         02
             13                               03
   (Left) 12                   +                   04 (Right)
             11                               05
                10                         06
                     09               07
                             08 (Down)
```

### 1.4 MARIA DMA Management & Zone Slicing
MARIA operates by scanning Display Lists organized into vertical zones (typically 8 or 16 scanlines each):
- **Zone Height**: Configured to 16 scanlines.
- **Display Objects Limit**: 24 objects per zone (configured via `displaymode 320A` and 7800basic zone buffers from `$1880` to `$23FF`).
- **DMA Budget Protection**: Because Spacewar features a central star, two ships, two thruster plumes, four torpedoes, and multiple explosion particles, objects are distributed across different vertical zones. The 320A 1-bit mode requires fewer DMA read cycles per byte than 160A (2-bit) or 160B (4-bit) modes, ensuring zero scanline dropouts or sprite tearing.

---

## 2. Audio Engine (`src/asm/sound.asm`)

The sound subsystem drives the Atari 7800's Television Interface Adaptor (TIA) sound generator, providing two polyphonic audio voices with hardware sound timers:

### 2.1 Channel Assignment

```
 [ Sound Engine (60 Hz tick via sound_tick) ]
        │
        ├── Voice 0 ($15 / $17 / $19): Flight Propulsion & Energy Weapons
        │     • Thrust Rumble: Distortion $08, Low Pitch, Envelope Modulation
        │     • Phaser Chirp: Distortion $04, High-Speed Downward Sweep
        │
        └── Voice 1 ($16 / $18 / $1A): Ballistics, Shields & Detonations
              • Torpedo Launch: Distortion $0C, Dual Harmonic Ping
              • Shield Impact: Distortion $06, Sharp Metallic Clang
              • Hyperspace Distortion: Distortion $07, Ascending Frequency Warble
              • Ship Explosion: Distortion $08, Long Low-Frequency Rumbling Roar
```

### 2.2 Sound Routine APIs
- `snd_thrust_on`: Triggers rocket engine roar on Channel 0 for active burn.
- `snd_thrust_off`: Silences Channel 0 when engines cut out.
- `snd_fire_phaser`: Initiates high-velocity laser sweep on Channel 0.
- `snd_fire_torp`: Plays resonant torpedo discharge on Channel 1.
- `snd_shield_hit`: Emits shield deflection chime on Channel 1.
- `snd_hyperspace`: Plays spatial translation audio envelope on Channel 1.
- `snd_explode`: Fires multi-frame decaying explosion rumble on Channel 1.

---

## 3. Physics & Co-Processor Pipeline (`src/asm/physics.asm`)

The physics engine is executed at 60 Hz during vertical blanking. It processes motion, gravitational pull, boundary enforcement, weapon tracking, and collision detection.

### 3.1 Physics Execution Loop
1. **Ship Update (`update_ship`)**:
   - Computes distance and direction vector to Central Sun.
   - Invokes AstroCart MathUnit co-processor to derive inverse-square acceleration:
     $$a = \frac{K}{r^2}$$
   - Adds gravitational delta to ship velocity $(V_x, V_y)$.
   - Adds inertia and updates position $(P_x, P_y)$.
   - Enforces arena boundary mode (toroidal wrap or bounce).
2. **Torpedo Tracking (`update_torpedoes`)**:
   - Moves up to 4 simultaneous torpedoes.
   - Decrements lifetime counters.
   - In Normal Sun mode, applies gravitational bending to torpedo trajectories.
3. **Explosion Animation (`update_explosions`)**:
   - Advances 4-stage explosion frame timers.
   - Cleans up inactive particle slots.
4. **Collision Detection (`check_collisions`)**:
   - Torpedo-to-Ship bounding circle checks ($r_{\text{col}} < 8$ pixels).
   - Phaser-to-Ship ray intersection.
   - Ship-to-Ship ramming detection.
   - Solar corona thermal envelope breach ($r < 12$ pixels).

---

## 4. Memory Layout & Zero Page Map

```
Address Range    Usage
────────────────────────────────────────────────────────────────
$0040 - $007F    Spacewar Engine Zero Page Registers:
                 • sw_px (4 bytes): Ships X coordinates (8.8 fixed-point)
                 • sw_py (4 bytes): Ships Y coordinates (8.8 fixed-point)
                 • sw_vx (4 bytes): Ships X velocities (8.8 fixed-point)
                 • sw_vy (4 bytes): Ships Y velocities (8.8 fixed-point)
                 • sw_ang (4 bytes): Ships Headings (16-bit angle)
                 • sw_energy (2 bytes): Ships Reactor Reserves (0-99)
                 • sw_shield (2 bytes): Shield states (0=off, 1=active)
                 • sw_tlife (4 bytes): Torpedo lifetime counters
                 • sw_tx / sw_ty (8 bytes): Torpedo positions
$0140 - $01C0    Display Buffers & Explosion Slots
$01C2            Stack Canary (Preserved for 7800basic runtime safety)
$0420 - $042F    AstroCart CORDIC Trigonometric Co-Processor
$0430 - $043F    AstroCart 32-bit Arithmetic MathUnit
$1880 - $23FF    MARIA Zone Memory (24 objects per zone)
$D000 - $EFFF    Graphics ROM Bank (Sprites & Font tiles)
$F000 - $FFFF    Main Code ROM, Encryption Signature & Cart Vectors
```
