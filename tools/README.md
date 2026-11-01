# tools

Test helpers used during development (not needed to build or use X86VIEW).

- `harness.py` - Z80 test harness (python `z80` package): fake BIOS / MSX-DOS 2 / V9938 VDP, renders VRAM to PNG.
- `mkimg.py` - creates the sample pictures in `SAMPLE/` (SCREEN 2, 5, 6, 7, 8, 11, 12).
- `t2.py`, `t3.py`, `t5.py`, `t7.py` - screenshot, slideshow/error, command-line and random-key tests.

They expect `x86view.com` one folder up and a `fs/` test tree (folder `PIC/` filled by `mkimg.py`). Install: `pip install z80 pillow`.
