; ===== data =====
m_mem:   db 'Not enough memory.',13,10,'$'
m_dos:   db 'X86VIEW needs MSX-DOS 2 or later.',13,10,'$'
m_vram:  db 'X86VIEW needs 128KB VRAM (SCREEN 7).',13,10,'$'
m_msx:   db 'X86VIEW needs MSX2 or later.',13,10,'$'
m_usage: db 'X86VIEW 1.1.0 - picture viewer for MSX2/2+ (SCREEN 2-8,10-12, V9990)',13,10
         db 'Usage: X86VIEW [drive:][path][file]',13,10
         db 13,10
         db 'Browser : Up/Down select, Enter view/open, Space slideshow',13,10
         db '          Left/BS parent, D drive, A all files, ESC quit',13,10
         db 'Viewer  : Left/Right prev/next, Space slideshow, 1-9 seconds',13,10
         db '          M change SCREEN mode, R reset, ESC back',13,10,'$'

s_all:   db '*.*',0
s_root:  db '\',0
s_dotdot: db '..',0
s_dos2:  db 'DOS2',0
s_msx2:  db 'MSX2',0
s_msx2p: db 'MSX2+',0
s_tr:    db 'TURBO R',0
machtab: dw s_msx2,s_msx2p,s_tr
s_items: db ' items',0
s_dirtag: db '<DIR>',0
s_cur:   db 'now',0
s_huge:  db '>16M',0
s_open:  db ' (',0
s_close: db 'B)',0
s_screen: db 'SCREEN ',0
s_parent: db 'PARENT',0
s_folder: db 'FOLDER',0
s_file:  db 'FILE',0
s_embed: db 'Embedded',0
s_default: db 'Default',0
s_pdef:  db 'MSX default',0
s_fixed: db 'Fixed',0
m_open:  db 'Cannot open the file',0
m_bad:   db 'Bad picture file',0
m_pack:  db 'Packed file (FD)',0
m_needp: db 'Needs MSX2+ (V9958)',0
m_cderr: db 'Cannot open folder',0
m_rderr: db 'Cannot read drive',0
m_nopic: db 'No pictures here',0

; hint pills
hk_updn: db 1Eh,1Fh,0
hk_ent:  db 'ENTER',0
hk_spc:  db 'SPACE',0
hk_d:    db 'D',0
hk_a:    db 'A',0
hk_esc:  db 'ESC',0
hl_move: db 'Move',0
hl_view: db 'View',0
hl_slide: db 'Slides',0
hl_drive: db 'Drive',0
hl_all:  db 'All',0
hl_quit: db 'Quit',0
hint_tab:
        dw hk_updn,hl_move
        dw hk_ent,hl_view
        dw hk_spc,hl_slide
        dw hk_d,hl_drive
        dw hk_a,hl_all
        dw hk_esc,hl_quit
        dw 0

icontab: db 5,C_MUT, 1,C_YEL, 3,C_CYAN, 3,C_DIM

; mode table: screen, chipcolor, minver, bpl/16, paladdr, res, colors, pad
mt:
        db 2,C_CYAN,1,0
        dw 0,r_192,c_16fix,s_pdef
        db 3,C_CYAN,1,0
        dw 0,r_64,c_16fix,s_pdef
        db 4,C_CYAN,1,0
        dw 0,r_192,c_16fix,s_pdef
        db 5,C_GRN,1,8
        dw 7680h,r_212,c_16of,0
        db 6,C_YEL,1,8
        dw 7680h,r_512,c_4of,0
        db 7,C_ORG,1,16
        dw 0FA80h,r_512,c_16of,0
        db 8,C_RED,1,16
        dw 0,r_212,c_256,s_fixed
        db 10,C_PUR,2,16
        dw 0FA80h,r_212,c_yjkrgb,0
        db 11,C_PUR,2,16
        dw 0FA80h,r_212,c_yjkrgb,0
        db 12,C_PUR,2,16
        dw 0,r_212,c_yjk,s_fixed
        db 90,C_BLU,1,0
        dw 0,r_v9,c_v9,s_pdef
r_192:   db '256x192',0
r_64:    db '64x48',0
r_212:   db '256x212',0
r_512:   db '512x212',0
c_16fix: db '16 fixed',0
c_16of:  db '16 of 512',0
c_4of:   db '4 of 512',0
c_256:   db '256 fixed',0
c_yjkrgb: db 'YJK + RGB',0
c_yjk:   db '19268 YJK',0
modelab: db 'SC2',0,'SC3',0,'SC4',0,'SC5',0,'SC6',0,'SC7',0,'SC8',0,'S10',0,'S11',0,'S12',0,'V90',0

exttab:
        db 'SC2',0, 'GR2',0, 'S02',0
        db 'SC3',1, 'S03',1
        db 'SC4',2, 'S04',2
        db 'SC5',3, 'SR5',3, 'GE5',3, 'S05',3
        db 'SC6',4, 'SR6',4, 'GE6',4, 'S06',4
        db 'SC7',5, 'SR7',5, 'GE7',5, 'S07',5
        db 'SC8',6, 'SR8',6, 'GE8',6, 'S08',6
        db 'SCA',7, 'SRA',7, 'S10',7
        db 'SCB',8, 'SRB',8, 'S11',8
        db 'SCC',9, 'SRC',9, 'GEC',9, 'S12',9
        db 0

; glyphs for chars 1..6 (folder, picture, up) and arrows 1Eh,1Fh
glyphs:
        db 000h,078h,0FCh,0FCh,0FCh,0FCh,07Ch,000h
        db 000h,000h,0F8h,0FCh,0FCh,0FCh,0F8h,000h
        db 07Ch,080h,080h,090h,0B8h,0FCh,07Ch,000h
        db 0F8h,004h,034h,034h,004h,0BCh,0F8h,000h
        db 004h,00Ch,01Ch,03Ch,004h,004h,004h,000h
        db 080h,0C0h,0E0h,0F0h,080h,080h,080h,000h
glyphs_end:
glyph_arr:
        db 030h,078h,0FCh,030h,030h,030h,030h,000h
        db 000h,030h,030h,030h,030h,0FCh,078h,030h

; palettes (RB,G)
uipal:  db 001h,000h, 012h,001h, 023h,002h, 034h,003h
        db 077h,007h, 056h,005h, 035h,004h, 047h,003h
        db 017h,006h, 023h,006h, 071h,006h, 073h,002h
        db 071h,004h, 037h,004h, 067h,002h, 025h,001h
defpal: db 000h,000h, 000h,000h, 011h,006h, 033h,007h
        db 017h,001h, 027h,003h, 051h,001h, 027h,006h
        db 071h,001h, 073h,003h, 061h,006h, 064h,006h
        db 011h,004h, 065h,002h, 055h,005h, 077h,007h
