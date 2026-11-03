; ===== V9990 (Gfx9000) part =====
; Self-contained block: chip detection, G9B header read, details card.
; Hooks in shared code (one line each):
;   start.asm  call v9_detect        (init)
;   dos.asm    fm_no: jp v9_fm       (extension G9B -> mode 10, only if chip found)
;   view.asm   loadimg: mode 10 -> jp v9_load
;   ui.asm     dd_img:  mode 10 -> jp v9_dd
; Without a V9990 the extension is not recognised, so nothing changes.

V9_P3   equ 63h                 ; register data
V9_P4   equ 64h                 ; register select
V9_P5   equ 65h                 ; status (read only)
V9MODE  equ 10                  ; mode table index of the V9990 row

v9_present: db 0                ; 1 = a V9990 answers on ports 60h-6Fh
v9_fh:   db 0                   ; file handle while reading a header

; ---- detect: open bus reads FFh; otherwise write/read back R#3 ----
v9_detect:
        xor a
        ld (v9_present),a
        in a,(V9_P5)
        cp 0FFh
        ret z
        ld a,43h                ; select R#3 for read, no auto increment
        out (V9_P4),a
        in a,(V9_P3)
        ld b,a                  ; keep old value
        ld a,0A5h
        call v9_t3
        ret nz
        ld a,5Ah
        call v9_t3
        ret nz
        ld a,83h                ; put the old value back
        out (V9_P4),a
        ld a,b
        out (V9_P3),a
        ld a,1
        ld (v9_present),a
        ret

; A = value ; write to R#3, read it back ; Z = matches
v9_t3:  ld c,a
        ld a,83h                ; select R#3 for write, no auto increment
        out (V9_P4),a
        ld a,c
        out (V9_P3),a
        ld a,43h
        out (V9_P4),a
        in a,(V9_P3)
        cp c
        ret

; ---- extension hook: reached when the table has no match ----
v9_fm:  ld a,(v9_present)
        or a
        jr z,v9f_n
        ld hl,EXTB
        ld a,(hl)
        cp 'G'
        jr nz,v9f_n
        inc hl
        ld a,(hl)
        cp '9'
        jr nz,v9f_n
        inc hl
        ld a,(hl)
        cp 'B'
        jr nz,v9f_n
        ld a,V9MODE
        ret
v9f_n:  ld a,0FFh
        ret

; ---- read the first 16 bytes of file HL into RDBUF ; carry = error ----
v9_rd:  ex de,hl
        ld a,1
        ld c,43h
        call BDOS
        or a
        jr nz,v9r_er
        ld a,b
        ld (v9_fh),a
        ld de,RDBUF
        ld hl,16
        ld c,48h
        call BDOS
        push af
        push hl
        ld a,(v9_fh)
        ld b,a
        ld c,45h
        call BDOS
        pop hl
        pop af
        or a
        jr nz,v9r_er
        ld de,16
        or a
        sbc hl,de
        jr nz,v9r_er
        ret                     ; carry clear
v9r_er: scf
        ret

; ---- RDBUF holds a G9B header? carry = no ----
v9_chk: ld hl,RDBUF
        ld a,(hl)
        cp 'G'
        jr nz,v9c_no
        inc hl
        ld a,(hl)
        cp '9'
        jr nz,v9c_no
        inc hl
        ld a,(hl)
        cp 'B'
        jr nz,v9c_no
        ld hl,(RDBUF+3)         ; header size must cover the 11 known bytes
        ld de,11
        or a
        sbc hl,de
        jr c,v9c_no
        or a
        ret
v9c_no: scf
        ret

; ---- colour mode text for the header in RDBUF -> HL ----
v9_colstr:
        ld a,(RDBUF+5)
        ld hl,s_bd16
        cp 16
        ret z
        ld hl,s_bp2
        cp 2
        ret z
        ld hl,s_bp4
        cp 4
        ret z
        cp 8
        ld hl,s_v9unk
        ret nz
        ld a,(RDBUF+6)
        and 0C0h
        ld hl,s_bp6
        ret z
        cp 40h
        ld hl,s_bd8
        ret z
        cp 80h
        ld hl,s_byjk
        ret z
        ld hl,s_byuv
        ret

; ---- load hook: viewing is added in the next step ----
v9_load:
        ld hl,(CURENT)
        inc hl
        inc hl
        call v9_rd
        ld hl,m_open
        jr c,v9l_set
        call v9_chk
        ld hl,m_bad
        jr c,v9l_set
        ld hl,m_v9wip
v9l_set: ld (ERRP),hl
        scf
        ret

; ---- details card for a G9B entry (EPTR is set) ----
v9_dd:  ld hl,s_v9big
        call dd_big
        ld hl,(EPTR)
        inc hl
        inc hl
        call dd_name
        call dd_size
        ld hl,(EPTR)
        inc hl
        inc hl
        call v9_rd
        jp c,v9d_bad
        call v9_chk
        jp c,v9d_bad
        call tx
        db 162,92,C_MUT,C_PAN
        db 'Resolut.',0
        ld hl,(RDBUF+8)
        ld de,STRB2
        call dec16
        ld a,'x'
        ld (de),a
        inc de
        ld hl,(RDBUF+10)
        call dec16
        xor a
        ld (de),a
        ld hl,STRB2
        ld a,C_TXT
        ld b,C_PAN
        ld c,190
        ld d,92
        call txs
        call tx
        db 162,104,C_MUT,C_PAN
        db 'Colors',0
        call v9_colstr
        ld a,C_TXT
        ld b,C_PAN
        ld c,190
        ld d,104
        call txs
        call tx
        db 162,116,C_MUT,C_PAN
        db 'Palette',0
        ld hl,s_none
        ld a,(RDBUF+7)
        or a
        jr z,v9d_p
        ld hl,s_embed
v9d_p:  ld a,C_TXT
        ld b,C_PAN
        ld c,190
        ld d,116
        call txs
        call tx
        db 162,128,C_MUT,C_PAN
        db 'Packed',0
        ld hl,s_no
        ld a,(RDBUF+12)
        or a
        jr z,v9d_k
        ld hl,s_bbs
v9d_k:  ld a,C_TXT
        ld b,C_PAN
        ld c,190
        ld d,128
        call txs
        jp dd_hint
v9d_bad: call tx
        db 162,92,C_RED,C_PAN
        db 'Not a G9B file',0
        jp dd_hint

; ---- texts ----
s_v9big: db 'V9990',0
r_v9:    db 'V9990',0
c_v9:    db 'Gfx9000',0
m_v9wip: db 'V9990 display: next step',0
s_none:  db 'None',0
s_no:    db 'No',0
s_bbs:   db 'BitBuster',0
s_bp2:   db 'BP2  4 of 32768',0
s_bp4:   db 'BP4  16 of 32768',0
s_bp6:   db 'BP6  64 of 32768',0
s_bd8:   db 'BD8  256 fixed',0
s_bd16:  db 'BD16  32768',0
s_byjk:  db 'YJK  19268',0
s_byuv:  db 'YUV  19268',0
s_v9unk: db 'Unknown',0
