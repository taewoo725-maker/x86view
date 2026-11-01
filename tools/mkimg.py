import struct, math, random, os, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter
random.seed(7)

def make_art(w=512, h=212):
    img = Image.new('RGB', (w, h))
    d = ImageDraw.Draw(img)
    # sky gradient
    top = (18, 14, 70); mid = (200, 70, 110); low = (255, 170, 80)
    hor = int(h*0.62)
    for y in range(hor):
        t = y / hor
        if t < .55:
            u = t/.55; c = tuple(int(top[i]+(mid[i]-top[i])*u) for i in range(3))
        else:
            u = (t-.55)/.45; c = tuple(int(mid[i]+(low[i]-mid[i])*u) for i in range(3))
        d.line([(0, y), (w, y)], fill=c)
    # stars
    for _ in range(70):
        x = random.randrange(w); y = random.randrange(int(hor*.5))
        v = random.randrange(150, 255)
        d.point((x, y), fill=(v, v, v))
    # sun
    cx, cy, r = int(w*.62), hor-6, int(h*.17)
    for k in range(r, 0, -1):
        t = k / r
        c = (255, int(210-60*t), int(110-80*t))
        d.ellipse([cx-k*1.0*(w/256)/2*2/2*1, cy-k, cx+k*(w/256)/1, cy+k], fill=c) if False else d.ellipse([cx-k*w/256, cy-k, cx+k*w/256, cy+k], fill=c)
    # mountains
    def mount(base, amp, seed, col):
        random.seed(seed)
        pts = [(0, h)]
        ph = [random.random()*6.28 for _ in range(3)]
        for x in range(0, w+1, 4):
            y = base - amp*(0.55*math.sin(x/w*5+ph[0]) + 0.3*math.sin(x/w*11+ph[1]) + 0.15*math.sin(x/w*23+ph[2]))
            pts.append((x, y))
        pts.append((w, h))
        d.polygon(pts, fill=col)
    mount(hor-4, 26, 3, (60, 30, 90))
    mount(hor+6, 20, 5, (35, 18, 62))
    # water
    for y in range(hor+10, h):
        t = (y-hor-10)/(h-hor-10)
        c = (int(40+80*(1-t)), int(20+40*(1-t)), int(70+30*(1-t)))
        d.line([(0, y), (w, y)], fill=c)
    # sun reflection
    for y in range(hor+10, h, 3):
        t = (y-hor)/(h-hor)
        ww = int((1-t*0.4)*w*0.06)
        sh = int(math.sin(y*1.7)*w*0.01)
        d.line([(cx-ww+sh, y), (cx+ww+sh, y)], fill=(255, int(170-90*t), int(90-50*t)))
    # title
    try:
        f = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', int(h*0.13))
    except Exception:
        f = ImageFont.load_default()
    txt = 'X86VIEW'
    tw = d.textlength(txt, font=f)
    d.text(((w-tw)/2*0.5, 10), txt, font=f, fill=(255, 245, 230))
    return img

def q3(c): return round(c*7/255)

def bsave(path, data, start=0):
    end = start + len(data) - 1
    with open(path, 'wb') as f:
        f.write(bytes([0xFE]) + struct.pack('<HHH', start, end, 0) + data)

def pal_bytes(pal):
    out = bytearray()
    for r, g, b in pal:
        out += bytes([(r << 4) | b, g])
    return bytes(out)

def quant(img, n, dither=True):
    p = img.quantize(colors=n, method=Image.MEDIANCUT, dither=Image.FLOYDSTEINBERG if dither else Image.NONE)
    pl = p.getpalette()[:n*3]
    pal = [(q3(pl[i*3]), q3(pl[i*3+1]), q3(pl[i*3+2])) for i in range(n)]
    # remap with the rounded palette
    pp = Image.new('P', (1, 1)); flat = []
    for r, g, b in pal: flat += [r*255//7, g*255//7, b*255//7]
    flat += flat[:3]*(256-n)
    pp.putpalette(flat)
    p2 = img.quantize(palette=pp, dither=Image.FLOYDSTEINBERG if dither else Image.NONE)
    p2 = p2.point([i if i < n else 0 for i in range(256)])
    return p2, pal

def make_sc5(art):
    im = art.resize((256, 212), Image.LANCZOS)
    p, pal = quant(im, 16)
    px = p.load(); data = bytearray(0x76A0)
    for y in range(212):
        for x in range(0, 256, 2):
            data[y*128 + x//2] = (px[x, y] << 4) | px[x+1, y]
    data[0x7680:0x76A0] = pal_bytes(pal)
    return bytes(data)

def make_sc6(art):
    im = art.resize((512, 212), Image.LANCZOS)
    p, pal = quant(im, 4)
    pal += [(0, 0, 0)]*12
    px = p.load(); data = bytearray(0x76A0)
    for y in range(212):
        for x in range(0, 512, 4):
            data[y*128 + x//4] = (px[x, y] << 6) | (px[x+1, y] << 4) | (px[x+2, y] << 2) | px[x+3, y]
    data[0x7680:0x76A0] = pal_bytes(pal)
    return bytes(data)

def make_sc7(art):
    im = art.resize((512, 212), Image.LANCZOS)
    p, pal = quant(im, 16)
    px = p.load(); data = bytearray(0xFAA0)
    for y in range(212):
        for x in range(0, 512, 2):
            data[y*256 + x//2] = (px[x, y] << 4) | px[x+1, y]
    data[0xFA80:0xFAA0] = pal_bytes(pal)
    return bytes(data)

def make_sc8(art):
    im = art.resize((256, 212), Image.LANCZOS)
    pp = Image.new('P', (1, 1)); flat = []
    for i in range(256):
        g = (i >> 5) & 7; r = (i >> 2) & 7; b = i & 3
        flat += [r*255//7, g*255//7, b*255//3]
    pp.putpalette(flat)
    p = im.quantize(palette=pp, dither=Image.FLOYDSTEINBERG)
    return bytes(p.tobytes())

def yjk(art, mode):
    im = art.resize((256, 212), Image.LANCZOS).convert('RGB')
    px = im.load(); data = bytearray(256*212)
    for y in range(212):
        for x0 in range(0, 256, 4):
            Ys = []; Js = []; Ks = []
            for k in range(4):
                r, g, b = [c*31/255 for c in px[x0+k, y]]
                Y = b/2 + r/4 + g/8
                Ys.append(Y); Js.append(r-Y); Ks.append(g-Y)
            J = max(-32, min(31, round(sum(Js)/4))); K = max(-32, min(31, round(sum(Ks)/4)))
            Jb = J & 63; Kb = K & 63
            low = [Kb & 7, Kb >> 3, Jb & 7, Jb >> 3]
            for k in range(4):
                Yq = max(0, min(31, round(Ys[k])))
                if mode == 12: v = (Yq << 3) | low[k]
                else: v = ((Yq >> 1) << 4) | low[k]
                data[y*256 + x0 + k] = v
    return bytes(data)

TMS = [(0,0,0),(0,0,0),(1,6,1),(3,7,3),(1,1,7),(2,3,7),(5,1,1),(2,6,7),(7,1,1),(7,3,3),(6,6,1),(6,6,4),(1,4,1),(6,2,5),(5,5,5),(7,7,7)]
def make_sc2(art):
    im = art.resize((256, 192), Image.LANCZOS)
    pp = Image.new('P', (1, 1)); flat = []
    for r, g, b in TMS[1:] + [TMS[-1]]*1: flat += [r*255//7, g*255//7, b*255//7]
    flat += flat[:3]*(256-len(flat)//3)
    pp.putpalette(flat)
    p = im.quantize(palette=pp, dither=Image.NONE)
    p = p.point([i if i < 15 else 0 for i in range(256)])
    px = p.load()
    data = bytearray(0x3800)
    for ry in range(24):
        bank = ry // 8
        for cx in range(32):
            name = (ry % 8)*32 + cx
            data[0x1800 + ry*32 + cx] = name
            for row in range(8):
                y = ry*8 + row
                vals = [px[cx*8+k, y]+1 for k in range(8)]
                cnt = {}
                for v in vals: cnt[v] = cnt.get(v, 0)+1
                top = sorted(cnt, key=lambda v: -cnt[v])
                fg = top[0]; bgc = top[1] if len(top) > 1 else top[0]
                def dist(a, b): return sum((TMS[a][i]-TMS[b][i])**2 for i in range(3))
                pat = 0
                for k, v in enumerate(vals):
                    if dist(v, fg) <= dist(v, bgc): pat |= 0x80 >> k
                a = (bank*256 + name)*8 + row
                data[a] = pat
                data[0x2000 + a] = (fg << 4) | bgc
    return bytes(data)

def main(out):
    os.makedirs(out, exist_ok=True)
    art = make_art(512, 212)
    art.save(os.path.join(out, '_ref.png'))
    bsave(os.path.join(out, 'SUNSET.SC5'), make_sc5(art))
    bsave(os.path.join(out, 'SUNSET.SC6'), make_sc6(art))
    bsave(os.path.join(out, 'SUNSET.SC7'), make_sc7(art))
    bsave(os.path.join(out, 'SUNSET.SC8'), make_sc8(art))
    bsave(os.path.join(out, 'SUNSET.SCC'), yjk(art, 12))
    bsave(os.path.join(out, 'SUNSET.SCB'), yjk(art, 11))
    bsave(os.path.join(out, 'SUNSET.SC2'), make_sc2(art))
    print('ok')
if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'fs/PIC')
