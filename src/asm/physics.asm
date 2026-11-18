; Spacewar 7800 - Physics, MathUnit CORDIC Engine & Weapons Simulation
; Port of Bill Seiler's 1985 DOS Spacewar for Atari 7800 ProSystem
;
; Coordinate System:
;   World X (sw_px): 16-bit 8.8 fixed-point in 7800 horizontal clocks (8.0 .. 152.0)
;   World Y (sw_py): 16-bit 8.8 fixed-point in scanlines (18.0 .. 182.0)
;   Sun Center:      X = 78.0 ($4E00), Y = 100.0 ($6400)
;   Velocity:        16-bit signed 8.8 fixed-point ($0100 = 1 screen unit/frame)
;   Angle:           16-bit unsigned ($0000=East, $4000=South, $8000=West, $C000=North)

; AstroCart MathUnit Register Addresses
M_X     = $0420
M_Y     = $0422
M_T     = $0424
M_XR    = $0420
M_YR    = $0422
M_ANG   = $0424
M_LEN   = $0426

M_A     = $0430
M_B     = $0432
M_N     = $0434
M_D     = $0438
M_SIGN  = $043A
M_P     = $0430
M_Q     = $0434
M_R     = $0438
M_RND   = $043E

; World Arena Constants (8.8 fixed-point)
SUN_X       = $4E00     ; 78 * 256 (Center X)
SUN_Y       = $6400     ; 100 * 256 (Center Y)
SUN_RAD_HI  = $06       ; Lethal sun radius = 6 units ($0600)

X_MIN_HI    = 8         ; Left arena border
X_MAX_HI    = 152       ; Right arena border
Y_MIN_HI    = 18        ; Top arena border (below HUD)
Y_MAX_HI    = 182       ; Bottom arena border

; Physics & Combat Tuning Constants
THRUST_ACC      = $000C     ; Balanced rocket thrust (12/256 unit/frame^2)
MAX_VEL_HI      = $01       ; Clamp velocity to +/- $01A0 (~1.625 units/frame)
MAX_VEL_LO      = $A0
ROT_SPEED       = $0380     ; Crisp rotation (~1.2 sec per full 360 turn)
MAX_TORPS       = 12        ; 12 simultaneous torpedoes (6 per player: 0..5 P1, 6..11 P2)
TORP_SPEED      = $00C0     ; Tuned torpedo speed (0.75 units/frame + ship vel) for natural gravity curve
TORP_LIFE       = 180       ; 180 frames (3.0 sec) flight life
TORP_ARM_LIFE   = 164       ; Armed against own ship after 16 frames (0.26s launch clearance)
PHASER_SPEED    = $0320     ; Fast straight-line phaser bolt (3.125 units/frame)

; Memory Layout ($2200 - $22FF: 256 bytes of dedicated Game State RAM)
sw_px       = $2200     ; (4) Ship 0, 1 X pos (8.8 fixed-point)
sw_py       = $2204     ; (4) Ship 0, 1 Y pos (8.8 fixed-point)
sw_vx       = $2208     ; (4) Ship 0, 1 X vel (8.8 signed)
sw_vy       = $220C     ; (4) Ship 0, 1 Y vel (8.8 signed)
sw_ang      = $2210     ; (4) Ship 0, 1 Heading angle (16-bit)
sw_energy   = $2214     ; (2) Energy (0-99)
sw_shield   = $2216     ; (2) Shield (0-99)
sw_cloak    = $2218     ; (2) Fire cooldown timer per ship
sw_alive    = $221A     ; (2) 1=alive, 0=destroyed
sw_thrust   = $221C     ; (2) 1=thrusting this frame
sw_score    = $221E     ; (2) Match wins (0-5)

sw_lx       = $2220     ; (4) Phaser 0..1 X pos (8.8)
sw_ly       = $2224     ; (4) Phaser 0..1 Y pos (8.8)
sw_lvx      = $2228     ; (4) Phaser 0..1 X vel
sw_lvy      = $222C     ; (4) Phaser 0..1 Y vel
sw_llife    = $2230     ; (2) Phaser 0..1 lifetime (0=inactive)

sw_ex       = $2232     ; (2) Explosion X (screen coords)
sw_ey       = $2234     ; (2) Explosion Y (screen coords)
sw_eframe   = $2236     ; (2) Explosion frame (0-3)
sw_etimer   = $2238     ; (2) Explosion timer

sw_sx       = $223A     ; (2) Ship 0, 1 screen X
sw_sy       = $223C     ; (2) Ship 0, 1 screen Y
sw_sframe   = $223E     ; (2) Ship 0, 1 rotation frame (0-15)

sw_mode     = $2240     ; 0 = 2P Battle, 1 = 1P vs CPU (Default = 1)
sw_grav     = $2241     ; 0 = Normal Sun, 1 = Zero-G, 2 = Repulsor Sun
sw_wrap     = $2242     ; 0 = Wrap Around, 1 = Bounce Walls
sw_state    = $2243     ; 0 = Menu, 1 = Playing, 2 = Round Over
sw_winner   = $2244     ; Last round winner
sw_timer    = $2245     ; Round transition timer
sw_frame    = $2246     ; Global frame counter

sfx_ch0_id      = $2248
sfx_ch0_timer   = $2249
sfx_ch0_step    = $224A
sfx_ch1_id      = $224B
sfx_ch1_timer   = $224C
sfx_ch1_step    = $224D

sw_tmp      = $224E     ; (4) Scratch
sw_dx       = $2252     ; (2)
sw_dy       = $2254     ; (2)
sw_len      = $2256     ; (2)
sw_dir      = $2258     ; (2)

; Precomputed ASCII HUD digits & projectile screen coords
sw_lsx      = $225A     ; (2) Phaser 0..1 screen X
sw_lsy      = $225C     ; (2) Phaser 0..1 screen Y
sw_e0_asc   = $225E     ; (2) P1 Energy ASCII digits
sw_s0_asc   = $2260     ; (2) P1 Shield ASCII digits
sw_w0_asc   = $2262     ; (2) P1 Wins ASCII digits
sw_e1_asc   = $2264     ; (2) P2 Energy ASCII digits
sw_s1_asc   = $2266     ; (2) P2 Shield ASCII digits
sw_w1_asc   = $2268     ; (2) P2 Wins ASCII digits
sw_fpx      = $226A     ; (2) Ship 0, 1 Thrust flame screen X
sw_fpy      = $226C     ; (2) Ship 0, 1 Thrust flame screen Y
sw_ai_tac   = $226E     ; (1) AI random opening angle / strafe offset
sw_ai_tmr   = $226F     ; (1) AI maneuver timer (bit 7 = opening break phase)

; 12 Photon Torpedo Slots (0..5 = Player 1, 6..11 = Player 2)
; Placed in 7800basic dedicated user RAM ($0140-$019F and $2270-$229F)
; so they NEVER overlap MARIA Zone 15 Display List memory ($22B0+)!
sw_tx       = $0140     ; (24) Torpedo 0..11 X pos (8.8) ($0140-$0157)
sw_ty       = $0158     ; (24) Torpedo 0..11 Y pos (8.8) ($0158-$016F)
sw_tvx      = $0170     ; (24) Torpedo 0..11 X vel       ($0170-$0187)
sw_tvy      = $0188     ; (24) Torpedo 0..11 Y vel       ($0188-$019F)
sw_tlife    = $2270     ; (12) Torpedo 0..11 lifetime    ($2270-$227B)
sw_towner   = $227C     ; (12) Torpedo 0..11 owner (0/1) ($227C-$2287)
sw_tsx      = $2288     ; (12) Torpedo 0..11 screen X    ($2288-$2293)
sw_tsy      = $2294     ; (12) Torpedo 0..11 screen Y    ($2294-$229F)

; Macro: Rotate immediate 16-bit constant {1} by 16-bit angle at address {2}
    MAC M_ROTATE_IMM
    lda #<{1}
    sta M_X
    lda #>{1}
    sta M_X+1
    lda #0
    sta M_Y
    sta M_Y+1
    lda {2}
    sta M_T
    lda {2}+1
    sta M_T+1
    ENDM

; Macro: Rotate 16-bit variable at address {1} by 16-bit angle at address {2}
    MAC M_ROTATE_VAR
    lda {1}
    sta M_X
    lda {1}+1
    sta M_X+1
    lda #0
    sta M_Y
    sta M_Y+1
    lda {2}
    sta M_T
    lda {2}+1
    sta M_T+1
    ENDM

; Initialize entire match (called at boot or match reset)
spacewar_init
    lda #1
    sta M_SIGN          ; Enable signed math mode on AstroCart
    lda #0
    sta sw_score
    sta sw_score+1
    sta sw_grav         ; Default: Normal Sun Gravity
    sta sw_wrap         ; Default: Toroidal Wrap-Around
    sta sw_state
    sta sw_timer
    sta sw_frame
    lda #1
    sta sw_mode         ; Default: 1-Player vs CPU so P2 is active immediately!
    jsr sound_init
    jsr round_init
    rts

; Initialize a single combat round
round_init
    ; Step hardware xorshift PRNG ($043E)
    lda M_RND

    ; Player 1 (Needle): Starts on Left (X=34, Y=100), orbiting downward
    lda #0
    sta sw_px
    lda #34
    sta sw_px+1
    lda #0
    sta sw_py
    lda #100
    sta sw_py+1

    lda #0
    sta sw_vx
    sta sw_vx+1
    lda #$7C            ; Downward circular orbital velocity (+0.48 units/frame)
    sta sw_vy
    lda #0
    sta sw_vy+1

    lda #0              ; Facing South ($4000) along orbit
    sta sw_ang
    lda #$40
    sta sw_ang+1

    ; Player 2 (Wedge): Starts on Right (X=122, Y=100), orbiting upward
    lda #0
    sta sw_px+2
    lda #122
    sta sw_px+3
    lda #0
    sta sw_py+2
    lda #100
    sta sw_py+3

    lda #0
    sta sw_vx+2
    sta sw_vx+3
    lda #<-$7C          ; Upward circular orbital velocity (-0.48 units/frame)
    sta sw_vy+2
    lda #>-$7C
    sta sw_vy+3

    lda #0              ; Facing North ($C000) along orbit
    sta sw_ang+2
    lda #$C0
    sta sw_ang+3

    ; If Gravity is OFF (sw_grav == 1 or sw_grav == 3), start with zero velocity
    ; and give the AI an unpredictable initial drift vector via CORDIC while facing Player 1!
    lda #0
    sta sw_ai_tac
    sta sw_ai_tmr
    lda sw_grav
    and #1
    beq .keep_orb_vel
    lda #0
    sta sw_vy
    sta sw_vy+1
    sta sw_vy+2
    sta sw_vy+3

    lda M_RND
    eor sw_frame
    and #7
    tax
    lda ai_open_angles,x
    sta sw_ai_tac
    lda sw_mode
    cmp #1
    bne .keep_orb_vel
    ; Rotate cruise speed ($0044) by random angle sw_ai_tac for unpredictable opening drift
    lda #$44
    sta M_X
    lda #0
    sta M_X+1
    sta M_Y
    sta M_Y+1
    sta M_T
    lda sw_ai_tac
    sta M_T+1
    lda M_XR
    sta sw_vx+2
    lda M_XR+1
    sta sw_vx+3
    lda M_YR
    sta sw_vy+2
    lda M_YR+1
    sta sw_vy+3
    ; Point AI roughly toward Player 1 (+/- random offset) so it aims immediately
    lda sw_ai_tac
    and #$3F
    clc
    adc #$60            ; Heading in $60..$9F (West-Southwest to West-Northwest)
    sta sw_ang+3
.keep_orb_vel

    ; Initial Energy & Shields (99 max for clean 2-digit HUD)
    lda #99
    sta sw_energy
    sta sw_energy+1
    sta sw_shield
    sta sw_shield+1

    lda #1
    sta sw_alive
    sta sw_alive+1
    lda #15             ; 15-frame initial safety cooldown for P1
    sta sw_cloak
    lda #30             ; AI waits 30 frames into the round to observe Player 1 first!
    sta sw_cloak+1
    lda #0
    sta sw_thrust
    sta sw_thrust+1

    ; Clear active weapons and explosions
    ldx #MAX_TORPS-1
.clr_torp
    lda #0
    sta sw_tlife,x
    dex
    bpl .clr_torp

    ldx #1
.clr_phas
    lda #0
    sta sw_llife,x
    sta sw_etimer,x
    dex
    bpl .clr_phas

    jsr update_screen_coords
    rts

; =========================================================================
; Player 1 & Player 2 Control Actions
; =========================================================================

p1_turn_left
    sec
    lda sw_ang
    sbc #<ROT_SPEED
    sta sw_ang
    lda sw_ang+1
    sbc #>ROT_SPEED
    sta sw_ang+1
    rts

p1_turn_right
    clc
    lda sw_ang
    adc #<ROT_SPEED
    sta sw_ang
    lda sw_ang+1
    adc #>ROT_SPEED
    sta sw_ang+1
    rts

p1_thrust
    lda sw_energy
    beq .p1_th_skip
    lda sw_frame
    and #3
    bne .p1_no_edrain
    dec sw_energy
.p1_no_edrain
    lda #2
    sta sw_thrust
    M_ROTATE_IMM THRUST_ACC, sw_ang
    clc
    lda sw_vx
    adc M_XR
    sta sw_vx
    lda sw_vx+1
    adc M_XR+1
    sta sw_vx+1
    clc
    lda sw_vy
    adc M_YR
    sta sw_vy
    lda sw_vy+1
    adc M_YR+1
    sta sw_vy+1
    lda sw_frame
    and #3
    bne .p1_th_skip
    lda #SFX_THRUST
    jsr sound_play_ch0
.p1_th_skip
    rts

p2_turn_left
    sec
    lda sw_ang+2
    sbc #<ROT_SPEED
    sta sw_ang+2
    lda sw_ang+3
    sbc #>ROT_SPEED
    sta sw_ang+3
    rts

p2_turn_right
    clc
    lda sw_ang+2
    adc #<ROT_SPEED
    sta sw_ang+2
    lda sw_ang+3
    adc #>ROT_SPEED
    sta sw_ang+3
    rts

p2_thrust
    lda sw_energy+1
    beq .p2_th_skip
    lda sw_frame
    and #3
    bne .p2_no_edrain
    dec sw_energy+1
.p2_no_edrain
    lda #2
    sta sw_thrust+1
    M_ROTATE_IMM THRUST_ACC, sw_ang+2
    clc
    lda sw_vx+2
    adc M_XR
    sta sw_vx+2
    lda sw_vx+3
    adc M_XR+1
    sta sw_vx+3
    clc
    lda sw_vy+2
    adc M_YR
    sta sw_vy+2
    lda sw_vy+3
    adc M_YR+1
    sta sw_vy+3
    lda sw_frame
    and #3
    bne .p2_th_skip
    lda #SFX_THRUST
    jsr sound_play_ch1
.p2_th_skip
    rts

p1_fire_phaser
    lda sw_cloak        ; Cooldown active?
    bne .p1_ph_done
    lda sw_llife
    bne .p1_ph_done
    lda sw_energy
    cmp #6              ; Meaningful 6-energy reactor cost per Phaser burst
    bcc .p1_ph_done
    sec
    sbc #6
    sta sw_energy
    lda #16             ; 16-frame cooldown
    sta sw_cloak
    lda #14             ; 14-frame reach (~44 screen units = 30% of arena width)
    sta sw_llife
    lda sw_px
    sta sw_lx
    lda sw_px+1
    sta sw_lx+1
    lda sw_py
    sta sw_ly
    lda sw_py+1
    sta sw_ly+1
    M_ROTATE_IMM PHASER_SPEED, sw_ang
    clc
    lda sw_vx
    adc M_XR
    sta sw_lvx
    lda sw_vx+1
    adc M_XR+1
    sta sw_lvx+1
    clc
    lda sw_vy
    adc M_YR
    sta sw_lvy
    lda sw_vy+1
    adc M_YR+1
    sta sw_lvy+1
    lda #SFX_PHASER
    jsr sound_play_ch0
.p1_ph_done
    rts

p1_fire_torpedo
    lda sw_cloak        ; Cooldown active?
    bne .p1_t_early
    lda sw_energy
    cmp #2              ; 2-energy reactor cost per Photon Torpedo
    bcc .p1_t_early
    ldx #0              ; Scan Player 1's 6 torpedo slots (0..5)
.p1_find_slot
    lda sw_tlife,x
    beq .p1_t_fire
    inx
    cpx #6
    bcc .p1_find_slot
.p1_t_early
    rts
.p1_t_fire
    lda #14             ; 14-frame cooldown between torpedo launches
    sta sw_cloak
    lda #TORP_LIFE      ; 180 frames (3.0 sec) flight life
    sta sw_tlife,x
    lda #0
    sta sw_towner,x
    lda sw_energy
    sec
    sbc #2
    sta sw_energy
    txa
    asl
    tay
    M_ROTATE_IMM TORP_SPEED, sw_ang
    clc
    lda sw_px
    adc M_XR
    sta sw_tx,y
    lda sw_px+1
    adc M_XR+1
    sta sw_tx+1,y
    clc
    lda sw_py
    adc M_YR
    sta sw_ty,y
    lda sw_py+1
    adc M_YR+1
    sta sw_ty+1,y
    clc
    lda sw_vx
    adc M_XR
    sta sw_tvx,y
    lda sw_vx+1
    adc M_XR+1
    sta sw_tvx+1,y
    clc
    lda sw_vy
    adc M_YR
    sta sw_tvy,y
    lda sw_vy+1
    adc M_YR+1
    sta sw_tvy+1,y
    lda #SFX_TORPEDO
    jsr sound_play_ch0
.p1_t_done
    rts

p2_fire_phaser
    lda sw_cloak+1
    bne .p2_ph_done
    lda sw_llife+1
    bne .p2_ph_done
    lda sw_energy+1
    cmp #6              ; Meaningful 6-energy reactor cost per Phaser burst
    bcc .p2_ph_done
    sec
    sbc #6
    sta sw_energy+1
    lda #16             ; 16-frame cooldown
    sta sw_cloak+1
    lda #14             ; 14-frame reach (~44 screen units = 30% of arena width)
    sta sw_llife+1
    lda sw_px+2
    sta sw_lx+2
    lda sw_px+3
    sta sw_lx+3
    lda sw_py+2
    sta sw_ly+2
    lda sw_py+3
    sta sw_ly+3
    M_ROTATE_IMM PHASER_SPEED, sw_ang+2
    clc
    lda sw_vx+2
    adc M_XR
    sta sw_lvx+2
    lda sw_vx+3
    adc M_XR+1
    sta sw_lvx+3
    clc
    lda sw_vy+2
    adc M_YR
    sta sw_lvy+2
    lda sw_vy+3
    adc M_YR+1
    sta sw_lvy+3
    lda #SFX_PHASER
    jsr sound_play_ch1
.p2_ph_done
    rts

p2_fire_torpedo
    lda sw_cloak+1
    bne .p2_t_early
    lda sw_energy+1
    cmp #2              ; 2-energy reactor cost per Photon Torpedo
    bcc .p2_t_early
    ldx #6              ; Scan Player 2's 6 torpedo slots (6..11)
.p2_find_slot
    lda sw_tlife,x
    beq .p2_t_fire
    inx
    cpx #12
    bcc .p2_find_slot
.p2_t_early
    rts
.p2_t_fire
    lda #14             ; 14-frame cooldown between torpedo launches
    sta sw_cloak+1
    lda #TORP_LIFE
    sta sw_tlife,x
    lda #1
    sta sw_towner,x
    lda sw_energy+1
    sec
    sbc #2
    sta sw_energy+1
    txa
    asl
    tay
    M_ROTATE_IMM TORP_SPEED, sw_ang+2
    clc
    lda sw_px+2
    adc M_XR
    sta sw_tx,y
    lda sw_px+3
    adc M_XR+1
    sta sw_tx+1,y
    clc
    lda sw_py+2
    adc M_YR
    sta sw_ty,y
    lda sw_py+3
    adc M_YR+1
    sta sw_ty+1,y
    clc
    lda sw_vx+2
    adc M_XR
    sta sw_tvx,y
    lda sw_vx+3
    adc M_XR+1
    sta sw_tvx+1,y
    clc
    lda sw_vy+2
    adc M_YR
    sta sw_tvy,y
    lda sw_vy+3
    adc M_YR+1
    sta sw_tvy+1,y
    lda #SFX_TORPEDO
    jsr sound_play_ch1
.p2_t_done
    rts

; =========================================================================
; Main 60Hz Physics Step
; =========================================================================
spacewar_step
    inc sw_frame
    lda #1
    sta M_SIGN

    jsr sound_update

    ; Decrement weapon fire cooldowns
    lda sw_cloak
    beq .nc0
    dec sw_cloak
.nc0
    lda sw_cloak+1
    beq .nc1
    dec sw_cloak+1
.nc1

    ; Regenerate reactor energy (+1 every 8 frames up to 99)
    lda sw_frame
    and #7
    bne .no_regen
    lda sw_energy
    cmp #99
    bcs .no_regen0
    inc sw_energy
.no_regen0
    lda sw_energy+1
    cmp #99
    bcs .no_regen
    inc sw_energy+1
.no_regen

    ; Update Ships
    ldx #0
    jsr update_ship
    ldx #1
    jsr update_ship

    ; Update Weapons & Explosions
    jsr update_torpedoes
    jsr update_phasers
    jsr update_explosions

    ; Check Collisions
    jsr check_collisions

    ; Compute screen coordinates and ASCII HUD digits
    jsr update_screen_coords

    ; Decay thrust plume indicators
    lda sw_thrust
    beq .nt0
    dec sw_thrust
.nt0
    lda sw_thrust+1
    beq .nt1
    dec sw_thrust+1
.nt1
    rts

; =========================================================================
; Update Ship X (0 or 1)
; =========================================================================
update_ship
    txa
    asl
    tay                 ; Y = word offset (0 or 2)

    lda sw_alive,x
    bne .ship_alive
    rts

.ship_alive
    ; Vector from ship to Central Sun: (SUN_X - px, SUN_Y - py)
    sec
    lda #<SUN_X
    sbc sw_px,y
    sta M_X
    lda #>SUN_X
    sbc sw_px+1,y
    sta M_X+1

    sec
    lda #<SUN_Y
    sbc sw_py,y
    sta M_Y
    lda #>SUN_Y
    sbc sw_py+1,y
    sta M_Y+1

    ; Read CORDIC Distance & Direction to Sun
    lda M_LEN
    sta sw_len
    lda M_LEN+1
    sta sw_len+1

    lda M_ANG
    sta sw_dir
    lda M_ANG+1
    sta sw_dir+1

    ; If sw_grav == 3 (No Planet & Zero-G), skip planet collision and gravity
    lda sw_grav
    cmp #3
    beq .skip_gravity

    ; Check collision with Central Planet
    lda sw_len+1
    cmp #SUN_RAD_HI
    bcs .not_in_sun
    jsr destroy_ship
    rts

.not_in_sun
    ; Check if Gravity is enabled (0 = Planet+Grav, 1 = Planet Only, 2 = Repulsor)
    lda sw_grav
    cmp #1
    beq .skip_gravity

    jsr calc_sun_grav_vec

    ; Add gravitational pull to ship velocity
    clc
    lda sw_vx,y
    adc M_XR
    sta sw_vx,y
    lda sw_vx+1,y
    adc M_XR+1
    sta sw_vx+1,y

    clc
    lda sw_vy,y
    adc M_YR
    sta sw_vy,y
    lda sw_vy+1,y
    adc M_YR+1
    sta sw_vy+1,y

.skip_gravity
    ; Clamp ship velocity so ships never fly uncontrollably fast
    jsr clamp_ship_vel

    ; Integrate velocity -> position
    clc
    lda sw_px,y
    adc sw_vx,y
    sta sw_px,y
    lda sw_px+1,y
    adc sw_vx+1,y
    sta sw_px+1,y

    clc
    lda sw_py,y
    adc sw_vy,y
    sta sw_py,y
    lda sw_py+1,y
    adc sw_vy+1,y
    sta sw_py+1,y

    ; Enforce Arena Boundaries (Wrap or Bounce)
    jsr handle_screen_boundary
    rts

; =========================================================================
; Shared Inverse-Square Gravity Routine: a = (K_GRAV / sw_len + 0.5) / sw_len
; Uses identical Newtonian constant ($08800000) for both Ships and Torpedoes!
; Input:  sw_len (distance to Sun), sw_dir (angle to Sun)
; Output: M_XR, M_YR = gravitational acceleration vector
; =========================================================================
calc_sun_grav_vec
    lda #0
    sta M_N
    sta M_N+1
    lda #$80
    sta M_N+2
    lda #$08
    sta M_N+3

    lda sw_len
    sta M_D
    lda sw_len+1
    sta M_D+1

    ; Add sw_len / 2 to first quotient so second divide rounds instead of truncating!
    lda sw_len+1
    lsr
    sta sw_tmp+3
    lda sw_len
    ror
    clc
    adc M_Q
    sta sw_tmp
    lda M_Q+1
    adc sw_tmp+3
    sta sw_tmp+1
    lda M_Q+2
    adc #0
    sta sw_tmp+2

    ; Load rounded first quotient into M_N for second divide by sw_len
    lda sw_tmp
    sta M_N
    lda sw_tmp+1
    sta M_N+1
    lda sw_tmp+2
    sta M_N+2
    lda #0
    sta M_N+3

    ; Read resulting acceleration magnitude |a| from M_Q
    lda M_Q
    sta sw_tmp
    lda M_Q+1
    sta sw_tmp+1

    ; Cap gravity acceleration at $0007 near the solar corona
    lda sw_tmp+1
    bne .clamp_grav
    lda sw_tmp
    cmp #$07
    bcc .grav_ok
.clamp_grav
    lda #$07
    sta sw_tmp
    lda #0
    sta sw_tmp+1
.grav_ok

    ; If Repulsor mode (sw_grav == 2), flip direction 180 degrees
    lda sw_grav
    cmp #2
    bne .do_grav_rot
    lda sw_dir+1
    eor #$80
    sta sw_dir+1

.do_grav_rot
    M_ROTATE_VAR sw_tmp, sw_dir
    rts

; =========================================================================
; Clamp Ship Velocity to [-$01C0, +$01C0]
; =========================================================================
clamp_ship_vel
    ; Check VX
    lda sw_vx+1,y
    bmi .vx_neg
    cmp #MAX_VEL_HI
    bcc .vy_check
    bne .clamp_vx_pos
    lda sw_vx,y
    cmp #MAX_VEL_LO
    bcc .vy_check
.clamp_vx_pos
    lda #MAX_VEL_LO
    sta sw_vx,y
    lda #MAX_VEL_HI
    sta sw_vx+1,y
    jmp .vy_check

.vx_neg
    cmp #$FE            ; -$01C0 has high byte $FE, low byte $40
    bcc .clamp_vx_neg
    bne .vy_check
    lda sw_vx,y
    cmp #$40
    bcs .vy_check
.clamp_vx_neg
    lda #$40
    sta sw_vx,y
    lda #$FE
    sta sw_vx+1,y

.vy_check
    ; Check VY
    lda sw_vy+1,y
    bmi .vy_neg
    cmp #MAX_VEL_HI
    bcc .vel_done
    bne .clamp_vy_pos
    lda sw_vy,y
    cmp #MAX_VEL_LO
    bcc .vel_done
.clamp_vy_pos
    lda #MAX_VEL_LO
    sta sw_vy,y
    lda #MAX_VEL_HI
    sta sw_vy+1,y
    rts

.vy_neg
    cmp #$FE
    bcc .clamp_vy_neg
    bne .vel_done
    lda sw_vy,y
    cmp #$40
    bcs .vel_done
.clamp_vy_neg
    lda #$40
    sta sw_vy,y
    lda #$FE
    sta sw_vy+1,y
.vel_done
    rts

; =========================================================================
; Arena Boundary Handler: Wrap (sw_wrap=0) or Bounce (sw_wrap=1)
; =========================================================================
handle_screen_boundary
    ; Check X < X_MIN_HI
    lda sw_px+1,y
    cmp #X_MIN_HI
    bcs .check_xmax
    lda sw_wrap
    bne .bounce_x_left
    lda #X_MAX_HI-1
    sta sw_px+1,y
    jmp .check_y
.bounce_x_left
    lda #X_MIN_HI
    sta sw_px+1,y
    jmp .negate_vx

.check_xmax
    cmp #X_MAX_HI
    bcc .check_y
    lda sw_wrap
    bne .bounce_x_right
    lda #X_MIN_HI+1
    sta sw_px+1,y
    jmp .check_y
.bounce_x_right
    lda #X_MAX_HI-1
    sta sw_px+1,y
.negate_vx
    sec
    lda #0
    sbc sw_vx,y
    sta sw_vx,y
    lda #0
    sbc sw_vx+1,y
    sta sw_vx+1,y

.check_y
    ; Check Y < Y_MIN_HI
    lda sw_py+1,y
    cmp #Y_MIN_HI
    bcs .check_ymax
    lda sw_wrap
    bne .bounce_y_top
    lda #Y_MAX_HI-1
    sta sw_py+1,y
    rts
.bounce_y_top
    lda #Y_MIN_HI
    sta sw_py+1,y
    jmp .negate_vy

.check_ymax
    cmp #Y_MAX_HI
    bcc .bounds_done
    lda sw_wrap
    bne .bounce_y_bot
    lda #Y_MIN_HI+1
    sta sw_py+1,y
    rts
.bounce_y_bot
    lda #Y_MAX_HI-1
    sta sw_py+1,y
.negate_vy
    sec
    lda #0
    sbc sw_vy,y
    sta sw_vy,y
    lda #0
    sbc sw_vy+1,y
    sta sw_vy+1,y
.bounds_done
    rts

; =========================================================================
; Update Active Photon Torpedoes (Slots 0..11)
; =========================================================================
update_torpedoes
    ldx #MAX_TORPS-1
.torp_loop
    lda sw_tlife,x
    bne .torp_is_alive
    jmp .next_torp
.torp_is_alive
    dec sw_tlife,x

    txa
    asl
    tay

    ; If sw_grav == 3 (No Planet & Zero-G), skip planet collision and gravity
    lda sw_grav
    cmp #3
    beq .move_torp

    ; Compute vector from torpedo to Central Planet (for collision & gravity)
    sec
    lda #<SUN_X
    sbc sw_tx,y
    sta M_X
    lda #>SUN_X
    sbc sw_tx+1,y
    sta M_X+1

    sec
    lda #<SUN_Y
    sbc sw_ty,y
    sta M_Y
    lda #>SUN_Y
    sbc sw_ty+1,y
    sta M_Y+1

    lda M_LEN
    sta sw_len
    lda M_LEN+1
    sta sw_len+1
    cmp #SUN_RAD_HI
    bcs .torp_not_in_sun
    jmp .kill_torp
.torp_not_in_sun

    ; Apply Planet gravity to torpedo trajectory (unless Planet-Only Zero-G)
    lda sw_grav
    cmp #1
    beq .move_torp

    lda M_ANG
    sta sw_dir
    lda M_ANG+1
    sta sw_dir+1

    jsr calc_sun_grav_vec

    clc
    lda sw_tvx,y
    adc M_XR
    sta sw_tvx,y
    lda sw_tvx+1,y
    adc M_XR+1
    sta sw_tvx+1,y

    clc
    lda sw_tvy,y
    adc M_YR
    sta sw_tvy,y
    lda sw_tvy+1,y
    adc M_YR+1
    sta sw_tvy+1,y

.move_torp
    ; Move torpedo
    clc
    lda sw_tx,y
    adc sw_tvx,y
    sta sw_tx,y
    lda sw_tx+1,y
    adc sw_tvx+1,y
    sta sw_tx+1,y

    clc
    lda sw_ty,y
    adc sw_tvy,y
    sta sw_ty,y
    lda sw_ty+1,y
    adc sw_tvy+1,y
    sta sw_ty+1,y

    ; Wrap or expire at arena boundaries
    lda sw_tx+1,y
    cmp #X_MIN_HI
    bcc .torp_x_low
    cmp #X_MAX_HI
    bcc .torp_check_y
    lda sw_wrap
    bne .kill_torp
    lda #X_MIN_HI+1
    sta sw_tx+1,y
    jmp .torp_check_y
.torp_x_low
    lda sw_wrap
    bne .kill_torp
    lda #X_MAX_HI-1
    sta sw_tx+1,y

.torp_check_y
    lda sw_ty+1,y
    cmp #Y_MIN_HI
    bcc .torp_y_low
    cmp #Y_MAX_HI
    bcc .next_torp
    lda sw_wrap
    bne .kill_torp
    lda #Y_MIN_HI+1
    sta sw_ty+1,y
    jmp .next_torp
.torp_y_low
    lda sw_wrap
    bne .kill_torp
    lda #Y_MAX_HI-1
    sta sw_ty+1,y
    jmp .next_torp

.kill_torp
    lda #0
    sta sw_tlife,x
.next_torp
    dex
    bmi .torp_done
    jmp .torp_loop
.torp_done
    rts

; =========================================================================
; Update Active Phaser Bolts
; =========================================================================
update_phasers
    ldx #1
.phas_loop
    lda sw_llife,x
    beq .next_phas
    dec sw_llife,x

    txa
    asl
    tay

    clc
    lda sw_lx,y
    adc sw_lvx,y
    sta sw_lx,y
    lda sw_lx+1,y
    adc sw_lvx+1,y
    sta sw_lx+1,y

    clc
    lda sw_ly,y
    adc sw_lvy,y
    sta sw_ly,y
    lda sw_ly+1,y
    adc sw_lvy+1,y
    sta sw_ly+1,y

    ; Kill phaser if out of bounds
    lda sw_lx+1,y
    cmp #X_MIN_HI
    bcc .kill_phas
    cmp #X_MAX_HI
    bcs .kill_phas
    lda sw_ly+1,y
    cmp #Y_MIN_HI
    bcc .kill_phas
    cmp #Y_MAX_HI
    bcc .next_phas
.kill_phas
    lda #0
    sta sw_llife,x
.next_phas
    dex
    bpl .phas_loop
    rts

; =========================================================================
; Update Active Explosions
; =========================================================================
update_explosions
    ldx #1
.exp_loop
    lda sw_etimer,x
    beq .next_exp
    dec sw_etimer,x
    lda sw_etimer,x
    lsr
    lsr
    and #3
    eor #3
    sta sw_eframe,x
.next_exp
    dex
    bpl .exp_loop
    rts

; =========================================================================
; Check Collisions: Torpedoes, Phasers & Ship-to-Ship
; =========================================================================
check_collisions
    ; 1. Torpedo vs Ships (Slots 0..11 against both Ship 0 and Ship 1)
    ldx #MAX_TORPS-1
.torp_col_loop
    lda sw_tlife,x
    bne .torp_col_active
    jmp .next_torp_col
.torp_col_active

    txa
    asl
    sta sw_tmp          ; sw_tmp = 2 * X (torpedo word offset)

    ; Check torpedo collision against BOTH ships (0 and 1), including own ship!
    stx sw_tmp+1        ; Save torpedo loop index X (0..11)
    lda #1
    sta sw_tmp+3        ; sw_tmp+3 = ship index being tested (1 down to 0)

.torp_ship_loop
    ldy sw_tmp+3
    lda sw_alive,y
    beq .next_torp_ship

    ; If testing against the torpedo's owner, allow 15 frames of launch clearance
    tya
    cmp sw_towner,x
    bne .check_torp_dist
    lda sw_tlife,x
    cmp #TORP_ARM_LIFE
    bcs .next_torp_ship

.check_torp_dist
    tya
    asl
    tay                 ; Y = ship word offset (0 or 2)
    ldx sw_tmp          ; X = torpedo word offset (0, 2, 4, 6)

    sec
    lda sw_tx,x
    sbc sw_px,y
    sta M_X
    lda sw_tx+1,x
    sbc sw_px+1,y
    sta M_X+1

    sec
    lda sw_ty,x
    sbc sw_py,y
    sta M_Y
    lda sw_ty+1,x
    sbc sw_py+1,y
    sta M_Y+1

    ldx sw_tmp+1        ; Restore torpedo loop index X (0..3)

    ; Hit if distance < 6 units ($0600)
    lda M_LEN+1
    cmp #6
    bcs .next_torp_ship

    ; Torpedo HIT Ship (sw_tmp+3)!
    lda #0
    sta sw_tlife,x
    ldx sw_tmp+3
    lda #35             ; Torpedo deals 35 shield damage
    jsr apply_damage
    ldx sw_tmp+1
    jmp .next_torp_col

.next_torp_ship
    dec sw_tmp+3
    bpl .torp_ship_loop

.next_torp_col
    dex
    bmi .torp_col_done
    jmp .torp_col_loop
.torp_col_done

    ; 2. Phaser vs Target Ship
    ldx #1
.phas_col_loop
    lda sw_llife,x
    beq .next_phas_col

    txa
    eor #1
    tay                 ; Target ship index (1 - X)
    lda sw_alive,y
    beq .next_phas_col

    stx sw_tmp+1        ; Save phaser index X (0 or 1)
    tya
    asl
    tay                 ; Y = target ship word offset (0 or 2)
    lda sw_tmp+1
    asl
    tax                 ; X = phaser word offset (0 or 2)

    sec
    lda sw_lx,x
    sbc sw_px,y
    sta M_X
    lda sw_lx+1,x
    sbc sw_px+1,y
    sta M_X+1

    sec
    lda sw_ly,x
    sbc sw_py,y
    sta M_Y
    lda sw_ly+1,x
    sbc sw_py+1,y
    sta M_Y+1

    ldx sw_tmp+1        ; Restore phaser index X (0 or 1)
    lda M_LEN+1
    cmp #6
    bcs .next_phas_col

    ; Phaser HIT!
    lda #0
    sta sw_llife,x
    txa
    eor #1
    tax
    lda #20             ; Phaser deals 20 shield damage
    jsr apply_damage
    ldx sw_tmp+1

.next_phas_col
    dex
    bpl .phas_col_loop
    rts

; Apply A damage to Ship X (0 or 1)
apply_damage
    sta sw_tmp+2
    lda sw_shield,x
    sec
    sbc sw_tmp+2
    bcc .ship_destroyed
    beq .ship_destroyed
    sta sw_shield,x
    lda #SFX_SHIELD_HIT
    cpx #0
    beq .sfx_p0
    jsr sound_play_ch1
    rts
.sfx_p0
    jsr sound_play_ch0
    rts

.ship_destroyed
    lda #0
    sta sw_shield,x
    jsr destroy_ship
    rts

; Destroy Ship X (0 or 1)
destroy_ship
    ; If round is already over (sw_state == 2), surviving winner is invulnerable
    lda sw_state
    cmp #2
    bne .do_destroy
    rts
.do_destroy
    lda #0
    sta sw_alive,x

    ; Spawn explosion at ship's screen position
    lda sw_sx,x
    sta sw_ex,x
    lda sw_sy,x
    sta sw_ey,x
    lda #16
    sta sw_etimer,x
    lda #0
    sta sw_eframe,x

    lda #SFX_EXPLOSION
    jsr sound_play_ch1

    ; Increment opponent's score
    txa
    eor #1
    tax
    inc sw_score,x

    ; Set Round Over state
    lda #2
    sta sw_state
    lda #90             ; 1.5 second pause before next round
    sta sw_timer
    rts

; =========================================================================
; Convert World Coordinates -> Screen Coordinates & ASCII HUD Digits
; =========================================================================
; Helper: Divide A (0..99) by 10 using MathUnit Divider -> M_Q=tens, M_R=ones
div10_ascii
    sta M_N
    lda #0
    sta M_N+1
    sta M_N+2
    sta M_N+3
    lda #10
    sta M_D
    lda #0
    sta M_D+1
    rts

update_screen_coords
    ; 1. Ships 0 and 1
    ldx #0
.ship_sc_loop
    txa
    asl
    tay
    sec
    lda sw_px+1,y
    sbc #4              ; Center 8-clock-wide sprite
    sta sw_sx,x
    sec
    lda sw_py+1,y
    sbc #4              ; Center 8-scanline-tall sprite
    sta sw_sy,x

    ; Compute exhaust flame position (4 units behind ship along sw_ang + 180 deg)
    lda #0
    sta M_X
    lda #4
    sta M_X+1
    lda #0
    sta M_Y
    sta M_Y+1
    lda sw_ang,y
    sta M_T
    lda sw_ang+1,y
    eor #$80
    sta M_T+1

    clc
    lda sw_px+1,y
    adc M_XR+1
    sec
    sbc #2
    sta sw_fpx,x

    clc
    lda sw_py+1,y
    adc M_YR+1
    sec
    sbc #4
    sta sw_fpy,x

    ; Rotation frame (0..15) with half-sector (+$0800) rounding
    clc
    lda sw_ang+1,y
    adc #$08
    lsr
    lsr
    lsr
    lsr
    sta sw_sframe,x

    inx
    cpx #2
    bcc .ship_sc_loop

    ; Format ASCII digits for P1 HUD
    lda sw_energy
    jsr div10_ascii
    lda M_Q
    ora #$30
    sta sw_e0_asc
    lda M_R
    ora #$30
    sta sw_e0_asc+1

    lda sw_shield
    jsr div10_ascii
    lda M_Q
    ora #$30
    sta sw_s0_asc
    lda M_R
    ora #$30
    sta sw_s0_asc+1

    lda sw_score
    jsr div10_ascii
    lda M_Q
    ora #$30
    sta sw_w0_asc
    lda M_R
    ora #$30
    sta sw_w0_asc+1

    ; Format ASCII digits for P2 HUD
    lda sw_energy+1
    jsr div10_ascii
    lda M_Q
    ora #$30
    sta sw_e1_asc
    lda M_R
    ora #$30
    sta sw_e1_asc+1

    lda sw_shield+1
    jsr div10_ascii
    lda M_Q
    ora #$30
    sta sw_s1_asc
    lda M_R
    ora #$30
    sta sw_s1_asc+1

    lda sw_score+1
    jsr div10_ascii
    lda M_Q
    ora #$30
    sta sw_w1_asc
    lda M_R
    ora #$30
    sta sw_w1_asc+1

    ; 2. Torpedoes 0..11
    ldx #0
.torp_sc_loop
    txa
    asl
    tay
    sec
    lda sw_tx+1,y
    sbc #2
    sta sw_tsx,x
    sec
    lda sw_ty+1,y
    sbc #4
    sta sw_tsy,x
    inx
    cpx #MAX_TORPS
    bcc .torp_sc_loop

    ; 3. Phasers 0..1
    ldx #0
.phas_sc_loop
    txa
    asl
    tay
    sec
    lda sw_lx+1,y
    sbc #2
    sta sw_lsx,x
    sec
    lda sw_ly+1,y
    sbc #4
    sta sw_lsy,x
    inx
    cpx #2
    bcc .phas_sc_loop

    rts
