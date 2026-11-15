 rem ** Spacewar 7800
 rem ** Port of Bill Seiler's 1985 DOS Spacewar for the Atari 7800 ProSystem
 rem ** Powered by the AstroCart FPGA MathUnit & CORDIC Engine ($0420-$043F)

 set romsize 32k
 displaymode 320A
 set zoneheight 8
 set screenheight 192
 set extradlmemory on

 BACKGRND=$00

 rem ** Include 320A Graphics (All 8 scanlines tall to match zoneheight 8)
 incgraphic gfx/menufont.png 320A
 incgraphic gfx/sun.png 320A
 incgraphic gfx/torpedo.png 320A
 incgraphic gfx/phaser.png 320A
 incgraphic gfx/flame.png 320A
 incgraphic gfx/dot.png 320A
 incgraphic gfx/logo_t0.png 320A
 incgraphic gfx/logo_t1.png 320A
 incgraphic gfx/logo_t2.png 320A
 incgraphic gfx/logo_t3.png 320A
 incgraphic gfx/logo_b0.png 320A
 incgraphic gfx/logo_b1.png 320A
 incgraphic gfx/logo_b2.png 320A
 incgraphic gfx/logo_b3.png 320A

 incgraphic gfx/exp_0.png 320A
 incgraphic gfx/exp_1.png 320A
 incgraphic gfx/exp_2.png 320A
 incgraphic gfx/exp_3.png 320A

 incgraphic gfx/needle_00.png 320A
 incgraphic gfx/needle_01.png 320A
 incgraphic gfx/needle_02.png 320A
 incgraphic gfx/needle_03.png 320A
 incgraphic gfx/needle_04.png 320A
 incgraphic gfx/needle_05.png 320A
 incgraphic gfx/needle_06.png 320A
 incgraphic gfx/needle_07.png 320A
 incgraphic gfx/needle_08.png 320A
 incgraphic gfx/needle_09.png 320A
 incgraphic gfx/needle_10.png 320A
 incgraphic gfx/needle_11.png 320A
 incgraphic gfx/needle_12.png 320A
 incgraphic gfx/needle_13.png 320A
 incgraphic gfx/needle_14.png 320A
 incgraphic gfx/needle_15.png 320A

 incgraphic gfx/wedge_00.png 320A
 incgraphic gfx/wedge_01.png 320A
 incgraphic gfx/wedge_02.png 320A
 incgraphic gfx/wedge_03.png 320A
 incgraphic gfx/wedge_04.png 320A
 incgraphic gfx/wedge_05.png 320A
 incgraphic gfx/wedge_06.png 320A
 incgraphic gfx/wedge_07.png 320A
 incgraphic gfx/wedge_08.png 320A
 incgraphic gfx/wedge_09.png 320A
 incgraphic gfx/wedge_10.png 320A
 incgraphic gfx/wedge_11.png 320A
 incgraphic gfx/wedge_12.png 320A
 incgraphic gfx/wedge_13.png 320A
 incgraphic gfx/wedge_14.png 320A
 incgraphic gfx/wedge_15.png 320A

 rem ** Palettes
 rem ** P0: Text & Menu (Bright White)
 P0C2=$0F
 rem ** P1: Central Sun (Solar Gold / Yellow)
 P1C2=$1E
 rem ** P2: Player 1 Needle Ship & HUD (Electric Cyan)
 P2C2=$9C
 rem ** P3: Player 2 Wedge Ship & HUD (Vermillion Orange)
 P3C2=$3A
 rem ** P4: Photon Torpedoes (Bright Lime Green)
 P4C2=$CA
 rem ** P5: Phasers & Explosions (Flame Yellow/Amber)
 P5C2=$1C

 characterset menufont
 alphachars ASCII

 rem ** Zero-Page Scratch Variables
 dim tmp = a
 dim sx0 = b
 dim sy0 = c
 dim sframe0 = d
 dim sx1 = e
 dim sy1 = f
 dim sframe1 = g
 dim wx = h
 dim wy = o
 dim wf = p
 dim menu_sel = q
 dim debounce = r
 dim fire_wait = s

 rem ** Memory-Mapped Variables from physics.asm ($2214 - $22FF)
 dim v_energy0 = $2214
 dim v_energy1 = $2215
 dim v_shield0 = $2216
 dim v_shield1 = $2217
 dim v_alive0  = $221A
 dim v_alive1  = $221B
 dim v_thrust0 = $221C
 dim v_thrust1 = $221D
 dim v_score0  = $221E
 dim v_score1  = $221F

 dim v_llife0  = $2230
 dim v_llife1  = $2231

 dim v_ex0     = $2232
 dim v_ex1     = $2233
 dim v_ey0     = $2234
 dim v_ey1     = $2235
 dim v_eframe0 = $2236
 dim v_eframe1 = $2237
 dim v_etimer0 = $2238
 dim v_etimer1 = $2239

 dim v_sx0     = $223A
 dim v_sx1     = $223B
 dim v_sy0     = $223C
 dim v_sy1     = $223D
 dim v_sf0     = $223E
 dim v_sf1     = $223F

 dim v_mode    = $2240
 dim v_grav    = $2241
 dim v_wrap    = $2242
 dim v_state   = $2243
 dim v_timer   = $2245
 dim v_frame   = $2246

 dim v_lsx0    = $225A
 dim v_lsx1    = $225B
 dim v_lsy0    = $225C
 dim v_lsy1    = $225D

 dim v_e0_asc  = $225E
 dim v_s0_asc  = $2260
 dim v_w0_asc  = $2262
 dim v_e1_asc  = $2264
 dim v_s1_asc  = $2266
 dim v_w1_asc  = $2268
 dim v_fpx0    = $226A
 dim v_fpx1    = $226B
 dim v_fpy0    = $226C
 dim v_fpy1    = $226D

 rem ** 12 Photon Torpedo Slots (0..5 = Player 1, 6..11 = Player 2) ($2270 - $229F)
 dim v_tlife0  = $2270
 dim v_tlife1  = $2271
 dim v_tlife2  = $2272
 dim v_tlife3  = $2273
 dim v_tlife4  = $2274
 dim v_tlife5  = $2275
 dim v_tlife6  = $2276
 dim v_tlife7  = $2277
 dim v_tlife8  = $2278
 dim v_tlife9  = $2279
 dim v_tlife10 = $227A
 dim v_tlife11 = $227B

 dim v_tsx0    = $2288
 dim v_tsx1    = $2289
 dim v_tsx2    = $228A
 dim v_tsx3    = $228B
 dim v_tsx4    = $228C
 dim v_tsx5    = $228D
 dim v_tsx6    = $228E
 dim v_tsx7    = $228F
 dim v_tsx8    = $2290
 dim v_tsx9    = $2291
 dim v_tsx10   = $2292
 dim v_tsx11   = $2293

 dim v_tsy0    = $2294
 dim v_tsy1    = $2295
 dim v_tsy2    = $2296
 dim v_tsy3    = $2297
 dim v_tsy4    = $2298
 dim v_tsy5    = $2299
 dim v_tsy6    = $229A
 dim v_tsy7    = $229B
 dim v_tsy8    = $229C
 dim v_tsy9    = $229D
 dim v_tsy10   = $229E
 dim v_tsy11   = $229F

 rem ** Verify AstroCart MathUnit & CORDIC Hardware Presence
 asm
 lda $043F
 sta tmp
end
 if tmp <> $A1 then goto nomath
 asm
 lda $042F
 sta tmp
end
 if tmp <> $A2 then goto nomath

 rem ** Initialize Engine
 asm
 jsr spacewar_init
end
 menu_sel = 0
 debounce = 15
 fire_wait = 1

 rem =====================================================================
 rem ** TITLE SCREEN MENU (Authentic 1985 Bill Seiler DOS Layout)
 rem =====================================================================
title_loop
 clearscreen

 rem ** Starfield & Striped Planet in Top-Right Corner (matching 1985 DOS menu)
 plotsprite dot 0 18 12
 plotsprite dot 0 64 8
 plotsprite dot 0 102 14
 plotsprite sun 1 132 10

 rem ** Giant Beveled 1985 DOS "SPACEWAR" Title Banner (128x16 across X=48..112)
 plotsprite logo_t0 0 48 20
 plotsprite logo_t1 0 64 20
 plotsprite logo_t2 0 80 20
 plotsprite logo_t3 0 96 20
 plotsprite logo_b0 0 48 28
 plotsprite logo_b1 0 64 28
 plotsprite logo_b2 0 80 28
 plotsprite logo_b3 0 96 28

 plotchars 'V1.50  (C) 1985 B SEILER' 0 32 5

 rem ** Showcase Ships & Match Score Tally: [Ship1]=00    [Ship2]=00
 plotsprite needle_00 2 38 54
 plotchars '=' 0 50 7
 plotchars v_w0_asc 2 58 7 2

 plotsprite wedge_08 3 98 54
 plotchars '=' 0 110 7
 plotchars v_w1_asc 3 118 7 2

 rem ** Draw Cursor Arrow (>>) next to active row
 if menu_sel = 0 then plotchars '>>' 1 12 10
 if menu_sel = 1 then plotchars '>>' 1 12 12
 if menu_sel = 2 then plotchars '>>' 1 12 14

 rem ** Option 0: Game Mode (1P vs Robot or 2P Battle)
 if v_mode = 1 then plotchars 'PLAYERS: < 1P VS ROBOT >' 2 24 10 else plotchars 'PLAYERS: < 2P BATTLE   >' 2 24 10

 rem ** Option 1: Planet & Gravity Mode (matching [F3]Planet & [F4]Gravity)
 if v_grav = 0 then plotchars 'GRAVITY: < PLANET+GRAV >' 1 24 12
 if v_grav = 1 then plotchars 'GRAVITY: < PLANET ONLY >' 1 24 12
 if v_grav = 2 then plotchars 'GRAVITY: < REPULSOR    >' 1 24 12
 if v_grav = 3 then plotchars 'GRAVITY: < DEEP SPACE  >' 1 24 12

 rem ** Option 2: Arena Borders
 if v_wrap = 0 then plotchars 'BORDERS: < WRAP EDGES  >' 3 24 14 else plotchars 'BORDERS: < BOUNCE WALL >' 3 24 14

 plotchars 'UP/DOWN: ROW   LEFT/RIGHT: SET' 0 20 18
 plotchars 'PRESS FIRE TO PLAY SPACEWAR' 1 26 20

 drawscreen

 if debounce > 0 then debounce = debounce - 1

 rem ** Wait for fire button release before accepting Fire to start
 if !joy0fire then fire_wait = 0

 if debounce > 0 then goto title_check_fire

 rem ** UP / DOWN moves cursor between options 0, 1, 2
 if joy0up then debounce = 10 : gosub menu_move_up
 if joy0down then debounce = 10 : gosub menu_move_down

 rem ** LEFT changes highlighted option backward
 if joy0left then debounce = 10 : gosub menu_change_left

 rem ** RIGHT or SELECT changes highlighted option forward
 if joy0right || switchselect then debounce = 10 : gosub menu_change_right

title_check_fire
 if joy0fire && fire_wait = 0 then goto start_battle
 if v_state = 1 then goto start_battle
 goto title_loop

menu_move_up
 if menu_sel > 0 then menu_sel = menu_sel - 1 : return
 menu_sel = 2
 return

menu_move_down
 if menu_sel < 2 then menu_sel = menu_sel + 1 : return
 menu_sel = 0
 return

menu_change_left
 if menu_sel = 0 then v_mode = v_mode ^ 1 : return
 if menu_sel = 2 then v_wrap = v_wrap ^ 1 : return
 if v_grav > 0 then v_grav = v_grav - 1 : return
 v_grav = 3
 return

menu_change_right
 if menu_sel = 0 then v_mode = v_mode ^ 1 : return
 if menu_sel = 2 then v_wrap = v_wrap ^ 1 : return
 if v_grav < 3 then v_grav = v_grav + 1 : return
 v_grav = 0
 return

start_battle
 v_score0 = 0
 v_score1 = 0
 v_state = 1
 asm
 jsr round_init
end

 rem =====================================================================
 rem ** MAIN 60HZ GAMEPLAY LOOP
 rem =====================================================================
game_loop
 if switchreset then fire_wait = 1 : debounce = 15 : goto title_loop

 rem ** Player 1 Controls (Needle)
 if v_alive0 = 0 then goto skip_p1_input
 if joy0left then gosub do_p1_left
 if joy0right then gosub do_p1_right
 if joy0up then gosub do_p1_th
 if joy0down && v_energy0 >= 2 && v_shield0 < 99 then v_energy0 = v_energy0 - 1 : v_shield0 = v_shield0 + 1
 if joy0fire1 then gosub do_p1_tp
 if joy0fire0 then gosub do_p1_ph
skip_p1_input

 rem ** Player 2 Controls (Human or CPU AI)
 if v_mode = 1 then gosub do_ai_step : goto skip_p2_input
 if v_alive1 = 0 then goto skip_p2_input
 if joy1left then gosub do_p2_left
 if joy1right then gosub do_p2_right
 if joy1up then gosub do_p2_th
 if joy1down && v_energy1 >= 2 && v_shield1 < 99 then v_energy1 = v_energy1 - 1 : v_shield1 = v_shield1 + 1
 if joy1fire1 then gosub do_p2_tp
 if joy1fire0 then gosub do_p2_ph
skip_p2_input

 rem ** Step Physics, Gravity, Weapons & Collisions via AstroCart MathUnit
 asm
 jsr spacewar_step
end

 rem ** Render Frame
 clearscreen

 rem ** Top Telemetry Bar (with low-shield blinking at S < 25 like DOS Spacewar!)
 plotchars 'P1 E:' 2 4 0
 plotchars v_e0_asc 2 24 0 2
 plotchars 'S:' 2 36 0
 tmp = v_frame & 4
 if v_shield0 >= 25 || tmp = 0 then plotchars v_s0_asc 2 44 0 2
 plotchars 'W:' 2 56 0
 plotchars v_w0_asc 2 64 0 2

 if v_mode = 0 then plotchars 'P2 E:' 3 86 0 else plotchars 'AI E:' 3 86 0
 plotchars v_e1_asc 3 106 0 2
 plotchars 'S:' 3 118 0
 if v_shield1 >= 25 || tmp = 0 then plotchars v_s1_asc 3 126 0 2
 plotchars 'W:' 3 138 0
 plotchars v_w1_asc 3 146 0 2

 rem ** Subtle Deep Space Starfield Reference Points
 plotsprite dot 0 22 32
 plotsprite dot 0 134 40
 plotsprite dot 0 48 152
 plotsprite dot 0 116 164

 rem ** Draw Central Striped Planet at (74, 96) unless Deep Space mode (v_grav = 3)
 if v_grav <> 3 then plotsprite sun 1 74 96

 rem ** Draw Player 1 (Needle) & Thrust Plume
 if v_alive0 = 0 then goto skip_draw_p1
 if v_thrust0 > 0 then plotsprite flame 5 v_fpx0 v_fpy0
 sx0 = v_sx0
 sy0 = v_sy0
 sframe0 = v_sf0
 gosub plot_needle
skip_draw_p1

 rem ** Draw Player 2 (Wedge) & Thrust Plume
 if v_alive1 = 0 then goto skip_draw_p2
 if v_thrust1 > 0 then plotsprite flame 5 v_fpx1 v_fpy1
 sx1 = v_sx1
 sy1 = v_sy1
 sframe1 = v_sf1
 gosub plot_wedge
skip_draw_p2

 rem ** Draw Active Photon Torpedoes (6 per Player = 12 Total)
 if v_tlife0 > 0 then plotsprite torpedo 4 v_tsx0 v_tsy0
 if v_tlife1 > 0 then plotsprite torpedo 4 v_tsx1 v_tsy1
 if v_tlife2 > 0 then plotsprite torpedo 4 v_tsx2 v_tsy2
 if v_tlife3 > 0 then plotsprite torpedo 4 v_tsx3 v_tsy3
 if v_tlife4 > 0 then plotsprite torpedo 4 v_tsx4 v_tsy4
 if v_tlife5 > 0 then plotsprite torpedo 4 v_tsx5 v_tsy5
 if v_tlife6 > 0 then plotsprite torpedo 4 v_tsx6 v_tsy6
 if v_tlife7 > 0 then plotsprite torpedo 4 v_tsx7 v_tsy7
 if v_tlife8 > 0 then plotsprite torpedo 4 v_tsx8 v_tsy8
 if v_tlife9 > 0 then plotsprite torpedo 4 v_tsx9 v_tsy9
 if v_tlife10 > 0 then plotsprite torpedo 4 v_tsx10 v_tsy10
 if v_tlife11 > 0 then plotsprite torpedo 4 v_tsx11 v_tsy11

 rem ** Draw Active Phaser Bolts
 if v_llife0 > 0 then plotsprite phaser 5 v_lsx0 v_lsy0
 if v_llife1 > 0 then plotsprite phaser 5 v_lsx1 v_lsy1

 rem ** Draw Active Explosions
 if v_etimer0 > 0 then wx = v_ex0 : wy = v_ey0 : wf = v_eframe0 : gosub plot_explosion
 if v_etimer1 > 0 then wx = v_ex1 : wy = v_ey1 : wf = v_eframe1 : gosub plot_explosion

 rem ** Handle Round / Match Over Banner
 if v_state = 2 then gosub handle_round_over

 drawscreen
 goto game_loop

 rem =====================================================================
 rem ** ASSEMBLY SUBROUTINE WRAPPERS
 rem =====================================================================
do_p1_left
 asm
 jsr p1_turn_left
end
 return

do_p1_right
 asm
 jsr p1_turn_right
end
 return

do_p1_th
 asm
 jsr p1_thrust
end
 return

do_p1_ph
 asm
 jsr p1_fire_phaser
end
 return

do_p1_tp
 asm
 jsr p1_fire_torpedo
end
 return

do_p2_left
 asm
 jsr p2_turn_left
end
 return

do_p2_right
 asm
 jsr p2_turn_right
end
 return

do_p2_th
 asm
 jsr p2_thrust
end
 return

do_p2_ph
 asm
 jsr p2_fire_phaser
end
 return

do_p2_tp
 asm
 jsr p2_fire_torpedo
end
 return

do_ai_step
 asm
 jsr ai_step
end
 return

handle_round_over
 if v_score0 >= 5 then plotchars 'PLAYER 1 WINS THE MATCH!' 2 32 10 : plotchars 'PRESS FIRE FOR MENU' 0 42 12 : goto match_over_check
 if v_score1 >= 5 then plotchars 'PLAYER 2 WINS THE MATCH!' 3 32 10 : plotchars 'PRESS FIRE FOR MENU' 0 42 12 : goto match_over_check
 plotchars 'ROUND COMPLETE' 0 52 10
 if v_timer > 0 then v_timer = v_timer - 1 : return
 v_state = 1
 asm
 jsr round_init
end
 return

match_over_check
 if v_timer > 0 then v_timer = v_timer - 1 : return
 if joy0fire then fire_wait = 1 : debounce = 15 : pop : goto title_loop
 return

plot_needle
 if sframe0 = 0 then plotsprite needle_00 2 sx0 sy0 : return
 if sframe0 = 1 then plotsprite needle_01 2 sx0 sy0 : return
 if sframe0 = 2 then plotsprite needle_02 2 sx0 sy0 : return
 if sframe0 = 3 then plotsprite needle_03 2 sx0 sy0 : return
 if sframe0 = 4 then plotsprite needle_04 2 sx0 sy0 : return
 if sframe0 = 5 then plotsprite needle_05 2 sx0 sy0 : return
 if sframe0 = 6 then plotsprite needle_06 2 sx0 sy0 : return
 if sframe0 = 7 then plotsprite needle_07 2 sx0 sy0 : return
 if sframe0 = 8 then plotsprite needle_08 2 sx0 sy0 : return
 if sframe0 = 9 then plotsprite needle_09 2 sx0 sy0 : return
 if sframe0 = 10 then plotsprite needle_10 2 sx0 sy0 : return
 if sframe0 = 11 then plotsprite needle_11 2 sx0 sy0 : return
 if sframe0 = 12 then plotsprite needle_12 2 sx0 sy0 : return
 if sframe0 = 13 then plotsprite needle_13 2 sx0 sy0 : return
 if sframe0 = 14 then plotsprite needle_14 2 sx0 sy0 : return
 if sframe0 = 15 then plotsprite needle_15 2 sx0 sy0 : return
 return

plot_wedge
 if sframe1 = 0 then plotsprite wedge_00 3 sx1 sy1 : return
 if sframe1 = 1 then plotsprite wedge_01 3 sx1 sy1 : return
 if sframe1 = 2 then plotsprite wedge_02 3 sx1 sy1 : return
 if sframe1 = 3 then plotsprite wedge_03 3 sx1 sy1 : return
 if sframe1 = 4 then plotsprite wedge_04 3 sx1 sy1 : return
 if sframe1 = 5 then plotsprite wedge_05 3 sx1 sy1 : return
 if sframe1 = 6 then plotsprite wedge_06 3 sx1 sy1 : return
 if sframe1 = 7 then plotsprite wedge_07 3 sx1 sy1 : return
 if sframe1 = 8 then plotsprite wedge_08 3 sx1 sy1 : return
 if sframe1 = 9 then plotsprite wedge_09 3 sx1 sy1 : return
 if sframe1 = 10 then plotsprite wedge_10 3 sx1 sy1 : return
 if sframe1 = 11 then plotsprite wedge_11 3 sx1 sy1 : return
 if sframe1 = 12 then plotsprite wedge_12 3 sx1 sy1 : return
 if sframe1 = 13 then plotsprite wedge_13 3 sx1 sy1 : return
 if sframe1 = 14 then plotsprite wedge_14 3 sx1 sy1 : return
 if sframe1 = 15 then plotsprite wedge_15 3 sx1 sy1 : return
 return

plot_explosion
 if wf = 0 then plotsprite exp_0 5 wx wy : return
 if wf = 1 then plotsprite exp_1 5 wx wy : return
 if wf = 2 then plotsprite exp_2 5 wx wy : return
 if wf = 3 then plotsprite exp_3 5 wx wy : return
 return

nomath
 clearscreen
 plotchars 'THIS GAME REQUIRES THE' 0 38 8
 plotchars 'ASTROCART FPGA MATHUNIT' 0 36 10
 plotchars '(VERSION 2: CORDIC TRIG)' 0 36 12
 drawscreen
nomath_wait
 goto nomath_wait

 asm
 include "sound.asm"
 include "physics.asm"
 include "ai.asm"
end
