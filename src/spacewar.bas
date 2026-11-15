 rem ** Spacewar 7800
 rem ** Port of Bill Seiler's 1985 DOS Spacewar for the Atari 7800 ProSystem
 rem ** Powered by the AstroCart FPGA MathUnit & CORDIC Engine ($0420-$043F)

 set romsize 32k
 displaymode 320A
 set zoneheight 8
 set screenheight 192
 set extradlmemory on

 BACKGRND=$00

 rem ** Inc Graphics
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
 rem ** P0: HUD & Text (White)
 P0C2=$0F
 rem ** P1: Central Sun (Bright Yellow/Orange)
 P1C2=$1E
 rem ** P2: Needle Ship (Cyan / Light Blue)
 P2C2=$9C
 rem ** P3: Wedge Ship (Orange / Red)
 P3C2=$3A
 rem ** P4: Torpedoes & Energy Bolts (Green/Yellow)
 P4C2=$CA
 rem ** P5: Explosions & Flame (Flame Yellow)
 P5C2=$36

 characterset menufont
 alphachars ASCII

 rem ** Variable Mapping
 dim tmp = a
 dim sx0 = b
 dim sy0 = c
 dim sframe0 = d
 dim sx1 = e
 dim sy1 = f
 dim sframe1 = g
 dim idx = h
 dim wx = o
 dim wy = p
 dim wl = q
 dim wf = r
 dim e0 = s
 dim e1 = t
 dim sh0 = u
 dim sh1 = v
 dim sc0 = w
 dim sc1 = x
 dim menu_sel = y
 dim debounce = z

 rem ** Memory mapped variables from physics.asm
 dim v_alive0 = $221A
 dim v_alive1 = $221B
 dim v_energy0 = $2214
 dim v_energy1 = $2215
 dim v_shield0 = $2216
 dim v_shield1 = $2217
 dim v_cloak0 = $2218
 dim v_cloak1 = $2219
 dim v_score0 = $221E
 dim v_score1 = $221F
 dim v_sx0 = $2262
 dim v_sy0 = $2264
 dim v_sf0 = $2266
 dim v_sx1 = $2263
 dim v_sy1 = $2265
 dim v_sf1 = $2267
 dim v_mode = $2268
 dim v_grav = $2269
 dim v_wrap = $226A
 dim v_state = $226B
 dim v_timer = $226D

 rem ** Check for MathUnit Hardware Presence
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

 rem ** MathUnit Verified: Initialize Game
 asm
 jsr spacewar_init
end
 v_state = 0
 menu_sel = 0
 debounce = 0

title_loop
 clearscreen
 plotchars 'SPACEWAR 7800' 0 54 2
 plotchars 'PORT OF BILL SEILER 1985 DOS CLASSIC' 0 20 4
 plotchars 'ASTROCART FPGA CORDIC ENGINE' 0 24 5

 if v_mode = 0 then plotchars 'MODE: 2-PLAYER COMBAT' 0 34 8 else plotchars 'MODE: 1-PLAYER VS CPU' 0 34 8
 if v_grav = 0 then plotchars 'GRAVITY: NORMAL (PULL)' 0 34 10
 if v_grav = 1 then plotchars 'GRAVITY: OFF (DEEP SPACE)' 0 34 10
 if v_grav = 2 then plotchars 'GRAVITY: REPULSOR (PUSH)' 0 34 10

 plotchars 'UP/DOWN: SELECT   SELECT: CHANGE' 0 24 14
 plotchars 'PRESS FIRE TO COMMENCE BATTLE' 0 24 16
 plotsprite sun 1 76 100
 drawscreen

 if debounce > 0 then debounce = debounce - 1

 if !joy0fire && joy0select && debounce = 0 then gosub toggle_option : debounce = 12
 if joy0up && debounce = 0 then v_mode = v_mode ^ 1 : debounce = 12
 if joy0down && debounce = 0 then v_grav = (v_grav + 1) : if v_grav > 2 then v_grav = 0 : debounce = 12

 if joy0fire && debounce = 0 then goto start_battle
 goto title_loop

start_battle
 v_state = 1
 asm
 jsr round_init
end
 goto game_loop

toggle_option
 v_mode = v_mode ^ 1
 return

game_loop
 rem ** Handle Player 1 Input
 if v_alive0 = 0 then goto skip_p1_input
 if joy0left then gosub do_p1_left
 if joy0right then gosub do_p1_right
 if joy0up then gosub do_p1_th
 if joy0down && v_energy0 >= 3 && v_shield0 < 100 then v_energy0 = v_energy0 - 2 : v_shield0 = v_shield0 + 1
 if joy0fire0 && v_energy0 >= 3 then gosub do_p1_ph
 if joy0fire1 && v_energy0 >= 10 then gosub do_p1_tp
skip_p1_input

 rem ** Handle Player 2 Input (Human or AI)
 if v_mode = 1 then gosub do_ai_step : goto skip_p2_input
 if v_alive1 = 0 then goto skip_p2_input
 if joy1left then gosub do_p2_left
 if joy1right then gosub do_p2_right
 if joy1up then gosub do_p2_th
 if joy1down && v_energy1 >= 3 && v_shield1 < 100 then v_energy1 = v_energy1 - 2 : v_shield1 = v_shield1 + 1
 if joy1fire0 && v_energy1 >= 3 then gosub do_p2_ph
 if joy1fire1 && v_energy1 >= 10 then gosub do_p2_tp
skip_p2_input

 rem ** Physics Update via MathUnit
 asm
 jsr spacewar_step
end

 rem ** Render Frame
 clearscreen

 rem ** Top HUD: Scores, Energy, Shields
 plotchars 'P1 E:' 0 2 0
 plotvalue menufont 0 v_energy0 3 24 0
 plotchars 'S:' 0 38 0
 plotvalue menufont 0 v_shield0 3 48 0
 plotchars 'WINS:' 0 62 0
 plotvalue menufont 0 v_score0 2 82 0

 if v_mode = 0 then plotchars 'P2 E:' 0 92 0 else plotchars 'CPU E:' 0 92 0
 plotvalue menufont 0 v_energy1 3 116 0
 plotchars 'S:' 0 130 0
 plotvalue menufont 0 v_shield1 3 140 0
 plotchars 'WINS:' 0 152 0
 plotvalue menufont 0 v_score1 2 172 0

 rem ** Draw Central Sun
 plotsprite sun 1 76 100

 rem ** Draw Player 1 (Needle) if alive and not cloaked
 if v_alive0 = 0 || v_cloak0 <> 0 then goto skip_draw_p1
 sx0 = v_sx0 / 2
 sy0 = v_sy0
 sframe0 = v_sf0
 gosub plot_needle
skip_draw_p1

 rem ** Draw Player 2 (Wedge) if alive and not cloaked
 if v_alive1 = 0 || v_cloak1 <> 0 then goto skip_draw_p2
 sx1 = v_sx1 / 2
 sy1 = v_sy1
 sframe1 = v_sf1
 gosub plot_wedge
skip_draw_p2

 rem ** Draw Torpedoes
 for idx = 0 to 3
 asm
 ldx idx
 lda sw_tlife,x
 sta wl
 txa
 asl
 tax
 lda sw_tx+1,x
 asl
 asl
 asl
 sta sw_tmp
 lda sw_tx,x
 lsr
 lsr
 lsr
 lsr
 lsr
 ora sw_tmp
 lsr
 sta wx
 lda sw_ty+1,x
 asl
 asl
 asl
 sta sw_tmp
 lda sw_ty,x
 lsr
 lsr
 lsr
 lsr
 lsr
 ora sw_tmp
 sta wy
end
 if wl > 0 then plotsprite torpedo 4 wx wy
 next

 rem ** Draw Explosions
 for idx = 0 to 1
 asm
 ldx idx
 lda sw_etimer,x
 sta wl
 lda sw_ex,x
 lsr
 sta wx
 lda sw_ey,x
 sta wy
 lda sw_eframe,x
 sta wf
end
 if wl > 0 then gosub plot_explosion
 next

 rem ** Check Round State
 if v_state = 2 then gosub handle_round_over

 drawscreen
 goto game_loop

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
 plotchars 'ROUND COMPLETE' 0 60 12
 if v_score0 >= 5 then plotchars 'PLAYER 1 WINS MATCH!' 0 50 14 : goto match_over
 if v_score1 >= 5 then plotchars 'PLAYER 2 WINS MATCH!' 0 50 14 : goto match_over
 if v_timer > 0 then v_timer = v_timer - 1 : return
 v_state = 1
 asm
 jsr round_init
end
 return

match_over
 if v_timer > 0 then v_timer = v_timer - 1 : return
 if joy0fire then goto do_restart
 return

do_restart
 v_state = 0
 asm
 jsr spacewar_init
end
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
