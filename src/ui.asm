; ===== browser UI =====
setup_ui:
        call disscr
        ld a,7
        call chgmod
        call disscr
        ld hl,uipal
        call setpal
        xor a
        call setyjk
        ld a,(RG8SAV)
        or 2
        ld (RG8SAV),a
        ld c,8
        call vreg
        ld a,(RG9SAV)
        or 80h
        ld (RG9SAV),a
        ld c,9
        call vreg
        xor a
        ld c,7
        call vreg
        ret

draw_all:
        call rct
        dw 0,0,512,212
        db C_BG
        call draw_title
        call rrct
        dw 8,20,296,166
        db C_PAN
        call rrct
        dw 312,20,192,166
        db C_PAN
        call rct
        dw 12,36,288,1
        db C_CARD
        call rct
        dw 316,36,184,1
        db C_CARD
        call tx
        db 162,24,C_MUT,C_PAN
        db 'DETAILS',0
        call draw_path
        call drawlist
        call drawdetails
        call draw_hints
        ret

draw_title:
        call rct
        dw 0,0,512,16
        db C_PAN
        call rrct
        dw 8,2,28,12
        db C_ACC
        call tx
        db 7,4,C_BG,C_ACC
        db 'XV',0
        call tx
        db 22,4,C_TXT,C_PAN
        db 'X86VIEW',0
        call tx
        db 47,4,C_MUT,C_PAN
        db 'MSX picture viewer v1.2.0',0
        ; right chips
        ld hl,460
        ld (CHX),hl
        ld a,2
        ld (CHY),a
        ld a,12
        ld (CHH),a
        ld hl,s_dos2
        ld d,C_CARD
        ld e,C_CYAN
        call chip
        ld a,(MSXVER)
        dec a
        add a,a
        ld e,a
        ld d,0
        ld hl,machtab
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        push de
        pop hl
        call slen
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        add hl,hl
        ld de,12+6
        add hl,de
        ex de,hl
        ld hl,460
        or a
        sbc hl,de
        ld (CHX),hl
        ld a,(MSXVER)
        dec a
        add a,a
        ld e,a
        ld d,0
        ld hl,machtab
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld d,C_CARD
        ld e,C_GRN
        call chip
        ret

draw_path:
        call rct
        dw 12,21,286,14
        db C_PAN
        call tx
        db 10,24,C_YEL,C_PAN
        db 1,2,0
        call mkpath
        ld hl,STRBUF
        ld a,C_TXT
        ld b,C_PAN
        ld c,20
        ld d,24
        call txs
        ld a,(STRBUF)
        ld (STRB2+30),a
        ld a,':'
        ld (STRB2+31),a
        xor a
        ld (STRB2+32),a
        ld hl,STRB2+30
        ld a,C_ACC
        ld b,C_PAN
        ld c,20
        ld d,24
        call txs
        ; count text
        ld de,STRB2
        ld hl,(COUNT)
        call dec16
        ld hl,s_items
        call cats
        xor a
        ld (de),a
        ld hl,STRB2
        call slen
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        add hl,hl
        ex de,hl
        ld hl,296
        or a
        sbc hl,de
        srl h
        rr l
        ld c,l
        ld hl,STRB2
        ld a,C_MUT
        ld b,C_PAN
        ld d,24
        call txs
        ret

; ---- list ----
drawlist:
        xor a
dl_l:   push af
        call drawrow
        pop af
        inc a
        cp 12
        jr nz,dl_l
drawscroll:
        call rct
        dw 296,40,4,144
        db C_PAN
        ld hl,(COUNT)
        ld de,12
        or a
        sbc hl,de
        ret c
        ret z
        call rct
        dw 296,40,4,144
        db C_CARD
        ld hl,(COUNT)
        ; thumb height = 1728/COUNT (min 8)
        push hl
        ex de,hl
        ld hl,1728
        call div16
        ld a,h
        or a
        jr nz,dl_hm
        ld a,l
        cp 8
        jr nc,dl_hs
dl_hm:  ld l,8
        ld h,0
        jr dl_hs2
dl_hs:  ld h,0
dl_hs2: ld (RH),hl
        pop de
        ; pos = TOP*144/COUNT
        ld hl,(TOP)
        ld b,h
        ld c,l
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,7
dl_m:   sla c
        rl b
        dec a
        jr nz,dl_m
        add hl,bc
        call div16
        ld de,40
        add hl,de
        ld (RY),hl
        ld hl,296
        ld (RX),hl
        ld hl,4
        ld (RW),hl
        ld a,C_ACC
        ld (RC),a
        call fillr
        ret

; A = view row (0..11)
drawrow:
        ld (VROW),a
        ld b,a
        add a,a
        add a,b
        add a,a
        add a,a
        add a,40
        ld (RY0),a
        ld a,(VROW)
        ld l,a
        ld h,0
        ld de,(TOP)
        add hl,de
        ld (EIDX),hl
        ld hl,12
        ld (RX),hl
        ld a,(RY0)
        ld l,a
        ld h,0
        ld (RY),hl
        ld hl,282
        ld (RW),hl
        ld hl,12
        ld (RH),hl
        ld a,C_PAN
        ld (RC),a
        call fillr
        ld hl,(EIDX)
        ld de,(COUNT)
        or a
        sbc hl,de
        ret nc
        ld hl,(EIDX)
        call entaddr
        ld (EPTR),hl
        ld a,C_PAN
        ld (RBG),a
        ld hl,(EIDX)
        ld de,(SEL)
        or a
        sbc hl,de
        jr nz,dr_ns
        ld a,C_SEL
        ld (RBG),a
        ld hl,12
        ld (QX),hl
        ld a,(RY0)
        ld l,a
        ld h,0
        ld (QY),hl
        ld hl,282
        ld (QW),hl
        ld hl,12
        ld (QH),hl
        ld a,C_SEL
        ld (QC),a
        call rrdraw
        ld hl,12
        ld (RX),hl
        ld a,(RY0)
        add a,2
        ld l,a
        ld h,0
        ld (RY),hl
        ld hl,4
        ld (RW),hl
        ld hl,8
        ld (RH),hl
        ld a,C_ACC
        ld (RC),a
        call fillr
dr_ns:  ld hl,(EPTR)
        ld a,(hl)
        ld (TMPB),a
        ; icon
        add a,a
        ld e,a
        ld d,0
        ld hl,icontab
        add hl,de
        ld a,(hl)
        inc hl
        ld e,(hl)
        ld (STRBUF),a
        inc a
        ld (STRBUF+1),a
        xor a
        ld (STRBUF+2),a
        ld hl,STRBUF
        ld a,e
        ld c,10
        call rtx
        ; name
        ld a,(TMPB)
        or a
        jr z,dr_nm
        cp 3
        jr z,dr_nm
        ld a,C_TXT
        jr dr_nw
dr_nm:  ld a,C_MUT
dr_nw:  ld hl,(EPTR)
        inc hl
        inc hl
        ld c,20
        call rtx
        ld a,(TMPB)
        cp 2
        jr nz,dr_oth
        ; chip with mode label
        ld hl,(EPTR)
        inc hl
        ld a,(hl)
        ld (TMPW),a
        call mtptr
        inc hl
        ld a,(hl)
        ld (TMPW+1),a
        ld a,(TMPW)
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,modelab
        add hl,de
        push hl
        ld hl,128
        ld (CHX),hl
        ld a,(RY0)
        inc a
        ld (CHY),a
        ld a,10
        ld (CHH),a
        ld a,(TMPW+1)
        ld d,a
        ld e,C_BG
        pop hl
        call chip
        ; resolution
        ld a,(TMPW)
        call mtptr
        ld de,6
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld a,C_MUT
        ld c,84
        call rtx
dr_oth: ld a,(TMPB)
        or a
        ret z
        cp 1
        jr nz,dr_sz
        ld hl,s_dirtag
        jr dr_szt
dr_sz:  ld hl,(EPTR)
        ld de,15
        add hl,de
        call fmtsize
        ld hl,SZBUF
dr_szt: ld a,C_MUT
        ld c,131
        jp rtx

; HL=str A=fg C=bx ; bg=(RBG) y=(RY0)+2
rtx:    push af
        ld a,(RY0)
        add a,2
        ld d,a
        ld a,(RBG)
        ld b,a
        pop af
        jp txs

; ---- details card ----
drawdetails:
        call rct
        dw 316,38,184,112
        db C_PAN
        call rct
        dw 316,150,184,35
        db C_PAN
        ld hl,(COUNT)
        ld a,h
        or l
        jr nz,dd_has
        call tx
        db 162,60,C_MUT,C_PAN
        db 'No pictures here',0
        call tx
        db 162,72,C_DIM,C_PAN
        db 'Press A: all files',0
        jp dd_hint
dd_has: ld hl,(SEL)
        call entaddr
        ld (EPTR),hl
        ld a,(hl)
        cp 2
        jp z,dd_img
        cp 3
        jp z,dd_oth
        cp 1
        jp z,dd_dir
        ld hl,s_parent
        call dd_big
        call tx
        db 162,64,C_MUT,C_PAN
        db 'Go up one level',0
        jp dd_hint
dd_dir: ld hl,s_folder
        call dd_big
        ld hl,(EPTR)
        inc hl
        inc hl
        call dd_name
        call tx
        db 162,80,C_MUT,C_PAN
        db 'Type',0
        call tx
        db 190,80,C_TXT,C_PAN
        db 'Directory',0
        jp dd_hint
dd_oth: ld hl,s_file
        call dd_big
        ld hl,(EPTR)
        inc hl
        inc hl
        call dd_name
        call dd_size
        call tx
        db 162,92,C_MUT,C_PAN
        db 'Type',0
        call tx
        db 190,92,C_YEL,C_PAN
        db 'Unknown',0
        jp dd_hint
dd_img: ld hl,(EPTR)
        inc hl
        ld a,(hl)
        cp V9MODE
        jp z,v9_dd
        call mtptr
        ld (MTP),hl
        ld de,STRB2
        ld hl,s_screen
        call cats
        ld hl,(MTP)
        ld l,(hl)
        ld h,0
        call dec16
        xor a
        ld (de),a
        ld hl,STRB2
        call dd_big
        ld hl,(EPTR)
        inc hl
        inc hl
        call dd_name
        call dd_size
        call tx
        db 162,92,C_MUT,C_PAN
        db 'Resolut.',0
        ld hl,(MTP)
        ld de,6
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld a,C_TXT
        ld b,C_PAN
        ld c,190
        ld d,92
        call txs
        call tx
        db 162,104,C_MUT,C_PAN
        db 'Colors',0
        ld hl,(MTP)
        ld de,8
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld a,C_TXT
        ld b,C_PAN
        ld c,190
        ld d,104
        call txs
        call tx
        db 162,116,C_MUT,C_PAN
        db 'Palette',0
        ld hl,(MTP)
        ld de,4
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,d
        or e
        jr nz,dd_pa
        ld hl,(MTP)
        ld de,10
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        jr dd_pl
dd_pa:
        ld hl,32
        add hl,de
        ex de,hl
        ld hl,(EPTR)
        ld bc,17
        add hl,bc
        ld a,(hl)
        inc hl
        or (hl)
        jr nz,dd_pe
        ld hl,(EPTR)
        ld bc,15
        add hl,bc
        ld c,(hl)
        inc hl
        ld b,(hl)
        ld hl,-7
        add hl,bc
        jr nc,dd_pd
        or a
        sbc hl,de
        jr c,dd_pd
dd_pe:  ld hl,s_embed
        jr dd_pl
dd_pd:  ld hl,s_default
dd_pl:  ld a,C_TXT
        ld b,C_PAN
        ld c,190
        ld d,116
        call txs
dd_hint:
        call rrct
        dw 320,152,176,30
        db C_CARD
        ld hl,(MSGP)
        ld a,h
        or l
        jr z,dh_norm
        ld a,C_YEL
        ld b,C_CARD
        ld c,164
        ld d,162
        jp txs
dh_norm:
        ld hl,(COUNT)
        ld a,h
        or l
        ret z
        ld hl,(SEL)
        call entaddr
        ld a,(hl)
        cp 2
        jr z,dh_img
        call tx
        db 164,162,C_TXT,C_CARD
        db 'ENTER  Open',0
        ret
dh_img: call tx
        db 164,155,C_TXT,C_CARD
        db 'ENTER  View picture',0
        call tx
        db 164,167,C_MUT,C_CARD
        db 'SPACE  Slideshow',0
        ret

; HL=str -> big 2x title
dd_big: push hl
        ld a,C_TXT
        ld b,C_PAN
        call settxt
        ld a,162
        ld (PBX),a
        ld a,42
        ld (PY),a
        pop hl
        jp pbig

; HL=name
dd_name: ld a,C_ACC
        ld b,C_PAN
        ld c,162
        ld d,64
        jp txs

dd_size: call tx
        db 162,80,C_MUT,C_PAN
        db 'Size',0
        ld hl,(EPTR)
        ld de,15
        add hl,de
        call fmtsize
        ld hl,SZBUF
ds_sk:  ld a,(hl)
        cp ' '
        jr nz,ds_go
        inc hl
        jr ds_sk
ds_go:  ld de,STRB2
        call cats
        ld hl,(EPTR)
        ld bc,17
        add hl,bc
        ld a,(hl)
        inc hl
        or (hl)
        jr nz,ds_fin
        ld hl,s_open
        call cats
        ld hl,(EPTR)
        ld bc,15
        add hl,bc
        ld c,(hl)
        inc hl
        ld b,(hl)
        ld h,b
        ld l,c
        call dec16
        ld hl,s_close
        call cats
ds_fin: xor a
        ld (de),a
        ld hl,STRB2
        ld a,C_TXT
        ld b,C_PAN
        ld c,190
        ld d,80
        jp txs

; ---- hint pills ----
draw_hints:
        ld hl,8
        ld (CHX),hl
        ld a,193
        ld (CHY),a
        ld a,12
        ld (CHH),a
        ld hl,hint_tab
dh_l:   ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        or e
        ret z
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        push hl
        push bc
        ex de,hl
        ld d,C_CARD
        ld e,C_TXT
        call chip
        ld hl,(CHX)
        ld de,4
        add hl,de
        ld (CHX),hl
        srl h
        rr l
        ld c,l
        pop hl
        push hl
        ld a,C_MUT
        ld b,C_BG
        ld d,195
        call txs
        pop hl
        call slen
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        add hl,hl
        ld de,(CHX)
        add hl,de
        ld de,8
        add hl,de
        ld (CHX),hl
        pop hl
        jr dh_l
