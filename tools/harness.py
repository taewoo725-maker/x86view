import sys, os, struct
from z80 import Z80Machine
from PIL import Image

DEFPAL = [(0,0,0),(0,0,0),(1,6,1),(3,7,3),(1,1,7),(2,3,7),(5,1,1),(2,6,7),
          (7,1,1),(7,3,3),(6,6,1),(6,6,4),(1,4,1),(6,2,5),(5,5,5),(7,7,7)]

class VDP:
    def __init__(s):
        s.vram = bytearray(131072)
        s.regs = [0]*64
        s.pal = [list(c) for c in DEFPAL]
        s.latch = None
        s.addr = 0
        s.palidx = 0; s.palbuf = None
        s.ptr17 = 0
        s.cmds = 0
        s.log_bad = []
    alias64 = False
    def out98(s, v):
        s.vram[s.addr & (0xFFFF if s.alias64 else 0x1FFFF)] = v
        s.addr = (s.addr + 1) & 0x1FFFF
    def in98(s):
        v = s.vram[s.addr & (0xFFFF if s.alias64 else 0x1FFFF)]; s.addr = (s.addr + 1) & 0x1FFFF; return v
    def out99(s, v):
        if s.latch is None:
            s.latch = v
        else:
            f = s.latch; s.latch = None
            if v & 0x80:
                s.wreg(v & 0x3F, f)
            else:
                s.addr = ((s.regs[14] & 7) << 14) | ((v & 0x3F) << 8) | f
    def in99(s):
        s.latch = None
        r = s.regs[15] & 15
        if r == 2: return 0
        return 0
    def wreg(s, r, v):
        s.regs[r] = v
        if r == 25: s.r25log = getattr(s,'r25log',[]) + [v]
        if r == 17: s.ptr17 = v
        if r == 46: s.command(v)
    def out9a(s, v):
        if s.palbuf is None: s.palbuf = v
        else:
            rb = s.palbuf; g = v; s.palbuf = None
            s.pal[s.palidx & 15] = [(rb >> 4) & 7, g & 7, rb & 7]
            s.palidx += 1
    def out9b(s, v):
        r = s.ptr17 & 0x3F
        s.wreg(r, v)
        if not (s.ptr17 & 0x80):
            s.ptr17 = (s.ptr17 & 0x80) | ((r + 1) & 0x3F)
    def command(s, v):
        cmd = v >> 4
        r = s.regs
        dx = r[36] | (r[37] << 8); dy = r[38] | (r[39] << 8)
        nx = r[40] | (r[41] << 8); ny = r[42] | (r[43] << 8)
        if cmd == 0xC:   # HMMV  (screen 7 assumed)
            clr = r[44]
            s.cmds += 1
            if dx & 1 or nx & 1: s.log_bad.append(('odd', dx, nx))
            for y in range(dy, dy + ny):
                a = y * 256 + dx // 2
                n = (nx + 1) // 2
                if a + n > 131072: s.log_bad.append(('range', dx, dy, nx, ny)); break
                s.vram[a:a+n] = bytes([clr]) * n
        elif cmd == 0xD:  # HMMM (screen 7)
            sx = r[32] | (r[33] << 8); sy = r[34] | (r[35] << 8)
            diy = (r[45] >> 3) & 1; dix = (r[45] >> 2) & 1
            n = (nx + 1) // 2
            rowsr = range(ny) if not diy else range(ny - 1, -1, -1)
            for k in rowsr:
                ys = sy + k if not diy else sy - (ny - 1 - k)
                yd = dy + k if not diy else dy - (ny - 1 - k)
                a = ys * 256 + sx // 2; b = yd * 256 + dx // 2
                s.vram[b:b+n] = s.vram[a:a+n]
            s.cmds += 1
        elif cmd != 0:
            s.log_bad.append(('cmd', cmd))

    def rgb(s, i):
        r, g, b = s.pal[i & 15]
        return (r * 255 // 7, g * 255 // 7, b * 255 // 7)

    def render(s, mode, lines=212):
        v = s.vram
        if mode == 7:
            img = Image.new('RGB', (512, lines))
            px = img.load()
            for y in range(lines):
                base = y * 256
                for x in range(256):
                    b = v[base + x]
                    px[2*x, y] = s.rgb(b >> 4); px[2*x+1, y] = s.rgb(b & 15)
            return img
        if mode == 5:
            img = Image.new('RGB', (256, lines)); px = img.load()
            for y in range(lines):
                base = y * 128
                for x in range(128):
                    b = v[base + x]
                    px[2*x, y] = s.rgb(b >> 4); px[2*x+1, y] = s.rgb(b & 15)
            return img
        if mode == 6:
            img = Image.new('RGB', (512, lines)); px = img.load()
            for y in range(lines):
                base = y * 128
                for x in range(128):
                    b = v[base + x]
                    for k in range(4):
                        px[4*x+k, y] = s.rgb((b >> (6 - 2*k)) & 3)
            return img
        if mode == 8:
            img = Image.new('RGB', (256, lines)); px = img.load()
            for y in range(lines):
                base = y * 256
                for x in range(256):
                    b = v[base + x]
                    g = (b >> 5) & 7; r = (b >> 2) & 7; bl = b & 3
                    px[x, y] = (r * 255 // 7, g * 255 // 7, bl * 255 // 3)
            return img
        if mode in (10, 11, 12):
            img = Image.new('RGB', (256, lines)); px = img.load()
            for y in range(lines):
                base = y * 256
                for x0 in range(0, 256, 4):
                    bs = [v[base + x0 + k] for k in range(4)]
                    K = (bs[0] & 7) | ((bs[1] & 7) << 3)
                    J = (bs[2] & 7) | ((bs[3] & 7) << 3)
                    if K >= 32: K -= 64
                    if J >= 32: J -= 64
                    for k in range(4):
                        Y = bs[k] >> 3
                        if mode != 12 and (bs[k] & 8):
                            px[x0+k, y] = s.rgb(bs[k] >> 4); continue
                        if mode != 12: Y = bs[k] >> 4 << 1
                        R = Y + J; G = Y + K; B = (5*Y - 2*J - K) / 4
                        cl = lambda t: max(0, min(31, int(round(t)))) * 255 // 31
                        px[x0+k, y] = (cl(R), cl(G), cl(B))
            return img
        if mode in (2, 4):
            img = Image.new('RGB', (256, 192)); px = img.load()
            for y in range(192):
                for xc in range(32):
                    name = v[0x1800 + (y // 8) * 32 + xc]
                    bank = (y // 64) * 256
                    pat = v[0x0000 + (bank + name) * 8 + (y % 8)]
                    col = v[0x2000 + (bank + name) * 8 + (y % 8)]
                    for k in range(8):
                        c = (col >> 4) if (pat >> (7 - k)) & 1 else (col & 15)
                        px[xc*8+k, y] = s.rgb(c)
            return img
        return Image.new('RGB', (64, 48))

class Env:
    def __init__(s, com, root, keys, verbose=False):
        s.m = Z80Machine()
        s.vdp = VDP()
        s.root = root
        s.cwd = ''          # path under root
        s.keys = list(keys)
        s.shots = []
        s.mode = 0
        s.disp = True
        s.handles = {}
        s.nexth = 5
        s.verbose = verbose
        s.done = False
        s.find = []
        s.exit_code = None
        s.shotn = 0
        m = s.m
        code = open(com, 'rb').read()
        m.memory[0x100:0x100+len(code)] = code
        # font in "ROM"
        s.rom = bytearray(0x8000)
        from PIL import ImageFont
        s.rom[0x2D] = 2  # MSX2+
        s.rom[4] = 0xBF; s.rom[5] = 0x1B
        s.makefont()
        m.memory[0x0006] = 0x00; m.memory[0x0007] = 0xDC   # BDOS top DC00
        m.memory[0xFCC1] = 0x00
        m.memory[0xFCAF] = 0   # SCRMOD
        m.memory[0xFFE8] = 0x00
        m.memory[0x80] = 0
        for a in (0x05, 0x0C, 0x1C): 
            m.memory[a] = 0xC9
        for a in (0x05, 0x0C, 0x1C):
            m.set_breakpoint(a)
        m.set_input_callback(s.inp)
        m.set_output_callback(s.outp)
        m.pc = 0x100; m.sp = 0xDBF0
        m.iff1 = 1
        s.ticks = 0

    def makefont(s):
        # use a PIL default bitmap font to fake an 8x8 MSX font: render ASCII with DejaVu-like if available
        from PIL import ImageFont, ImageDraw
        base = 0x1BBF
        try:
            f = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf', 9)
        except Exception:
            f = ImageFont.load_default()
        for c in range(32, 127):
            im = Image.new('1', (8, 8), 0)
            d = ImageDraw.Draw(im)
            d.text((0, -1), chr(c), font=f, fill=1)
            px = im.load()
            for r in range(8):
                b = 0
                for x in range(8):
                    if px[x, r]: b |= 0x80 >> x
                s.rom[base + c*8 + r] = b

    def inp(s, port):
        p = port & 0xFF
        if p == 0x99: return s.vdp.in99()
        if p == 0x98: return s.vdp.in98()
        return 0xFF
    def outp(s, port, v):
        p = port & 0xFF
        if p == 0x98: s.vdp.out98(v)
        elif p == 0x99: s.vdp.out99(v)
        elif p == 0x9A: s.vdp.out9a(v)
        elif p == 0x9B: s.vdp.out9b(v)

    # ---- helpers
    def ret(s):
        m = s.m
        lo = m.memory[m.sp]; hi = m.memory[m.sp+1]
        m.sp = (m.sp + 2) & 0xFFFF
        m.pc = lo | (hi << 8)
    def hostpath(s, p):
        p = p.replace('\\', '/')
        if len(p) >= 2 and p[1] == ':': p = p[2:]
        if p.startswith('/'): full = p.lstrip('/')
        else: full = os.path.join(s.cwd, p)
        full = os.path.normpath(full) if full else ''
        if full == '.': full = ''
        return full
    def cstr(s, addr):
        out = bytearray()
        while s.m.memory[addr]:
            out.append(s.m.memory[addr]); addr += 1
        return out.decode('latin1')

    def fill_fib(s, ix, name, isdir, size):
        mem = s.m.memory
        for i in range(64): mem[ix + i] = 0
        mem[ix] = 0xFF
        nb = name.encode()[:12]
        mem[ix+1:ix+1+len(nb)] = nb
        mem[ix+14] = 0x10 if isdir else 0x20
        mem[ix+21:ix+25] = struct.pack('<I', size)

    def bdos(s):
        m = s.m
        c = m.c
        mem = m.memory
        A = 0
        if c == 0x6F:
            m.b = 2; m.c = 20; m.a = 0; s.ret(); return
        elif c == 0x09:
            de = m.de; out = bytearray()
            while mem[de] != ord('$'): out.append(mem[de]); de += 1
            print('[DOS print]', out.decode('latin1').strip()); 
        elif c == 0x62:
            s.exit_code = m.b; s.done = True; return
        elif c == 0x06:
            s.spmin = min(getattr(s,'spmin',0xFFFF), m.sp)
            if m.e == 0xFF:
                while s.keys and isinstance(s.keys[0], tuple):
                    k = s.keys.pop(0)
                    if k[0] == 'shot': s.shot(k[1])
                    elif k[0] == 'wait':
                        if k[1] > 0:
                            s.keys.insert(0, ('wait', k[1]-1)); 
                            s.tick(); m.a = 0; s.ret(); return
                    elif k[0] == 'mode': s.setmsx(k[1])
                if not s.keys:
                    s.done = True; return
                m.a = s.keys.pop(0); s.ret(); return
        elif c == 0x0B:
            A = 0xFF if (s.keys and isinstance(s.keys[0], int)) else 0
        elif c == 0x19: A = 0
        elif c == 0x18: m.hl = 0b111; 
        elif c == 0x0E: pass
        elif c in (0x63, 0x64): pass
        elif c == 0x59:
            de = m.de; p = s.cwd.replace('/', '\\')
            for i, ch in enumerate(p.encode()): mem[de+i] = ch
            mem[de+len(p)] = 0
        elif c == 0x5A:
            p = s.cstr(m.de); h = s.hostpath(p)
            if os.path.isdir(os.path.join(s.root, h)): s.cwd = h
            else: A = 0xD6
        elif c == 0x40:
            pat = s.cstr(m.de)
            d = os.path.join(s.root, s.cwd)
            ents = []
            if s.cwd: ents.append(('.', True, 0)); ents.append(('..', True, 0))
            for n in sorted(os.listdir(d), reverse=True):
                fp = os.path.join(d, n)
                ents.append((n.upper(), os.path.isdir(fp), 0 if os.path.isdir(fp) else os.path.getsize(fp)))
            s.find = ents
            A = s.fnext(m.ix)
        elif c == 0x41:
            A = s.fnext(m.ix)
        elif c == 0x43:
            p = s.hostpath(s.cstr(m.de))
            real = None
            d = os.path.join(s.root, os.path.dirname(p))
            for n in os.listdir(d):
                if n.upper() == os.path.basename(p).upper(): real = os.path.join(d, n)
            if real is None: A = 0xD7
            else:
                h = 5
                while h in s.handles: h += 1
                s.handles[h] = open(real, 'rb'); m.b = h
        elif c == 0x48:
            f = s.handles[m.b]; data = f.read(m.hl)
            mem[m.de:m.de+len(data)] = data
            m.hl = len(data)
            A = 0xC7 if len(data) == 0 else 0
        elif c == 0x4A:
            f = s.handles[m.b]; f.seek((m.de << 16) | m.hl)
        elif c == 0x45:
            s.handles.pop(m.b).close()
        else:
            print('unhandled BDOS', hex(c))
        m.a = A
        s.ret()
    def fnext(s, ix):
        if not s.find: return 0xD7
        n, isdir, size = s.find.pop(0)
        s.fill_fib(ix, n, isdir, size)
        return 0

    def calslt(s):
        m = s.m
        ix = m.ix
        if ix == 0x5F:
            s.mode = m.a
            s.vdp.vram[:] = bytes(131072)
            s.vdp.pal = [list(c) for c in DEFPAL]
            m.memory[0xFCAF] = s.mode
            s.disp = True
        elif ix == 0x41: s.disp = False
        elif ix == 0x44: s.disp = True
        else: print('unhandled BIOS', hex(ix))
        s.ret()
    def rdslt(s):
        m = s.m
        m.a = s.rom[m.hl] if m.hl < len(s.rom) else 0
        s.ret()
    def setmsx(s, v): s.rom[0x2D] = v
    def tick(s):
        j = m_j = s.m.memory[0xFC9E] | (s.m.memory[0xFC9F] << 8)
        j = (j + 1) & 0xFFFF
        s.m.memory[0xFC9E] = j & 255; s.m.memory[0xFC9F] = j >> 8
    def shot(s, name, scale=2):
        s.lastvram = bytes(s.vdp.vram); s.lastpal = [list(c) for c in s.vdp.pal]
        lines = 212 if (s.vdp.regs[9] & 0x80) else 192
        if s.mode in (2, 3, 4): lines = 192
        em = s.mode
        if em == 8 and (s.vdp.regs[25] & 8): em = 11 if (s.vdp.regs[25] & 0x10) else 12
        img = s.vdp.render(em, lines)
        w, h = img.size
        if s.mode in (6, 7): img = img.resize((w*2, h*3), Image.NEAREST)
        else: img = img.resize((w*4, h*3), Image.NEAREST)
        fn = f'{name}.png'
        img.save(fn)
        s.shots.append(fn)
        print('shot', fn, 'mode', s.mode, 'disp', s.disp, 'R8/R9', s.vdp.regs[8], s.vdp.regs[9], 'cmds', s.vdp.cmds, s.vdp.log_bad[:3])

    def run(s, maxloops=2000000):
        m = s.m
        m.memory[0x38:0x3B] = bytes([0xFB, 0xED, 0x4D])
        loops = 0
        while not s.done and loops < maxloops:
            loops += 1
            r = m.run()
            pc = m.pc
            if pc == 0x05: s.bdos()
            elif pc == 0x0C: s.rdslt()
            elif pc == 0x1C: s.calslt()
            elif m.halted:
                s.tick(); m.on_handle_active_int()
        return loops
