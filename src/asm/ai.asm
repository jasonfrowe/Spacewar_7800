; Spacewar 7800 - Autopilot Computer AI Engine
; Controls Player 2 (Wedge Ship) in 1-Player Mode
; Leverages the MathUnit CORDIC block to navigate gravity and track Player 1

ai_step
    lda sw_mode
    cmp #1              ; 1 = 1-Player vs CPU
    beq .run_ai
    rts

.run_ai
    lda sw_alive+1
    bne .ai_active
    rts

.ai_active
    ; 1. Check distance to sun (Hazard Avoidance)
    sec
    lda #< SUN_X
    sbc sw_px+2
    sta M_X
    lda #> SUN_X
    sbc sw_px+3
    sta M_X+1

    sec
    lda #< SUN_Y
    sbc sw_py+2
    sta M_Y
    lda #> SUN_Y
    sbc sw_py+3
    sta M_Y+1

    lda M_LEN+1
    bne .ai_safe_dist   ; Far enough from sun
    lda M_LEN
    cmp #< (45 * 32)
    bcc .too_close_to_sun
.ai_safe_dist
    jmp .check_combat

.too_close_to_sun
    ; Too close to sun! Steer away from sun and thrust!
    lda M_ANG+1
    eor #$80            ; Opposite direction (away from sun)
    sta sw_tmp+1
    lda M_ANG
    sta sw_tmp

    ; Turn towards escape angle
    sec
    lda sw_tmp+1
    sbc sw_ang+3
    bpl .turn_cw_sun
    ; Turn CCW
    sec
    lda sw_ang+2
    sbc #< ROT_SPEED
    sta sw_ang+2
    lda sw_ang+3
    sbc #> ROT_SPEED
    sta sw_ang+3
    jmp .thrust_sun

.turn_cw_sun
    clc
    lda sw_ang+2
    adc #< ROT_SPEED
    sta sw_ang+2
    lda sw_ang+3
    adc #> ROT_SPEED
    sta sw_ang+3

.thrust_sun
    ; Thrust if energy available
    lda sw_energy+1
    cmp #10
    bcc .check_combat
    dec sw_energy+1
    lda #1
    sta sw_thrust+1
    
    ; Apply thrust vector
    M_ROTATE #< THRUST_ACC, sw_ang+2
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
    rts

.check_combat
    ; 2. Track Player 1 (Ship 0)
    sec
    lda sw_px
    sbc sw_px+2
    sta M_X
    lda sw_px+1
    sbc sw_px+3
    sta M_X+1

    sec
    lda sw_py
    sbc sw_py+2
    sta M_Y
    lda sw_py+1
    sbc sw_py+3
    sta M_Y+1

    lda M_ANG           ; Target angle to player
    sta sw_dir
    lda M_ANG+1
    sta sw_dir+1

    lda M_LEN           ; Distance to player
    sta sw_len
    lda M_LEN+1
    sta sw_len+1

    ; Turn towards player
    sec
    lda sw_dir+1
    sbc sw_ang+3
    cmp #$10            ; Within ~22 degrees?
    bcc .in_crosshairs
    cmp #$F0
    bcs .in_crosshairs

    bpl .turn_cw
    ; Turn CCW
    sec
    lda sw_ang+2
    sbc #< ROT_SPEED
    sta sw_ang+2
    lda sw_ang+3
    sbc #> ROT_SPEED
    sta sw_ang+3
    rts

.turn_cw
    clc
    lda sw_ang+2
    adc #< ROT_SPEED
    sta sw_ang+2
    lda sw_ang+3
    adc #> ROT_SPEED
    sta sw_ang+3
    rts

.in_crosshairs
    ; Player is in front! Decide firing action
    ; Torpedo check: if distance > 60 and energy > 35, fire torpedo!
    lda sw_len+1
    beq .close_range
    lda sw_energy+1
    cmp #35
    bcc .done_ai
    ; Fire torpedo!
    jsr ai_fire_torpedo
    rts

.close_range
    ; Phaser check: if energy > 15, fire phaser!
    lda sw_energy+1
    cmp #15
    bcc .done_ai
    jsr ai_fire_phaser

.done_ai
    rts

; AI Fires Torpedo
ai_fire_torpedo
    ; Find free torpedo slot (2 or 3)
    ldx #2
    lda sw_tlife+2
    beq .do_fire_torp
    ldx #3
    lda sw_tlife+3
    bne .torp_fail

.do_fire_torp
    lda #120            ; Lifetime
    sta sw_tlife,x
    lda #1              ; Owner = P2
    sta sw_towner,x

    lda sw_energy+1
    sec
    sbc #10
    sta sw_energy+1

    txa
    asl
    tay

    ; Spawn at P2 position
    lda sw_px+2
    sta sw_tx,y
    lda sw_px+3
    sta sw_tx+1,y
    lda sw_py+2
    sta sw_ty,y
    lda sw_py+3
    sta sw_ty+1,y

    ; Velocity = P2 velocity + launch vector
    M_ROTATE #< TORP_SPEED, sw_ang+2
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
.torp_fail
    rts

; AI Fires Phaser
ai_fire_phaser
    lda sw_llife+1
    bne .phas_fail      ; Slot already in use

    lda #20             ; 20 frames lifetime
    sta sw_llife+1
    lda sw_energy+1
    sec
    sbc #3
    sta sw_energy+1

    ; Slot 1 is offset 2
    lda sw_px+2
    sta sw_lx+2
    lda sw_px+3
    sta sw_lx+3
    lda sw_py+2
    sta sw_ly+2
    lda sw_py+3
    sta sw_ly+3

    M_ROTATE #< PHASER_SPEED, sw_ang+2
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
.phas_fail
    rts
