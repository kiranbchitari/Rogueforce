"""Cut sprites out of concept boards: flood-fill the panel background to
transparency, keep the item's own pieces, clean colour noise and upscale 4x
with an edge-preserving pixel-art scaler (EPX/Scale2x twice)."""
from PIL import Image, ImageFilter
from collections import deque

def dist2(a, b):
    return (a[0]-b[0])**2 + (a[1]-b[1])**2 + (a[2]-b[2])**2

def cut(src, box, seed, tol=30, keep_extra=True, strip_shadow=True):
    im = src.crop(box).convert("RGB")
    w, h = im.size
    px = im.load()
    border = [px[x, 0] for x in range(w)] + [px[x, h-1] for x in range(w)] + [px[0, y] for y in range(h)] + [px[w-1, y] for y in range(h)]
    border.sort(key=lambda c: c[0]+c[1]+c[2])
    ref = border[len(border)//2]
    t2 = tol*tol
    bg = bytearray(w*h)
    q = deque()
    for x in range(w):
        for y in (0, h-1):
            q.append((x, y))
    for y in range(h):
        for x in (0, w-1):
            q.append((x, y))
    while q:
        x, y = q.popleft()
        i = y*w+x
        if bg[i] or dist2(px[x, y], ref) > t2:
            continue
        # Local reference follows the panel gradient.
        bg[i] = 1
        for nx, ny in ((x+1,y),(x-1,y),(x,y+1),(x,y-1)):
            if 0 <= nx < w and 0 <= ny < h and not bg[ny*w+nx]:
                if dist2(px[nx, ny], px[x, y]) < 14*14 or dist2(px[nx, ny], ref) < t2:
                    q.append((nx, ny))
    # Enclosed pockets of panel colour (between legs, inside arms) are background too.
    seen = bytearray(w*h)
    for i0 in range(w*h):
        if bg[i0] or seen[i0] or dist2(px[i0 % w, i0 // w], ref) > (tol * 0.8) ** 2:
            continue
        stack = [i0]; seen[i0] = 1; region = []
        while stack:
            j = stack.pop(); region.append(j)
            x, y = j % w, j // w
            for nx, ny in ((x+1,y),(x-1,y),(x,y+1),(x,y-1)):
                if 0 <= nx < w and 0 <= ny < h:
                    k = ny*w+nx
                    if not bg[k] and not seen[k] and dist2(px[nx, ny], ref) <= (tol * 0.8) ** 2:
                        seen[k] = 1; stack.append(k)
        if len(region) >= 10:
            for j in region:
                bg[j] = 1
    # Connected components of the foreground.
    comp = [0]*(w*h)
    comps = []
    for i in range(w*h):
        if bg[i] or comp[i]:
            continue
        cid = len(comps)+1
        stack = [i]; comp[i] = cid
        pts = []; touches = False
        while stack:
            j = stack.pop(); pts.append(j)
            x, y = j % w, j // w
            if x == 0 or y == 0 or x == w-1 or y == h-1:
                touches = True
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    nx, ny = x+dx, y+dy
                    if 0 <= nx < w and 0 <= ny < h:
                        k = ny*w+nx
                        if not bg[k] and not comp[k]:
                            comp[k] = cid; stack.append(k)
        comps.append((pts, touches))
    sx, sy = seed[0]-box[0], seed[1]-box[1]
    main = comp[sy*w+sx]
    if main == 0:  # seed landed on background: take the biggest piece
        main = max(range(len(comps)), key=lambda c: len(comps[c][0])) + 1
    keep = set([main])
    if keep_extra:
        for c, (pts, touches) in enumerate(comps, 1):
            if c != main and not touches and len(pts) >= max(6, len(comps[main-1][0]) * 0.02):
                keep.add(c)
    # Painted floor shadows: dark, bluish, low-saturation pixels in the bottom band.
    ys = [i // w for i in range(w*h) if comp[i] in keep]
    if ys and strip_shadow:
        y0 = max(ys) - int((max(ys) - min(ys)) * 0.14)
        for i in range(w*h):
            if comp[i] in keep and i // w >= y0:
                r, g, b = px[i % w, i // w]
                if max(r, g, b) < 70 and b >= r and max(r, g, b) - min(r, g, b) < 26:
                    comp[i] = 0
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    op = out.load()
    for i in range(w*h):
        if comp[i] in keep:
            op[i % w, i // w] = px[i % w, i // w] + (255,)
    return out.crop(out.getbbox())

def denoise(im, colors=96):
    a = im.split()[3]
    rgb = Image.new("RGB", im.size, (0, 0, 0))
    rgb.paste(im.convert("RGB"), mask=a)
    rgb = rgb.filter(ImageFilter.MedianFilter(3)) if colors < 0 else rgb
    q = rgb.quantize(colors=abs(colors), method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    q.putalpha(a)
    return q

def scale2x(im):
    w, h = im.size
    s = im.load()
    out = Image.new("RGBA", (w*2, h*2))
    o = out.load()
    for y in range(h):
        for x in range(w):
            p = s[x, y]
            a = s[x, y-1] if y > 0 else p
            b = s[x+1, y] if x < w-1 else p
            c = s[x-1, y] if x > 0 else p
            d = s[x, y+1] if y < h-1 else p
            e0 = a if (c == a and c != d and a != b) else p
            e1 = b if (a == b and a != c and b != d) else p
            e2 = c if (d == c and d != b and c != a) else p
            e3 = d if (b == d and b != a and d != c) else p
            o[2*x, 2*y] = e0; o[2*x+1, 2*y] = e1; o[2*x, 2*y+1] = e2; o[2*x+1, 2*y+1] = e3
    return out

def upscale4(im, colors=96):
    return scale2x(scale2x(denoise(im, colors)))


def nearest(im, k=4):
    return im.resize((im.width*k, im.height*k), Image.NEAREST)

def sheet(frames, anims, k=4):
    """frames: {anim: [img,...]} -> (sheet image, frame_size, manifest animations).
    Frames are bottom-aligned and centred on their feet."""
    allf = [f for a in anims for f in frames[a]]
    fw = max(f.width for f in allf) + 4
    fh = max(f.height for f in allf) + 2
    cols = max(len(frames[a]) for a in anims)
    out = Image.new("RGBA", (fw*cols, fh*len(anims)), (0, 0, 0, 0))
    for r, a in enumerate(anims):
        for c, f in enumerate(frames[a]):
            # feet centre: mean x of opaque pixels in the bottom 25% rows
            px = f.load(); xs = []
            for y in range(int(f.height*0.75), f.height):
                for x in range(f.width):
                    if px[x, y][3] > 0: xs.append(x)
            cx = sum(xs)/len(xs) if xs else f.width/2
            ox = int(round(fw/2 - cx)); ox = max(0, min(fw - f.width, ox))
            out.alpha_composite(f, (c*fw + ox, r*fh + fh - f.height))
    return nearest(out, k), [fw*k, fh*k]
