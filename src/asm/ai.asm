; Spacewar 7800 - Smart Autopilot Computer AI Engine
; Controls Player 2 (Wedge Ship) in 1-Player Mode
; Uses the AstroCart MathUnit Multiplier & CORDIC Engine for:
;   1. 40-frame look-ahead trajectory prediction to never crash into the Sun
;   2. Monotonic single-target escape vector (sun_ang + $78) that never oscillates
;   3. 14-frame relative velocity lead-target aiming against Player 1
;   4. Tactical torpedo/phaser selection & automatic shield recharging

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
    ; Automatic tactical shield recharge when energy is plentiful
    lda sw_frame
    and #3
    bne .check_sun_now
    lda sw_shield+1
    cmp #85
    bcs .check_sun_now
    lda sw_energy+1
    cmp #45
    bcc .check_sun_now
    dec sw_energy+1
    inc sw_shield+1

.check_sun_now
    ; =====================================================================
    ; 1. Current Vector & Distance from AI Ship to Central Sun
    ; =====================================================================
    sec
    lda #<SUN_X
    sbc sw_px+2
    sta M_X
    lda #>SUN_X
    sbc sw_px+3
    sta M_X+1

    sec
    lda #<SUN_Y
    sbc sw_py+2
    sta M_Y
    lda #>SUN_Y
    sbc sw_py+3
    sta M_Y+1

    lda M_ANG+1
    sta sw_dx           ; sw_dx = sun_ang (angle from AI toward Sun)
    lda M_LEN+1
    sta sw_dx+1         ; sw_dx+1 = current distance to Sun in screen units

    ; =====================================================================
    ; 2. Look-Ahead Trajectory Prediction (Position 40 frames in future)
    ;    P_pred = P + 40 * V (computed via AstroCart Hardware Multiplier)
    ; =====================================================================
    lda sw_vx+2
    sta M_A
    lda sw_vx+3
    sta M_A+1
    lda #40
    sta M_B
    lda #0
    sta M_B+1

    clc
    lda sw_px+2
    adc M_P
    sta sw_tmp
    lda sw_px+3
    adc M_P+1
    sta sw_tmp+1

    lda sw_vy+2
    sta M_A
    lda sw_vy+3
    sta M_A+1
    lda #40
    sta M_B
    lda #0
    sta M_B+1

    clc
    lda sw_py+2
    adc M_P
    sta sw_tmp+2
    lda sw_py+3
    adc M_P+1
    sta sw_tmp+3

    ; Feed predicted future vector to Sun into CORDIC
    sec
    lda #<SUN_X
    sbc sw_tmp
    sta M_X
    lda #>SUN_X
    sbc sw_tmp+1
    sta M_X+1

    sec
    lda #<SUN_Y
    sbc sw_tmp+2
    sta M_Y
    lda #>SUN_Y
    sbc sw_tmp+3
    sta M_Y+1

    ; Check if either current distance < 32 OR predicted future distance < 32
    lda sw_dx+1
    cmp #32
    bcc .evade_sun
    lda M_LEN+1
    cmp #32
    bcc .evade_sun

    ; =====================================================================
    ; 3. Check Orbital Speed (prevent stalling and falling into the star)
    ; =====================================================================
    lda sw_grav
    cmp #1              ; Gravity OFF? No stall hazard
    beq .jmp_combat

    lda sw_vx+2
    sta M_X
    lda sw_vx+3
    sta M_X+1
    lda sw_vy+2
    sta M_Y
    lda sw_vy+3
    sta M_Y+1

    ; If speed < $0088 (0.53 units/frame), boost tangentially to maintain orbit!
    lda M_LEN+1
    bne .jmp_combat
    lda M_LEN
    cmp #$88
    bcc .evade_sun
.jmp_combat
    jmp .check_combat

.evade_sun
    ; Single monotonic escape heading: sun_ang + $74 (163 deg away from Sun,
    ; angled with the CCW orbit so it never oscillates across the Sun vector!)
    lda sw_dx
    clc
    adc #$74
    sta sw_dir+1

    sec
    lda sw_dir+1
    sbc sw_ang+3
    cmp #$08
    bcc .burn_escape
    cmp #$F8
    bcs .burn_escape
    bmi .turn_esc_left
    jsr p2_turn_right
    jsr p2_turn_right   ; Rapid emergency rudder when evading Sun
    jmp .check_esc_burn
.turn_esc_left
    jsr p2_turn_left
    jsr p2_turn_left    ; Rapid emergency rudder when evading Sun

.check_esc_burn
    ; Thrust whenever pointed > 90 degrees away from Sun
    sec
    lda sw_ang+3
    sbc sw_dx
    cmp #$40            ; >= +90 deg?
    bcc .no_esc_burn
    cmp #$C0            ; <= -90 deg?
    bcs .no_esc_burn
.burn_escape
    jsr p2_thrust
.no_esc_burn
    rts

    ; =====================================================================
    ; 4. Active Combat: Lead-Target Prediction against Player 1
    ; =====================================================================
.check_combat
    lda sw_alive
    bne .p1_is_alive
    rts
.p1_is_alive

    ; Compute relative velocity (V_p1 - V_ai) * 14 for lead-target aiming
    sec
    lda sw_vx
    sbc sw_vx+2
    sta M_A
    lda sw_vx+1
    sbc sw_vx+3
    sta M_A+1
    lda #14
    sta M_B
    lda #0
    sta M_B+1

    clc
    lda sw_px
    adc M_P
    sta sw_tmp
    lda sw_px+1
    adc M_P+1
    sta sw_tmp+1

    sec
    lda sw_vy
    sbc sw_vy+2
    sta M_A
    lda sw_vy+1
    sbc sw_vy+3
    sta M_A+1
    lda #14
    sta M_B
    lda #0
    sta M_B+1

    clc
    lda sw_py
    adc M_P
    sta sw_tmp+2
    lda sw_py+1
    adc M_P+1
    sta sw_tmp+3

    ; Vector from AI to Player 1's Lead Position
    sec
    lda sw_tmp
    sbc sw_px+2
    sta M_X
    lda sw_tmp+1
    sbc sw_px+3
    sta M_X+1

    sec
    lda sw_tmp+2
    sbc sw_py+2
    sta M_Y
    lda sw_tmp+3
    sbc sw_py+3
    sta M_Y+1

    lda M_ANG+1
    sta sw_dir+1
    lda M_LEN+1
    sta sw_len+1

    ; Check if the Sun is blocking the line of sight to Player 1
    ; (|lead_angle - sun_ang| < $24, i.e. within +/- 50 degrees of the Sun)
    sec
    lda sw_dir+1
    sbc sw_dx
    cmp #$24
    bcc .flank_around_sun
    cmp #$DC
    bcc .line_of_sight_clear

.flank_around_sun
    ; Sun is between AI and Player 1! Steer tangentially around the Sun
    ; (sun_ang + $58) to flank Player 1 and keep nose pointed away from Sun!
    lda sw_dx
    clc
    adc #$58
    sta sw_dir+1
    sec
    lda sw_dir+1
    sbc sw_ang+3
    bmi .flank_left
    jsr p2_turn_right
    rts
.flank_left
    jsr p2_turn_left
    rts

.line_of_sight_clear
    ; Turn toward Lead Intercept Angle
    sec
    lda sw_dir+1
    sbc sw_ang+3
    cmp #$0A            ; Within ~14 degrees of lead angle?
    bcc .in_sights
    cmp #$F6
    bcs .in_sights

    bmi .aim_left
    jsr p2_turn_right
    jmp .check_wide_fire
.aim_left
    jsr p2_turn_left

.check_wide_fire
    ; Even while turning, if within ~25 degrees and close, snap-fire phaser!
    sec
    lda sw_dir+1
    sbc sw_ang+3
    cmp #$12
    bcc .try_snap_shot
    cmp #$EE
    bcc .combat_done
.try_snap_shot
    lda sw_len+1
    cmp #36
    bcs .combat_done
    lda sw_energy+1
    cmp #30             ; Always keep 30 energy in reserve for orbital thrusters
    bcc .combat_done
    jsr p2_fire_phaser
    rts

.in_sights
    ; Pursue Player 1 if far (> 55 units), energy >= 45, AND path doesn't cross Sun!
    lda sw_len+1
    cmp #55
    bcc .fire_weapons
    lda sw_frame
    and #3
    bne .fire_weapons
    lda sw_energy+1
    cmp #45
    bcc .fire_weapons

    ; Ensure heading is at least 65 degrees ($2E) away from Sun direction sw_dx
    sec
    lda sw_ang+3
    sbc sw_dx
    cmp #$2E
    bcc .fire_weapons
    cmp #$D2
    bcs .fire_weapons
    jsr p2_thrust

.fire_weapons
    ; Fire every 8 frames when lined up and energy >= 30
    lda sw_frame
    and #7
    bne .combat_done
    lda sw_energy+1
    cmp #30
    bcc .combat_done

    ; Close range (< 34 units): rapid Phaser; Medium/Long range (< 95 units): Photon Torpedo
    lda sw_len+1
    cmp #34
    bcc .ai_phaser
    cmp #95
    bcs .combat_done
    jsr p2_fire_torpedo
    rts
.ai_phaser
    jsr p2_fire_phaser
.combat_done
    rts
