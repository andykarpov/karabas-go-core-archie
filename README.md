# Acorn Archimedes core for Karabas Go / Mini / Mini G

[Русская версия](README.ru.md)

Acorn Archimedes (A3xx / A4xx / A3000: ARM2, MEMC, VIDC, IOC, 4 MB) for the Karabas Go board family. A port of [Archie_MiSTer](https://github.com/MiSTer-devel/Archie_MiSTer) (the MiSTer port of Stephen J. Leary's Archie core for MiST) to the Xilinx Spartan-6 XC6SLX25.

Status: work in progress (see `docs/PLAN.md`, in Russian). Mini G: RISC OS 3.11 desktop, keyboard, mouse, sound, floppies, CMOS / clock and the IDE hard disc work on the board; Go and Mini come later.

RISC OS is not included: put your own RISC OS 3.11 image on the SD card as `/archie/riscos.rom`.

## Files on the SD card

- `/archie/riscos.rom`: RISC OS 3.11 (2 MB, your own image), loaded at start.
- Floppy A / B: `.adf` 800K (ADFS E). The core cannot format floppies: make an empty one with `src/tools/mkadf.py IMAGE [NAME]`.
- Hard disc 0 / 1 (the IDE podule of RISC Developments, IDEFS): `.hdf` images with 512-byte sectors. The IDE Filer cannot format a disc without `!IDEForm` of the IDE utilities floppy, so start from an empty one: `src/tools/mkhdf.py IMAGE [SIZE_MB] [NAME]` (64 MB by default, at most 512 MB). `src/tools/hdfcheck.py IMAGE` checks an image.

To use a hard disc: mount it as Hard disc 0, press F12 and type `*Configure IDEFSDiscs 1` (once: the CMOS is kept in `/config/archie.eep`), then reset the machine. The disc shows on the icon bar under its name, `IDEFS::4` (`*Cat :4`).

## Licence

The Amber ARM core is LGPL; the Archie core is LGPL / BSD (MiSTer) and GPL v3 (MiST files); the Karabas parts are GPL v3 (`LICENSE`).
