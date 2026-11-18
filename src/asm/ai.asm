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
    ; 4. Active Combat: Speed Control, Salvo/Cut-Off Aiming & Smart Evasion
    ; =====================================================================
.check_combat
    lda sw_alive
    bne .p1_is_alive
    rts
.p1_is_alive

    ; Measure AI ship's current scalar speed & velocity angle via CORDIC:
    ;   sw_dy   = 0 if slow (< $0040), 1 if cruising ($0040..$0063), 2 if fast (>= $0064)
    ;   sw_dy+1 = velocity heading angle theta_v (M_ANG+1)
    lda sw_vx+2
    sta M_X
    lda sw_vx+3
    sta M_X+1
    lda sw_vy+2
    sta M_Y
    lda sw_vy+3
    sta M_Y+1
    lda M_ANG+1
    sta sw_dy+1
    lda #2
    sta sw_dy
    lda M_LEN+1
    bne .ai_speed_done
    lda M_LEN
    cmp #$64
    bcs .ai_speed_done
    dec sw_dy           ; sw_dy = 1 (cruise: $0040..$0063)
    cmp #$40
    bcs .ai_speed_done
    dec sw_dy           ; sw_dy = 0 (slow: < $0040)
.ai_speed_done

    ; Count AI's active torpedoes in flight (slots 6..11) -> sw_ai_tac
    ldy #0
    ldx #6
.cnt_ai_torps
    lda sw_tlife,x
    beq .cnt_next
    iny
.cnt_next
    inx
    cpx #12
    bcc .cnt_ai_torps
    sty sw_ai_tac       ; sw_ai_tac = ai_torps_active (0..6)

    ; Choose weapon & salvo lead time factor:
    ;   - Inside Phaser reach (< 42 units) with Phaser ready: 6-frame Phaser lead
    ;   - Wave 1 Salvo (ai_torps_active < 4): 16-frame direct intercept lead
    ;   - Wave 2 Cut-Off Salvo (ai_torps_active >= 4): 26-frame cut-off lead ahead of Player 1!
    ldy #16
    lda sw_ai_tac
    cmp #4
    bcc .check_phas_lead
    ldy #26             ; Wave 2 (shots 5 & 6): lead further ahead to cut Player 1 off!
.check_phas_lead
    lda sw_llife+1
    bne .use_lead_y
    lda sw_len+1
    cmp #42
    bcs .use_lead_y
    ldy #6              ; Fast 6-frame lead for high-speed Phaser!
.use_lead_y
    sty sw_tmp          ; sw_tmp = lead frames (6, 16, or 26)

    ; Compute relative velocity (V_p1 - V_ai) * lead_frames
    sec
    lda sw_vx
    sbc sw_vx+2
    sta M_A
    lda sw_vx+1
    sbc sw_vx+3
    sta M_A+1
    lda sw_tmp
    sta M_B
    lda #0
    sta M_B+1

    clc
    lda sw_px
    adc M_P
    sta sw_tmp+2
    lda sw_px+1
    adc M_P+1
    sta sw_tmp+3

    sec
    lda sw_vy
    sbc sw_vy+2
    sta M_A
    lda sw_vy+1
    sbc sw_vy+3
    sta M_A+1
    lda sw_tmp
    sta M_B
    lda #0
    sta M_B+1

    clc
    lda sw_py
    adc M_P
    sta sw_tmp
    lda sw_py+1
    adc M_P+1
    sta sw_tmp+1

    ; Vector from AI to Player 1's Lead Position
    sec
    lda sw_tmp+2
    sbc sw_px+2
    sta M_X
    lda sw_tmp+3
    sbc sw_px+3
    sta M_X+1

    ; If wrapping enabled (sw_wrap == 0), wrap only when > 96 units ($60) apart in X
    lda sw_wrap
    bne .no_wrap_x
    lda M_X+1
    bmi .wrap_x_neg
    cmp #96
    bcc .no_wrap_x
    sec
    lda M_X
    sbc #$00
    sta M_X
    lda M_X+1
    sbc #$90
    sta M_X+1
    jmp .no_wrap_x
.wrap_x_neg
    cmp #$A0
    bcs .no_wrap_x
    clc
    lda M_X
    adc #$00
    sta M_X
    lda M_X+1
    adc #$90
    sta M_X+1
.no_wrap_x

    sec
    lda sw_tmp
    sbc sw_py+2
    sta M_Y
    lda sw_tmp+1
    sbc sw_py+3
    sta M_Y+1

    ; If wrapping enabled (sw_wrap == 0), wrap only when > 110 units ($6E) apart in Y
    lda sw_wrap
    bne .no_wrap_y
    lda M_Y+1
    bmi .wrap_y_neg
    cmp #110
    bcc .no_wrap_y
    sec
    lda M_Y
    sbc #$00
    sta M_Y
    lda M_Y+1
    sbc #$A4
    sta M_Y+1
    jmp .no_wrap_y
.wrap_y_neg
    cmp #$92
    bcs .no_wrap_y
    clc
    lda M_Y
    adc #$00
    sta M_Y
    lda M_Y+1
    adc #$A4
    sta M_Y+1
.no_wrap_y

    lda M_ANG+1
    sta sw_dir+1
    lda M_LEN+1
    sta sw_len+1

    ; If firing Wave 2 Cut-Off Salvo (ai_torps_active >= 4) at medium range (>= 38 units),
    ; add a +/-11 deg ($08) cut-off bracket offset so shots spread across Player 1's escape path!
    lda sw_ai_tac
    cmp #4
    bcc .no_cutoff_bias
    lda sw_len+1
    cmp #38
    bcc .no_cutoff_bias
    lda sw_ai_tac
    and #1
    bne .cutoff_pos
    lda sw_dir+1
    sec
    sbc #$08
    sta sw_dir+1
    jmp .no_cutoff_bias
.cutoff_pos
    lda sw_dir+1
    clc
    adc #$08
    sta sw_dir+1
.no_cutoff_bias

    ; =====================================================================
    ; 5. Selective CORDIC CPA Torpedo Threat Evasion
    ;    Scans Player 1's 6 torpedoes (slots 0..5) within 28 units.
    ;    Only breaks off aiming at Player 1 when dodging is the right strategy:
    ;      - 2+ torpedoes are converging on the AI at once (salvo threat), OR
    ;      - AI shields <= 35 (next torpedo hit is lethal!), OR
    ;      - Point-blank impact imminent (< 14 units away).
    ; =====================================================================
    lda #28
    sta sw_tmp          ; sw_tmp = best_D (28 = scan radius)
    lda #0
    sta sw_ai_tmr       ; sw_ai_tmr = threat_count
    ldx #5              ; Only scan Player 1's torpedoes (slots 0..5)

.torp_scan_loop
    lda sw_tlife,x
    bne .torp_check_vec
    jmp .next_torp_scan

.torp_check_vec
    txa
    asl
    tay                 ; Y = torpedo word offset (0..10)

    sec
    lda sw_px+2
    sbc sw_tx,y
    sta M_X
    lda sw_px+3
    sbc sw_tx+1,y
    sta M_X+1

    lda sw_wrap
    bne .t_nowrap_x
    lda M_X+1
    bmi .t_wrap_xn
    cmp #72
    bcc .t_nowrap_x
    sbc #$90
    sta M_X+1
    jmp .t_nowrap_x
.t_wrap_xn
    cmp #$B8
    bcs .t_nowrap_x
    adc #$90
    sta M_X+1
.t_nowrap_x

    sec
    lda sw_py+2
    sbc sw_ty,y
    sta M_Y
    lda sw_py+3
    sbc sw_ty+1,y
    sta M_Y+1

    lda sw_wrap
    bne .t_nowrap_y
    lda M_Y+1
    bmi .t_wrap_yn
    cmp #82
    bcc .t_nowrap_y
    sbc #$A4
    sta M_Y+1
    jmp .t_nowrap_y
.t_wrap_yn
    cmp #$AE
    bcs .t_nowrap_y
    adc #$A4
    sta M_Y+1
.t_nowrap_y

    ; Read CORDIC #1: Distance D and angle from torpedo to AI
    lda M_LEN+1
    beq .next_torp_jmp
    cmp #28             ; Must be within 28 units to be an imminent threat
    bcc .torp_within_r
.next_torp_jmp
    jmp .next_torp_scan

.torp_within_r
    sta sw_tmp+2        ; sw_tmp+2 = D
    lda M_ANG+1
    sta sw_tmp+3        ; sw_tmp+3 = theta_to_AI

    ; CORDIC #2: Relative velocity V_rel = V_torp - V_ai
    sec
    lda sw_tvx,y
    sbc sw_vx+2
    sta M_X
    lda sw_tvx+1,y
    sbc sw_vx+3
    sta M_X+1

    sec
    lda sw_tvy,y
    sbc sw_vy+2
    sta M_Y
    lda sw_tvy+1,y
    sbc sw_vy+3
    sta M_Y+1

    lda M_LEN+1
    bne .t_rel_fast
    lda M_LEN
    cmp #$38            ; Ignore slow/non-closing torpedoes
    bcc .next_torp_scan
.t_rel_fast
    lda M_ANG+1
    sta sw_len          ; sw_len = theta_vel

    ; Angle error delta_theta = theta_vel - theta_to_AI
    sec
    sbc sw_tmp+3
    sta sw_dir          ; sw_dir = delta_theta
    bpl .t_dt_pos
    cmp #$D8            ; Within -39 deg (-$28 = $D8)?
    bcc .next_torp_scan
    bcs .t_calc_cpa
.t_dt_pos
    cmp #$28            ; Within +39 deg (+$28)?
    bcs .next_torp_scan

.t_calc_cpa
    ; CORDIC #3: Rotate (D * 256, 0) by (delta_theta * 256) -> M_YR+1 = D * sin(delta_theta)
    lda #0
    sta M_X
    sta M_Y
    sta M_Y+1
    sta M_T
    lda sw_tmp+2        ; D
    sta M_X+1
    lda sw_dir          ; delta_theta
    sta M_T+1

    lda M_YR+1
    bpl .t_cpa_abs
    eor #$FF
    clc
    adc #1
.t_cpa_abs
    cmp #10             ; Will torpedo pass within 10 units of AI center (hit radius = 6)?
    bcs .next_torp_scan

    ; Confirmed Collision Threat! Increment threat_count
    inc sw_ai_tmr
    lda sw_tmp+2
    cmp sw_tmp          ; Is this the closest threat so far?
    bcs .next_torp_scan
    sta sw_tmp          ; best_D = D

    lda sw_dir          ; delta_theta
    cmp #$04
    bcc .t_dodge_closest
    cmp #$FC
    bcs .t_dodge_closest
    bmi .t_dodge_cw     ; Passing on North/CCW side -> dodge CW (+$58)
.t_dodge_ccw
    lda sw_len          ; theta_vel
    sec
    sbc #$58
    sta sw_tmp+1
    jmp .next_torp_scan
.t_dodge_cw
    lda sw_len          ; theta_vel
    clc
    adc #$58
    sta sw_tmp+1
    jmp .next_torp_scan
.t_dodge_closest
    sec
    lda sw_ang+3
    sbc sw_len
    bmi .t_dodge_ccw
    bpl .t_dodge_cw

.next_torp_scan
    dex
    bmi .torp_scan_done
    jmp .torp_scan_loop
.torp_scan_done

    ; Decide whether dodging is the right tactical play:
    ;   1. threat_count == 0 -> Never dodge, aim at Player 1!
    ;   2. threat_count >= 2 -> Multiple torpedoes converging, DODGE!
    ;   3. sw_shield+1 <= 35 -> Next hit is lethal, DODGE!
    ;   4. best_D < 14       -> Point-blank impact imminent, DODGE!
    lda sw_ai_tmr
    beq .no_torp_threat
    cmp #2
    bcs .do_torp_dodge
    lda sw_shield+1
    cmp #36
    bcc .do_torp_dodge
    lda sw_tmp
    cmp #14
    bcs .no_torp_threat

.do_torp_dodge
    sec
    lda sw_tmp+1
    sbc sw_ang+3
    cmp #$08
    bcc .torp_dodge_burn
    cmp #$F8
    bcs .torp_dodge_burn
    bmi .torp_dodge_l
    jsr p2_turn_right
    jsr p2_turn_right
    jmp .torp_check_burn
.torp_dodge_l
    jsr p2_turn_left
    jsr p2_turn_left

.torp_check_burn
    sec
    lda sw_tmp+1
    sbc sw_ang+3
    cmp #$34
    bcc .torp_dodge_burn
    cmp #$CC
    bcc .torp_dodge_fire
.torp_dodge_burn
    ; Cap emergency dodge speed at $0078 (~0.47 px/frame)
    lda sw_vx+2
    sta M_X
    lda sw_vx+3
    sta M_X+1
    lda sw_vy+2
    sta M_Y
    lda sw_vy+3
    sta M_Y+1
    lda M_LEN+1
    bne .torp_dodge_fire
    lda M_LEN
    cmp #$78
    bcs .torp_dodge_fire
    jsr p2_thrust
.torp_dodge_fire
    jmp .check_wide_fire

.no_torp_threat
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
    ; Aim offset by +$28 from the Sun to sling-shot curved Photon Torpedoes
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
    ; Primary AI behavior: ALWAYS turn directly toward Player 1's intercept angle!
    sec
    lda sw_dir+1
    sbc sw_ang+3
    cmp #$08            ; Tightly aligned within ~11 degrees of lead angle?
    bcc .in_sights
    cmp #$F8
    bcs .in_sights

    bmi .aim_left
    jsr p2_turn_right
    jmp .turn_thrust_check
.aim_left
    jsr p2_turn_left

.turn_thrust_check
    ; In Zero-G modes, manage cruise speed & retrograde braking while rotating
    lda sw_grav
    and #1
    beq .check_wide_fire
    jsr ai_smart_thrust

.check_wide_fire
    ; While turning, only fire if within ~14 degrees ($0A) so shots don't spray wildly!
    sec
    lda sw_dir+1
    sbc sw_ang+3
    cmp #$0A
    bcc .jmp_fire_weapons
    cmp #$F6
    bcc .wide_no_fire
.jmp_fire_weapons
    jmp .fire_weapons
.wide_no_fire
    rts

.in_sights
    ; In Deep Space (sw_grav == 3) or Planet-Only (sw_grav == 1), AI actively manages range
    lda sw_grav
    and #1
    bne .deep_space_maneuver

    ; Standard Gravity mode: Pursue Player 1 if far (> 58 units) and path doesn't cross Sun
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
    jmp .fire_weapons

.deep_space_maneuver
    ; Deep Space / Zero-G Range & Speed Control:
    ;   - If outside Phaser range (>= 40 units) and speed < $0058, thrust toward Player 1 to close into Phaser range!
    ;   - Otherwise use CORDIC velocity-aware thrust controller (keeps drift $0040..$0063, retro-brakes if >= $0064).
    lda sw_len+1
    cmp #40
    bcc .ds_keep_cruise
    lda sw_dy
    cmp #2
    bcs .ds_keep_cruise
    lda sw_energy+1
    cmp #35
    bcc .fire_weapons
    lda sw_frame
    and #3
    bne .fire_weapons
    jsr p2_thrust
    jmp .fire_weapons

.ds_keep_cruise
    jsr ai_smart_thrust

.fire_weapons
    ; Always keep 24 energy in reserve for thrusters & shields
    lda sw_energy+1
    cmp #24
    bcc .combat_done

    ; 1. Inside Phaser reach (< 42 units):
    ;    Always use Phaser whenever ready (sw_llife+1 == 0)!
    lda sw_len+1
    cmp #42
    bcs .medium_range_salvo
    lda sw_llife+1
    bne .close_torp_followup
    jmp p2_fire_phaser

.close_torp_followup
    ; Inside 42 units while Phaser is in flight: fire Photon Torpedoes!
    jmp p2_fire_torpedo

.medium_range_salvo
    ; 2. Medium Range (42..88 units) Two-Stage "4-Shot Salvo + 2-Shot Cut-Off" Strategy:
    ;    - Do not waste torpedoes beyond 88 units!
    cmp #88
    bcs .combat_done

    ;    - Wave 1 (ai_torps_active < 4): Fire 4-torpedo opening salvo at direct lead (16 frames).
    ;      After launching the 4th torpedo, set a 28-frame tactical pause so the AI can
    ;      read Player 1's reaction and aim Wave 2 (shots 5 & 6) at the 26-frame Cut-Off angle!
    lda sw_ai_tac
    cmp #4
    bcc .launch_wave1

    ;    - Wave 2 (ai_torps_active == 4 or 5): Fire remaining 2 torpedoes at Cut-Off angle!
    jmp p2_fire_torpedo

.launch_wave1
    jsr p2_fire_torpedo
    ; If that launch just put our 4th torpedo in flight (sw_ai_tac was 3 and cooldown set to 14),
    ; extend cooldown to 28 frames to create a distinct 4-shot salvo + cut-off pause!
    lda sw_ai_tac
    cmp #3
    bne .combat_done
    lda sw_cloak+1
    cmp #14
    bne .combat_done
    lda #28
    sta sw_cloak+1

.combat_done
    rts

; =====================================================================
; Smart Zero-G Thrust Controller (uses CORDIC speed sw_dy & course sw_dy+1)
;   - sw_dy == 0 (speed < $0040): accelerate to minimum cruise speed
;   - sw_dy == 1 (cruise $0040..$0063): only burn laterally/retrograde (> 84 deg off velocity)
;   - sw_dy == 2 (fast >= $0064): only burn retrograde (> 118 deg off velocity) to brake!
; =====================================================================
ai_smart_thrust
    lda sw_energy+1
    cmp #25
    bcc .ast_done
    lda sw_dy
    beq .ast_burn
    cmp #1
    beq .ast_cruise
    ; sw_dy == 2 (fast >= $0064): retro-brake when pointed > 118 deg ($54) opposite to velocity
    sec
    lda sw_ang+3
    sbc sw_dy+1
    cmp #$54
    bcc .ast_done
    cmp #$AC
    bcs .ast_done
    jmp p2_thrust
.ast_cruise
    ; sw_dy == 1 (cruise): lateral/retro burn only (> 84 deg = $3C off velocity)
    lda sw_frame
    and #1
    bne .ast_done
    sec
    lda sw_ang+3
    sbc sw_dy+1
    cmp #$3C
    bcc .ast_done
    cmp #$C4
    bcs .ast_done
.ast_burn
    jmp p2_thrust
.ast_done
    rts

; 8 randomized initial drift directions for Zero-G / Deep Space rounds
ai_open_angles
    .byte $48, $B8, $5C, $A4, $34, $CC, $68, $98
