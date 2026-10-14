#!/usr/bin/env python3
"""Level 2 (NEON TIDE) placeholder art: nautical enemies, bullets, LEVIATHAN and sea tiles.

Uses the same 16-colour palette and helpers as gen_sprites.py (which calls this at the end).
Run on its own from the repo root:  python3 tools/gen_sprites_sea.py
"""
import math
import random

from PIL import Image, ImageDraw

from gen_sprites import C, PAL, outline, save, circle, dither_on, from_ascii, palm, shadow_rect

W, H = 270, 480


# ---------------------------------------------------------------- small craft (all point down)

def gen_jetski():
    img = Image.new("RGBA", (12, 18), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(1, 0), (10, 0), (11, 9), (6, 17), (5, 17), (0, 9)], fill=C("6"))
    d.polygon([(3, 1), (8, 1), (9, 8), (6, 14), (5, 14), (2, 8)], fill=C("w"))
    d.line([(5, 2), (5, 13)], fill=C("c"))
    d.line([(6, 2), (6, 13)], fill=C("c"))
    circle(d, 5.5, 6, 2, C("1"))  # rider
    img.putpixel((5, 5), C("8"))
    save(outline(img), "sprites", "jetski.png")


def gen_mine():
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for a in range(8):
        ang = a * math.pi / 4
        x, y = 7.5 + math.cos(ang) * 7, 7.5 + math.sin(ang) * 7
        d.line([(7.5, 7.5), (x, y)], fill=C("g"))
    circle(d, 7.5, 7.5, 5, C("d"))
    circle(d, 6.5, 6.5, 3, C("g"))
    d.point((5, 5), fill=C("l"))
    circle(d, 7.5, 7.5, 1, C("5"))
    save(outline(img), "sprites", "mine.png")


def gen_harpooner():
    img = Image.new("RGBA", (22, 30), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(2, 0), (19, 0), (21, 18), (11, 29), (10, 29), (0, 18)], fill=C("d"))
    d.polygon([(4, 2), (17, 2), (18, 17), (11, 26), (10, 26), (3, 17)], fill=C("2"))
    d.rectangle([6, 4, 15, 10], fill=C("g"))
    d.rectangle([7, 5, 14, 6], fill=C("l"))
    d.rectangle([8, 8, 13, 9], fill=C("c"))
    # harpoon gun on the bow
    d.rectangle([9, 14, 12, 18], fill=C("g"))
    d.rectangle([10, 18, 11, 25], fill=C("l"))
    d.point((10, 25), fill=C("5"))
    d.point((11, 25), fill=C("5"))
    for y in (12, 20):
        d.point((3, y), fill=C("5"))
        d.point((18, y), fill=C("5"))
    save(outline(img), "sprites", "harpooner.png")


def gen_inker():
    img = Image.new("RGBA", (18, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # mantle (top) and tentacles hanging down towards the player
    d.ellipse([2, 0, 15, 13], fill=C("3"))
    d.ellipse([4, 1, 12, 8], fill=C("4"))
    d.point((6, 3), fill=C("w"))
    for i, x in enumerate((3, 6, 9, 11, 14)):
        wob = 1 if i % 2 else -1
        d.line([(x, 11), (x + wob, 17), (x, 22)], fill=C("6"))
    d.point((6, 9), fill=C("c"))
    d.point((11, 9), fill=C("c"))
    d.rectangle([7, 11, 10, 13], fill=C("1"))  # ink sac nozzle
    save(outline(img), "sprites", "inker.png")


def gen_torpedo_boat():
    img = Image.new("RGBA", (26, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(3, 0), (22, 0), (25, 20), (13, 31), (12, 31), (0, 20)], fill=C("1"))
    d.polygon([(5, 2), (20, 2), (22, 19), (13, 28), (12, 28), (3, 19)], fill=C("d"))
    d.rectangle([8, 4, 17, 9], fill=C("g"))
    d.line([(8, 4), (17, 4)], fill=C("l"))
    # twin torpedo tubes
    for x in (6, 17):
        d.rectangle([x, 12, x + 2, 24], fill=C("0"))
        d.rectangle([x, 22, x + 2, 24], fill=C("7"))
    d.line([(12, 11), (12, 26)], fill=C("c"))
    d.line([(13, 11), (13, 26)], fill=C("c"))
    save(outline(img), "sprites", "torpedo_boat.png")


def gen_frigate():
    img = Image.new("RGBA", (34, 50), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(6, 0), (27, 0), (33, 24), (18, 49), (15, 49), (0, 24)], fill=C("d"))
    d.polygon([(8, 2), (25, 2), (30, 24), (17, 45), (16, 45), (3, 24)], fill=C("g"))
    d.polygon([(10, 4), (23, 4), (25, 14), (8, 14)], fill=C("l"))
    # superstructure + sonar dome
    d.rectangle([11, 16, 22, 28], fill=C("1"))
    circle(d, 16.5, 22, 5, C("2"))
    circle(d, 16.5, 22, 3, C("c"))
    circle(d, 16.5, 22, 1, C("w"))
    for y in (8, 32, 38):
        d.point((6, y), fill=C("5"))
        d.point((27, y), fill=C("5"))
    d.line([(16, 30), (16, 44)], fill=C("m"))
    d.line([(17, 30), (17, 44)], fill=C("m"))
    save(outline(img), "sprites", "frigate.png")


def gen_trawler():
    img = Image.new("RGBA", (32, 30), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(4, 0), (27, 0), (31, 16), (17, 29), (14, 29), (0, 16)], fill=C("2"))
    d.polygon([(6, 2), (25, 2), (28, 15), (16, 26), (15, 26), (3, 15)], fill=C("3"))
    # cargo hold with the weapon capsule
    d.rectangle([10, 4, 21, 13], fill=C("1"))
    d.rectangle([12, 6, 19, 11], fill=C("m"))
    d.rectangle([14, 7, 17, 10], fill=C("w"))
    # net crane
    d.line([(4, 18), (27, 18)], fill=C("g"))
    d.line([(15, 14), (15, 24)], fill=C("l"))
    for x in range(6, 26, 3):
        d.point((x, 20), fill=C("4"))
    d.point((4, 8), fill=C("8"))
    d.point((27, 8), fill=C("8"))
    save(outline(img), "sprites", "trawler.png")


def gen_barracuda():
    """Mid-boss submarine, pointing down."""
    img = Image.new("RGBA", (30, 70), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([3, 0, 26, 69], fill=C("d"))
    d.ellipse([5, 2, 24, 66], fill=C("g"))
    d.ellipse([8, 4, 15, 50], fill=C("l"))
    # conning tower
    d.rounded_rectangle([10, 20, 19, 36], radius=3, fill=C("1"))
    d.rectangle([12, 23, 17, 25], fill=C("c"))
    # torpedo doors at the bow
    for x in (9, 13, 17):
        d.rectangle([x, 56, x + 2, 62], fill=C("0"))
        d.point((x + 1, 61), fill=C("7"))
    # neon seams + tail fins
    d.line([(5, 44), (24, 44)], fill=C("6"))
    d.polygon([(0, 4), (8, 8), (6, 14)], fill=C("2"))
    d.polygon([(29, 4), (21, 8), (23, 14)], fill=C("2"))
    save(outline(img), "sprites", "barracuda.png")


def gen_torpedo():
    img = Image.new("RGBA", (6, 14), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([1, 0, 4, 12], radius=2, fill=C("g"))
    d.line([(2, 1), (2, 10)], fill=C("l"))
    d.rectangle([1, 11, 4, 13], fill=C("5"))
    d.point((0, 1), fill=C("d"))
    d.point((5, 1), fill=C("d"))
    save(outline(img), "sprites", "torpedo.png")


# ---------------------------------------------------------------- bullets

def gen_sea_bullets():
    # harpoon (points down; rotated in game)
    hp = Image.new("RGBA", (5, 14), (0, 0, 0, 0))
    d = ImageDraw.Draw(hp)
    d.line([(2, 0), (2, 10)], fill=C("l"))
    d.polygon([(0, 10), (4, 10), (2, 13)], fill=C("w"))
    d.point((1, 9), fill=C("5"))
    d.point((3, 9), fill=C("5"))
    save(outline(hp), "sprites", "b_harpoon.png")
    # chain link left in the harpoon's wake
    ln = Image.new("RGBA", (5, 5), (0, 0, 0, 0))
    d = ImageDraw.Draw(ln)
    d.ellipse([0, 0, 4, 4], outline=C("8"))
    d.point((2, 2), fill=C("w"))
    save(outline(ln), "sprites", "b_link.png")
    # geyser water droplet
    gy = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
    d = ImageDraw.Draw(gy)
    circle(d, 3.5, 3.5, 3.5, C("m"))
    circle(d, 3, 3, 2, C("w"))
    save(outline(gy), "sprites", "b_geyser.png")
    # sonar pellet
    sn = Image.new("RGBA", (6, 6), (0, 0, 0, 0))
    d = ImageDraw.Draw(sn)
    circle(d, 2.5, 2.5, 2.5, C("c"))
    circle(d, 2.5, 2.5, 1, C("w"))
    save(outline(sn), "sprites", "b_sonar.png")


# ---------------------------------------------------------------- TITAN-02 LEVIATHAN (mecha-whale)

def gen_leviathan():
    BW, BH = 104, 150
    img = Image.new("RGBA", (BW, BH), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = BW // 2
    # tail flukes at the top
    d.polygon([(cx, 26), (cx - 48, 2), (cx - 30, 0), (cx - 6, 12)], fill=C("d"))
    d.polygon([(cx, 26), (cx + 48, 2), (cx + 30, 0), (cx + 6, 12)], fill=C("d"))
    d.polygon([(cx - 4, 22), (cx - 40, 4), (cx - 30, 3), (cx - 6, 14)], fill=C("g"))
    d.polygon([(cx + 4, 22), (cx + 40, 4), (cx + 30, 3), (cx + 6, 14)], fill=C("g"))
    # body: an ellipse-ish hull widening towards the head (bottom)
    pts = []
    for i in range(0, 41):
        t = i / 40
        y = 18 + t * (BH - 20)
        half = 8 + 36 * math.sin(min(1.0, t * 1.25) * math.pi / 2) ** 1.2
        if t > 0.85:
            half *= max(0.0, 1 - (t - 0.85) / 0.15 * 0.55)
        pts.append((cx - half, y))
    right = [(2 * cx - x, y) for (x, y) in reversed(pts)]
    hull = pts + right
    d.polygon(hull, fill=C("d"))
    inner = [(cx + (x - cx) * 0.9, y) for (x, y) in hull]
    d.polygon(inner, fill=C("g"))
    # chrome banding (plates) and a light dorsal stripe
    for y in range(34, BH - 22, 12):
        half = min((cx - x for (x, py) in pts if abs(py - y) < 2.5), default=0) * 0.85
        d.line([(cx - half, y), (cx + half, y)], fill=C("d"))
    d.polygon([(cx - 6, 20), (cx + 6, 20), (cx + 10, 100), (cx - 10, 100)], fill=C("l"))
    # neon seams along the flanks
    for s in (-1, 1):
        d.line([(cx + s * 20, 40), (cx + s * 32, 70), (cx + s * 34, 100), (cx + s * 26, 126)], fill=C("c"))
        d.point((cx + s * 33, 85), fill=C("w"))
    # blowhole
    circle(d, cx, 96, 5, C("1"))
    circle(d, cx, 96, 3, C("2"))
    circle(d, cx, 96, 1, C("m"))
    # eyes on the sides of the head
    for s in (-1, 1):
        circle(d, cx + s * 30, 122, 3, C("0"))
        circle(d, cx + s * 30, 122, 2, C("5"))
        d.point((cx + s * 30 - 1, 121), fill=C("w"))
    # mouth cavity (the core sits here once the jaw opens)
    d.ellipse([cx - 18, 124, cx + 18, 148], fill=C("0"))
    d.ellipse([cx - 15, 126, cx + 15, 146], fill=C("1"))
    save(outline(img), "sprites", "leviathan_body.png")

    # jaw plate (left half; mirrored in game)
    jaw = Image.new("RGBA", (20, 26), (0, 0, 0, 0))
    d = ImageDraw.Draw(jaw)
    d.polygon([(19, 0), (4, 2), (0, 12), (8, 24), (19, 25)], fill=C("d"))
    d.polygon([(19, 1), (6, 3), (2, 12), (9, 22), (19, 23)], fill=C("g"))
    for y in range(5, 22, 4):
        d.line([(12, y), (18, y)], fill=C("l"))
    d.line([(19, 1), (19, 24)], fill=C("c"))
    for x in (10, 14, 18):
        d.point((x, 24), fill=C("w"))  # teeth
    save(outline(jaw), "sprites", "leviathan_jaw.png")

    # pectoral fin cannon (left; mirrored for right)
    fin = Image.new("RGBA", (34, 36), (0, 0, 0, 0))
    d = ImageDraw.Draw(fin)
    d.polygon([(33, 2), (33, 16), (6, 34), (0, 30), (14, 8)], fill=C("d"))
    d.polygon([(32, 4), (32, 14), (8, 31), (3, 29), (15, 10)], fill=C("g"))
    d.line([(31, 6), (6, 30)], fill=C("6"))
    # cannon pod at the fin tip
    circle(d, 7, 28, 6, C("1"))
    circle(d, 7, 28, 4, C("2"))
    d.rectangle([5, 30, 9, 35], fill=C("l"))
    d.rectangle([6, 33, 8, 35], fill=C("7"))
    save(outline(fin), "sprites", "leviathan_fin.png")

    # abyssal reactor core
    core = Image.new("RGBA", (30, 30), (0, 0, 0, 0))
    d = ImageDraw.Draw(core)
    circle(d, 14.5, 14.5, 14, C("2"))
    circle(d, 14.5, 14.5, 12, C("c"))
    circle(d, 14.5, 14.5, 9, C("m"))
    circle(d, 14.5, 14.5, 6, C("w"))
    for a in range(6):
        ang = a * math.pi / 3
        d.line([(14.5, 14.5), (14.5 + math.cos(ang) * 12, 14.5 + math.sin(ang) * 12)], fill=C("c"))
    circle(d, 14.5, 14.5, 3, C("w"))
    save(outline(core), "sprites", "leviathan_core.png")


# ---------------------------------------------------------------- sea tiles

HWY_EDGE = 14


def pier(img, rng, x0, x1, y):
    d = ImageDraw.Draw(img)
    shadow_rect(img, (x0, y, x1, y + 7), 2)
    d.rectangle([x0, y, x1, y + 7], fill=C("1"))
    for x in range(x0, x1, 4):
        d.line([(x, y), (x, y + 7)], fill=C("2"))
    d.line([(x0, y), (x1, y)], fill=C("4"))
    for x in range(x0 + 2, x1, 10):
        d.point((x, y + 3), fill=C("8"))  # dock lights


def moored_boat(img, rng, x, y, flip):
    d = ImageDraw.Draw(img)
    w, h = rng.randint(8, 12), rng.randint(16, 24)
    col = rng.choice(("6", "4", "c", "l"))
    d.ellipse([x, y, x + w, y + h], fill=C(col))
    d.ellipse([x + 2, y + 3, x + w - 2, y + h - 5], fill=C("w"))
    d.rectangle([x + 3, y + h // 3, x + w - 3, y + h // 3 + 4], fill=C("1"))


def rig(img, rng, cx, cy):
    """Oil/neon rig platform."""
    d = ImageDraw.Draw(img)
    s = rng.randint(16, 22)
    shadow_rect(img, (cx - s, cy - s, cx + s, cy + s), 4)
    d.rectangle([cx - s, cy - s, cx + s, cy + s], fill=C("d"))
    d.rectangle([cx - s + 2, cy - s + 2, cx + s - 2, cy + s - 2], fill=C("1"))
    for k in range(-s + 4, s - 2, 6):
        d.line([(cx - s + 2, cy + k), (cx + s - 2, cy + k)], fill=C("2"))
    # helipad / derrick
    circle(d, cx + s // 3, cy - s // 3, s // 3, C("8"))
    circle(d, cx + s // 3, cy - s // 3, s // 3 - 2, C("1"))
    d.line([(cx - s + 4, cy + s - 4), (cx - 2, cy - 2)], fill=C("g"))
    d.line([(cx - s + 4, cy - 2), (cx - 2, cy + s - 4)], fill=C("g"))
    for (x, y) in ((cx - s, cy - s), (cx + s, cy - s), (cx - s, cy + s), (cx + s, cy + s)):
        d.point((x, y), fill=C("5"))
    d.line([(cx - s, cy + s - 1), (cx + s, cy + s - 1)], fill=C("c"))


def rock(img, rng, cx, cy):
    d = ImageDraw.Draw(img)
    r = rng.randint(6, 13)
    pts = [(cx + math.cos(a) * r * rng.uniform(0.7, 1.1), cy + math.sin(a) * r * rng.uniform(0.7, 1.1))
           for a in [i * math.pi / 4 for i in range(8)]]
    d.polygon(pts, fill=C("1"))
    d.polygon([(x - 1, y - 1) for (x, y) in pts[:5]], fill=C("2"))
    # foam ring
    d.ellipse([cx - r - 2, cy - r - 2, cx + r + 2, cy + r + 2], outline=C("c", 150))


def buoy(img, x, y, col):
    d = ImageDraw.Draw(img)
    circle(d, x, y, 2, C(col))
    d.point((x, y - 1), fill=C("w"))


def gen_sea(name, seed, harbour):
    rng = random.Random(seed)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    if harbour:
        # quays along both edges with piers reaching into the water
        d = ImageDraw.Draw(img)
        for side in (0, 1):
            x0, x1 = (0, 22) if side == 0 else (W - 23, W - 1)
            d.rectangle([x0, 0, x1, H - 1], fill=C("1"))
            d.line([((x1 if side == 0 else x0), 0), ((x1 if side == 0 else x0), H - 1)], fill=C("c"))
            for y in range(6, H, 16):
                d.rectangle([x0 + 4, y, x0 + 10, y + 6], fill=C("d"))  # warehouses/containers
                d.point((x0 + 7, y + 3), fill=rng.choice((C("5"), C("8"), C("m"))))
            for y in range(HWY_EDGE + 10, H - HWY_EDGE - 10, rng.randint(70, 90)):
                if side == 0:
                    pier(img, rng, x1, x1 + rng.randint(30, 60), y)
                    moored_boat(img, rng, x1 + 6, y + 10, False)
                else:
                    pier(img, rng, x0 - rng.randint(30, 60), x0, y)
                    moored_boat(img, rng, x0 - 16, y + 10, True)
        for _ in range(10):
            buoy(img, rng.randint(40, W - 40), rng.randint(HWY_EDGE, H - HWY_EDGE), rng.choice(("5", "m")))
        # lighthouse
        lx, ly = 11, rng.randint(150, 300)
        circle(ImageDraw.Draw(img), lx, ly, 6, C("w"))
        circle(ImageDraw.Draw(img), lx, ly, 3, C("8"))
    else:
        for _ in range(rng.randint(1, 2)):
            rig(img, rng, rng.choice((40, W - 40)) + rng.randint(-10, 10), rng.randint(60, H - 80))
        for _ in range(rng.randint(5, 8)):
            rock(img, rng, rng.randint(14, W - 14), rng.randint(HWY_EDGE + 10, H - HWY_EDGE - 10))
        for _ in range(6):
            buoy(img, rng.randint(20, W - 20), rng.randint(HWY_EDGE, H - HWY_EDGE), rng.choice(("5", "m", "8")))
    save(img, "bg", name + ".png")


def gen_spray():
    """Sea-spray layer (the nautical counterpart of haze.png)."""
    rng = random.Random(77)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()
    blobs = [(rng.uniform(0, W), rng.uniform(0, H), rng.uniform(20, 50), rng.uniform(6, 14),
              rng.choice(("c", "w", "4"))) for _ in range(12)]
    for y in range(H):
        for x in range(W):
            best, col = 0.0, None
            for bx, by, rx, ry, c in blobs:
                for oy in (-H, 0, H):
                    dx, dy = (x - bx) / rx, (y - (by + oy)) / ry
                    v = 1 - (dx * dx + dy * dy)
                    if v > best:
                        best, col = v, c
            if col and best > 0 and dither_on(x, y, best * 0.45):
                px[x, y] = C(col, 60)
    save(img, "bg", "spray.png")


def main():
    gen_jetski()
    gen_mine()
    gen_harpooner()
    gen_inker()
    gen_torpedo_boat()
    gen_frigate()
    gen_trawler()
    gen_barracuda()
    gen_torpedo()
    gen_sea_bullets()
    gen_leviathan()
    gen_sea("sea_harbour", 31, harbour=True)
    gen_sea("sea_open", 47, harbour=False)
    gen_spray()


if __name__ == "__main__":
    main()
    print("sea sprites written")
