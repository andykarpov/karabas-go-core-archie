# Ядро Acorn Archimedes для Karabas Go / Mini / Mini G

[English version](README.md)

Acorn Archimedes (A3xx / A4xx / A3000: ARM2, MEMC, VIDC, IOC, 4 МБ) для плат Karabas Go. Порт [Archie_MiSTer](https://github.com/MiSTer-devel/Archie_MiSTer) (порт ядра Archie Stephen J. Leary с MiST) на Xilinx Spartan-6 XC6SLX25.

Состояние: в работе (план — `docs/PLAN.md`). Mini G: рабочий стол RISC OS 3.11, клавиатура, мышь, звук, дискеты, CMOS / часы и жёсткий диск IDE работают на плате. Сборки Go (VGA) и Mini (HDMI) тоже в `archie.kg`, на платах пока не запускались.

RISC OS в ядро не входит: положите свой образ RISC OS 3.11 на SD-карту как `/archie/riscos.rom`.

## Файлы на SD-карте

- `/archie/riscos.rom`: RISC OS 3.11 (2 МБ, свой образ), грузится при старте.
- Floppy A / B: `.adf` 800 КБ (ADFS E). Ядро не форматирует дискеты: пустую можно сделать `src/tools/mkadf.py IMAGE [NAME]`.
- Hard disc 0 / 1 (IDE-подула RISC Developments, IDEFS): образы `.hdf` с секторами 512 байт. IDE Filer не форматирует диск без `!IDEForm` с дискеты утилит IDE, поэтому начните с пустого: `src/tools/mkhdf.py IMAGE [SIZE_MB] [NAME]` (по умолчанию 64 МБ, не больше 512 МБ). `src/tools/hdfcheck.py IMAGE` проверяет образ.

Жёсткий диск: смонтируйте его как Hard disc 0, нажмите F12 и введите `*Configure IDEFSDiscs 1` (один раз: CMOS хранится в `/config/archie.eep`), затем перезапустите машину. Диск появится на панели иконок под своим именем, `IDEFS::4` (`*Cat :4`).

## Лицензия

Ядро ARM Amber — LGPL; ядро Archie — LGPL / BSD (MiSTer) и GPL v3 (файлы MiST); части Karabas — GPL v3 (`LICENSE`).
