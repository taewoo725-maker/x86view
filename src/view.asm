; ===== browser loop & viewer =====
brw_loop:
        ld a,(DETD)
        or a
        jr z,bl_w
        ld c,0Bh
        call BDOS
        or a
        jr nz,bl_w
        xor a
        ld (DETD),a
        call drawdetails
bl_w:   call waitkey
        ld b,a
        ld hl,(MSGP)
        ld a,h
        or l
        jr z,bl_nm
        ld hl,0
        ld (MSGP),hl
        push bc
        call dd_hint
        pop bc
bl_nm:  ld a,b
        cp 'a'
        jr c,bl_k
        cp 'z'+1
        jr nc,bl_k
        and 0DFh
bl_k:   cp 1Bh
        jp z,quit
        cp 'Q'
        jp z,quit
        cp 1Eh
        jp z,k_up
        cp 1Fh
        jp z,k_dn
        cp 0Bh
        jp z,k_home
        cp '['
        jp z,k_pgup
        cp ']'
        jp z,k_pgdn
        cp 0Dh
        jp z,k_enter
        cp 1Ch
        jp z,k_enter
        cp 1Dh
        jp z,k_parent
        cp 08h
        jp z,k_parent
        cp ' '
        jp z,k_space
        cp 'D'
        jp z,k_drive
        cp 'A'
        jp z,k_all
        cp 'R'
        jp z,k_refresh
        jp brw_loop

k_up:   ld hl,(SEL)
        ld a,h
        or l
        jp z,brw_loop
        dec hl
        jr selgo
k_dn:   ld hl,(SEL)
        inc hl
        jr selgo
k_home: ld hl,0
        jr selgo
k_pgup: ld hl,(SEL)
        ld de,12
        or a
        sbc hl,de
        jr nc,selgo
        ld hl,0
        jr selgo
k_pgdn: ld hl,(SEL)
        ld de,12
        add hl,de
        jr selgo

selgo:  ld de,(COUNT)
        ld a,d
        or e
        jp z,brw_loop
        push hl
        or a
        sbc hl,de
        pop hl
        jr c,sg_ok
        ex de,hl
        dec hl
sg_ok:  ld (NSEL),hl
        ld hl,(SEL)
        ld (OSEL),hl
        ld hl,(NSEL)
        ld (SEL),hl
        ld hl,(TOP)
        ld (TMPW2),hl
        call fix_top
        jr nc,sg_two
        ld hl,(TOP)
        ld de,(TMPW2)
        or a
        sbc hl,de
        ld a,h
        and l
        inc a
        jr z,sg_dn1
        ld a,l
        dec a
        or h
        jr z,sg_up1
        call drawlist
        jr sg_end
sg_up1: ld hl,scr_up
        call scrollrows
        ld a,11
        call drawrow
        ld hl,(OSEL)
        ld de,(TOP)
        or a
        sbc hl,de
        ld a,l
        call drawrow
        call drawscroll
        jr sg_end
sg_dn1: ld hl,scr_dn
        call scrollrows
        xor a
        call drawrow
        ld hl,(OSEL)
        ld de,(TOP)
        or a
        sbc hl,de
        ld a,l
        call drawrow
        call drawscroll
        jr sg_end
sg_two: ld hl,(OSEL)
        ld de,(TOP)
        or a
        sbc hl,de
        ld a,l
        call drawrow
        ld hl,(SEL)
        ld de,(TOP)
        or a
        sbc hl,de
        ld a,l
        call drawrow
sg_end: ld a,1
        ld (DETD),a
        jp brw_loop

; HL = 15-byte HMMM table -> copy list body one row
scrollrows:
        push hl
        call vwait
        pop hl
        di
        ld a,32
        out (99h),a
        ld a,91h
        out (99h),a
        ld bc,0F9Bh
        otir
        ei
        jp vwait

scr_up: dw 12,52,12,40,282,132
        db 0,0,0D0h
scr_dn: dw 12,171,12,183,282,132
        db 0,8,0D0h

; make SEL visible. carry set if TOP changed
fix_top:
        ld hl,(SEL)
        ld de,(TOP)
        or a
        sbc hl,de
        jr c,ft_up
        ld de,12
        or a
        sbc hl,de
        jr c,ft_no
        ld hl,(SEL)
        ld de,11
        or a
        sbc hl,de
        ld (TOP),hl
        scf
        ret
ft_up:  ld hl,(SEL)
        ld (TOP),hl
        scf
        ret
ft_no:  or a
        ret

k_enter:
        ld hl,(COUNT)
        ld a,h
        or l
        jp z,brw_loop
        ld hl,(SEL)
        call entaddr
        ld a,(hl)
        cp 2
        jp nc,view_start
ke_dir: or a
        push hl
        jr nz,ke_nu
        call savecur
        ld a,1
        jr ke_su
ke_nu:  xor a
ke_su:  ld (UPF),a
        pop hl
        inc hl
        inc hl
        ex de,hl
ke_cd:  ld c,5Ah
        call BDOS
        or a
        jr z,ke_ok
        ld hl,m_cderr
        ld (MSGP),hl
        call dd_hint
        jp brw_loop
ke_ok:  call scan
        ld a,(UPF)
        or a
        call nz,selname
        xor a
        ld (UPF),a
        call post_scan
        jp brw_loop

post_scan:
        ld a,(EXTRA)
        or a
        jr z,ps_ok
        cp 0D7h
        jr z,ps_ok
        ld hl,m_rderr
        ld (MSGP),hl
ps_ok:  call draw_path
        call drawlist
        call drawdetails
        ret

k_parent:
        ld hl,(COUNT)
        ld a,h
        or l
        jp z,brw_loop
        ld hl,ENT
        ld a,(hl)
        or a
        jp nz,brw_loop
        call savecur
        ld a,1
        ld (UPF),a
        ld de,s_dotdot
        jr ke_cd

k_all:  ld a,(ALLF)
        xor 1
        ld (ALLF),a
k_refresh:
        call scan
        call post_scan
        jp brw_loop

k_space:
        ld hl,(COUNT)
        ld a,h
        or l
        jp z,brw_loop
        ld hl,(SEL)
        call entaddr
        ld a,(hl)
        cp 2
        jr z,ksp_ok
        ld a,1
        call step_sel
        ld hl,(SEL)
        call entaddr
        ld a,(hl)
        cp 2
        jr z,ksp_ok
        ld hl,m_nopic
        ld (MSGP),hl
        call dd_hint
        jp brw_loop
ksp_ok: ld a,1
        ld (SLIDE),a
        jp view_start

k_drive:
        call drvbuild
        ld a,(DRVN)
        cp 2
        jp c,brw_loop
        xor a
        ld (DRVTOP),a
        call drvwin
dp_draw: call drvdraw
dp_key: call waitkey
        cp 1Bh
        jr z,dp_cancel
        cp 0Dh
        jr z,dp_ok
        cp 1Eh
        jr z,dp_up
        cp 1Fh
        jr z,dp_dn
        cp 'a'
        jr c,dp_l1
        cp 'z'+1
        jr nc,dp_l1
        and 0DFh
dp_l1:  cp 'D'
        jr z,dp_cancel
        sub 'A'
        jr c,dp_key
        cp 16
        jr nc,dp_key
        ld c,a
        ld a,(DRVN)
        ld b,a
        ld hl,DRVLIST
        ld d,0
dp_f:   ld a,(hl)
        cp c
        jr z,dp_found
        inc hl
        inc d
        djnz dp_f
        jr dp_key
dp_found: ld a,d
        ld (DRVSEL),a
        jr dp_ok
dp_up:  ld a,(DRVSEL)
        or a
        jr z,dp_key
        dec a
        ld (DRVSEL),a
        call drvwin
        jr dp_draw
dp_dn:  ld a,(DRVSEL)
        inc a
        ld hl,DRVN
        cp (hl)
        jr nc,dp_key
        ld (DRVSEL),a
        call drvwin
        jr dp_draw
dp_cancel:
        call drawlist
        jp brw_loop
dp_ok:  ld a,(DRVSEL)
        ld e,a
        ld d,0
        ld hl,DRVLIST
        add hl,de
        ld e,(hl)
        ld c,0Eh
        call BDOS
        call scan
        call post_scan
        jp brw_loop

; build DRVLIST/DRVN from the login vector, DRVSEL = current drive's index
drvbuild:
        ld c,19h
        call BDOS
        ld (DRVCUR),a
        ld c,18h
        call BDOS
        ld (TMPW2),hl
        xor a
        ld (DRVN),a
        ld (DRVSEL),a
        ld c,0
db_l:   ld hl,(TMPW2)
        ld a,c
        or a
        jr z,db_t
        ld b,a
db_s:   srl h
        rr l
        djnz db_s
db_t:   ld a,l
        and 1
        jr z,db_n
        ld a,(DRVN)
        ld e,a
        ld d,0
        ld hl,DRVLIST
        add hl,de
        ld (hl),c
        ld b,a
        ld a,(DRVCUR)
        cp c
        jr nz,db_c
        ld a,b
        ld (DRVSEL),a
db_c:   ld a,b
        inc a
        ld (DRVN),a
db_n:   inc c
        ld a,c
        cp 16
        jr nz,db_l
        ret

; keep DRVSEL inside the 8-row window
drvwin: ld a,(DRVSEL)
        ld hl,DRVTOP
        cp (hl)
        jr nc,dw_1
        ld (hl),a
        ret
dw_1:   sub 7
        jr c,dw_2
        cp (hl)
        ret c
        ret z
        ld (hl),a
dw_2:   ret

; draw the drive pulldown under the path bar
drvdraw:
        ld a,(DRVN)
        cp 9
        jr c,dd_v
        ld a,8
dd_v:   ld (TMPB),a
        ld b,a
        add a,a
        add a,b
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld de,8
        add hl,de
        ld (QH),hl
        ld hl,10
        ld (QX),hl
        ld hl,38
        ld (QY),hl
        ld hl,88
        ld (QW),hl
        ld a,C_ACC
        ld (QC),a
        call rrdraw
        ld hl,12
        ld (QX),hl
        ld hl,40
        ld (QY),hl
        ld hl,84
        ld (QW),hl
        ld hl,(QH)
        ld de,-4
        add hl,de
        ld (QH),hl
        ld a,C_CARD
        ld (QC),a
        call rrdraw
        xor a
        ld (VROW),a
dr_row: ld a,(VROW)
        ld hl,DRVTOP
        add a,(hl)
        ld (TMPW),a
        ld hl,DRVN
        cp (hl)
        ret nc
        ld a,(VROW)
        ld b,a
        add a,a
        add a,b
        add a,a
        add a,a
        add a,42
        ld (RY0),a
        ld a,C_CARD
        ld (RBG),a
        ld a,(TMPW)
        ld hl,DRVSEL
        cp (hl)
        jr nz,dr_ns2
        ld a,C_SEL
        ld (RBG),a
        ld hl,14
        ld (QX),hl
        ld a,(RY0)
        ld l,a
        ld h,0
        ld (QY),hl
        ld hl,80
        ld (QW),hl
        ld hl,12
        ld (QH),hl
        ld a,C_SEL
        ld (QC),a
        call rrdraw
dr_ns2: ld a,(TMPW)
        ld e,a
        ld d,0
        ld hl,DRVLIST
        add hl,de
        ld a,(hl)
        ld c,a
        add a,'A'
        ld (STRB2),a
        ld a,':'
        ld (STRB2+1),a
        xor a
        ld (STRB2+2),a
        ld hl,STRB2
        ld a,C_TXT
        push bc
        ld c,12
        call rtx3
        pop bc
        ld a,(DRVCUR)
        cp c
        jr nz,dr_nx
        ld hl,s_cur
        ld a,C_MUT
        ld c,24
        call rtx3
dr_nx:  ld a,(VROW)
        inc a
        ld (VROW),a
        cp 8
        jp nz,dr_row
        ret

; like rtx but y = (RY0)+2 (RBG background)
rtx3:   push af
        ld a,(RY0)
        add a,2
        ld d,a
        ld a,(RBG)
        ld b,a
        pop af
        jp txs

; A=1 forward, 0FFh backward : move SEL to next picture (wraps)
step_sel:
        ld (NSTEP),a
        ld hl,(COUNT)
        ld a,h
        or l
        ret z
        ld hl,(SEL)
        ld (TMPW2),hl
ss_l:   ld hl,(SEL)
        ld a,(NSTEP)
        cp 1
        jr nz,ss_back
        inc hl
        ld de,(COUNT)
        push hl
        or a
        sbc hl,de
        pop hl
        jr c,ss_chk
        ld hl,0
        jr ss_chk
ss_back: ld a,h
        or l
        jr nz,ss_dec
        ld hl,(COUNT)
ss_dec: dec hl
ss_chk: ld (SEL),hl
        ld de,(TMPW2)
        push hl
        or a
        sbc hl,de
        pop hl
        ret z
        call entaddr
        ld a,(hl)
        cp 2
        jr nz,ss_l
        ret

; command line file
auto_open:
        ld hl,0
ao_l:   ld de,(COUNT)
        push hl
        or a
        sbc hl,de
        pop hl
        ret nc
        push hl
        call entaddr
        inc hl
        inc hl
        ld de,(AUTOP)
ao_c:   ld a,(de)
        cp (hl)
        jr nz,ao_n
        or a
        jr z,ao_f
        inc hl
        inc de
        jr ao_c
ao_n:   pop hl
        inc hl
        jr ao_l
ao_f:   pop hl
        ld (SEL),hl
        call entaddr
        ld a,(hl)
        cp 2
        ret c
        jr view_start

; ---- viewer session ----
view_start:
        ld a,0FFh
        ld (MODEOVR),a
vs_load:
        ld hl,(SEL)
        call entaddr
        ld (CURENT),hl
        call loadimg
        jr c,vs_err
        call view_wait
        or a
        jr z,vs_back
        cp 1
        jr z,vs_next
        cp 2
        jr z,vs_prev
        jr vs_load
vs_next: ld a,0FFh
        ld (MODEOVR),a
        ld a,1
        call step_sel
        jr vs_load
vs_prev: ld a,0FFh
        ld (MODEOVR),a
        call step_sel_b
        jr vs_load
vs_err: ld hl,(ERRP)
        ld (MSGP),hl
vs_back:
        xor a
        ld (SLIDE),a
        call setup_ui
        call fix_top
        call c,centertop
        call draw_all
        call enascr
        jp brw_loop

step_sel_b:
        ld a,0FFh
        jp step_sel

; returns A: 0 back, 1 next, 2 prev, 4 reload
view_wait:
        ld hl,(JIFFY)
        ld (T0),hl
vw_l:   call getkey
        or a
        jr nz,vw_k
        ld a,(SLIDE)
        or a
        jr z,vw_idle
        ld hl,(JIFFY)
        ld de,(T0)
        or a
        sbc hl,de
        ld de,(SLTICK)
        or a
        sbc hl,de
        jr c,vw_idle
        ld a,1
        ret
vw_idle: ei
        halt
        jr vw_l
vw_k:   cp 1Bh
        jr z,vw_back
        cp 0Dh
        jr z,vw_back
        cp 08h
        jr z,vw_back
        cp 1Ch
        jr z,vw_next
        cp 1Dh
        jr z,vw_prev
        cp ' '
        jr z,vw_sp
        cp '1'
        jr c,vw_ltr
        cp '9'+1
        jr nc,vw_ltr
        sub '0'
        ld (SLSEC),a
        call calc_ticks
        ld hl,(JIFFY)
        ld (T0),hl
        jp vw_l
vw_ltr: and 0DFh
        cp 'Q'
        jr z,vw_back
        cp 'M'
        jr z,vw_mode
        cp 'R'
        jr z,vw_rst
        jp vw_l
vw_back: xor a
        ret
vw_next: ld a,1
        ret
vw_prev: ld a,2
        ret
vw_sp:  ld a,(SLIDE)
        xor 1
        ld (SLIDE),a
        ld hl,(JIFFY)
        ld (T0),hl
        jp vw_l
vw_rst: ld a,0FFh
        ld (MODEOVR),a
        ld a,4
        ret
vw_mode:
        ld a,(CURMODE)
vm_n:   inc a
        cp 10
        jr c,vm_c
        xor a
vm_c:   ld c,a
        call mtptr
        inc hl
        inc hl
        ld a,(MSXVER)
        cp (hl)
        ld a,c
        jr c,vm_n
        ld (MODEOVR),a
        ld a,4
        ret

; ---- load picture in (CURENT) ----
; carry set on error (ERRP = message)
loadimg:
        ld hl,(CURENT)
        ld de,15
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (FSZLO),de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (FSZHI),de
        ; mode
        ld a,(MODEOVR)
        cp 0FFh
        jr nz,li_m
        ld hl,(CURENT)
        inc hl
        ld a,(hl)
        cp 0FFh
        jr nz,li_m
        ld hl,(FSZLO)
        ld de,(FSZHI)
        ld a,d
        or e
        ld a,6
        jr nz,li_m
        ld a,h
        cp 50h
        ld a,0
        jr c,li_m
        ld a,h
        cp 90h
        ld a,3
        jr c,li_m
        ld a,6
li_m:   ld (CURMODE),a
        call mtptr
        ld (MTP),hl
        ld a,(hl)
        ld (MSCR),a
        inc hl
        inc hl
        ld a,(hl)
        ld (MMIN),a
        inc hl
        ld a,(hl)
        ld (MBPL),a
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (MPAL),de
        ld a,(MSXVER)
        ld hl,MMIN
        cp (hl)
        jr nc,li_vok
        ld hl,m_needp
        ld (ERRP),hl
        scf
        ret
li_vok: ; open
        ld hl,(CURENT)
        inc hl
        inc hl
        ex de,hl
        ld a,1
        ld c,43h
        call BDOS
        or a
        jr z,li_op
        ld hl,m_open
        ld (ERRP),hl
        scf
        ret
li_op:  ld a,b
        ld (FH),a
        ld de,HDR
        ld hl,7
        ld c,48h
        call BDOS
        ld a,(HDR)
        cp 0FDh
        jr z,li_pack
        cp 0FEh
        jr nz,li_raw
        ld hl,(HDR+3)
        ld de,(HDR+1)
        ld (HSTART),de
        or a
        sbc hl,de
        jr c,li_bad
        inc hl
        ld a,h
        or l
        jr nz,li_l1
        ld hl,0FFFFh
li_l1:  ld (HLEN),hl
        ; clamp to file size-7
        ld de,(FSZHI)
        ld a,d
        or e
        jr nz,li_cl
        ld hl,(FSZLO)
        ld de,7
        or a
        sbc hl,de
        jr c,li_bad
        ld de,(HLEN)
        push hl
        or a
        sbc hl,de
        pop hl
        jr nc,li_cl
        ld (HLEN),hl
li_cl:  jr li_hok
li_raw: ld a,(FH)
        ld b,a
        xor a
        ld de,0
        ld hl,0
        ld c,4Ah
        call BDOS
        ld hl,0
        ld (HSTART),hl
        ld hl,(FSZHI)
        ld a,h
        or l
        ld hl,0FFFFh
        jr nz,li_rl
        ld hl,(FSZLO)
li_rl:  ld (HLEN),hl
li_hok: ld hl,(HLEN)
        ld a,h
        or l
        jr nz,li_len
li_pack: call li_close
        ld hl,m_pack
        ld (ERRP),hl
        scf
        ret
li_bad: call li_close
        ld hl,m_bad
        ld (ERRP),hl
        scf
        ret
li_len: ; lines
        ld a,(MBPL)
        or a
        ld a,192
        jr z,li_ln
        ld hl,(HSTART)
        ld de,(HLEN)
        add hl,de
        jr nc,li_e1
        ld hl,0FFFFh
li_e1:  ld de,(MPAL)
        ld a,d
        or e
        jr z,li_e2
        push hl
        or a
        sbc hl,de
        pop hl
        jr c,li_e2
        ex de,hl
li_e2:  ld a,(MBPL)
        cp 16
        jr z,li_b256
        ld a,l
        rl a
        ld a,h
        rla
        jr li_cmp
li_b256: ld a,h
li_cmp: cp 193
        ld a,192
        jr c,li_ln
        ld a,212
li_ln:  ld (NLINES),a
        ; ---- screen setup ----
        call disscr
        ld a,(MSCR)
        cp 10
        jr c,li_cm
        ld a,8
li_cm:  call chgmod
        call disscr
        ld hl,defpal
        call setpal
        ld a,(MSCR)
        ld b,0
        cp 12
        jr nz,ly1
        ld b,08h
        jr ly3
ly1:    cp 10
        jr c,ly3
        ld b,18h
ly3:    ld a,b
        call setyjk
        ld a,(RG8SAV)
        or 2
        ld (RG8SAV),a
        ld c,8
        call vreg
        ld a,(RG9SAV)
        and 7Fh
        ld b,a
        ld a,(NLINES)
        cp 212
        ld a,b
        jr nz,li_r9
        or 80h
li_r9:  ld (RG9SAV),a
        ld c,9
        call vreg
        xor a
        ld c,7
        call vreg
        ; ---- data ----
        ld hl,(HSTART)
        ld (VADDR),hl
        ld hl,(HLEN)
        ld (REM),hl
li_lp:  ld hl,(REM)
        ld a,h
        or l
        jp z,li_done
        ld bc,2048
        or a
        sbc hl,bc
        jr nc,lc1
        ld bc,(REM)
lc1:    ld hl,(VADDR)
        ld a,h
        and 3Fh
        ld h,a
        ex de,hl
        ld hl,4000h
        or a
        sbc hl,de
        push hl
        or a
        sbc hl,bc
        pop hl
        jr nc,lc2
        ld b,h
        ld c,l
lc2:    ld (CHUNK),bc
        ld a,(FH)
        ld b,a
        ld de,RDBUF
        ld hl,(CHUNK)
        ld c,48h
        call BDOS
        ld a,h
        or l
        jp z,li_done
        ld (CHUNK),hl
        call grabpal
        ld hl,(VADDR)
        call vsetw
        ld hl,RDBUF
        ld de,(CHUNK)
        call vramout
        ld hl,(VADDR)
        ld de,(CHUNK)
        add hl,de
        ld (VADDR),hl
        ld hl,(REM)
        or a
        sbc hl,de
        ld (REM),hl
        jp li_lp
li_done:
        ; palette
        ld hl,(MPAL)
        ld a,h
        or l
        jr z,li_np
        ld hl,(HSTART)
        ld de,(HLEN)
        add hl,de
        jr c,li_pc
        ex de,hl
        ld hl,(MPAL)
        ld bc,32
        add hl,bc
        or a
        sbc hl,de
        jr c,li_pc
        jr nz,li_nopal
li_pc:  ld hl,(MPAL)
        ld de,(HSTART)
        or a
        sbc hl,de
        jr c,li_nopal
        ld hl,PALBUF
        call setpal
        jr li_np
li_nopal:
        call tryplfile
li_np:  call enascr
        call li_close
        or a
        ret

; palette in a separate file NAME.PLn (Graph Saurus): first 32 bytes
tryplfile:
        ld hl,(CURENT)
        inc hl
        inc hl
        ld de,STRBUF
tp_c:   ld a,(hl)
        or a
        ret z
        cp '.'
        jr z,tp_dot
        ld (de),a
        inc hl
        inc de
        jr tp_c
tp_dot: ld a,'.'
        ld (de),a
        inc de
        ld a,'P'
        ld (de),a
        inc de
        ld a,'L'
        ld (de),a
        inc de
tp_e:   ld a,(hl)
        inc hl
        or a
        jr nz,tp_e
        dec hl
        dec hl
        ld a,(hl)
        ld (de),a
        inc de
        xor a
        ld (de),a
        ld de,STRBUF
        ld a,1
        ld c,43h
        call BDOS
        or a
        ret nz
        ld a,b
        ld (TMPB),a
        ld de,PALBUF
        ld hl,32
        ld c,48h
        call BDOS
        ld a,(TMPB)
        ld b,a
        ld c,45h
        call BDOS
        ld hl,PALBUF
        jp setpal

li_close:
        ld a,(FH)
        ld b,a
        ld c,45h
        call BDOS
        ret

; copy palette bytes that lie inside the chunk just read (RDBUF at VADDR, CHUNK bytes) into PALBUF
grabpal:
        ld hl,(MPAL)
        ld a,h
        or l
        ret z
        ld c,0
gp_l:   ld hl,(MPAL)
        ld b,0
        add hl,bc
        ld de,(VADDR)
        or a
        sbc hl,de
        jr c,gp_n
        ld de,(CHUNK)
        push hl
        or a
        sbc hl,de
        pop hl
        jr nc,gp_n
        ld de,RDBUF
        add hl,de
        ld a,(hl)
        ld hl,PALBUF
        ld b,0
        add hl,bc
        ld (hl),a
gp_n:   inc c
        ld a,c
        cp 32
        jr nz,gp_l
        ret

; remember the name of the current folder (last path part) in NAMEBUF
savecur:
        ld b,0
        ld de,PATHBUF
        ld c,59h
        call BDOS
        ld hl,PATHBUF
        ld (TMPW2),hl
sv_l:   ld a,(hl)
        or a
        jr z,sv_d
        inc hl
        cp '\'
        jr nz,sv_l
        ld (TMPW2),hl
        jr sv_l
sv_d:   ld hl,(TMPW2)
        ld de,NAMEBUF
        ld b,12
sv_c:   ld a,(hl)
        ld (de),a
        or a
        ret z
        inc hl
        inc de
        djnz sv_c
        xor a
        ld (de),a
        ret

; select the folder named NAMEBUF in the list (after going up)
selname:
        ld hl,0
sn_l:   ld de,(COUNT)
        push hl
        or a
        sbc hl,de
        pop hl
        ret nc
        push hl
        call entaddr
        ld a,(hl)
        cp 1
        jr nz,sn_n
        inc hl
        inc hl
        ld de,NAMEBUF
sn_c:   ld a,(de)
        cp (hl)
        jr nz,sn_n
        or a
        jr z,sn_f
        inc hl
        inc de
        jr sn_c
sn_n:   pop hl
        inc hl
        jr sn_l
sn_f:   pop hl
        ld (SEL),hl
centertop:
        ld hl,(SEL)
        ld de,12
        push hl
        or a
        sbc hl,de
        pop hl
        ld de,0
        jr c,sn_t
        ld de,5
        or a
        sbc hl,de
        ex de,hl
        ld hl,(COUNT)
        ld bc,12
        or a
        sbc hl,bc
        jr nc,sn_m
        ld hl,0
sn_m:   push hl
        or a
        sbc hl,de
        pop hl
        jr nc,sn_t
        ex de,hl
sn_t:   ld (TOP),de
        ret
