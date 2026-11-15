; Spacewar 7800 - Autopilot Computer AI Engine
; Controls Player 2 (Wedge Ship) in 1-Player Mode
; Uses the AstroCart MathUnit CORDIC block to navigate gravity and fight Player 1

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
    ; 1. Solar Hazard Avoidance: check distance from Ship 2 to Central Sun
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

    ; M_LEN+1 is distance to Sun in screen units
    lda M_LEN+1
    cmp #22             ; Within 22 units of Sun?
    bcs .check_combat

    ; Too close to Sun! Steer tangentially/away from Sun (M_ANG + 160 deg) and thrust
    lda M_ANG+1
    clc
    adc #$70
    sta sw_dir+1

    sec
    lda sw_dir+1
    sbc sw_ang+3
    bmi .sun_ccw
    jsr p2_turn_right
    jmp .sun_burn
.sun_ccw
    jsr p2_turn_left
.sun_burn
    ; Only thrust when pointed roughly away from the sun
    sec
    lda sw_dir+1
    sbc sw_ang+3
    cmp #$28
    bcc .do_sun_thrust
    cmp #$D8
    bcc .ai_done
.do_sun_thrust
    jsr p2_thrust
.ai_done
    rts

.check_combat
    ; If Player 1 is dead, just hold orbit
    lda sw_alive
    beq .ai_done

    ; 2. Compute vector from AI (Ship 2) to Player 1 (Ship 1)
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

    lda M_ANG+1
    sta sw_dir+1
    lda M_LEN+1
    sta sw_len+1

    ; Turn toward Player 1
    sec
    lda sw_dir+1
    sbc sw_ang+3
    cmp #$0C            ; Aimed within ~16 degrees?
    bcc .aimed_on_target
    cmp #$F4
    bcs .aimed_on_target

    bmi .combat_ccw
    jsr p2_turn_right
    rts
.combat_ccw
    jsr p2_turn_left
    rts

.aimed_on_target
    ; If far away (> 65 units) and plenty of energy, pulse thrusters gently
    lda sw_len+1
    cmp #65
    bcc .consider_firing
    lda sw_frame
    and #7
    bne .consider_firing
    lda sw_energy+1
    cmp #45
    bcc .consider_firing
    jsr p2_thrust

.consider_firing
    ; Don't spam every single frame; fire on a steady rhythm
    lda sw_frame
    and #15
    bne .combat_done
    lda sw_energy+1
    cmp #25
    bcc .combat_done

    ; Close range (< 32 units): fire rapid Phaser; Medium/Long range: fire Torpedo
    lda sw_len+1
    cmp #32
    bcc .use_phaser
    jsr p2_fire_torpedo
    rts
.use_phaser
    jsr p2_fire_phaser
.combat_done
    rts
