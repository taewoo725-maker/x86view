; ===== text drawing (SCREEN 7, 4bpp) =====
; A=fg B=bg  -> builds TT, NT
settxt: ld c,a
        ld a,(FG)
        cp c
        jr nz,st_go
        ld a,(BG)
        cp b
        ret z
st_go:  ld a,c
        ld (FG),a
        ld a,b
        ld (BG),a
        ld c,a
        add a,a
        add a,a
        add a,a
        add a,a
        ld d,a            ; D = bg<<4
        or c
        ld (TT),a         ; bg bg
        ld a,(FG)
        ld e,a            ; E = fg
        or d
        ld (TT+1),a       ; bg fg  (left bg, right fg)
        ld a,e
        add a,a
        add a,a
        add a,a
        add a,a
        ld b,a            ; B = fg<<4
        or c
        ld (TT+2),a       ; fg bg
        ld a,b
        or e
        ld (TT+3),a       ; fg fg
        ld hl,NT
        ld c,0
st_l:   ld a,c
        rrca
        rrca
        and 3
        ld e,a
        ld d,0
        push hl
        ld hl,TT
        add hl,de
        ld a,(hl)
        pop hl
        ld (hl),a
        inc hl
        ld a,c
        and 3
        ld e,a
        push hl
        ld hl,TT
        add hl,de
        ld a,(hl)
        pop hl
        ld (hl),a
        inc hl
        inc c
        ld a,c
        cp 16
        jr nz,st_l
        ret

; draw string HL at (PBX,PY)
pstr:   ld (STRP),hl
        xor a
        ld (ROW),a
ps_row: ld a,(ROW)
        ld e,a
        ld d,0
        ld hl,FONT
        add hl,de
        ld (GBASE),hl
        ld a,(PY)
        ld h,a
        ld a,(ROW)
        add a,h
        ld h,a
        ld a,(PBX)
        ld l,a
        call vsetw
        ld hl,(STRP)
        ld c,98h
ps_ch:  ld a,(hl)
        or a
        jr z,ps_end
        inc hl
        push hl
        and 7Fh
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,(GBASE)
        add hl,de
        ld a,(hl)
        ld e,a
        rrca
        rrca
        rrca
        rrca
        and 0Fh
        add a,a
        ld l,a
        ld h,81h
        ld a,(hl)
        out (98h),a
        call dly1
        inc l
        ld a,(hl)
        out (98h),a
        call dly1
        ld a,e
        rrca
        rrca
        and 3
        add a,20h
        ld l,a
        ld a,(hl)
        out (98h),a
        call dly1
        pop hl
        jr ps_ch
ps_end: ld a,(ROW)
        inc a
        ld (ROW),a
        cp 8
        jr nz,ps_row
        ret

; call tx / db bx,y,fg,bg / db 'text',0
tx:     pop hl
        ld a,(hl)
        ld (PBX),a
        inc hl
        ld a,(hl)
        ld (PY),a
        inc hl
        ld a,(hl)
        inc hl
        ld b,(hl)
        inc hl
        push hl
        call settxt
        pop hl
        push hl
        call pstr
        pop hl
tx_f:   ld a,(hl)
        inc hl
        or a
        jr nz,tx_f
        jp (hl)

; txs: HL=str C=bx D=y A=fg B=bg
txs:    push hl
        ld hl,PBX
        ld (hl),c
        inc hl
        ld (hl),d
        call settxt
        pop hl
        jp pstr

; big 2x text: HL=str at (PBX,PY), FG/BG as set by settxt
pbig:   ld (STRP),hl
        ld a,(BG)
        ld b,a
        add a,a
        add a,a
        add a,a
        add a,a
        or b
        ld (TMPW),a           ; bg byte
        ld b,a
        ld a,(FG)
        ld c,a
        add a,a
        add a,a
        add a,a
        add a,a
        or c
        xor b
        ld (TMPW+1),a         ; fg^bg mask
        xor a
        ld (ROW),a
pb_row: ld a,(ROW)
        ld e,a
        ld d,0
        ld hl,FONT
        add hl,de
        ld (GBASE),hl
        xor a
        ld (NSTEP),a
pb_rep: ld a,(ROW)
        add a,a
        ld b,a
        ld a,(NSTEP)
        add a,b
        ld b,a
        ld a,(PY)
        add a,b
        ld h,a
        ld a,(PBX)
        ld l,a
        call vsetw
        ld hl,(STRP)
pb_ch:  ld a,(hl)
        or a
        jr z,pb_ce
        inc hl
        push hl
        and 7Fh
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,(GBASE)
        add hl,de
        ld c,(hl)
        ld b,6
pb_bit: rl c
        sbc a,a
        ld d,a
        ld a,(TMPW+1)
        and d
        ld d,a
        ld a,(TMPW)
        xor d
        out (98h),a
        call dly1
        djnz pb_bit
        pop hl
        jr pb_ch
pb_ce:  ld a,(NSTEP)
        inc a
        ld (NSTEP),a
        cp 2
        jr nz,pb_rep
        ld a,(ROW)
        inc a
        ld (ROW),a
        cp 8
        jr nz,pb_row
        ret

; ---- strings ----
; HL -> A=len (HL kept)
slen:   push hl
        ld c,0
sl1:    ld a,(hl)
        or a
        jr z,sl2
        inc hl
        inc c
        jr sl1
sl2:    ld a,c
        pop hl
        ret

; append ASCIIZ HL to DE (no terminator copied)
cats:   ld a,(hl)
        or a
        ret z
        ld (de),a
        inc hl
        inc de
        jr cats

; HL=value, DE=dest -> decimal, DE advanced
dec16:  xor a
        ld (ZF),a
        ld bc,-10000
        call dg
        ld bc,-1000
        call dg
        ld bc,-100
        call dg
        ld bc,-10
        call dg
        ld a,1
        ld (ZF),a
        ld bc,-1
dg:     ld a,'0'-1
dg1:    inc a
        add hl,bc
        jr c,dg1
        sbc hl,bc
        cp '0'
        jr nz,dgw
        ld c,a
        ld a,(ZF)
        or a
        ld a,c
        ret z
dgw:    ld (de),a
        inc de
        ld a,1
        ld (ZF),a
        ret

; HL/DE -> HL
div16:  ld a,h
        ld c,l
        ld hl,0
        ld b,16
dv_l:   sla c
        rla
        adc hl,hl
        sbc hl,de
        jr nc,dv_ok
        add hl,de
        jr dv_n
dv_ok:  inc c
dv_n:   djnz dv_l
        ld h,a
        ld l,c
        ret

; ---- chip: HL=str D=bg E=fg, at (CHX,CHY) height CHH ----
chip:   ld (CHS),hl
        ld a,d
        ld (CHBG),a
        ld a,e
        ld (CHFG),a
        call slen
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        add hl,hl
        ld de,12
        add hl,de
        ld (CHW),hl
        ld hl,(CHX)
        ld (QX),hl
        ld a,(CHY)
        ld l,a
        ld h,0
        ld (QY),hl
        ld hl,(CHW)
        ld (QW),hl
        ld a,(CHH)
        ld l,a
        ld h,0
        ld (QH),hl
        ld a,(CHBG)
        ld (QC),a
        call rrdraw
        ld hl,(CHX)
        ld de,6
        add hl,de
        srl h
        rr l
        ld a,l
        ld (PBX),a
        ld a,(CHH)
        srl a
        sub 4
        ld b,a
        ld a,(CHY)
        add a,b
        ld (PY),a
        ld a,(CHFG)
        ld hl,CHBG
        ld b,(hl)
        call settxt
        ld hl,(CHS)
        call pstr
        ld hl,(CHX)
        ld de,(CHW)
        add hl,de
        ld (CHX),hl
        ret
