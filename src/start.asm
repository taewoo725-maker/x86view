; ===== start / init / exit =====
start:  jp main

main:   ld hl,(0006h)
        ld de,0B100h
        or a
        sbc hl,de
        ld de,m_mem
        jp c,fatal
        ld sp,0B000h
        ld c,6Fh
        call BDOS
        or a
        ld de,m_dos
        jp nz,fatal
        ld a,b
        cp 2
        ld de,m_dos
        jp c,fatal
        ld a,(EXPTBL)
        ld hl,002Dh
        call RDSLT
        ei
        ld (MSXVER),a
        or a
        ld de,m_msx
        jp z,fatal
        call vram128
        ld de,m_vram
        jp nz,fatal
        ld a,(SCRMOD)
        ld (OLDMODE),a
        ld a,(RG8SAV)
        ld (OLD8),a
        ld a,(RG9SAV)
        ld (OLD9),a
        ld a,0FFh
        ld (MODEOVR),a
        ld a,4
        ld (SLSEC),a
        xor a
        ld (ALLF),a
        ld (SLIDE),a
        ld hl,0
        ld (MSGP),hl
        ld (AUTOP),hl
        ld (SEL),hl
        ld (TOP),hl
        ld (COUNT),hl
        ld a,(RG9SAV)
        and 2
        ld a,60
        jr z,mn_hz
        ld a,50
mn_hz:  ld (HZ),a
        call calc_ticks
        ld a,0FFh
        ld (FG),a
        ld (BG),a
        ld a,(MSXVER)
        cp 3
        jr nz,mn_nd
        xor a
        ld (dly1),a
mn_nd:  call v9_detect
        call parseargs
        call loadfont
        ld de,diskerr
        ld c,64h
        call BDOS
        ld de,abortr
        ld c,63h
        call BDOS
        call setup_ui
        call scan
        call draw_all
        call enascr
        ld hl,(AUTOP)
        ld a,h
        or l
        call nz,auto_open
        jp brw_loop

fatal:  ld c,9
        call BDOS
        ld b,1
        ld c,62h
        call BDOS
        rst 0

diskerr: ld a,3
        ret

abortr: push af
        call restore_screen
        pop af
        ret

; leave program
quit:   call restore_screen
qt_f:   call getkey
        or a
        jr nz,qt_f
        ld b,0
        ld c,62h
        call BDOS
        rst 0

restore_screen:
        call v9_off
        ld a,(OLD8)
        ld (RG8SAV),a
        ld a,(OLD9)
        ld (RG9SAV),a
        ld a,(OLDMODE)
        call chgmod
        xor a
        call setyjk
        ld hl,defpal
        call setpal
        ld a,(OLD8)
        ld c,8
        call vreg
        ld a,(OLD9)
        ld c,9
        call vreg
        ret

; HZ*SLSEC -> SLTICK
calc_ticks:
        ld a,(SLSEC)
        ld b,a
        ld a,(HZ)
        ld e,a
        ld d,0
        ld hl,0
ct_l:   add hl,de
        djnz ct_l
        ld (SLTICK),hl
        ret

; ---- BIOS via CALSLT ----
disscr: ld ix,DISSCR
        jr biosc
enascr: ld ix,ENASCR
        jr biosc
chgmod: ld ix,CHGMOD
biosc:  ld iy,(EXPMAL)
        call CALSLT
        ei
        ret

; ---- keyboard ----
getkey: ld e,0FFh
        ld c,6
        call BDOS
        ret
waitkey: call getkey
        or a
        ret nz
        ei
        halt
        jr waitkey

; ---- font (built in) ----
loadfont:
        ld hl,FONT
        ld de,FONT+1
        ld bc,1023
        ld (hl),0
        ldir
        ld hl,myfont
        ld de,FONT+20h*8
        ld bc,myfont_end-myfont
        ldir
        ld hl,glyphs
        ld de,FONT+8
        ld bc,glyphs_end-glyphs
        ldir
        ld hl,glyph_arr
        ld de,FONT+1Eh*8
        ld bc,16
        ldir
        ret

; ---- command line ----
parseargs:
        ld hl,0080h
        ld a,(hl)
        or a
        ret z
        ld b,a
        inc hl
pa_sk:  ld a,(hl)
        cp ' '
        jr nz,pa_go
        inc hl
        djnz pa_sk
        ret
pa_go:  ld a,b
        cp 60
        jr c,pa_ln
        ld b,60
pa_ln:  ld de,ARGBUF
pa_cp:  ld a,(hl)
        cp ' '
        jr z,pa_end
        cp 'a'
        jr c,pa_u
        cp 'z'+1
        jr nc,pa_u
        and 0DFh
pa_u:   ld (de),a
        inc hl
        inc de
        djnz pa_cp
pa_end: xor a
        ld (de),a
        ld hl,ARGBUF
        ld a,(hl)
        cp '/'
        jr z,pa_opt
        cp '-'
        jr nz,pa_path
pa_opt: inc hl
        ld a,(hl)
        cp '?'
        jr z,pa_help
        cp 'H'
        jr nz,pa_clr
pa_help: ld de,m_usage
        jp fatal
pa_clr: xor a
        ld (ARGBUF),a
        ret
pa_path:
        inc hl
        ld a,(hl)
        dec hl
        cp ':'
        jr nz,pa_nd
        ld a,(hl)
        sub 'A'
        ld e,a
        ld c,0Eh
        call BDOS
        ld hl,ARGBUF+2
pa_nd:  ld a,(hl)
        or a
        ret z
        ld (TMPW2),hl
        ex de,hl
        ld c,5Ah
        call BDOS
        or a
        ret z
        ld hl,(TMPW2)
        ld de,0
        ld (LASTBS),de
pa_f:   ld a,(hl)
        or a
        jr z,pa_fe
        cp '\'
        jr nz,pa_fn
        ld (LASTBS),hl
pa_fn:  inc hl
        jr pa_f
pa_fe:  ld hl,(LASTBS)
        ld a,h
        or l
        jr nz,pa_bs
        ld hl,(TMPW2)
        ld (AUTOP),hl
        ret
pa_bs:  ld de,(TMPW2)
        or a
        sbc hl,de
        ld hl,(LASTBS)
        jr nz,pa_sub
        inc hl
        ld (AUTOP),hl
        ld de,s_root
        ld c,5Ah
        call BDOS
        ret
pa_sub: xor a
        ld (hl),a
        inc hl
        ld (AUTOP),hl
        ld de,(TMPW2)
        ld c,5Ah
        call BDOS
        ret

; Z if VRAM is 128KB (A16 works). uses 3F00h / 13F00h
vram128:
        di
        ld a,0
        out (99h),a
        ld a,8Eh
        out (99h),a
        ld a,00h
        out (99h),a
        ld a,3Fh
        or 40h
        out (99h),a
        ld a,5Ah
        out (98h),a
        ld a,4
        out (99h),a
        ld a,8Eh
        out (99h),a
        ld a,00h
        out (99h),a
        ld a,3Fh
        or 40h
        out (99h),a
        ld a,0A5h
        out (98h),a
        xor a
        out (99h),a
        ld a,8Eh
        out (99h),a
        ld a,00h
        out (99h),a
        ld a,3Fh
        out (99h),a
        in a,(98h)
        ei
        cp 5Ah
        ret


; A = R#25 YJK bits (0 off, 08h YJK, 18h YJK+YAE). V9958 only
setyjk: ld b,a
        ld a,(MSXVER)
        cp 2
        ret c
        ld a,(RG25SAV)
        and 0E7h
        or b
        ld (RG25SAV),a
        ld c,25
        jp vreg
