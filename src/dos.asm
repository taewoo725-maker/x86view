; ===== directory / entries =====
; HL=count -> HL*20  (uses BC,DE)
mul20:  ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        ld b,h
        ld c,l
        add hl,hl
        add hl,hl
        add hl,bc
        ret

; HL=index -> HL=entry addr
entaddr: call mul20
        ld de,ENT
        add hl,de
        ret

; HL=name -> A=mode idx / FFh
findmode:
fm_d:   ld a,(hl)
        or a
        jr z,fm_no
        cp '.'
        jr z,fm_dot
        inc hl
        jr fm_d
fm_dot: inc hl
        ld de,EXTB
        ld b,3
fm_e:   ld a,(hl)
        or a
        jr z,fm_pad
        cp 'a'
        jr c,fm_u
        cp 'z'+1
        jr nc,fm_u
        and 0DFh
fm_u:   ld (de),a
        inc hl
        inc de
        djnz fm_e
        jr fm_look
fm_pad: xor a
fm_p2:  ld (de),a
        inc de
        djnz fm_p2
fm_look: ld hl,exttab
fm_l:   ld a,(hl)
        or a
        jr z,fm_no
        push hl
        ld de,EXTB
        ld b,3
fm_c:   ld a,(de)
        cp (hl)
        jr nz,fm_nx
        inc de
        inc hl
        djnz fm_c
        ld a,(hl)
        pop de
        ret
fm_nx:  pop hl
        ld de,4
        add hl,de
        jr fm_l
fm_no:  jp v9_fm

; HL=new, DE=existing -> carry if new<existing
cmpent: ld a,(de)
        ld b,a
        ld a,(hl)
        cp b
        ret nz
        inc hl
        inc hl
        inc de
        inc de
        ld c,13
cm1:    ld a,(de)
        ld b,a
        ld a,(hl)
        cp b
        ret nz
        or a
        ret z
        inc hl
        inc de
        dec c
        jr nz,cm1
        or a
        ret

; add FIB entry to list
addent: ld hl,(COUNT)
        ld de,MAXE
        or a
        sbc hl,de
        ret nc
        ld hl,FIB+1
        ld a,(hl)
        cp '.'
        jr nz,ae_n
        inc hl
        ld a,(hl)
        or a
        ret z
        cp '.'
        jr nz,ae_n
        ld a,(FIB+14)
        and 10h
        ret z
        ld a,0
        ld b,0FFh
        jr ae_k
ae_n:   ld a,(FIB+14)
        and 10h
        jr z,ae_f
        ld a,1
        ld b,0FFh
        jr ae_k
ae_f:   ld hl,FIB+1
        call findmode
        ld b,a
        cp 0FFh
        jr nz,ae_img
        ld a,(ALLF)
        or a
        ret z
        ld a,3
        jr ae_k
ae_img: ld a,2
ae_k:   ld hl,TMPREC
        ld (hl),a
        inc hl
        ld (hl),b
        inc hl
        ex de,hl
        ld hl,FIB+1
        ld bc,13
        ldir
        ld hl,FIB+21
        ld bc,4
        ldir
        ld a,(FIB+14)
        ld (de),a
ins_rec:
        ld bc,0
        ld de,ENT
ir_lp:  ld hl,(COUNT)
        or a
        sbc hl,bc
        jr z,ir_at
        push bc
        push de
        ld hl,TMPREC
        call cmpent
        pop de
        pop bc
        jr c,ir_at
        inc bc
        ld hl,ESZ
        add hl,de
        ex de,hl
        jr ir_lp
ir_at:  ld hl,(COUNT)
        or a
        sbc hl,bc
        jr z,ir_cp
        push de
        call mul20
        ld b,h
        ld c,l
        pop de
        push de
        add hl,de
        dec hl
        push hl
        ld de,ESZ
        add hl,de
        ex de,hl
        pop hl
        lddr
        pop de
ir_cp:  ld hl,TMPREC
        ld bc,ESZ
        ldir
        ld hl,(COUNT)
        inc hl
        ld (COUNT),hl
        ret

; scan current directory
scan:   ld hl,0
        ld (COUNT),hl
        ld (SEL),hl
        ld (TOP),hl
        ld de,s_all
        ld b,10h
        ld ix,FIB
        ld c,40h
        call BDOS
        ld (EXTRA),a
        or a
        ret nz
sc_lp:  call addent
        ld ix,FIB
        ld c,41h
        call BDOS
        or a
        jr z,sc_lp
        xor a
        ld (EXTRA),a
        ret

; build "A:\path" in STRBUF
mkpath: ld c,19h
        call BDOS
        add a,'A'
        ld de,STRBUF
        ld (de),a
        inc de
        ld a,':'
        ld (de),a
        inc de
        ld a,'\'
        ld (de),a
        inc de
        push de
        ld b,0
        ld de,PATHBUF
        ld c,59h
        call BDOS
        pop de
        ld hl,PATHBUF
        ld b,28
mp_c:   ld a,(hl)
        or a
        jr z,mp_e
        ld (de),a
        inc hl
        inc de
        djnz mp_c
mp_e:   xor a
        ld (de),a
        ret

; HL -> 4-byte size ; result right aligned in SZBUF (5 chars + 0)
fmtsize:
        ld de,SZ32
        ld bc,4
        ldir
        ld a,(SZ32+3)
        ld b,a
        ld a,(SZ32+2)
        or b
        jr nz,fz_k
        ld hl,(SZ32)
        ld de,1000
        or a
        sbc hl,de
        jr nc,fz_k
        add hl,de
        ld de,NUMB
        call dec16
        ld a,'B'
        ld (de),a
        inc de
        jr fz_fin
fz_k:   ld a,(SZ32+3)
        or a
        jr nz,fz_big
        ld hl,(SZ32+1)
        inc hl
        inc hl
        srl h
        rr l
        srl h
        rr l
        ld de,10000
        or a
        sbc hl,de
        add hl,de
        jr c,fz_ok
        ld hl,9999
fz_ok:  ld de,NUMB
        call dec16
        ld a,'K'
        ld (de),a
        inc de
        jr fz_fin
fz_big: ld hl,s_huge
        ld de,NUMB
        call cats
fz_fin: xor a
        ld (de),a
        ld hl,NUMB
        call slen
        ld c,a
        ld a,5
        sub c
        jr nc,fz_p
        xor a
fz_p:   ld de,SZBUF
        ld b,a
        or a
        jr z,fz_cp
fz_sp:  ld a,' '
        ld (de),a
        inc de
        djnz fz_sp
fz_cp:  call cats
        xor a
        ld (de),a
        ret

; HL = MT entry for A
mtptr:  ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        ld de,mt
        add hl,de
        ret
