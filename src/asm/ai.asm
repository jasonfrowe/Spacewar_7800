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
    ; If sw_grav == 3 (No Planet & Zero-G), skip planet evasion completely!
    lda sw_grav
    cmp #3
    bne .do_planet_avoid
    jmp .check_combat
.do_planet_avoid
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
    ; 2. Look-Ahead Trajectory Prediction (Position 32 frames in future)
    ;    P_pred = P + 32 * V (computed via AstroCart Hardware Multiplier)
    ; =====================================================================
    lda sw_vx+2
    sta M_A
    lda sw_vx+3
    sta M_A+1
    lda #32
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
    lda #32
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

    ; Check if either current distance < 22 OR predicted future distance < 20
    lda sw_dx+1
    cmp #22
    bcc .evade_sun
    lda M_LEN+1
    cmp #20
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

    ; If speed < $0060 (0.375 units/frame), boost tangentially to maintain orbit!
    lda M_LEN+1
    bne .jmp_combat
    lda M_LEN
    cmp #$60
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

    ; Compute relative velocity (V_p1 - V_ai) * 18 for lead-target aiming
    sec
    lda sw_vx
    sbc sw_vx+2
    sta M_A
    lda sw_vx+1
    sbc sw_vx+3
    sta M_A+1
    lda #18
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
    lda #18
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

    ; Check if the Planet is directly blocking the line of sight to Player 1
    ; (Skip if sw_grav == 3, No Planet mode)
    lda sw_grav
    cmp #3
    beq .line_of_sight_clear

    sec
    lda sw_dir+1
    sbc sw_dx
    cmp #$0C
    bcc .flank_around_sun
    cmp #$F4
    bcc .line_of_sight_clear

.flank_around_sun
    ; Sun is directly between AI and Player 1!
    ; Aim offset by +$1C (39 deg) from the Sun to sling-shot curved Photon Torpedoes
    ; around the Sun's gravity well AND thrust tangentially to break orbital symmetry!
    lda sw_dx
    clc
    adc #$28
    sta sw_dir+1
    sec
    lda sw_dir+1
    sbc sw_ang+3
    cmp #$0C
    bcc .flank_aligned
    cmp #$F4
    bcs .flank_aligned
    bmi .flank_left
    jsr p2_turn_right
    rts
.flank_left
    jsr p2_turn_left
    rts
.flank_aligned
    ; Fire curved orbital torpedo around the Sun and thrust to flank!
    lda sw_energy+1
    cmp #35
    bcc .flank_done
    jsr p2_fire_torpedo
    lda sw_frame
    and #3
    bne .flank_done
    jsr p2_thrust
.flank_done
    rts

.line_of_sight_clear
    ; Turn toward Lead Intercept Angle
    sec
    lda sw_dir+1
    sbc sw_ang+3
    cmp #$0B            ; Within ~15 degrees of lead angle?
    bcc .in_sights
    cmp #$F5
    bcs .in_sights

    bmi .aim_left
    jsr p2_turn_right
    jmp .check_wide_fire
.aim_left
    jsr p2_turn_left

.check_wide_fire
    ; Even while turning, if within ~22 degrees ($10), fire weapon!
    sec
    lda sw_dir+1
    sbc sw_ang+3
    cmp #$10
    bcc .fire_weapons
    cmp #$F0
    bcs .fire_weapons
    rts

.in_sights
    ; Pursue Player 1 if far (> 58 units), energy >= 45, AND path doesn't cross Sun!
    lda sw_len+1
    cmp #58
    bcc .fire_weapons
    lda sw_frame
    and #3
    bne .fire_weapons
    lda sw_energy+1
    cmp #45
    bcc .fire_weapons

    ; Ensure heading is at least 60 degrees ($2A) away from Sun direction sw_dx
    sec
    lda sw_ang+3
    sbc sw_dx
    cmp #$2A
    bcc .fire_weapons
    cmp #$D6
    bcs .fire_weapons
    jsr p2_thrust

.fire_weapons
    ; Always keep 24 energy in reserve for orbital thrusters
    lda sw_energy+1
    cmp #24
    bcc .combat_done

    ; Space AI shots slightly (every 4 frames when ready) so 6-torpedo salvos spread out
    lda sw_frame
    and #3
    bne .combat_done

    ; Primary AI weapon: Photon Torpedoes (Slots 6..11)!
    ; If at close range (< 26 units), mix Phasers and Torpedoes
    lda sw_len+1
    cmp #26
    bcc .close_dogfight

    ; Medium/Long range (up to 135 units): Fire Photon Torpedoes!
    cmp #135
    bcs .combat_done
    jsr p2_fire_torpedo
    ; If all 6 AI torpedoes were already in flight (sw_cloak+1 still 0) and < 42 units, fire Phaser
    lda sw_cloak+1
    bne .combat_done
    lda sw_len+1
    cmp #42
    bcs .combat_done
    jmp p2_fire_phaser

.close_dogfight
    ; Close range: alternate between Photon Torpedoes and Phasers
    lda sw_frame
    and #8
    beq .ai_torp
    jmp p2_fire_phaser

.ai_torp
    jmp p2_fire_torpedo

.combat_done
    rts
