#!/usr/bin/env python3
"""
Generates all 1-bit PNG sprites (320A format) for Spacewar 7800:
- Needle Ship (16 rotational frames)
- Wedge Ship (16 rotational frames)
- Central Sun (animated corona)
- Photon Torpedo & Trail
- Phaser Bolt
- Ship Explosion (4 frames)
- HUD icons & bars
"""
import os
import math
import struct
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
GFX_DIR = os.path.join(HERE, "../src/gfx")
os.makedirs(GFX_DIR, exist_ok=True)

def write_png(name, rows):
    h, w = len(rows), len(rows[0])
    raw = b""
    for r in rows:
        bits = "".join("1" if c == "#" else "0" for c in r).ljust((w + 7) // 8 * 8, "0")
        raw += b"\0" + bytes(int(bits[i:i + 8], 2) for i in range(0, len(bits), 8))

    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d))

    data = (
        b"\x89PNG\r\n\x1a\n" +
        chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 1, 3, 0, 0, 0)) +
        chunk(b"PLTE", bytes([0, 0, 0, 255, 255, 255])) +
        chunk(b"IDAT", zlib.compress(raw, 9)) +
        chunk(b"IEND", b"")
    )
    with open(os.path.join(GFX_DIR, name + ".png"), "wb") as f:
        f.write(data)

def render_rotated_polygon(poly_pts, angle_deg, size=16):
    """Renders a 2D polygon rotated by angle into a grid of '#' and '.'"""
    rad = math.radians(angle_deg)
    cos_a, sin_a = math.cos(rad), math.sin(rad)
    cx, cy = size / 2.0, size / 2.0
    
    # Rotate vertices around (0,0) then translate to center
    rot_poly = []
    for x, y in poly_pts:
        rx = x * cos_a - y * sin_a + cx
        ry = x * sin_a + y * cos_a + cy
        rot_poly.append((rx, ry))
        
    grid = []
    for py in range(size):
        row = ""
        for px in range(size):
            # Point in polygon test (ray casting)
            inside = False
            j = len(rot_poly) - 1
            for i in range(len(rot_poly)):
                xi, yi = rot_poly[i]
                xj, yj = rot_poly[j]
                if ((yi > py) != (yj > py)) and (px < (xj - xi) * (py - yi) / (yj - yi + 1e-9) + xi):
                    inside = not inside
                j = i
            row += "#" if inside else "."
        grid.append(row)
    return grid

def generate_all_sprites():
    print("--> Generating Spacewar 7800 sprites...")
    
    # 1. Needle Ship: long, sharp spearhead
    needle_poly = [
        (6.5, 0.0),    # Tip
        (-4.5, -2.8),  # Left wing
        (-2.5, 0.0),   # Engine notch
        (-4.5, 2.8),   # Right wing
    ]
    
    # 2. Wedge Ship: wider triangular delta-wing
    wedge_poly = [
        (5.5, 0.0),    # Tip
        (-4.0, -4.5),  # Left wingtip
        (-1.5, -1.0),  # Inward indent
        (-3.0, 0.0),   # Rear center
        (-1.5, 1.0),
        (-4.0, 4.5),   # Right wingtip
    ]
    
    # 16 rotational angles: 0=East (facing right), 4=South, 8=West, 12=North
    for i in range(16):
        deg = i * 22.5
        rows_needle = render_rotated_polygon(needle_poly, deg, size=16)
        write_png(f"needle_{i:02d}", rows_needle)
        
        rows_wedge = render_rotated_polygon(wedge_poly, deg, size=16)
        write_png(f"wedge_{i:02d}", rows_wedge)

    # 3. Central Sun (16x16 glowing star)
    sun_rows = [
        "......####......",
        "....########....",
        "...##########...",
        "..############..",
        "..############..",
        ".##############.",
        ".##############.",
        "################",
        "################",
        ".##############.",
        ".##############.",
        "..############..",
        "..############..",
        "...##########...",
        "....########....",
        "......####......"
    ]
    write_png("sun", sun_rows)

    # 4. Photon Torpedo (8x8)
    torp_rows = [
        "........",
        "..####..",
        ".######.",
        ".######.",
        ".######.",
        ".######.",
        "..####..",
        "........"
    ]
    write_png("torpedo", torp_rows)

    # 5. Phaser Bolt (8x8 centered)
    phaser_rows = [
        "........",
        "........",
        "...##...",
        "..####..",
        "..####..",
        "...##...",
        "........",
        "........"
    ]
    write_png("phaser", phaser_rows)

    # 6. Trail / Particle Dot (8x8)
    dot_rows = [
        "........",
        "........",
        "........",
        "...##...",
        "...##...",
        "........",
        "........",
        "........"
    ]
    write_png("dot", dot_rows)

    # 7. Ship Explosion (4 frames, 16x16)
    exp0 = [
        "................",
        "......####......",
        "....########....",
        "...##########...",
        "..############..",
        "..############..",
        "...##########...",
        "....########....",
        "......####......",
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
        "................"
    ]
    exp1 = [
        "....#......#....",
        "..#...####...#..",
        "....########....",
        "..#..######..#..",
        ".##.########.##.",
        "....########....",
        "..#..######..#..",
        "....########....",
        "..#...####...#..",
        "....#......#....",
        "................",
        "................",
        "................",
        "................",
        "................",
        "................"
    ]
    exp2 = [
        "#...#......#...#",
        "..#...#..#...#..",
        "....#......#....",
        ".#....####....#.",
        ".....######.....",
        "....########....",
        ".....######.....",
        ".#....####....#.",
        "....#......#....",
        "..#...#..#...#..",
        "#...#......#...#",
        "................",
        "................",
        "................",
        "................",
        "................"
    ]
    exp3 = [
        "#..............#",
        "...#...#....#...",
        ".....#........#.",
        "..#......#......",
        "......#....#....",
        ".#............#.",
        "....#......#....",
        "........#.......",
        "..#...#......#..",
        "....#......#....",
        "#..............#",
        "................",
        "................",
        "................",
        "................",
        "................"
    ]
    write_png("exp_0", exp0)
    write_png("exp_1", exp1)
    write_png("exp_2", exp2)
    write_png("exp_3", exp3)
    
    # 8. Thrust Flame (8x8)
    flame_rows = [
        "........",
        "........",
        "..####..",
        ".######.",
        "..####..",
        "...##...",
        "....#...",
        "........"
    ]
    write_png("flame", flame_rows)

    print("    Sprites generated in src/gfx/!")

if __name__ == "__main__":
    generate_all_sprites()
