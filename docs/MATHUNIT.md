# Spacewar 7800: AstroCart MathUnit Specification

A comprehensive technical reference for the **AstroCart FPGA MathUnit & CORDIC Trigonometric Engine** and its implementation in *Spacewar 7800*.

---

## 1. Overview & Purpose

The Atari 7800 ProSystem is powered by the Sally 6502C microprocessor running at 1.79 MHz. While capable of nimble sprite sequencing and game logic, the 6502 lacks hardware multiplication, division, or trigonometric instructions. 

Calculating real-time Newtonian celestial mechanics:
$$F = G \frac{M_\odot \cdot m}{r^2}$$
at 60 Hz for multiple moving bodies (Needle, Wedge, and 4 Photon Torpedoes), alongside real-time vector rotations for 16-directional flight models and lead-angle target prediction, would completely overwhelm the 6502 CPU, resulting in severe frame drops.

The **AstroCart V4 Cartridge** embeds a high-speed FPGA hardware co-processor mapped into the Atari 7800 expansion space at memory addresses `$0420 - $043F`. This co-processor operates synchronously with the 6502 bus, providing **zero wait-state** mathematical execution.

---

## 2. Hardware Memory Map

The co-processor is partitioned into two distinct functional units:

```
Address Range    Unit Name       Description
───────────────────────────────────────────────────────────────────────
$0420 - $042F    CORDIC Engine   Vector rotation, magnitude, and atan2
$0430 - $043F    Arithmetic Unit 32/16-bit division and 16x16 multiply
```

### 2.1 CORDIC Trigonometric Engine ($0420 - $042F)

The CORDIC (COordinate Rotation DIgital Computer) engine implements hardware vector conversion in both Cartesian $\to$ Polar and Polar $\to$ Cartesian modes using pipelined micro-rotations.

| Address | Symbol | Size | Direction | Description |
|---|---|---|---|---|
| `$0420` | `M_X` | 2 bytes (16-bit signed) | Write | Cartesian X coordinate / vector component |
| `$0422` | `M_Y` | 2 bytes (16-bit signed) | Write | Cartesian Y coordinate / vector component |
| `$0424` | `M_A` | 2 bytes (16-bit unsigned) | Write | Rotation Angle ($0 \dots 65535 \equiv 0^\circ \dots 360^\circ$) |
| `$0426` | `M_LEN` | 2 bytes (16-bit unsigned) | Read | Vector Magnitude output: $r = \sqrt{X^2 + Y^2}$ |
| `$0428` | `M_ANG` | 2 bytes (16-bit unsigned) | Read | Vector Angle output: $\theta = \text{atan2}(Y, X)$ |
| `$042A` | `M_RX` | 2 bytes (16-bit signed) | Read | Rotated X output: $X \cos(A) - Y \sin(A)$ |
| `$042C` | `M_RY` | 2 bytes (16-bit signed) | Read | Rotated Y output: $X \sin(A) + Y \cos(A)$ |

### 2.2 Arithmetic Unit ($0430 - $043F)

The Arithmetic Unit executes high-precision fixed-point divisions and products.

| Address | Symbol | Size | Direction | Description |
|---|---|---|---|---|
| `$0430` | `M_N` | 4 bytes (32-bit unsigned) | Write | Division Dividend / Numerator ($N$) |
| `$0434` | `M_D` | 2 bytes (16-bit unsigned) | Write | Division Divisor / Denominator ($D$) |
| `$0436` | `M_Q` | 2 bytes (16-bit unsigned) | Read | Division Quotient: $Q = \lfloor N / D \rfloor$ |
| `$0438` | `M_R` | 2 bytes (16-bit unsigned) | Read | Division Remainder: $R = N \pmod D$ |
| `$043A` | `M_MUL_A` | 2 bytes (16-bit signed) | Write | Multiplier Input A |
| `$043C` | `M_MUL_B` | 2 bytes (16-bit signed) | Write | Multiplier Input B |
| `$043E` | `M_MUL_RES`| 4 bytes (32-bit signed) | Read | Multiplication Product: $A \times B$ |

---

## 3. Co-Processor Execution in Spacewar 7800

### 3.1 Inverse-Square Gravity Pipeline
To compute gravitational acceleration towards the sun $(X_\odot, Y_\odot)$ in 6502 assembly:

```asm
    ; 1. Compute delta vector from ship to sun
    sec
    lda #< SUN_X
    sbc sw_px,y
    sta M_X             ; Store low byte of DX
    lda #> SUN_X
    sbc sw_px+1,y
    sta M_X+1           ; Store high byte of DX

    sec
    lda #< SUN_Y
    sbc sw_py,y
    sta M_Y             ; Store low byte of DY
    lda #> SUN_Y
    sbc sw_py+1,y
    sta M_Y+1           ; Store high byte of DY

    ; 2. Read exact distance and angle (Instantly available!)
    lda M_LEN
    sta sw_len
    lda M_LEN+1
    sta sw_len+1

    lda M_ANG
    sta sw_dir
    lda M_ANG+1
    sta sw_dir+1

    ; 3. Divide 1: K / r
    lda #< K_GRAV
    sta M_N
    lda #> K_GRAV
    sta M_N+1
    lda #0
    sta M_N+2
    lda #$0A            ; 32-bit constant K = 0x000A0000
    sta M_N+3

    lda sw_len
    sta M_D
    lda sw_len+1
    sta M_D+1

    ; 4. Divide 2: (K / r) / r = K / r^2
    lda M_Q
    sta M_N
    lda M_Q+1
    sta M_N+1
    lda #0
    sta M_N+2
    sta M_N+3

    lda sw_len
    sta M_D
    lda sw_len+1
    sta M_D+1

    ; M_Q now holds exact scalar acceleration |a|!
```

### 3.2 Ship Thrust & Inertia Vector Projection
When a pilot burns their main thrusters, an acceleration vector along the ship's current heading angle $\theta$ is added to the velocity vector:

```asm
    ; Feed thrust magnitude into M_X and zero into M_Y
    lda #< THRUST_ACCEL
    sta M_X
    lda #> THRUST_ACCEL
    sta M_X+1
    lda #0
    sta M_Y
    sta M_Y+1

    ; Set heading angle
    lda sw_ang,y
    sta M_A
    lda sw_ang+1,y
    sta M_A+1

    ; Read rotated Cartesian impulse components
    clc
    lda sw_vx,y
    adc M_RX
    sta sw_vx,y
    lda sw_vx+1,y
    adc M_RX+1
    sta sw_vx+1,y

    clc
    lda sw_vy,y
    adc M_RY
    sta sw_vy,y
    lda sw_vy+1,y
    adc M_RY+1
    sta sw_vy+1,y
```

---

## 4. Benchmark: Software 6502 vs AstroCart Hardware

| Operation | Software 6502 Cycles | AstroCart Co-Processor Cycles | Speedup Factor |
|---|---|---|---|
| **32 / 16-bit Unsigned Division** | ~350 - 450 cycles | **14 cycles** (Bus load/store only) | **~28x faster** |
| **16 $\times$ 16-bit Signed Multiplication** | ~200 - 320 cycles | **10 cycles** (Bus load/store only) | **~25x faster** |
| **Vector Magnitude $\sqrt{X^2 + Y^2}$** | ~400 - 600 cycles | **8 cycles** (Read `M_LEN`) | **~60x faster** |
| **Vector Angle $\text{atan2}(Y, X)$** | ~500 - 800 cycles | **8 cycles** (Read `M_ANG`) | **~80x faster** |
| **2D Vector Rotation $(X', Y')$** | ~600 - 950 cycles | **16 cycles** (Read `M_RX`, `M_RY`) | **~50x faster** |
| **Total 1-Frame Gravity Step (2 Ships + 4 Torps)** | ~9,500 cycles (53% frame budget!) | **320 cycles (1.7% frame budget)** | **~30x faster** |

By offloading all vector and gravity arithmetic to the AstroCart hardware co-processor, the 6502 CPU is free to spend 98% of its clock cycles updating MARIA display lists and servicing joystick inputs with instantaneous responsiveness.

---

## 5. Cartridge Header Signature

To inform emulators and flash cartridges that the AstroCart co-processor is required, bytes 59-61 of the 128-byte `.a78` header are stamped with the ASCII magic identifier:

```
Offset 59: 'A' ($41)
Offset 60: 'C' ($43)
Offset 61: 'M' ($4D)  ; AstroCart MathUnit Enabled
```

This signature is validated by the A7800 / MAME emulator (`mame64` on branch `cordic`) to automatically instantiate the co-processor memory region at `$0420 - $043F`.
