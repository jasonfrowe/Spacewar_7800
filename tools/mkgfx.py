#!/usr/bin/env python3
"""
Generates 1-bit PNG sprites (320A format, 8 scanlines tall to match zoneheight 8)
for Spacewar 7800:
- Needle Ship (16 rotational frames, 16x8 aspect-corrected for 320A)
- Wedge Ship (16 rotational frames, 16x8 aspect-corrected for 320A)
- Central Sun (16x8 aspect-corrected solar disc + corona rays)
- Photon Torpedo (8x8)
- Phaser Bolt (8x8)
- Ship Explosion (4 frames, 16x8)
- Thrust Flame (8x8)
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
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 1, 3, 0, 0, 0))
        + chunk(b"PLTE", bytes([0, 0, 0, 255, 255, 255]))
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )
    with open(os.path.join(GFX_DIR, name + ".png"), "wb") as f:
        f.write(data)


def dist_to_segment(px, py, x1, y1, x2, y2):
    dx, dy = x2 - x1, y2 - y1
    if dx == 0 and dy == 0:
        return math.hypot(px - x1, py - y1)
    t = max(0.0, min(1.0, ((px - x1) * dx + (py - y1) * dy) / (dx * dx + dy * dy)))
    return math.hypot(px - (x1 + t * dx), py - (y1 + t * dy))


def render_ship(segments, poly_pts, angle_deg, w=16, h=8, thickness=0.48):
    """
    Renders a ship at angle_deg in 320A aspect ratio (w=16, h=8 represents an 8x8 square
    in 160-clock x scanline space).
    """
    rad = math.radians(angle_deg)
    cos_a, sin_a = math.cos(rad), math.sin(rad)

    def rot(x, y):
        return (x * cos_a - y * sin_a, x * sin_a + y * cos_a)

    rot_segs = [(rot(x1, y1), rot(x2, y2)) for (x1, y1), (x2, y2) in segments]
    rot_poly = [rot(x, y) for x, y in poly_pts]

    grid = []
    for py in range(h):
        # Convert pixel center to [-4..+4] world space
        wy = (py + 0.5) - (h / 2.0)
        row = ""
        for px in range(w):
            wx = ((px + 0.5) - (w / 2.0)) * 0.5  # 320A: 2 horizontal pixels = 1 vertical scanline

            # Check filled polygon
            inside = False
            if rot_poly:
                j = len(rot_poly) - 1
                for i in range(len(rot_poly)):
                    xi, yi = rot_poly[i]
                    xj, yj = rot_poly[j]
                    if ((yi > wy) != (yj > wy)) and (wx < (xj - xi) * (wy - yi) / (yj - yi + 1e-9) + xi):
                        inside = not inside
                    j = i

            # Check wireframe segments so thin tips and fins never vanish
            if not inside:
                for (x1, y1), (x2, y2) in rot_segs:
                    if dist_to_segment(wx, wy, x1, y1, x2, y2) <= thickness:
                        inside = True
                        break

            row += "#" if inside else "."
        grid.append(row)
    return grid


def generate_all_sprites():
    print("--> Generating Spacewar 7800 sprites (320A aspect-corrected 16x8 / 8x8)...")

    # 1. Needle Ship: sleek fuselage with rear swept fins
    needle_poly = [
        (3.6, 0.0),    # Nose tip
        (-1.2, -0.8),  # Mid fuselage
        (-3.2, -2.2),  # Left fin tip
        (-2.4, 0.0),   # Tail center
        (-3.2, 2.2),   # Right fin tip
        (-1.2, 0.8),   # Mid fuselage
    ]
    needle_segs = [
        ((3.6, 0.0), (-2.6, 0.0)),      # Center spine
        ((1.8, 0.0), (-3.2, -2.2)),     # Left wing edge
        ((1.8, 0.0), (-3.2, 2.2)),      # Right wing edge
        ((-3.2, -2.2), (-2.2, 0.0)),    # Left tail
        ((-3.2, 2.2), (-2.2, 0.0)),     # Right tail
    ]

    # 2. Wedge Ship: wide delta arrowhead
    wedge_poly = [
        (3.4, 0.0),    # Nose tip
        (-3.0, -3.1),  # Left wingtip
        (-1.8, -0.9),  # Inner notch
        (-2.6, 0.0),   # Engine core
        (-1.8, 0.9),   # Inner notch
        (-3.0, 3.1),   # Right wingtip
    ]
    wedge_segs = [
        ((3.4, 0.0), (-3.0, -3.1)),
        ((3.4, 0.0), (-3.0, 3.1)),
        ((-3.0, -3.1), (-1.6, 0.0)),
        ((-3.0, 3.1), (-1.6, 0.0)),
    ]

    for i in range(16):
        deg = i * 22.5
        write_png(f"needle_{i:02d}", render_ship(needle_segs, needle_poly, deg, thickness=0.45))
        write_png(f"wedge_{i:02d}", render_ship(wedge_segs, wedge_poly, deg, thickness=0.48))

    # 3. Central Sun (16x8 aspect-corrected star with corona rays, matching orbit's star.png)
    sun_rows = [
        "...#...##...#...",
        "....########....",
        "..############..",
        "################",
        "################",
        "..############..",
        "....########....",
        "...#...##...#...",
    ]
    write_png("sun", sun_rows)

    # 4. Photon Torpedo (8x8 bright diamond projectile)
    torp_rows = [
        "........",
        "........",
        "...##...",
        "..####..",
        "..####..",
        "...##...",
        "........",
        "........",
    ]
    write_png("torpedo", torp_rows)

    # 5. Phaser Bolt (8x8 concentrated energy pulse)
    phaser_rows = [
        "........",
        "...##...",
        "..####..",
        ".######.",
        ".######.",
        "..####..",
        "...##...",
        "........",
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
        "........",
    ]
    write_png("dot", dot_rows)

    # 7. Ship Explosion (4 frames, 16x8)
    exp0 = [
        "......####......",
        "....########....",
        "...##########...",
        "..############..",
        "..############..",
        "...##########...",
        "....########....",
        "......####......",
    ]
    exp1 = [
        "..#...####...#..",
        "....########....",
        "..#..######..#..",
        ".##.########.##.",
        ".##.########.##.",
        "..#..######..#..",
        "....########....",
        "..#...####...#..",
    ]
    exp2 = [
        "#...#......#...#",
        "..#...####...#..",
        ".#...######...#.",
        "....###..###....",
        "....###..###....",
        ".#...######...#.",
        "..#...####...#..",
        "#...#......#...#",
    ]
    exp3 = [
        "#......#.......#",
        "..#.........#...",
        "....#.....#.....",
        ".#..........#...",
        "...#..........#.",
        ".....#....#.....",
        "...#.........#..",
        "#.......#......#",
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
        "........",
        "........",
    ]
    write_png("flame", flame_rows)

    print("    Sprites generated in src/gfx/!")


if __name__ == "__main__":
    generate_all_sprites()
