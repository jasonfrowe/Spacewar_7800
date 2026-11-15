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

 rem ** Memory-Mapped Variables from physics.asm ($2214 - $2293)
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

 dim v_tlife0  = $2240
 dim v_tlife1  = $2241
 dim v_tlife2  = $2242
 dim v_tlife3  = $2243

 dim v_llife0  = $2258
 dim v_llife1  = $2259

 dim v_ex0     = $225A
 dim v_ex1     = $225B
 dim v_ey0     = $225C
 dim v_ey1     = $225D
 dim v_eframe0 = $225E
 dim v_eframe1 = $225F
 dim v_etimer0 = $2260
 dim v_etimer1 = $2261

 dim v_sx0     = $2262
 dim v_sx1     = $2263
 dim v_sy0     = $2264
 dim v_sy1     = $2265
 dim v_sf0     = $2266
 dim v_sf1     = $2267

 dim v_mode    = $2268
 dim v_grav    = $2269
 dim v_wrap    = $226A
 dim v_state   = $226B
 dim v_timer   = $226D
 dim v_frame   = $226E

 dim v_tsx0    = $2288
 dim v_tsx1    = $2289
 dim v_tsx2    = $228A
 dim v_tsx3    = $228B
 dim v_tsy0    = $228C
 dim v_tsy1    = $228D
 dim v_tsy2    = $228E
 dim v_tsy3    = $228F

 dim v_lsx0    = $2290
 dim v_lsx1    = $2291
 dim v_lsy0    = $2292
 dim v_lsy1    = $2293

 dim v_e0_asc  = $2294
 dim v_s0_asc  = $2296
 dim v_w0_asc  = $2298
 dim v_e1_asc  = $229A
 dim v_s1_asc  = $229C
 dim v_w1_asc  = $229E
 dim v_fpx0    = $22A0
 dim v_fpx1    = $22A1
 dim v_fpy0    = $22A2
 dim v_fpy1    = $22A3

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
 rem ** TITLE SCREEN MENU (UP/DOWN picks row, LEFT/RIGHT changes option)
 rem =====================================================================
title_loop
 clearscreen

 plotchars 'SPACEWAR 7800' 1 54 1
 plotchars 'BILL SEILER 1985 DOS CLASSIC' 0 24 3

 rem ** Showcase Ships & Central Sun
 plotsprite needle_00 2 36 44
 plotsprite sun 1 76 44
 plotsprite wedge_08 3 116 44

 rem ** Draw Cursor Arrow (>>) next to active row
 if menu_sel = 0 then plotchars '>>' 1 16 8
 if menu_sel = 1 then plotchars '>>' 1 16 10
 if menu_sel = 2 then plotchars '>>' 1 16 12

 rem ** Option 0: Game Mode (1P vs CPU or 2P Head-to-Head)
 if v_mode = 1 then plotchars 'PLAYERS:  < 1P VS CPU >' 2 28 8 else plotchars 'PLAYERS:  < 2P BATTLE >' 2 28 8

 rem ** Option 1: Gravity Mode
 if v_grav = 0 then plotchars 'GRAVITY:  < NORMAL SUN >' 1 28 10
 if v_grav = 1 then plotchars 'GRAVITY:  < ZERO-G OFF >' 1 28 10
 if v_grav = 2 then plotchars 'GRAVITY:  < REPULSOR   >' 1 28 10

 rem ** Option 2: Arena Borders
 if v_wrap = 0 then plotchars 'BORDERS:  < WRAP EDGES >' 3 28 12 else plotchars 'BORDERS:  < BOUNCE WALL>' 3 28 12

 plotchars 'UP/DOWN: ROW   LEFT/RIGHT: SET' 0 20 16
 plotchars 'PRESS FIRE TO LAUNCH BATTLE' 1 26 18

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
 v_grav = 2
 return

menu_change_right
 if menu_sel = 0 then v_mode = v_mode ^ 1 : return
 if menu_sel = 2 then v_wrap = v_wrap ^ 1 : return
 if v_grav < 2 then v_grav = v_grav + 1 : return
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

 rem ** Top Telemetry Bar (Strictly within X = 4..154, zero wrap!)
 plotchars 'P1 E:' 2 4 0
 plotchars v_e0_asc 2 24 0 2
 plotchars 'S:' 2 36 0
 plotchars v_s0_asc 2 44 0 2
 plotchars 'W:' 2 56 0
 plotchars v_w0_asc 2 64 0 2

 if v_mode = 0 then plotchars 'P2 E:' 3 86 0 else plotchars 'AI E:' 3 86 0
 plotchars v_e1_asc 3 106 0 2
 plotchars 'S:' 3 118 0
 plotchars v_s1_asc 3 126 0 2
 plotchars 'W:' 3 138 0
 plotchars v_w1_asc 3 146 0 2

 rem ** Draw Central Sun at (74, 96) -> center at (78, 100)
 plotsprite sun 1 74 96

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

 rem ** Draw Active Photon Torpedoes
 if v_tlife0 > 0 then plotsprite torpedo 4 v_tsx0 v_tsy0
 if v_tlife1 > 0 then plotsprite torpedo 4 v_tsx1 v_tsy1
 if v_tlife2 > 0 then plotsprite torpedo 4 v_tsx2 v_tsy2
 if v_tlife3 > 0 then plotsprite torpedo 4 v_tsx3 v_tsy3

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
