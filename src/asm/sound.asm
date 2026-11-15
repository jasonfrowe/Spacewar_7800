; Spacewar 7800 - TIA Sound Effects Engine
; Channel 0: Player 1 (Thrust rumble, Phaser zap, Warp tone)
; Channel 1: Player 2 / World (Thrust rumble, Torpedo launch, Explosion)

AUDC0   = $15
AUDC1   = $16
AUDF0   = $17
AUDF1   = $18
AUDV0   = $19
AUDV1   = $1A

; Sound effect IDs
SFX_NONE        = 0
SFX_THRUST      = 1
SFX_PHASER      = 2
SFX_TORPEDO     = 3
SFX_EXPLOSION   = 4
SFX_WARP        = 5
SFX_SHIELD_HIT  = 6

sound_init
    lda #0
    sta AUDV0
    sta AUDV1
    sta sfx_ch0_id
    sta sfx_ch1_id
    sta sfx_ch0_timer
    sta sfx_ch1_timer
    rts

; Trigger sound on Channel 0 (Player 1)
; A = SFX ID
sound_play_ch0
    sta sfx_ch0_id
    lda #0
    sta sfx_ch0_step
    lda #15
    sta sfx_ch0_timer
    rts

; Trigger sound on Channel 1 (Player 2 / Global)
; A = SFX ID
sound_play_ch1
    sta sfx_ch1_id
    lda #0
    sta sfx_ch1_step
    lda #20
    sta sfx_ch1_timer
    rts

sound_update
    ; --- Channel 0 Update ---
    lda sfx_ch0_timer
    beq .mute_ch0
    dec sfx_ch0_timer
    inc sfx_ch0_step
    
    lda sfx_ch0_id
    cmp #SFX_THRUST
    beq .sfx0_thrust
    cmp #SFX_PHASER
    beq .sfx0_phaser
    cmp #SFX_WARP
    beq .sfx0_warp
    cmp #SFX_SHIELD_HIT
    beq .sfx0_hit
    jmp .mute_ch0

.sfx0_thrust
    lda #$08            ; White noise
    sta AUDC0
    lda #$1E            ; Low frequency rumble
    sta AUDF0
    lda #$05            ; Low volume
    sta AUDV0
    jmp .do_ch1

.sfx0_phaser
    lda #$04            ; Pure tone
    sta AUDC0
    lda sfx_ch0_step
    asl
    clc
    adc #$02            ; Fast rising/falling chirp
    sta AUDF0
    lda sfx_ch0_timer
    lsr
    sta AUDV0
    jmp .do_ch1

.sfx0_warp
    lda #$06            ; Buzz / flange
    sta AUDC0
    lda sfx_ch0_timer
    asl
    sta AUDF0
    lda #$08
    sta AUDV0
    jmp .do_ch1

.sfx0_hit
    lda #$0C            ; Lead noise
    sta AUDC0
    lda #$06
    sta AUDF0
    lda sfx_ch0_timer
    sta AUDV0
    jmp .do_ch1

.mute_ch0
    lda #0
    sta AUDV0
    sta sfx_ch0_id

.do_ch1
    ; --- Channel 1 Update ---
    lda sfx_ch1_timer
    beq .mute_ch1
    dec sfx_ch1_timer
    inc sfx_ch1_step
    
    lda sfx_ch1_id
    cmp #SFX_THRUST
    beq .sfx1_thrust
    cmp #SFX_TORPEDO
    beq .sfx1_torp
    cmp #SFX_EXPLOSION
    beq .sfx1_exp
    cmp #SFX_SHIELD_HIT
    beq .sfx1_hit
    jmp .mute_ch1

.sfx1_thrust
    lda #$08
    sta AUDC1
    lda #$1F
    sta AUDF1
    lda #$05
    sta AUDV1
    rts

.sfx1_torp
    lda #$0C
    sta AUDC1
    lda sfx_ch1_timer
    lsr
    clc
    adc #$08
    sta AUDF1
    lda sfx_ch1_timer
    lsr
    sta AUDV1
    rts

.sfx1_exp
    lda #$08            ; Heavy rumble noise
    sta AUDC1
    lda sfx_ch1_step
    asl
    clc
    adc #$0A
    sta AUDF1
    lda sfx_ch1_timer
    lsr
    clc
    adc #$04
    sta AUDV1
    rts

.sfx1_hit
    lda #$0C
    sta AUDC1
    lda #$06
    sta AUDF1
    lda sfx_ch1_timer
    sta AUDV1
    rts

.mute_ch1
    lda #0
    sta AUDV1
    sta sfx_ch1_id
    rts
