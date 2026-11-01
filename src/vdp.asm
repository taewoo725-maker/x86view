; ===== VDP primitives =====
; A=value C=reg
vreg:   di
        out (99h),a
        ld a,c
        or 80h
        out (99h),a
        ei
        ret

; HL=VRAM addr (bit16=0) for write
vsetw:  di
        ld a,h
        rlca
        rlca
        and 3
        out (99h),a
        ld a,8Eh
        out (99h),a
        ld a,l
        out (99h),a
        ld a,h
        and 3Fh
        or 40h
        out (99h),a
        ei
        ret

vsetr:  di
        ld a,h
        rlca
        rlca
        and 3
        out (99h),a
        ld a,8Eh
        out (99h),a
        ld a,l
        out (99h),a
        ld a,h
        and 3Fh
        out (99h),a
        ei
        ret

; wait for VDP command end
vwait:  di
        ld a,2
        out (99h),a
        ld a,8Fh
        out (99h),a
        in a,(99h)
        push af
        xor a
        out (99h),a
        ld a,8Fh
        out (99h),a
        ei
        pop af
        rra
        jr c,vwait
        ret

; wait between VRAM/palette data writes (HL kept).
; first byte is RET (MSX2/2+: no wait). Patched to NOP on turbo R (MSXVER=3) -> ~4us wait
dly1:   ret
        ex (sp),hl
        ex (sp),hl
        ex (sp),hl
        ex (sp),hl
        ret

; HL=src, DE=count (>0) -> VRAM data port
vramout:
        ld a,(dly1)
        cp 0C9h
        jr nz,vo_l
        ld c,98h
        ld a,d
        or a
        jr z,vo_r
vo_b:   ld b,0
        otir
        dec d
        jr nz,vo_b
vo_r:   ld a,e
        or a
        ret z
        ld b,a
        otir
        ret
vo_l:   ld a,(hl)
        out (98h),a
        inc hl
        call dly1
        dec de
        ld a,d
        or e
        jr nz,vo_l
        ret

; HL = 32-byte palette table
setpal: di
        xor a
        out (99h),a
        ld a,90h
        out (99h),a
        ei
        ld b,32
sp_l:   ld a,(hl)
        out (9Ah),a
        inc hl
        call dly1
        djnz sp_l
        ret

; HMMV fill using RX,RY,RW,RH,RC
fillr:  call vwait
        di
        ld a,36
        out (99h),a
        ld a,91h
        out (99h),a
        ld hl,RX
        ld bc,089Bh
        otir
        ld a,(RC)
        ld b,a
        add a,a
        add a,a
        add a,a
        add a,a
        or b
        out (9Bh),a
        xor a
        out (9Bh),a
        ld a,0C0h
        out (9Bh),a
        ei
        jp vwait

; call rct / dw x,y,w,h / db color
rct:    pop hl
        ld de,RX
        ld bc,8
        ldir
        ld a,(hl)
        ld (RC),a
        inc hl
        push hl
        jp fillr

; call rrct / dw x,y,w,h / db color  (rounded)
rrct:   pop hl
        ld de,QX
        ld bc,8
        ldir
        ld a,(hl)
        ld (QC),a
        inc hl
        push hl
rrdraw: ld a,(QC)
        ld (RC),a
        ld hl,(QX)
        ld de,4
        add hl,de
        ld (RX),hl
        ld hl,(QY)
        ld (RY),hl
        ld hl,(QW)
        ld de,-8
        add hl,de
        ld (RW),hl
        ld hl,1
        ld (RH),hl
        call fillr
        ld hl,(QX)
        ld de,2
        add hl,de
        ld (RX),hl
        ld hl,(QY)
        inc hl
        ld (RY),hl
        ld hl,(QW)
        ld de,-4
        add hl,de
        ld (RW),hl
        call fillr
        ld hl,(QX)
        ld (RX),hl
        ld hl,(QY)
        inc hl
        inc hl
        ld (RY),hl
        ld hl,(QW)
        ld (RW),hl
        ld hl,(QH)
        ld de,-4
        add hl,de
        ld (RH),hl
        call fillr
        ld hl,(QX)
        ld de,2
        add hl,de
        ld (RX),hl
        ld hl,(QY)
        ld de,(QH)
        add hl,de
        dec hl
        dec hl
        ld (RY),hl
        ld hl,(QW)
        ld de,-4
        add hl,de
        ld (RW),hl
        ld hl,1
        ld (RH),hl
        call fillr
        ld hl,(QX)
        ld de,4
        add hl,de
        ld (RX),hl
        ld hl,(QY)
        ld de,(QH)
        add hl,de
        dec hl
        ld (RY),hl
        ld hl,(QW)
        ld de,-8
        add hl,de
        ld (RW),hl
        call fillr
        ret
