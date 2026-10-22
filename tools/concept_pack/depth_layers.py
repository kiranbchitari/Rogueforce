"""Turns the flat jungle backdrop into depth layers.

    python3 tools/concept_pack/depth_layers.py <unzipped pack folder> assets/environments/jungle

Writes:
  bg_far.png    sky, mountains and mist (near scenery replaced by soft haze)
  bg_near.png   cliffs, towers and bridges on transparency, misted at the base
  fg_leaves.png dark, out-of-focus foliage that passes in front of the action
Needs bg_panorama.png (from env_art.py) in the output folder. Requires Pillow.
"""
import os, sys, random
from PIL import Image, ImageFilter, ImageChops, ImageEnhance

P, OUT = sys.argv[1], sys.argv[2]
HAZE = (176, 204, 204)
pano = Image.open(os.path.join(OUT, "bg_panorama.png")).convert("RGB")
W, H = pano.size

# 1. Far/near mask: bluish or very bright pixels are distance (sky, haze, falls).
px = pano.load()
mask = Image.new("L", (W, H)); mp = mask.load()
for y in range(H):
    for x in range(W):
        r, g, b = px[x, y]
        lum = (r * 3 + g * 6 + b) / 10
        mp[x, y] = 255 if ((b > r + 12 and b >= g - 6 and lum > 95) or (lum > 200 and abs(r - b) < 40)) else 0
mask = mask.filter(ImageFilter.MedianFilter(9)).filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.GaussianBlur(2.0))
near_alpha = ImageChops.invert(mask)

# 2. Far layer: keep distant pixels, fill the rest with a soft blur of the distance.
far_only = Image.composite(pano, Image.new("RGB", (W, H)), mask)
blur_rgb = far_only.filter(ImageFilter.GaussianBlur(40))
blur_m = mask.filter(ImageFilter.GaussianBlur(40))
bp, bm = blur_rgb.load(), blur_m.load()
fill = Image.new("RGB", (W, H)); fp = fill.load()
for y in range(H):
    for x in range(W):
        m = bm[x, y] / 255.0
        c = bp[x, y]
        # Where little distance is nearby, fall back to plain haze (no halo artefacts).
        k = min(1.0, max(0.0, (m - 0.12) / 0.25))
        fp[x, y] = tuple(int(HAZE[i] * (1 - k) + min(255, c[i] / max(m, 0.01)) * k) for i in range(3))
far = Image.composite(pano, fill, mask).filter(ImageFilter.GaussianBlur(0.8))
far = ImageEnhance.Color(far).enhance(0.75)
far = Image.blend(far, Image.new("RGB", (W, H), HAZE), 0.32)
far.save(os.path.join(OUT, "bg_far.png"), optimize=True)

# 3. Near layer: scenery on transparency, lightly hazed, fading into river mist at the base.
near = Image.blend(pano, Image.new("RGB", (W, H), HAZE), 0.24)
near = ImageEnhance.Contrast(ImageEnhance.Color(near).enhance(0.8)).enhance(0.85)
mist = Image.new("L", (W, H)); mi = mist.load()
for y in range(H):
    t = max(0.0, (y / H - 0.45) / 0.45)          # river mist: 0 above 55% height, 1 at the bottom
    top = max(0.0, 1.0 - y / (H * 0.5)) * 0.7  # distant scenery near the top recedes into haze
    v = int(255 * min(1.0, t * 0.95 + top))
    for x in range(W):
        mi[x, y] = v
near = Image.composite(Image.new("RGB", (W, H), HAZE), near, mist)
near.putalpha(near_alpha)
near.save(os.path.join(OUT, "bg_near.png"), optimize=True)

# 4. Foreground foliage: palms and bushes cut from the board, darkened and defocused.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cut import cut
FC = Image.open(os.path.join(P, "asset_sheet_full_campaign.png")).convert("RGB")
plants = [cut(FC, (552, 850, 682, 950), (600, 900), strip_shadow=False)]
def silhouette(im, scale):
    im = im.resize((int(im.width * scale), int(im.height * scale)), Image.LANCZOS)
    r, g, b, a = im.split()
    dark = Image.merge("RGBA", (r.point(lambda v: int(v * 0.16)), g.point(lambda v: int(v * 0.24)), b.point(lambda v: int(v * 0.2)), a))
    return dark.filter(ImageFilter.GaussianBlur(scale * 0.9))
random.seed(5)
FW, FH = 3600, 340
fg = Image.new("RGBA", (FW, FH))
x = 120
while x < FW - 300:
    piece = silhouette(plants[0], random.uniform(2.2, 3.4))
    if random.random() < 0.5:
        piece = piece.transpose(Image.FLIP_LEFT_RIGHT)
    piece = piece.crop((0, 0, piece.width, min(piece.height, FH)))
    fg.alpha_composite(piece, (x, FH - piece.height + random.randint(10, 70) if piece.height > 80 else FH - piece.height))
    x += int(piece.width * random.uniform(2.2, 4.0))
fg = fg.crop((0, 0, FW, FH))
fg.save(os.path.join(OUT, "fg_leaves.png"), optimize=True)
print("far", far.size, "near", near.size, "fg", fg.size)
