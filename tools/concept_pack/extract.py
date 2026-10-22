"""Re-cuts the Jungle Assault concept pack into game sprites.

    python3 tools/concept_pack/extract.py <unzipped pack folder> <output folder>
    python3 tools/concept_pack/env_art.py <unzipped pack folder> <output folder>

Copy the PNGs from the output folder into assets/. Requires Pillow."""
import sys, os, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cut import cut, nearest, sheet
from PIL import Image, ImageDraw
P, OUT = sys.argv[1], sys.argv[2]
FC = Image.open(P + "/asset_sheet_full_campaign.png").convert("RGB")
OV = Image.open(P + "/asset_sheet_overview.png").convert("RGB")
CAT = Image.open(P + "/asset_sheet_enemy_boss_vehicle_catalog.png").convert("RGB")
made = {}
def save(img, rel):
    path = os.path.join(OUT, rel); os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=True); made[rel] = img
    return img

# --- player (overview board: one consistent character with many frames) ---
def ov(box, seed): return cut(OV, box, seed)
frames = {
    "idle":   [ov((2, 298, 68, 378), (37, 345))],
    "run":    [ov((64, 298, 130, 378), (93, 345)), ov((116, 298, 190, 378), (150, 345)), ov((168, 298, 238, 378), (203, 345)), ov((225, 298, 285, 378), (257, 345)), ov((276, 298, 334, 378), (307, 345))],
    "jump":   [ov((330, 298, 366, 378), (350, 335)), ov((362, 298, 400, 378), (385, 335))],
    "crouch": [cut(FC, (200, 470, 275, 532), (235, 505))],
    "hurt":   [ov((248, 403, 302, 482), (273, 445))],
    "die":    [ov((372, 425, 432, 482), (407, 462)), ov((430, 425, 486, 482), (460, 455))],
}
anims = ["idle", "run", "jump", "crouch", "hurt", "die"]
img, fs = sheet(frames, anims)
save(img, "characters/commando_sheet.png")
player_anims = {a: {"row": i, "frames": len(frames[a]), "fps": {"run": 12, "jump": 6, "die": 4}.get(a, 6), "loop": a not in ("die", "hurt")} for i, a in enumerate(anims)}
made_meta = {"char.commando": {"type": "sheet", "path": "res://assets/characters/commando_sheet.png", "frame_size": fs, "animations": player_anims}}

# --- singles ---
singles = {
    "enemy.infantry": ("enemies/infantry.png", FC, (603, 438, 685, 521), (640, 480)),
    "enemy.heavy": ("enemies/heavy.png", FC, (688, 438, 758, 521), (720, 480)),
    "enemy.shield_trooper": ("enemies/shield_trooper.png", FC, (775, 438, 845, 521), (810, 480)),
    "enemy.grenadier": ("enemies/grenadier.png", FC, (875, 438, 950, 521), (905, 480)),
    "enemy.sniper": ("enemies/sniper.png", FC, (955, 438, 1032, 521), (990, 480)),
    "enemy.drone": ("enemies/drone.png", CAT, (8, 688, 85, 752), (50, 718)),
    "enemy.turret": ("enemies/turret.png", CAT, (468, 692, 548, 752), (500, 720)),
    "enemy.raider_buggy": ("enemies/raider_buggy.png", FC, (1042, 436, 1175, 521), (1100, 490)),
    "prop.fuel_barrel": ("props/fuel_barrel.png", OV, (1378, 377, 1410, 436), (1393, 410)),
    "env.jungle.prop_crate": ("environments/jungle/prop_crate.png", OV, (1125, 377, 1182, 428), (1150, 402)),
    "env.jungle.prop_sandbags": ("environments/jungle/prop_sandbags.png", OV, (1472, 377, 1528, 432), (1500, 410)),
    "env.jungle.prop_fern": ("environments/jungle/prop_fern.png", FC, (163, 860, 212, 910), (185, 895)),
    "boss.warden_tank": ("bosses/warden_tank.png", FC, (8, 688, 252, 826), (130, 770)),
    "boss.hornet_gunship": ("bosses/hornet_gunship.png", FC, (420, 682, 708, 793), (560, 745)),
    "pickup.spread": ("pickups/spread.png", FC, (1058, 758, 1120, 803), (1090, 780)),
    "pickup.laser": ("pickups/laser.png", FC, (1125, 758, 1175, 803), (1150, 780)),
    "pickup.mg": ("pickups/machine_gun.png", FC, (1165, 686, 1240, 716), (1200, 700)),
    "pickup.extra_life": ("pickups/extra_life.png", FC, (1395, 758, 1450, 803), (1420, 780)),
    "pickup.medkit": ("pickups/medkit.png", FC, (1455, 758, 1518, 803), (1487, 780)),
}
for aid, (rel, src, box, seed) in singles.items():
    im = cut(src, box, seed, strip_shadow=not aid.startswith("pickup"))
    save(nearest(im), rel)
    made_meta[aid] = {"type": "single", "path": "res://assets/" + rel}
for aid in ("boss.warden_tank",):
    made_meta[aid]["faces_left"] = True
for aid in [a for a in made_meta if a.startswith("pickup.") or a.startswith("env.jungle.prop")]:
    made_meta[aid]["fit"] = "contain"

# Gunship: drop a neighbouring helicopter fragment and baked-in missile exhaust.
def _clean_heli(path):
    im = Image.open(path).convert("RGBA"); px = im.load()
    k = im.height / 96.0; cx, cy = im.width / 2, im.height / 2
    def erase(x0, y0, x1, y1, only_hot=False):
        for X in range(int(cx + x0 * k), int(cx + x1 * k)):
            for Y in range(int(cy + y0 * k), int(cy + y1 * k)):
                if 0 <= X < im.width and 0 <= Y < im.height:
                    r, g, b, a = px[X, Y]
                    if not only_hot or (r > 170 and r > b + 40):
                        px[X, Y] = (0, 0, 0, 0)
    erase(-160, 12, -104, 60)
    erase(-60, 26, -6, 48, True); erase(70, 26, 140, 48, True); erase(40, 26, 66, 42, True)
    im.crop(im.getbbox()).save(path, optimize=True)
_clean_heli(os.path.join(OUT, "bosses/hornet_gunship.png"))

json.dump(made_meta, open(os.path.join(OUT, "_extracted.json"), "w"), indent=1)

# preview contact sheet for review
prev = Image.new("RGBA", (1600, 1300), (70, 100, 80, 255)); x = y = 0; rowh = 0
for rel, im in made.items():
    t = im.copy(); t.thumbnail((300, 260))
    if x + t.width > 1600: x = 0; y += rowh + 20; rowh = 0
    prev.alpha_composite(t, (x, y)); ImageDraw.Draw(prev).text((x, y + t.height), rel.split("/")[-1], fill=(255, 255, 0))
    x += t.width + 10; rowh = max(rowh, t.height)
prev.save(os.path.join(OUT, "_preview.png"))
print("\n".join(f"{k}: {v.size}" for k, v in made.items()))
