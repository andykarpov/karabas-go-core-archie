# Acorn Archimedes core for Karabas Go / Mini / Mini G

[Русская версия](README.ru.md)

Acorn Archimedes (A3xx / A4xx / A3000: ARM2, MEMC, VIDC, IOC, 4 MB) for the Karabas Go board family. A port of [Archie_MiSTer](https://github.com/MiSTer-devel/Archie_MiSTer) (the MiSTer port of Stephen J. Leary's Archie core for MiST) to the Xilinx Spartan-6 XC6SLX25.

Status: work in progress (see `docs/PLAN.md`, in Russian). Nothing runs on a board yet.

RISC OS is not included: put your own RISC OS 3.11 image on the SD card as `/archie/riscos.rom`.

## Licence

The Amber ARM core is LGPL; the Archie core is LGPL / BSD (MiSTer) and GPL v3 (MiST files); the Karabas parts are GPL v3 (`LICENSE`).
