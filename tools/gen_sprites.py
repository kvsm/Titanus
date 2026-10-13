#!/usr/bin/env python3
"""Generates all placeholder pixel art for Titanus.

Every colour comes from the 16-colour master palette (docs/DESIGN.md §7.2).
Run from the repo root:  python3 tools/gen_sprites.py
Hand-drawn art can replace any output PNG as long as the name and size match.
"""
import math
import os
import random

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets")

PAL = {
    "0": (0x0D, 0x02, 0x21),  # midnight
    "1": (0x26, 0x14, 0x47),  # deep purple
    "2": (0x54, 0x13, 0x88),  # grid violet
    "3": (0x8C, 0x1E, 0xFF),  # electric violet
    "4": (0xB9, 0x67, 0xFF),  # lavender
    "5": (0xFF, 0x2A, 0x6D),  # hot pink
    "6": (0xF2, 0x22, 0xFF),  # magenta
    "7": (0xFF, 0x6C, 0x11),  # sunset orange
    "8": (0xFF, 0xD3, 0x19),  # sun yellow
    "9": (0xFF, 0xFB, 0x96),  # pale yellow
    "c": (0x01, 0xCD, 0xFE),  # cyan
    "m": (0x05, 0xFF, 0xA1),  # mint
    "d": (0x3D, 0x3D, 0x5C),  # chrome dark
    "g": (0x7A, 0x7A, 0xA8),  # chrome mid
    "l": (0xC8, 0xC8, 0xE8),  # chrome light
    "w": (0xFF, 0xFF, 0xFF),  # white
}


def C(k, a=255):
    return PAL[k] + (a,)


# ---------------------------------------------------------------- helpers

def from_ascii(rows, mirror=True):
    """Build an image from ASCII rows. With mirror, rows are the left half."""
    if mirror:
        rows = [r + r[::-1] for r in rows]
    w = max(len(r) for r in rows)
    img = Image.new("RGBA", (w, len(rows)), (0, 0, 0, 0))
    px = img.load()
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch in PAL:
                px[x, y] = C(ch)
    return img


def pad(img, n=1):
    out = Image.new("RGBA", (img.width + 2 * n, img.height + 2 * n), (0, 0, 0, 0))
    out.paste(img, (n, n))
    return out


def outline(img, col="0"):
    """Adds a 1px midnight outline around every opaque pixel (4-neighbour)."""
    img = pad(img)
    src = img.copy().load()
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            if src[x, y][3] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < img.width and 0 <= ny < img.height and src[nx, ny][3] > 0 and src[nx, ny][:3] != PAL[col]:
                    px[x, y] = C(col)
                    break
    return img


def save(img, *path):
    p = os.path.join(OUT, *path)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    img.save(p)


def circle(d, cx, cy, r, col):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col)


BAYER4 = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def dither_on(x, y, level):
    """level 0..1 -> ordered-dither boolean."""
    return level * 16 > BAYER4[y % 4][x % 4] + 0.5


# ---------------------------------------------------------------- font
# 5x7 glyphs. '*' is a small multiplication sign used for the chain multiplier.
GLYPHS = {
    " ": ["", "", "", "", "", "", ""],
    "0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
    "1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
    "2": [".###.", "#...#", "....#", "..##.", ".#...", "#....", "#####"],
    "3": ["####.", "....#", "....#", ".###.", "....#", "....#", "####."],
    "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
    "5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
    "6": [".###.", "#....", "#....", "####.", "#...#", "#...#", ".###."],
    "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
    "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
    "9": [".###.", "#...#", "#...#", ".####", "....#", "....#", ".###."],
    "A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
    "C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
    "D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
    "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
    "F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
    "G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".####"],
    "H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "I": [".###.", "..#..", "..#..", "..#..", "..#..", "..#..", ".###."],
    "J": ["..###", "...#.", "...#.", "...#.", "...#.", "#..#.", ".##.."],
    "K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
    "L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
    "M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
    "N": ["#...#", "#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#"],
    "O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
    "Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
    "R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
    "S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
    "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
    "U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
    "W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#"],
    "X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
    "Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
    "Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
    "!": ["..#..", "..#..", "..#..", "..#..", "..#..", ".....", "..#.."],
    "?": [".###.", "#...#", "....#", "..##.", "..#..", ".....", "..#.."],
    ".": [".....", ".....", ".....", ".....", ".....", ".....", "..#.."],
    ",": [".....", ".....", ".....", ".....", ".....", "..#..", ".#..."],
    ":": [".....", "..#..", ".....", ".....", ".....", "..#..", "....."],
    "-": [".....", ".....", ".....", ".###.", ".....", ".....", "....."],
    "+": [".....", "..#..", "..#..", "#####", "..#..", "..#..", "....."],
    "*": [".....", ".....", "#...#", ".#.#.", "..#..", ".#.#.", "#...#"],
    "%": ["##..#", "##.#.", "...#.", "..#..", ".#...", ".#.##", "#..##"],
    "/": ["....#", "...#.", "...#.", "..#..", ".#...", ".#...", "#...."],
    "<": ["...#.", "..#..", ".#...", "#....", ".#...", "..#..", "...#."],
    ">": [".#...", "..#..", "...#.", "....#", "...#.", "..#..", ".#..."],
    "(": ["..#..", ".#...", "#....", "#....", "#....", ".#...", "..#.."],
    ")": ["..#..", "...#.", "....#", "....#", "....#", "...#.", "..#.."],
    "'": ["..#..", "..#..", ".#...", ".....", ".....", ".....", "....."],
    "=": [".....", ".....", "#####", ".....", "#####", ".....", "....."],
    "#": ["#####", "#####", "#####", "#####", "#####", "#####", "#####"],
}
FONT_ORDER = " 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ!?.,:-+*%/<>()'=#"


def gen_font():
    img = Image.new("RGBA", (len(FONT_ORDER) * 6, 8), (0, 0, 0, 0))
    px = img.load()
    for i, ch in enumerate(FONT_ORDER):
        for y, row in enumerate(GLYPHS[ch]):
            for x, c in enumerate(row):
                if c == "#":
                    px[i * 6 + x, y] = (255, 255, 255, 255)
    save(img, "font", "font.png")
    with open(os.path.join(OUT, "font", "font_order.txt"), "w") as f:
        f.write(FONT_ORDER)


def gen_logo():
    text = "TITANUS"
    s = 5
    w = len(text) * 6 * s - s
    h = 7 * s
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    grad = ["w", "w", "l", "l", "l", "g", "l", "g", "g", "d", "6", "5", "5", "7", "7", "8", "8", "9", "8", "8"]
    for i, ch in enumerate(text):
        for gy, row in enumerate(GLYPHS[ch]):
            for gx, c in enumerate(row):
                if c != "#":
                    continue
                for yy in range(s):
                    for xx in range(s):
                        y = gy * s + yy
                        x = i * 6 * s + gx * s + xx
                        k = grad[min(len(grad) - 1, int(y / h * len(grad)))]
                        px[x, y] = C(k)
    # horizon highlight line through the middle (classic 80s chrome)
    for x in range(w):
        y = int(h * 0.5)
        if px[x, y][3]:
            px[x, y] = C("w")
    logo = outline(img, "6")
    logo = outline(logo, "0")
    # cyan drop shadow
    shadow = Image.new("RGBA", (logo.width + 3, logo.height + 3), (0, 0, 0, 0))
    sh = logo.copy()
    sp = sh.load()
    for y in range(sh.height):
        for x in range(sh.width):
            if sp[x, y][3]:
                sp[x, y] = C("c")
    shadow.paste(sh, (3, 3), sh)
    shadow.paste(logo, (0, 0), logo)
    save(shadow, "sprites", "logo.png")


# ---------------------------------------------------------------- ships

def gen_player():
    rows = [
        ".........w",
        ".........l",
        "........gl",
        "........gl",
        "........gc",
        ".......gcw",
        ".......gcc",
        ".......dgc",
        "......5dgl",
        "......5dgl",
        ".....65dgl",
        "....665dgl",
        "...6655dgl",
        "..66655dgl",
        ".c66655dgl",
        ".cc6655ddl",
        ".c...55ddg",
        ".......d7d",
        ".......d8d",
    ]
    img = outline(from_ascii(rows))
    save(img, "sprites", "player.png")
    # mini ship for the HUD lives counter
    mini = [
        "...w",
        "..gl",
        "..gc",
        ".5dl",
        "655l",
        "c.5d",
    ]
    save(outline(from_ascii(mini)), "sprites", "icon_life.png")


def gen_glitch():
    rows = [
        ".....l",
        "....gl",
        "...6gl",
        "..66dw",
        ".366d5",
        "3c6d55",
        "3c6d59",
        ".366dd",
        "..66d.",
        "...6..",
    ]
    save(outline(from_ascii(rows)), "sprites", "glitch.png")


def gen_strobe():
    rows = [
        ".3......",
        ".33.....",
        ".343....",
        ".3443...",
        "..3443..",
        "..34ddg.",
        "...3dggl",
        "...3dglc",
        "....dglc",
        "....5dgl",
        "....55dg",
        ".....55d",
        "......5w",
        ".......w",
    ]
    save(outline(from_ascii(rows)), "sprites", "strobe.png")


def gen_note():
    rows = [
        "...55",
        "..5w5",
        ".5665",
        "56665",
        "56665",
        ".5665",
        "..55.",
    ]
    save(outline(from_ascii(rows)), "sprites", "note.png")


def gen_turret():
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(4, 0), (11, 0), (15, 4), (15, 11), (11, 15), (4, 15), (0, 11), (0, 4)], fill=C("d"))
    d.polygon([(5, 2), (10, 2), (13, 5), (13, 10), (10, 13), (5, 13), (2, 10), (2, 5)], fill=C("1"))
    circle(d, 7.5, 7.5, 4, C("g"))
    circle(d, 7.5, 7.5, 3, C("d"))
    for (x, y) in ((1, 7), (14, 7), (7, 1), (7, 14), (8, 1), (8, 14), (1, 8), (14, 8)):
        img.putpixel((x, y), C("5"))
    save(outline(img), "sprites", "turret_base.png")
    gun = Image.new("RGBA", (6, 12), (0, 0, 0, 0))
    d = ImageDraw.Draw(gun)
    d.rectangle([0, 0, 5, 5], fill=C("g"))
    d.rectangle([1, 1, 4, 4], fill=C("l"))
    d.rectangle([2, 4, 3, 11], fill=C("l"))
    d.rectangle([3, 4, 3, 11], fill=C("g"))
    d.rectangle([2, 10, 3, 11], fill=C("5"))
    save(outline(gun), "sprites", "turret_gun.png")


def gen_car():
    img = Image.new("RGBA", (20, 12), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 1, 19, 10], radius=3, fill=C("6"))
    d.rectangle([2, 2, 17, 2], fill=C("4"))
    d.rectangle([2, 9, 17, 9], fill=C("2"))
    d.rounded_rectangle([7, 3, 14, 8], radius=1, fill=C("1"))
    d.rectangle([12, 3, 14, 8], fill=C("c"))
    d.rectangle([7, 3, 8, 8], fill=C("2"))
    img.putpixel((19, 3), C("9"))
    img.putpixel((19, 8), C("9"))
    img.putpixel((0, 3), C("5"))
    img.putpixel((0, 8), C("5"))
    d.rectangle([3, 5, 5, 6], fill=C("w"))
    save(outline(img), "sprites", "car.png")


def gen_carrier():
    img = Image.new("RGBA", (34, 28), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # engine pods
    for x0 in (0, 27):
        d.rounded_rectangle([x0, 4, x0 + 6, 22], radius=2, fill=C("d"))
        d.rectangle([x0 + 1, 5, x0 + 2, 20], fill=C("g"))
        d.rectangle([x0 + 1, 21, x0 + 5, 23], fill=C("7"))
        img.putpixel((x0 + 3, 24), C("8"))
    # hull
    d.polygon([(6, 2), (27, 2), (30, 10), (25, 26), (8, 26), (3, 10)], fill=C("2"))
    d.polygon([(8, 3), (25, 3), (27, 10), (23, 24), (10, 24), (6, 10)], fill=C("3"))
    d.polygon([(10, 4), (23, 4), (24, 9), (9, 9)], fill=C("4"))
    # cargo bay (holds the weapon capsule)
    d.rectangle([13, 11, 20, 18], fill=C("1"))
    d.rectangle([14, 12, 19, 17], fill=C("m"))
    d.rectangle([15, 13, 18, 16], fill=C("w"))
    # chrome nose (pointing down)
    d.polygon([(12, 20), (21, 20), (18, 26), (15, 26)], fill=C("g"))
    d.line([(13, 20), (20, 20)], fill=C("l"))
    for x in (9, 24):
        img.putpixel((x, 14), C("5"))
    save(outline(img), "sprites", "carrier.png")


def gen_subwoofer():
    img = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # treads
    for x0 in (0, 38):
        d.rectangle([x0, 2, x0 + 9, 45], fill=C("0"))
        for y in range(3, 45, 4):
            d.rectangle([x0 + 1, y, x0 + 8, y + 1], fill=C("d"))
        d.rectangle([x0 + 1, 2, x0 + 8, 2], fill=C("g"))
    # hull
    d.rounded_rectangle([7, 4, 40, 43], radius=4, fill=C("d"))
    d.rounded_rectangle([8, 5, 39, 42], radius=4, fill=C("1"))
    d.rectangle([9, 6, 38, 7], fill=C("g"))
    d.rectangle([9, 40, 38, 41], fill=C("0"))
    # speaker cone
    circle(d, 23.5, 23.5, 14, C("0"))
    circle(d, 23.5, 23.5, 13, C("g"))
    circle(d, 23.5, 23.5, 12, C("d"))
    circle(d, 23.5, 23.5, 10, C("2"))
    circle(d, 23.5, 23.5, 7, C("3"))
    circle(d, 23.5, 23.5, 5, C("5"))
    circle(d, 23.5, 23.5, 3, C("6"))
    circle(d, 22.5, 22.5, 1, C("w"))
    # screws + lights
    for (x, y) in ((11, 9), (36, 9), (11, 38), (36, 38)):
        img.putpixel((x, y), C("l"))
    for x in range(12, 36, 3):
        img.putpixel((x, 44), C("7"))
    save(outline(img), "sprites", "subwoofer.png")


# ---------------------------------------------------------------- boss: HELIOS

def gen_helios():
    W, H = 132, 84
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = W // 2
    # shoulders / pauldrons
    for s in (-1, 1):
        x0 = cx + s * 46
        d.ellipse([x0 - 18, 6, x0 + 18, 38], fill=C("d"))
        d.ellipse([x0 - 16, 7, x0 + 16, 34], fill=C("g"))
        d.ellipse([x0 - 12, 8, x0 + 10, 24], fill=C("l"))
        d.arc([x0 - 16, 7, x0 + 16, 34], 20, 160, fill=C("6"))
        # missile pod hatch
        d.rectangle([x0 - 5, 14, x0 + 5, 22], fill=C("1"))
        for yy in (15, 18, 21):
            d.line([(x0 - 4, yy), (x0 + 4, yy)], fill=C("5"))
    # torso
    torso = [(cx - 34, 10), (cx + 34, 10), (cx + 40, 34), (cx + 26, 70), (cx - 26, 70), (cx - 40, 34)]
    d.polygon(torso, fill=C("d"))
    inner = [(cx - 31, 12), (cx + 31, 12), (cx + 36, 34), (cx + 23, 67), (cx - 23, 67), (cx - 36, 34)]
    d.polygon(inner, fill=C("g"))
    # chrome banding (horizon reflection)
    d.polygon([(cx - 31, 12), (cx + 31, 12), (cx + 33, 20), (cx - 33, 20)], fill=C("l"))
    d.line([(cx - 33, 21), (cx + 33, 21)], fill=C("w"))
    d.polygon([(cx - 36, 34), (cx + 36, 34), (cx + 31, 46), (cx - 31, 46)], fill=C("d"))
    # chest cavity (behind the plates, where the sun core sits)
    d.ellipse([cx - 19, 22, cx + 19, 60], fill=C("0"))
    d.ellipse([cx - 17, 24, cx + 17, 58], fill=C("1"))
    # neon circuitry
    for s in (-1, 1):
        d.line([(cx + s * 22, 26), (cx + s * 30, 34), (cx + s * 30, 44), (cx + s * 22, 52)], fill=C("c"))
        d.line([(cx + s * 26, 56), (cx + s * 18, 66)], fill=C("6"))
        img.putpixel((cx + s * 30, 39), C("w"))
    # waist / hips
    d.polygon([(cx - 26, 70), (cx + 26, 70), (cx + 18, 82), (cx - 18, 82)], fill=C("1"))
    d.polygon([(cx - 22, 70), (cx + 22, 70), (cx + 16, 79), (cx - 16, 79)], fill=C("2"))
    for x in range(cx - 14, cx + 15, 4):
        d.line([(x, 72), (x, 77)], fill=C("5"))
    # head
    d.polygon([(cx - 10, 0), (cx + 10, 0), (cx + 13, 12), (cx - 13, 12)], fill=C("d"))
    d.polygon([(cx - 8, 1), (cx + 8, 1), (cx + 10, 10), (cx - 10, 10)], fill=C("l"))
    d.rectangle([cx - 8, 5, cx + 8, 7], fill=C("0"))
    d.rectangle([cx - 7, 6, cx + 7, 6], fill=C("5"))
    img.putpixel((cx - 3, 6), C("w"))
    img.putpixel((cx + 3, 6), C("w"))
    save(outline(img), "sprites", "helios_body.png")

    # chest plates (left; right is mirrored in game)
    plate = Image.new("RGBA", (18, 38), (0, 0, 0, 0))
    d = ImageDraw.Draw(plate)
    d.polygon([(17, 0), (6, 2), (0, 18), (6, 35), (17, 37)], fill=C("d"))
    d.polygon([(17, 1), (7, 3), (2, 18), (7, 34), (17, 36)], fill=C("g"))
    d.polygon([(17, 2), (8, 4), (5, 12), (17, 12)], fill=C("l"))
    d.line([(17, 1), (17, 36)], fill=C("6"))
    for y in (18, 24, 30):
        d.line([(9, y), (15, y)], fill=C("d"))
    save(outline(plate), "sprites", "helios_plate.png")

    # arm cannon (left arm; mirrored for right)
    arm = Image.new("RGBA", (26, 50), (0, 0, 0, 0))
    d = ImageDraw.Draw(arm)
    d.rounded_rectangle([3, 0, 22, 22], radius=5, fill=C("d"))
    d.rounded_rectangle([4, 1, 21, 20], radius=4, fill=C("g"))
    d.rounded_rectangle([5, 2, 14, 10], radius=3, fill=C("l"))
    d.rectangle([0, 20, 25, 34], fill=C("1"))
    d.rectangle([1, 21, 24, 33], fill=C("2"))
    d.rectangle([1, 26, 24, 27], fill=C("5"))
    for bx in (4, 11, 18):
        d.rectangle([bx, 34, bx + 4, 47], fill=C("d"))
        d.rectangle([bx + 1, 34, bx + 2, 47], fill=C("l"))
        d.rectangle([bx, 46, bx + 4, 49], fill=C("7"))
        arm.putpixel((bx + 2, 48), C("9"))
    save(outline(arm), "sprites", "helios_arm.png")

    save(sun(34, stripes_from=0.45), "sprites", "helios_core.png")


def sun(size, stripes_from=0.5, stripe_n=5):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    r = size / 2 - 0.5
    grad = ["9", "8", "8", "8", "7", "7", "5", "5", "6", "6"]
    for y in range(size):
        for x in range(size):
            dx, dy = x - r, y - r
            if dx * dx + dy * dy > r * r:
                continue
            t = y / (size - 1)
            # horizontal gaps in the lower part, growing thicker towards the bottom
            if t > stripes_from:
                u = (t - stripes_from) / (1 - stripes_from)
                period = max(3, int(size * (1 - stripes_from) / stripe_n))
                gap = 1 + int(u * period * 0.6)
                if (y - int(stripes_from * size)) % period < gap:
                    continue
            k = grad[min(len(grad) - 1, int(t * len(grad)))]
            px[x, y] = C(k)
    return img


# ---------------------------------------------------------------- bullets & shots & pickups

def gen_bullets():
    def ball(size, core, ring, outer=None):
        img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        c = (size - 1) / 2
        r = size / 2 - 1
        if outer:
            circle(d, c, c, r, C(outer))
            r -= 1
        circle(d, c, c, r, C(ring))
        circle(d, c, c, max(0.6, r - 1.2), C(core))
        return outline(img)

    save(ball(6, "w", "5"), "sprites", "b_pink.png")
    save(ball(6, "w", "7"), "sprites", "b_orange.png")
    save(ball(10, "w", "5", "6"), "sprites", "b_big.png")
    save(ball(6, "w", "4"), "sprites", "b_violet.png")

    vul = Image.new("RGBA", (3, 8), (0, 0, 0, 0))
    d = ImageDraw.Draw(vul)
    d.rectangle([0, 1, 2, 7], fill=C("7", 220))
    d.rectangle([1, 0, 1, 5], fill=C("9"))
    save(vul, "sprites", "shot_vulcan.png")

    for lvl, w in enumerate((12, 16, 20, 26), start=1):
        img = Image.new("RGBA", (w, 7), (0, 0, 0, 0))
        px = img.load()
        for x in range(w):
            u = (x - (w - 1) / 2) / ((w - 1) / 2)
            y = int(round(4.5 * u * u))
            for t in range(2):
                yy = y + t
                if 0 <= yy < 7:
                    px[x, yy] = C("c" if t == 0 else "m", 230)
            if abs(u) < 0.5:
                px[x, y] = C("w")
        save(img, "sprites", "shot_wave_%d.png" % lvl)


def gen_pickups():
    def capsule(col, letter):
        img = Image.new("RGBA", (12, 14), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.rounded_rectangle([0, 0, 11, 13], radius=4, fill=C(col))
        d.rounded_rectangle([1, 1, 10, 12], radius=3, fill=C("w"))
        d.rounded_rectangle([2, 2, 9, 11], radius=3, fill=C(col))
        # 3x5 mini letters
        mini = {"V": ["#.#", "#.#", "#.#", "#.#", ".#."],
                "L": ["#..", "#..", "#..", "#..", "###"],
                "W": ["#.#", "#.#", "###", "###", "#.#"],
                "S": [".##", "#..", ".#.", "..#", "##."],
                "B": ["##.", "#.#", "##.", "#.#", "##."]}[letter]
        for y, row in enumerate(mini):
            for x, ch in enumerate(row):
                if ch == "#":
                    img.putpixel((4 + x, 4 + y), C("0"))
        return outline(img)

    save(capsule("8", "V"), "sprites", "cap_vulcan.png")
    save(capsule("5", "L"), "sprites", "cap_laser.png")
    save(capsule("c", "W"), "sprites", "cap_wave.png")
    save(capsule("m", "S"), "sprites", "pick_shield.png")
    save(capsule("6", "B"), "sprites", "pick_bomb.png")

    bomb = from_ascii([
        "..55",
        ".566",
        "5669",
        "5666",
        ".566",
        "..55",
    ])
    save(outline(bomb), "sprites", "icon_bomb.png")


# ---------------------------------------------------------------- backgrounds

W, H = 270, 480
HWY_X0, HWY_X1 = 118, 152  # highway shared by every city tile so they tile seamlessly
EDGE = 14  # rows at the top/bottom of a tile left free of buildings


def draw_highway(img):
    d = ImageDraw.Draw(img)
    d.rectangle([HWY_X0, 0, HWY_X1, H - 1], fill=C("0"))
    d.line([(HWY_X0, 0), (HWY_X0, H - 1)], fill=C("5"))
    d.line([(HWY_X1, 0), (HWY_X1, H - 1)], fill=C("5"))
    d.line([(HWY_X0 + 1, 0), (HWY_X0 + 1, H - 1)], fill=C("2"))
    d.line([(HWY_X1 - 1, 0), (HWY_X1 - 1, H - 1)], fill=C("2"))
    mid = (HWY_X0 + HWY_X1) // 2
    for y in range(0, H, 16):
        d.rectangle([mid, y, mid, y + 7], fill=C("4"))
    for lane in (HWY_X0 + 8, HWY_X1 - 8):
        for y in range(8, H, 16):
            d.point((lane, y), fill=C("d"))


def shadow_rect(img, box, depth):
    """Darkened drop shadow down-right of a building, giving a hint of height."""
    x0, y0, x1, y1 = box
    px = img.load()
    for y in range(y0 + depth, min(H, y1 + depth + 1)):
        for x in range(x0 + depth, min(W, x1 + depth + 1)):
            if x0 <= x <= x1 and y0 <= y <= y1:
                continue
            r, g, b, a = px[x, y]
            if a == 0:
                px[x, y] = (0, 0, 0, 110)
            else:
                px[x, y] = (r // 2, g // 2, b // 2, a)


def building(img, rng, box, dense):
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    depth = rng.choice((2, 3, 4)) if dense else rng.choice((1, 2))
    shadow_rect(img, box, depth)
    roof = rng.choice(("1", "1", "d", "2"))
    light = {"1": "2", "d": "g", "2": "3"}[roof]
    d.rectangle(box, fill=C(roof))
    d.line([(x0, y0), (x1, y0)], fill=C(light))
    d.line([(x0, y0), (x0, y1)], fill=C(light))
    d.line([(x0, y1), (x1, y1)], fill=C("0"))
    d.line([(x1, y0), (x1, y1)], fill=C("0"))
    w, h = x1 - x0, y1 - y0
    # neon trim on one edge
    if rng.random() < 0.6:
        col = rng.choice(("5", "c", "6", "m"))
        side = rng.randrange(4)
        if side == 0:
            d.line([(x0 + 1, y0 + 1), (x1 - 1, y0 + 1)], fill=C(col))
        elif side == 1:
            d.line([(x0 + 1, y1 - 1), (x1 - 1, y1 - 1)], fill=C(col))
        elif side == 2:
            d.line([(x0 + 1, y0 + 1), (x0 + 1, y1 - 1)], fill=C(col))
        else:
            d.line([(x1 - 1, y0 + 1), (x1 - 1, y1 - 1)], fill=C(col))
    feature = rng.random()
    if feature < 0.07 and w > 16 and h > 16:
        # helipad
        cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
        r = min(w, h) // 2 - 3
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=C("8"))
        d.line([(cx - 2, cy - 3), (cx - 2, cy + 3)], fill=C("9"))
        d.line([(cx + 2, cy - 3), (cx + 2, cy + 3)], fill=C("9"))
        d.point((cx - 1, cy), fill=C("9"))
        d.point((cx, cy), fill=C("9"))
        d.point((cx + 1, cy), fill=C("9"))
    elif feature < 0.22 and w > 14 and h > 8:
        # rooftop billboard: sunset stripes
        bx0, by0 = x0 + 3, y0 + 3
        bx1, by1 = x1 - 3, min(y1 - 3, y0 + 3 + max(4, h // 3))
        cols = ["8", "7", "5", "6", "3"]
        for i, y in enumerate(range(by0, by1 + 1)):
            d.line([(bx0, y), (bx1, y)], fill=C(cols[min(len(cols) - 1, i * len(cols) // max(1, by1 - by0 + 1))]))
        d.rectangle([bx0 - 1, by0 - 1, bx1 + 1, by1 + 1], outline=C("0"))
    elif feature < 0.32 and w > 12 and h > 12:
        # pool
        d.rectangle([x0 + 3, y0 + 3, x0 + 3 + w // 3, y0 + 3 + h // 3], fill=C("c"))
        d.line([(x0 + 4, y0 + 4), (x0 + 2 + w // 3, y0 + 4)], fill=C("w"))
    else:
        for _ in range(rng.randint(1, 4)):
            ax = rng.randint(x0 + 2, max(x0 + 2, x1 - 5))
            ay = rng.randint(y0 + 2, max(y0 + 2, y1 - 5))
            d.rectangle([ax, ay, ax + 2, ay + 2], fill=C("g"))
            d.point((ax, ay), fill=C("l"))
    # blinking aircraft light
    if rng.random() < 0.3:
        d.point((x1 - 2, y0 + 2), fill=C("5"))


def pyramid(img, rng, cx, cy, r):
    d = ImageDraw.Draw(img)
    shadow_rect(img, (cx - r, cy - r, cx + r, cy + r), 4)
    d.polygon([(cx - r, cy - r), (cx + r, cy - r), (cx, cy)], fill=C("3"))
    d.polygon([(cx - r, cy - r), (cx - r, cy + r), (cx, cy)], fill=C("4"))
    d.polygon([(cx + r, cy - r), (cx + r, cy + r), (cx, cy)], fill=C("2"))
    d.polygon([(cx - r, cy + r), (cx + r, cy + r), (cx, cy)], fill=C("1"))
    d.line([(cx - r, cy - r), (cx + r, cy + r)], fill=C("6"))
    d.line([(cx + r, cy - r), (cx - r, cy + r)], fill=C("6"))
    d.rectangle([cx - r, cy - r, cx + r, cy + r], outline=C("0"))
    d.rectangle([cx - 1, cy - 1, cx + 1, cy + 1], fill=C("l"))
    d.point((cx - 1, cy - 1), fill=C("w"))


def palm(img, cx, cy):
    d = ImageDraw.Draw(img)
    for i in range(6):
        a = i * math.pi / 3 + 0.3
        ex, ey = cx + math.cos(a) * 6, cy + math.sin(a) * 6
        d.line([(cx, cy), (ex, ey)], fill=C("2"))
        d.point((round(ex), round(ey)), fill=C("3"))
        mx, my = cx + math.cos(a) * 3, cy + math.sin(a) * 3
        d.point((round(mx + math.cos(a + 1.2)), round(my + math.sin(a + 1.2))), fill=C("2"))
    d.point((cx, cy), fill=C("6"))


def place_blocks(rng, img, x_range, dense):
    xa, xb = x_range
    y = EDGE
    while y < H - EDGE - 10:
        bh = rng.randint(18, 46) if dense else rng.randint(12, 26)
        if y + bh > H - EDGE:
            break
        x = xa
        while x < xb - 8:
            bw = rng.randint(14, 38) if dense else rng.randint(10, 22)
            bw = min(bw, xb - x)
            if bw < 8:
                break
            if dense or rng.random() < 0.45:
                if dense and rng.random() < 0.12 and bw > 22 and bh > 22:
                    r = min(bw, bh) // 2 - 1
                    pyramid(img, rng, x + bw // 2, y + bh // 2, r)
                else:
                    building(img, rng, (x, y, x + bw - 1, y + bh - 1), dense)
            elif rng.random() < 0.6:
                palm(img, x + bw // 2, y + bh // 2)
            x += bw + rng.randint(3, 7)
        y += bh + rng.randint(6, 12)


def gen_city(name, seed, dense):
    rng = random.Random(seed)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw_highway(img)
    # cross street
    d = ImageDraw.Draw(img)
    for cy in ([160, 360] if dense else [240]):
        d.rectangle([0, cy, W - 1, cy + 9], fill=C("0"))
        d.line([(0, cy), (W - 1, cy)], fill=C("2"))
        d.line([(0, cy + 9), (W - 1, cy + 9)], fill=C("2"))
        for x in range(0, W, 12):
            d.point((x, cy + 4), fill=C("d"))
    draw_highway(img)
    place_blocks(rng, img, (4, HWY_X0 - 6), dense)
    place_blocks(rng, img, (HWY_X1 + 7, W - 4), dense)
    # palms lining the highway
    for y in range(EDGE + 6, H - EDGE, 28 if dense else 20):
        px = img.load()
        for x in (HWY_X0 - 4, HWY_X1 + 4):
            if px[x, y][3] == 0:
                palm(img, x, y)
    save(img, "bg", name + ".png")


def gen_haze():
    rng = random.Random(7)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()
    blobs = []
    for _ in range(9):
        blobs.append((rng.uniform(0, W), rng.uniform(0, H), rng.uniform(25, 60), rng.uniform(10, 22),
                      rng.choice(("5", "7", "6", "4"))))
    for y in range(H):
        for x in range(W):
            best, col = 0.0, None
            for bx, by, rx, ry, c in blobs:
                for oy in (-H, 0, H):  # wrap vertically so the layer tiles
                    dx, dy = (x - bx) / rx, (y - (by + oy)) / ry
                    v = 1 - (dx * dx + dy * dy)
                    if v > best:
                        best, col = v, c
            if col and best > 0 and dither_on(x, y, best * 0.55):
                px[x, y] = C(col, 70)
    save(img, "bg", "haze.png")


# ---------------------------------------------------------------- title + icon

def gen_title_art():
    save(sun(112, stripes_from=0.5, stripe_n=6), "sprites", "sun_big.png")


def gen_icon():
    player = Image.open(os.path.join(OUT, "sprites", "player.png"))

    def backdrop(size):
        img = Image.new("RGBA", (size, size), C("0"))
        d = ImageDraw.Draw(img)
        bands = ["0", "1", "2", "3", "6", "5", "7"]
        horizon = int(size * 0.62)
        for y in range(horizon):
            d.line([(0, y), (size, y)], fill=C(bands[int(y / horizon * len(bands))]))
        s = sun(int(size * 0.62), 0.5, 5)
        img.paste(s, ((size - s.width) // 2, horizon - s.height + int(size * 0.06)), s)
        d.rectangle([0, horizon, size, size], fill=C("0"))
        for i in range(1, 9):
            y = horizon + int((size - horizon) * (i / 8) ** 1.8)
            d.line([(0, y), (size, y)], fill=C("6"))
        for i in range(-8, 9):
            d.line([(size / 2 + i * size * 0.04, horizon), (size / 2 + i * size * 0.25, size)], fill=C("6"))
        d.line([(0, horizon), (size, horizon)], fill=C("9"))
        return img

    def with_ship(img, scale):
        ship = player.resize((player.width * scale, player.height * scale), Image.NEAREST)
        img.paste(ship, ((img.width - ship.width) // 2, img.height - ship.height - img.height // 10), ship)
        return img

    save(with_ship(backdrop(192), 4), "icon", "icon_192.png")
    save(with_ship(backdrop(128), 2), "icon", "icon_128.png")
    save(backdrop(432), "icon", "icon_bg_432.png")
    fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    ship = player.resize((player.width * 7, player.height * 7), Image.NEAREST)
    fg.paste(ship, ((432 - ship.width) // 2, (432 - ship.height) // 2 + 30), ship)
    save(fg, "icon", "icon_fg_432.png")


if __name__ == "__main__":
    gen_font()
    gen_logo()
    gen_player()
    gen_glitch()
    gen_strobe()
    gen_note()
    gen_turret()
    gen_car()
    gen_carrier()
    gen_subwoofer()
    gen_helios()
    gen_bullets()
    gen_pickups()
    gen_city("city_outskirts", 11, dense=False)
    gen_city("city_downtown", 23, dense=True)
    gen_haze()
    gen_title_art()
    gen_icon()
    print("sprites written to", OUT)
