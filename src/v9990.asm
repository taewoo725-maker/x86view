; ===== V9990 (Gfx9000) part =====
; Self-contained block: chip detection, G9B header read, details card.
; Hooks in shared code (one line each):
;   start.asm  call v9_detect        (init)
;   dos.asm    fm_no: jp v9_fm       (extension G9B -> mode 10, only if chip found)
;   view.asm   loadimg: mode 10 -> jp v9_load
;   ui.asm     dd_img:  mode 10 -> jp v9_dd
; Without a V9990 the extension is not recognised, so nothing changes.
; G9B format: Team Bomba (GFX9k library). BitBuster 2 unpacking follows the format of
; bitbuster.asm (c) 2003-2004,2022 Arjan Bakker, MIT License.

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

; ---- constants / part-owned state ----
V9_P0   equ 60h                 ; VRAM data (write address auto-increments)
V9_P1   equ 61h                 ; palette data
V9_P7   equ 67h                 ; system control
V9RING  equ 0B8h                ; match window B800h-BFFFh (2 KB, high byte)
V9BUF   equ RDBUF               ; compressed data buffer, 1024 bytes
v9_end:  dw 0                   ; end of valid bytes in V9BUF
v9_ip:   dw 0
v9_left: dw 0
v9_req:  dw 0
v9_nb:   db 0                   ; blocks left
v9_bb:   db 0                   ; bit buffer saved while copying
v9_shown: db 0
v9_r6:   db 0
v9_r7:   db 0
v9_r13:  db 0
v9_rem:  ds 3
v9_hd:   ds 16                  ; copy of the G9B header

; ---- read HL bytes to DE from the open file ; HL = bytes read ----
v9_readc:
        ld a,(v9_fh)
        ld b,a
        ld c,48h
        jp BDOS

; ---- after a short read: FFh up to 1000 bytes behind the data, so a cut or damaged file
; ends its blocks instead of running on (all ones = end-of-block pattern) ----
v9_pad: ld hl,(v9_end)
        ld d,h
        ld e,l
        inc de
        ld (hl),0FFh
        ld bc,999
        ldir
        ret

; ---- close the open file ----
v9_close:
        ld a,(v9_fh)
        ld b,a
        ld c,45h
        jp BDOS

; ---- show a line in the card under the details (HL = text) ----
v9_msg: push hl
        call rrct
        dw 320,152,176,30
        db C_CARD
        pop hl
        ld a,C_YEL
        ld b,C_CARD
        ld c,164
        ld d,162
        jp txs

; ---- picture off (leaving the viewer / program) ----
v9_off: ld a,(v9_shown)
        or a
        ret z
        xor a
        ld (v9_shown),a
        ld a,8
        out (V9_P4),a
        ld a,42h                ; DISP off, sprites off
        out (V9_P3),a
        ret

; ---- header in v9_hd -> v9_r6 / v9_r7 / v9_r13 ; carry = not supported ----
v9_params:
        ld hl,(v9_hd+8)         ; width
        ld de,256
        or a
        sbc hl,de
        ld bc,0                 ; B = DCKM, C = XIMM
        jr z,vp_w
        ld hl,(v9_hd+8)
        ld de,512
        or a
        sbc hl,de
        jp nz,vp_bad
        ld bc,0101h             ; 512 wide: DCKM 1, XIMM 1
vp_w:   ld hl,(v9_hd+10)        ; height 1..424
        ld a,h
        or l
        jp z,vp_bad
        ld de,425
        or a
        sbc hl,de
        jp nc,vp_bad
        ld a,(v9_hd+5)          ; bits per pixel -> CLRM
        ld d,0
        cp 2
        jr z,vp_c
        inc d
        cp 4
        jr z,vp_c
        inc d
        cp 8
        jr z,vp_c
        inc d
        cp 16
        jr nz,vp_bad
vp_c:   ld a,b                  ; R#6 = 10 DCKM XIMM CLRM
        add a,a
        add a,a
        or c
        add a,a
        add a,a
        or d
        or 80h
        ld (v9_r6),a
        ld hl,(v9_hd+10)        ; more than 212 lines: interlace, double
        ld de,213
        or a
        sbc hl,de
        ld a,0
        jr c,vp_7
        ld a,6                  ; EO + IL
vp_7:   ld (v9_r7),a
        xor a                   ; PLTM from the colour type (8 bit only)
        ld e,a
        ld a,(v9_hd+5)
        cp 8
        jr nz,vp_13
        ld a,(v9_hd+6)
        and 0C0h
        rlca
        rlca
        ld e,a
vp_13:  ld a,e
        rrca
        rrca
        and 0C0h
        ld (v9_r13),a
        or a
        ret
vp_bad: scf
        ret

; ---- program the chip ; BC = palette bytes at V9BUF+16 ----
v9_setup:
        ld a,10h                ; keep the display adjust R#16 over the reset
        out (V9_P4),a
        in a,(V9_P3)
        push af
        ld a,2
        out (V9_P7),a           ; soft reset
        xor a
        out (V9_P7),a
        ld a,10h
        out (V9_P4),a
        pop af
        out (V9_P3),a
        ld a,6                  ; R#6, R#7, R#8 in a row
        out (V9_P4),a
        ld a,(v9_r6)
        out (V9_P3),a
        ld a,(v9_r7)
        out (V9_P3),a
        ld a,42h                ; DISP off while loading
        out (V9_P3),a
        ld a,13                 ; R#13 colour mode, R#14 palette pointer 0, R#15 backdrop 0
        out (V9_P4),a
        ld a,(v9_r13)
        out (V9_P3),a
        xor a
        out (V9_P3),a
        out (V9_P3),a
        ld a,17                 ; R#17-R#28: scroll, sprite base, priority all 0
        out (V9_P4),a
        ld d,12
vs_z:   xor a
        out (V9_P3),a
        dec d
        jr nz,vs_z
        ld a,b                  ; palette
        or c
        jr z,vs_np
        push bc
        ld hl,V9BUF+16
        ld d,0
vs_s:   ld a,(hl)               ; any value above 31 -> 8 bit palette, scale down
        or d
        ld d,a
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,vs_s
        pop bc
        ld a,d
        and 0E0h
        ld e,a
        ld a,14
        out (V9_P4),a
        xor a
        out (V9_P3),a
        ld hl,V9BUF+16
vs_w:   ld a,(hl)
        inc hl
        ld d,a
        ld a,e
        or a
        ld a,d
        jr z,vs_n
        rrca
        rrca
        rrca
vs_n:   and 1Fh
        out (V9_P1),a
        dec bc
        ld a,b
        or c
        jr nz,vs_w
vs_np:  xor a                   ; VRAM write address 0, auto increment
        out (V9_P4),a
        out (V9_P3),a
        out (V9_P3),a
        out (V9_P3),a
        ret

; ---- load hook: show the picture on the V9990 ----
v9_load:
        ld hl,(0006h)           ; the match window needs memory up to BFFFh
        ld de,0C100h
        or a
        sbc hl,de
        ld hl,m_v9mem
        jp c,v9l_set
        ld hl,m_v9load
        call v9_msg
        ld hl,(CURENT)
        inc hl
        inc hl
        ex de,hl
        ld a,1
        ld c,43h
        call BDOS
        or a
        ld hl,m_open
        jp nz,v9l_set
        ld a,b
        ld (v9_fh),a
        ld de,V9BUF
        ld hl,1024
        call v9_readc
        ld de,V9BUF
        add hl,de
        ld (v9_end),hl
        ld de,1024+V9BUF
        or a
        sbc hl,de
        call c,v9_pad           ; shorter than asked: end of file
        ld hl,(v9_end)
        ld de,V9BUF+16
        or a
        sbc hl,de
        jp c,v9l_bad
        call v9_chk
        jp c,v9l_bad
        ld hl,V9BUF
        ld de,v9_hd
        ld bc,16
        ldir
        call v9_params
        jp c,v9l_size
        ld a,(v9_hd+12)         ; packing: 0 none, 1 BitBuster
        cp 2
        jp nc,v9l_comp
        ld a,(v9_hd+7)          ; palette bytes = colours * 3
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        ld b,h
        ld c,l
        ld hl,V9BUF+16
        add hl,bc
        ex de,hl                ; DE = first data byte
        ld hl,(v9_end)
        or a
        sbc hl,de
        jp c,v9l_bad
        push de
        call v9_setup
        pop hl                  ; HL = data
        ld a,(v9_hd+12)
        or a
        jr z,v9_raw
        call v9_bust
        jr v9_fin

; raw data: HL = pointer in V9BUF
v9_raw: ld a,(v9_hd+13)
        ld (v9_rem),a
        ld a,(v9_hd+14)
        ld (v9_rem+1),a
        ld a,(v9_hd+15)
        ld (v9_rem+2),a
rw_lp:  ld de,(v9_end)          ; bytes in the buffer from HL
        ex de,hl
        or a
        sbc hl,de               ; HL = available
        ld b,h
        ld c,l
        ld hl,(v9_rem)          ; use the smaller of available / remaining
        ld a,(v9_rem+2)
        or a
        jr nz,rw_go
        or a
        sbc hl,bc
        add hl,bc
        jr nc,rw_go             ; remaining >= available
        ld b,h
        ld c,l
rw_go:  ex de,hl                ; HL = data pointer again
        ld a,b
        or c
        jr z,rw_nx
        push bc
rw_b:   ld a,(hl)
        out (V9_P0),a
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,rw_b
        pop bc
        push hl
        ld hl,(v9_rem)
        or a
        sbc hl,bc
        ld (v9_rem),hl
        ld a,(v9_rem+2)
        sbc a,0
        ld (v9_rem+2),a
        pop hl
rw_nx:  ld a,(v9_rem+2)
        ld bc,(v9_rem)
        or b
        or c
        jr z,v9_fin
        call v9_refill
        ld de,(v9_end)
        ld a,d                  ; nothing more in the file: stop
        cp 87h
        jr nz,rw_lp
        ld a,e
        or a
        jr nz,rw_lp
v9_fin: ld a,8                  ; DISP on
        out (V9_P4),a
        ld a,0C2h
        out (V9_P3),a
        ld a,1
        ld (v9_shown),a
        call v9_close
        ld hl,m_v9on
        call v9_msg
        or a
        ret
v9l_bad: ld hl,m_bad
        jr v9l_cl
v9l_size: ld hl,m_v9size
        jr v9l_cl
v9l_comp: ld hl,m_v9comp
v9l_cl: push hl
        call v9_close
        pop hl
v9l_set: ld (ERRP),hl
        scf
        ret

; ---- more bytes: keep what is left from HL, read up to 1024 in total ; HL = V9BUF ----
v9_refill:
        push bc
        push de
        push iy
        ex de,hl                ; DE = pointer
        ld hl,(v9_end)
        or a
        sbc hl,de               ; HL = bytes left
        jr nc,rf_ok
        ld hl,0                 ; pointer ran past the end (damaged data)
rf_ok:  ld (v9_left),hl
        ld b,h
        ld c,l
        ex de,hl                ; HL = pointer
        ld de,V9BUF
        ld a,b
        or c
        jr z,rf_nm
        ldir
rf_nm:  push de
        ld hl,1024
        ld bc,(v9_left)
        or a
        sbc hl,bc
        ld (v9_req),hl
        pop de
        call v9_readc
        push hl
        ld de,(v9_left)
        add hl,de
        ld de,V9BUF
        add hl,de
        ld (v9_end),hl
        pop hl                  ; bytes read
        ld de,(v9_req)
        or a
        sbc hl,de
        call c,v9_pad           ; fewer than asked: end of file
        ld hl,V9BUF
        pop iy
        pop de
        pop bc
        ret

; ---- next bit from the stream (C = bit buffer, HL = pointer) ; carry = bit ----
v9_gb:  sla c
        ret nz
        ld c,(hl)
        inc hl
        scf
        rl c
        ret

; ---- BitBuster 2: HL = block count byte ; data goes to the V9990 and a 2 KB window ----
; stream = blocks; block = size word + bits (flag 0 = literal, 1 = match: gamma length,
; offset byte, 4 extra bits when bit 7 is set); a gamma that overflows ends the block
v9_bust:
        ld a,(hl)
        inc hl
        ld (v9_nb),a
        or a
        ret z
        ld de,V9RING*256
bb_blk: ld a,h
        cp 8Ah
        call nc,v9_refill
        inc hl                  ; skip the block size word
        inc hl
        ld c,128
bb_lp:  ld a,h
        cp 8Ah
        call nc,v9_refill
        call v9_gb
        jr c,bb_m
        ld a,(hl)
        inc hl
        out (V9_P0),a
        ld (de),a
        inc de
        bit 6,d
        jr z,bb_lp
        ld d,V9RING
        jr bb_lp
bb_m:   ld iy,1
bm_g:   call v9_gb
        jr nc,bm_o
        call v9_gb
        ld a,0
        rla
        add iy,iy
        jr c,bb_eob
        or a
        jr z,bm_g
        inc iy
        jr bm_g
bm_o:   ld a,(hl)
        inc hl
        ld b,0
        bit 7,a
        jr z,bm_1
        call v9_gb
        rl b
        call v9_gb
        rl b
        call v9_gb
        rl b
        call v9_gb
        jr c,bm_1
        res 7,a
bm_1:   ld (v9_ip),hl
        ld l,a
        ld h,b
        inc hl                  ; HL = distance
        ld a,c
        ld (v9_bb),a
        push de
        ld a,e
        sub l
        ld l,a
        ld a,d
        sbc a,h
        ld h,a                  ; HL = write pointer - distance
        bit 3,h
        jr nz,bm_s
        ld a,h
        add a,8
        ld h,a
bm_s:   push iy
        pop bc
        inc bc                  ; length = value + 1
        pop de
bm_c:   ld a,(hl)
        inc hl
        bit 6,h
        jr z,bm_c1
        ld h,V9RING
bm_c1:  out (V9_P0),a
        ld (de),a
        inc de
        bit 6,d
        jr z,bm_c2
        ld d,V9RING
bm_c2:  dec bc
        ld a,b
        or c
        jr nz,bm_c
        ld a,(v9_bb)
        ld c,a
        ld hl,(v9_ip)
        jp bb_lp
bb_eob: ld a,(v9_nb)
        dec a
        ld (v9_nb),a
        jp nz,bb_blk
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
m_v9load: db 'Loading on V9990...',0
m_v9on:  db 'Showing on V9990',0
m_v9size: db 'V9990: size not supported',0
m_v9comp: db 'Unknown packing type',0
m_v9mem: db 'Not enough memory',0
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
