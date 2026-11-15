; Spacewar 7800 - Physics, MathUnit CORDIC Engine & Weapons Simulation
; Port of Bill Seiler's 1985 DOS Spacewar for Atari 7800 ProSystem
; Uses the AstroCart MathUnit ($0420-$043F) for:
;   - CORDIC Trig Vector Rotations (O_TURN)
;   - Angle & Distance to Sun / Opponent (ANG, LEN)
;   - Gravitational Inverse-Square Law (a = K / r^2) via Dual 32/16 Divides
;   - Hardware PRNG for Hyperspace Teleportation & AI jitter

; MathUnit Register Addresses
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
M_CTRL  = $043A
M_CMD   = $043B
M_P     = $0430
M_Q     = $0434
M_R     = $0438
M_S     = $043A
M_RND   = $043E

; Constants
SUN_X   = 160 * 32     ; Center X in 1/32 pixel units = 5120 ($1400)
SUN_Y   = 96 * 32      ; Center Y in 1/32 pixel units = 3072 ($0C00)
SUN_RAD = 10 * 32      ; Lethal sun radius = 320 ($0140)
K_GRAV  = $0A000000    ; Gravitational parameter K = GM * scaling

THRUST_ACC  = $0050    ; Acceleration per thrust tick
ROT_SPEED   = $0800    ; 1/16 turn per rotation tick (16 headings)
TORP_SPEED  = $0280    ; Torpedo launch speed
PHASER_SPEED= $0480    ; Phaser beam speed
TORP_MAX    = 4        ; Max active torpedoes
PHASER_MAX  = 2        ; Max active phasers

; Memory Layout ($2200 - $228F)
sw_px       = $2200     ; (4) Ship 0, 1 X pos (16-bit)
sw_py       = $2204     ; (4) Ship 0, 1 Y pos
sw_vx       = $2208     ; (4) Ship 0, 1 X vel
sw_vy       = $220C     ; (4) Ship 0, 1 Y vel
sw_ang      = $2210     ; (4) Ship 0, 1 Heading angle (16-bit)
sw_energy   = $2214     ; (2) Energy (0-100)
sw_shield   = $2216     ; (2) Shield (0-100)
sw_cloak    = $2218     ; (2) Cloak state (0=off, 1=active)
sw_alive    = $221A     ; (2) 1=alive, 0=destroyed
sw_thrust   = $221C     ; (2) 1=thrusting
sw_score    = $221E     ; (2) Match wins

sw_tx       = $2220     ; (8) Torpedo X pos
sw_ty       = $2228     ; (8) Torpedo Y pos
sw_tvx      = $2230     ; (8) Torpedo X vel
sw_tvy      = $2238     ; (8) Torpedo Y vel
sw_tlife    = $2240     ; (4) Torpedo lifetime (0=dead)
sw_towner   = $2244     ; (4) Torpedo owner (0 or 1)

sw_lx       = $2248     ; (4) Phaser X pos
sw_ly       = $224C     ; (4) Phaser Y pos
sw_lvx      = $2250     ; (4) Phaser X vel
sw_lvy      = $2254     ; (4) Phaser Y vel
sw_llife    = $2258     ; (2) Phaser lifetime (0=dead)

sw_ex       = $225A     ; (2) Explosion X (screen)
sw_ey       = $225C     ; (2) Explosion Y (screen)
sw_eframe   = $225E     ; (2) Explosion frame (0-3)
sw_etimer   = $2260     ; (2) Explosion timer

sw_sx       = $2262     ; (2) Ship X screen pixel
sw_sy       = $2264     ; (2) Ship Y screen pixel
sw_sframe   = $2266     ; (2) Ship rotation sprite index (0-15)

sw_mode     = $2268     ; 0 = 2P, 1 = 1P vs CPU
sw_grav     = $2269     ; 0 = Gravity ON, 1 = OFF, 2 = Repulsor
sw_wrap     = $226A     ; 0 = Wrap, 1 = Bounce
sw_state    = $226B     ; 0 = Menu, 1 = Playing, 2 = Round Over, 3 = Match Over
sw_winner   = $226C     ; 0 = P1, 1 = P2, $FF = tie
sw_timer    = $226D     ; State transition timer

sfx_ch0_id      = $2270
sfx_ch0_timer   = $2271
sfx_ch0_step    = $2272
sfx_ch1_id      = $2273
sfx_ch1_timer   = $2274
sfx_ch1_step    = $2275

sw_tmp      = $2276     ; (4) Temp storage
sw_dx       = $227A     ; (2)
sw_dy       = $227C     ; (2)
sw_len      = $227E     ; (2)
sw_dir      = $2280     ; (2)
sw_ax       = $2282     ; (2)
sw_ay       = $2284     ; (2)

; Macro: CORDIC Rotate (X, 0) by Angle T -> Result in XR, YR
    MAC M_ROTATE
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

; Initialize entire match
spacewar_init
    lda #0
    sta sw_score
    sta sw_score+1
    sta sw_mode         ; Default: 2-Player (or toggleable)
    sta sw_grav         ; Default: Gravity ON
    sta sw_wrap         ; Default: Toroidal Wrap
    sta sw_state
    sta sw_timer
    jsr sound_init
    jsr round_init
    rts

; Initialize a single combat round
round_init
    ; Player 0 (Needle): Starts on Left orbiting counter-clockwise
    lda #< (60 * 32)
    sta sw_px
    lda #> (60 * 32)
    sta sw_px+1
    lda #< (96 * 32)
    sta sw_py
    lda #> (96 * 32)
    sta sw_py+1
    lda #0
    sta sw_vx
    sta sw_vx+1
    lda #< ($0200)      ; Downward initial orbital velocity
    sta sw_vy
    lda #> ($0200)
    sta sw_vy+1
    lda #0              ; Facing South ($4000)
    sta sw_ang
    lda #$40
    sta sw_ang+1

    ; Player 1 (Wedge): Starts on Right orbiting counter-clockwise
    lda #< (260 * 32)
    sta sw_px+2
    lda #> (260 * 32)
    sta sw_px+3
    lda #< (96 * 32)
    sta sw_py+2
    lda #> (96 * 32)
    sta sw_py+3
    lda #0
    sta sw_vx+2
    sta sw_vx+3
    lda #< (-$0200)     ; Upward initial orbital velocity
    sta sw_vy+2
    lda #> (-$0200)
    sta sw_vy+3
    lda #0              ; Facing North ($C000)
    sta sw_ang+2
    lda #$C0
    sta sw_ang+3

    ; Set initial Energy & Shields (100)
    lda #100
    sta sw_energy
    sta sw_energy+1
    sta sw_shield
    sta sw_shield+1

    lda #1
    sta sw_alive
    sta sw_alive+1
    lda #0
    sta sw_cloak
    sta sw_cloak+1
    sta sw_thrust
    sta sw_thrust+1

    ; Clear weapons and explosions
    ldx #3
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

    rts

; Input helper routines
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
    cmp #2
    bcc .p1_th_skip
    dec sw_energy
    lda #1
    sta sw_thrust
    M_ROTATE #<THRUST_ACC, sw_ang
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
    cmp #2
    bcc .p2_th_skip
    dec sw_energy+1
    lda #1
    sta sw_thrust+1
    M_ROTATE #<THRUST_ACC, sw_ang+2
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
    lda #SFX_THRUST
    jsr sound_play_ch1
.p2_th_skip
    rts

p1_fire_phaser
    lda sw_llife
    bne .p1_ph_done
    lda #20
    sta sw_llife
    lda sw_energy
    sec
    sbc #3
    sta sw_energy
    lda sw_px
    sta sw_lx
    lda sw_px+1
    sta sw_lx+1
    lda sw_py
    sta sw_ly
    lda sw_py+1
    sta sw_ly+1
    M_ROTATE #<PHASER_SPEED, sw_ang
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
    ldx #0
    lda sw_tlife
    beq .p1_t_fire
    ldx #1
    lda sw_tlife+1
    bne .p1_t_done
.p1_t_fire
    lda #140
    sta sw_tlife,x
    lda #0
    sta sw_towner,x
    lda sw_energy
    sec
    sbc #10
    sta sw_energy
    txa
    asl
    tay
    lda sw_px
    sta sw_tx,y
    lda sw_px+1
    sta sw_tx+1,y
    lda sw_py
    sta sw_ty,y
    lda sw_py+1
    sta sw_ty+1,y
    M_ROTATE #<TORP_SPEED, sw_ang
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
    lda sw_llife+1
    bne .p2_ph_done
    lda #20
    sta sw_llife+1
    lda sw_energy+1
    sec
    sbc #3
    sta sw_energy+1
    lda sw_px+2
    sta sw_lx+2
    lda sw_px+3
    sta sw_lx+3
    lda sw_py+2
    sta sw_ly+2
    lda sw_py+3
    sta sw_ly+3
    M_ROTATE #<PHASER_SPEED, sw_ang+2
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
    ldx #2
    lda sw_tlife+2
    beq .p2_t_fire
    ldx #3
    lda sw_tlife+3
    bne .p2_t_done
.p2_t_fire
    lda #140
    sta sw_tlife,x
    lda #1
    sta sw_towner,x
    lda sw_energy+1
    sec
    sbc #10
    sta sw_energy+1
    txa
    asl
    tay
    lda sw_px+2
    sta sw_tx,y
    lda sw_px+3
    sta sw_tx+1,y
    lda sw_py+2
    sta sw_ty,y
    lda sw_py+3
    sta sw_ty+1,y
    M_ROTATE #<TORP_SPEED, sw_ang+2
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

; Main physics and gameplay update step (runs 60 times/sec)
spacewar_step
    jsr sound_update

    ; Energy slow regeneration
    lda sw_energy
    cmp #100
    bcs .no_regen0
    inc sw_energy
.no_regen0
    lda sw_energy+1
    cmp #100
    bcs .no_regen1
    inc sw_energy+1
.no_regen1

    ; Reset thrust indicators
    lda #0
    sta sw_thrust
    sta sw_thrust+1

    ; Update Ships
    ldx #0
    jsr update_ship
    ldx #1
    jsr update_ship

    ; Update Weapons
    jsr update_torpedoes
    jsr update_phasers
    jsr update_explosions

    ; Check collisions
    jsr check_collisions

    ; Update screen coordinates for display lists
    jsr update_screen_coords
    rts

; Update ship (X = 0 for Player 1, X = 1 for Player 2)
update_ship
    txa
    asl
    tay                 ; Y = ship word offset (0 or 2)

    lda sw_alive,x
    bne .ship_is_alive
    rts

.ship_is_alive
    ; Apply Gravity from Central Sun (if Gravity ON)
    lda sw_grav
    cmp #1              ; 1 = Gravity OFF
    bne .do_gravity
    jmp .skip_gravity
.do_gravity

    ; Vector from ship to sun
    sec
    lda #< SUN_X
    sbc sw_px,y
    sta sw_dx
    lda #> SUN_X
    sbc sw_px+1,y
    sta sw_dx+1

    sec
    lda #< SUN_Y
    sbc sw_py,y
    sta sw_dy
    lda #> SUN_Y
    sbc sw_py+1,y
    sta sw_dy+1

    ; Feed CORDIC
    lda sw_dx
    sta M_X
    lda sw_dx+1
    sta M_X+1
    lda sw_dy
    sta M_Y
    lda sw_dy+1
    sta M_Y+1

    ; Distance and angle to sun
    lda M_LEN
    sta sw_len
    lda M_LEN+1
    sta sw_len+1

    lda M_ANG
    sta sw_dir
    lda M_ANG+1
    sta sw_dir+1

    ; Check crash into sun
    lda sw_len+1
    bne .grav_pull      ; > 256 subpixels away
    lda sw_len
    cmp #< SUN_RAD
    bcs .grav_pull
    ; Touched Sun! Destroy ship!
    jsr destroy_ship
    rts

.grav_pull
    ; Inverse-square gravity: a = K / LEN^2
    lda sw_len+1
    ora sw_len
    bne .len_nonzero
    jmp .skip_gravity
.len_nonzero
    ; MathUnit Divide 1: K / LEN
    lda #< K_GRAV
    sta M_N
    lda #> K_GRAV
    sta M_N+1
    lda #0
    sta M_N+2
    lda #$0A
    sta M_N+3

    lda sw_len
    sta M_D
    lda sw_len+1
    sta M_D+1

    ; MathUnit Divide 2: (K / LEN) / LEN
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

    ; Q is acceleration magnitude
    lda M_Q
    sta sw_tmp
    lda M_Q+1
    sta sw_tmp+1

    ; Rotate magnitude towards sun (sw_dir)
    ; If Repulsor (sw_grav == 2), reverse direction (+ half turn)
    lda sw_grav
    cmp #2
    bne .rot_grav
    lda sw_dir+1
    eor #$80
    sta sw_dir+1

.rot_grav
    M_ROTATE sw_tmp, sw_dir

    ; Add gravity acceleration to velocity
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
    ; Velocity integration -> Position
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

    ; Screen Wrap or Bounce
    jsr handle_screen_boundary
    rts

; Handles Toroidal Wrap or Elastic Bounce for Ship in Y
handle_screen_boundary
    ; X Boundary (0 to 320 * 32 = $2800)
    lda sw_px+1,y
    bpl .check_xmax
    ; Left edge wrap
    clc
    lda sw_px,y
    adc #< (320 * 32)
    sta sw_px,y
    lda sw_px+1,y
    adc #> (320 * 32)
    sta sw_px+1,y
    jmp .check_y

.check_xmax
    lda sw_px+1,y
    cmp #> (320 * 32)
    bcc .check_y
    bne .wrap_left
    lda sw_px,y
    cmp #< (320 * 32)
    bcc .check_y
.wrap_left
    sec
    lda sw_px,y
    sbc #< (320 * 32)
    sta sw_px,y
    lda sw_px+1,y
    sbc #> (320 * 32)
    sta sw_px+1,y

.check_y
    ; Y Boundary (0 to 192 * 32 = $1800)
    lda sw_py+1,y
    bpl .check_ymax
    clc
    lda sw_py,y
    adc #< (192 * 32)
    sta sw_py,y
    lda sw_py+1,y
    adc #> (192 * 32)
    sta sw_py+1,y
    rts

.check_ymax
    lda sw_py+1,y
    cmp #> (192 * 32)
    bcc .done_bounds
    bne .wrap_top
    lda sw_py,y
    cmp #< (192 * 32)
    bcc .done_bounds
.wrap_top
    sec
    lda sw_py,y
    sbc #< (192 * 32)
    sta sw_py,y
    lda sw_py+1,y
    sbc #> (192 * 32)
    sta sw_py+1,y

.done_bounds
    rts

; Update active photon torpedoes
update_torpedoes
    ldx #3
.torp_loop
    lda sw_tlife,x
    beq .next_torp
    dec sw_tlife,x

    txa
    asl
    tay

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

.next_torp
    dex
    bpl .torp_loop
    rts

; Update active phaser bolts
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

.next_phas
    dex
    bpl .phas_loop
    rts

; Update active explosions
update_explosions
    ldx #1
.exp_loop
    lda sw_etimer,x
    beq .next_exp
    dec sw_etimer,x
    lda sw_etimer,x
    lsr
    lsr
    eor #3
    sta sw_eframe,x
.next_exp
    dex
    bpl .exp_loop
    rts

; Collision checking: Torpedoes and Phasers against Ships
check_collisions
    ; Check Torpedoes against Ship 0 and Ship 1
    ldx #3
.torp_col_loop
    lda sw_tlife,x
    beq .next_torp_col

    ; Target is the opposite ship
    lda sw_towner,x
    eor #1
    tay                 ; Target ship index
    lda sw_alive,y
    beq .next_torp_col

    ; Check distance
    tya
    asl
    tay

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

    ; CORDIC Distance
    lda M_LEN+1
    bne .next_torp_col
    lda M_LEN
    cmp #< (10 * 32)
    bcs .next_torp_col

    ; HIT! Torpedo deals 40 damage
    lda #0
    sta sw_tlife,x
    
    lda sw_towner,x
    eor #1
    tax                 ; X = hit ship
    jsr hit_ship_torpedo

.next_torp_col
    dex
    bpl .torp_col_loop
    rts

hit_ship_torpedo
    lda sw_shield,x
    sec
    sbc #40
    bcc .ship_killed
    beq .ship_killed
    sta sw_shield,x
    lda #SFX_SHIELD_HIT
    cpx #0
    beq .hit_sfx0
    jsr sound_play_ch1
    rts
.hit_sfx0
    jsr sound_play_ch0
    rts

.ship_killed
    lda #0
    sta sw_shield,x
    jsr destroy_ship
    rts

; Destroys ship X (0 or 1)
destroy_ship
    lda #0
    sta sw_alive,x
    sta sw_cloak,x

    ; Trigger explosion
    lda sw_sx,x
    sta sw_ex,x
    lda sw_sy,x
    sta sw_ey,x
    lda #16
    sta sw_etimer,x
    lda #0
    sta sw_eframe,x

    ; Play explosion sound
    lda #SFX_EXPLOSION
    jsr sound_play_ch1

    ; Award score to opponent
    txa
    eor #1
    tax
    inc sw_score,x
    
    ; Set round over state
    lda #2
    sta sw_state
    lda #120            ; 2 seconds delay
    sta sw_timer
    rts

; Convert world subpixel coordinates to screen pixels for display lists
update_screen_coords
    ldx #0
.conv_ship
    txa
    asl
    tay

    ; X Screen = (sw_px >> 5)
    lda sw_px+1,y
    asl
    asl
    asl
    sta sw_tmp
    lda sw_px,y
    lsr
    lsr
    lsr
    lsr
    lsr
    ora sw_tmp
    sta sw_sx,x

    ; Y Screen = (sw_py >> 5)
    lda sw_py+1,y
    asl
    asl
    asl
    sta sw_tmp
    lda sw_py,y
    lsr
    lsr
    lsr
    lsr
    lsr
    ora sw_tmp
    sta sw_sy,x

    ; Rotation Frame Index: angle high nibble
    lda sw_ang+1,y
    lsr
    lsr
    lsr
    lsr
    sta sw_sframe,x

    inx
    cpx #2
    bcc .conv_ship
    rts
