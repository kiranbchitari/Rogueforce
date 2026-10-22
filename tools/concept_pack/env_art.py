"""Jungle terrain tiles and the painted backdrop panorama."""
import sys, os, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cut import cut
from PIL import Image
P, OUT = sys.argv[1], sys.argv[2]
FC = Image.open(P + "/asset_sheet_full_campaign.png").convert("RGB")
T = 256       # tile texture size (64 world px x 4 for 4K)
PAD = 16      # gutter between atlas tiles so mipmaps never bleed

def seamless(im, horizontal=True, vertical=False, band=0.18):
    """Cross-fade each edge with the mirrored image so opposite edges match."""
    w, h = im.size
    out = im.copy(); src = im.load(); o = out.load()
    if horizontal:
        bw = int(w * band)
        for x in range(w):
            d = min(x, w - 1 - x)
            if d >= bw: continue
            t = 0.5 * (1 - d / bw)
            for y in range(h):
                a = src[x, y]; b = src[w - 1 - x, y]
                o[x, y] = tuple(int(a[i] * (1 - t) + b[i] * t) for i in range(len(a)))
    if vertical:
        src = out.copy().load(); bh = int(h * band)
        for y in range(h):
            d = min(y, h - 1 - y)
            if d >= bh: continue
            t = 0.5 * (1 - d / bh)
            for x in range(w):
                a = src[x, y]; b = src[x, h - 1 - y]
                o[x, y] = tuple(int(a[i] * (1 - t) + b[i] * t) for i in range(len(a)))
    return out

def darken(im, f):
    r, g, b, a = im.split()
    return Image.merge("RGBA", [c.point(lambda v: int(v * f)) for c in (r, g, b)] + [a])

def up(im, size):
    k = max(1, -(-size[0] // im.width), -(-size[1] // im.height))
    return im.resize((im.width * k, im.height * k), Image.NEAREST).resize(size, Image.LANCZOS)

S1 = Image.open(P + "/screen_01.jpg").convert("RGB")
top = S1.crop((560, 446, 720, 606)).convert("RGBA")      # dirt path, moss, vines over rock
fill = S1.crop((600, 545, 700, 645)).convert("RGBA")     # boulders below the vines
block = FC.crop((1304, 359, 1349, 399)).convert("RGBA")

def ground_top(im):
    """Playable ground must read differently from the painted scenery:
    richer colour, stronger contrast, a bright walkable lip and a shadow under it."""
    from PIL import ImageEnhance, ImageDraw
    im = ImageEnhance.Contrast(ImageEnhance.Color(im).enhance(1.25)).enhance(1.3)
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, T, 5), fill=(214, 226, 120, 255))      # sunlit grass edge
    d.rectangle((0, 6, T, 9), fill=(120, 150, 52, 255))
    shade = Image.new("RGBA", (T, T))
    sd = ImageDraw.Draw(shade)
    for y in range(40, T):
        sd.line((0, y, T, y), fill=(10, 14, 20, int(min(150, (y - 40) * 1.1))))
    im.alpha_composite(shade)
    return im

tiles = {
    "ground_top": ground_top(seamless(up(top, (T, T)))),
    "ground_fill": darken(seamless(up(fill, (T, T)), vertical=True), 0.5),
    "platform": None,
    "block": up(block, (T, T)),
}
p = Image.new("RGBA", (T, T), (0, 0, 0, 0))
deck = S1.crop((1022, 463, 1098, 491)).convert("RGBA")     # bridge planks between posts
p.alpha_composite(seamless(up(deck, (T, 108))), (0, 0))
tiles["platform"] = p
atlas = Image.new("RGBA", (PAD + 4 * (T + PAD), T + 2 * PAD), (0, 0, 0, 0))
for i, k in enumerate(["ground_top", "ground_fill", "platform", "block"]):
    atlas.alpha_composite(tiles[k], (PAD + i * (T + PAD), PAD))
os.makedirs(OUT + "/environments/jungle", exist_ok=True)
atlas.save(OUT + "/environments/jungle/tiles.png", optimize=True)

# Painted backdrop: five concept screens joined with soft cross-fades.
screens = [Image.open(P + "/screen_%02d.jpg" % i).convert("RGB") for i in (1, 2, 4, 7, 6)]
blend = 200
W = 1280 * len(screens) - blend * (len(screens) - 1)
pano = Image.new("RGB", (W, 720))
x = 0
for i, s in enumerate(screens):
    if i == 0:
        pano.paste(s, (0, 0))
    else:
        # 0 at the left of the overlap (old screen) -> 255 at the right (new screen)
        mask = Image.new("L", (blend, 720))
        mask.putdata([int(255 * x / (blend - 1)) for y in range(720) for x in range(blend)])
        region = pano.crop((x, 0, x + blend, 720))
        mixed = Image.composite(s.crop((0, 0, blend, 720)), region, mask)
        pano.paste(s, (x, 0)); pano.paste(mixed, (x, 0))
    x += 1280 - blend
pano.save(OUT + "/environments/jungle/bg_panorama.png", optimize=True)
meta = {
    "env.jungle.tiles": {"type": "tiles", "path": "res://assets/environments/jungle/tiles.png", "tile_size": [T, T], "margin": PAD, "separation": PAD,
                          "tiles": {"ground_top": [0, 0], "ground_fill": [1, 0], "platform": [2, 0], "block": [3, 0]}},
    "env.jungle.bg_panorama": {"type": "single", "path": "res://assets/environments/jungle/bg_panorama.png", "filter": "nearest"},
}
json.dump(meta, open(OUT + "/_env.json", "w"), indent=1)
print(atlas.size, pano.size)
