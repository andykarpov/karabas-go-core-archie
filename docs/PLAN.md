# План ядра Acorn Archimedes (Archie) для Karabas Go / Mini / Mini G

Цель: Acorn Archimedes A3xx / A4xx / A3000 (ARM2, MEMC1a, VIDC1, IOC, 4 МБ RAM, RISC OS 3.11) на платах Karabas (XC6SLX25, ISE 14.7). Основа — rtl [Archie_MiSTer](https://github.com/MiSTer-devel/Archie_MiSTer), порта ядра Archie Stephen J. Leary с MiST. Файлы идут через прошивку (OSD, `FL`, `F`, `img_sdc`): загрузчика и soft-CPU в ядре нет. Имя `archie` (`archie.kg`, папка `/archie`), репозиторий `andykarpov/karabas-go-core-archie`, публичный.

## Что изучено (2026-11-10)

| Проект | Состояние | Что берём |
|---|---|---|
| [MiSTer-devel/Archie_MiSTer](https://github.com/MiSTer-devel/Archie_MiSTer) f12623a (2026-10-21) | живой: точные частоты VIDC, режим 23, игры (James Pond, Twinworld), STM, тайминги FDC | `rtl/`: a23 (Amber), MEMC, VIDC, IOC, latches, fdc1772, podule_ide + ПЗУ riscdevide, EEPROM 24C0x, `sdram.v` |
| [mist-devel/archimedes](https://github.com/mist-devel/archimedes) 09ac3d0 (2024-02) | оригинал, MiST и SiDi128 | сверка, тестбенчи `bench/`, даташиты MEMC / VIDC / IOC в `docs/`, `sw/vasm` |
| mist-firmware `archie.c` | протокол клавиатуры в прошивке ARM | переписать в RTL |
| Tang / ZX-Uno / Neptuno | портов с исходниками нет (только форки MiST) | — |

Лицензии: Amber — LGPL, ядро — LGPL / BSD (MiSTer) и GPL v3 (MiST). RISC OS 3.11 несвободна: только файл пользователя, в репозиторий и `.kg` не кладём. Легальный источник — образы ROM для эмуляторов от RISC OS Open / riscos.com.

### Проба XST (xc6slx25-2, `archimedes_top` отдельно, весь rtl через `sv2v`)

**8902 LUT (59 %), 5339 триггеров, 16 RAMB16 (30 %), 53 МГц** (нужно 42). Клоки: CLKCPU (42 МГц), CLKPIX (VIDC), CLKAUD. С обвязкой платы (около 18 % у других ядер) выйдет около 77–80 % LUT: места хватает, в отличие от atarist / nanomig.

Правки, без которых XST не собирает:
- `'h_1_0000` в `a23_barrel_shift_fpga.v` (sv2v не разбирает `_` после `'h`);
- `$clog2` в `fdc1772`; `cpu_export` в `a23_register_bank` (sv2v теряет `translate_off`);
- смешанные `=` / `<=` в сбросе `memc`;
- `sram_line_en` / `sram_byte_en` на `altsyncram` → выводимые (byte enable — побайтовый `generate`);
- **`fdc1772_dpram`** (порт A 16 бит, порт B 8 бит с записью части слова) — XST висит более 30 минут → две памяти по 8 бит;
- XST выкинул `sd_rd` / `sd_wr` у `fdc1772` (Xst:1710): та же неинициализированная `sd_state`, что в atarist, — дать начальное значение.

## Решения

Пользователь (2026-11-10): имя `archie`, публичный репозиторий (создаёт пользователь), **видео через кадровый буфер**, образ RISC OS ищем (своего нет).

Предложение (ждёт подтверждения):

1. **Основа** — rtl Archie_MiSTer как есть (`upstream/`) и его `sv2v` в `src/rtl/sv2v/` (как atarist); правки для XST в исходниках с пометкой `// karabas:`.
2. **Память.** RAM 4 МБ и ROM 2 МБ в SDRAM (MT48LC16M16A2, 16 бит), wishbone 32 бит пакетами, как на MiST / MiSTer (у них такая же ширина). `sdram.v` MiSTer: 126 МГц CL3 BL8 → проверить XST на 126 МГц; запасной вариант — 84 МГц (2 × 42) CL2. ROM пишет загрузчик прошивки (`FL`) через wishbone, как `ioctl` MiSTer. **SRAM 4 МБ — под кадровый буфер.**
3. **Видео: кадровый буфер.** VIDC работает в своём клоке пикселя (24 / 25,175 / 36 МГц, `VIDBASECLK` latch C) — нужен для правильных таймингов и звука; клок от DCM_CLKGEN с перепрограммированием (как `kg_hdmi_ft_pll`), смена частоты не трогает HDMI. Пиксели (RGB 4:4:4) пишутся в SRAM через строковый буфер BRAM; вывод — всегда один режим, предлагаю **800 × 600 @ 60 Гц (40 МГц)**: в него влезают все обычные режимы (640 × 256 удвоением строк → 640 × 512, 640 × 480, 800 × 600, 320 × 256 удвоением пикселей), рамка — цветом бордюра. Режим 23 (1152 × 896 моно) — позже или никогда. Полоса SRAM: запись ≤ 24 Мпикс/с только в активной части строки VIDC, чтение 29 Мпикс/с; SRAM 10 нс, доступ на 100 МГц — 2 такта: укладывается с запасом пакетами по строкам. Если монитор пользователя примет, вариант 50 Гц (без рывков 50 → 60).
4. **Клавиатура и мышь** — автомат протокола клавиатуры Archimedes в RTL (`archie_kbd.v`: HRST / RAK1 / RAK2, KDDA / KUDA с BACK / SACK / SMAK, мышь пакетами RQMP / MDAT) поверх `kg_mcu_hid`: HID-код → код клавиши Archimedes (таблица по `archie.c`).
5. **Файлы.** ROM — `FL` (`/archie/riscos.rom`, автозагрузка). Дискеты A: / B: — `.adf` 800 КБ (`fdc1772` → `img_sdc`, как atarist). Жёсткий диск — IDE-подула MiSTer (`podule_ide` + ПЗУ riscdevide) → `hdf_ata` / `img_sdc`, `.hdf`. CMOS (EEPROM 24C0x / PCF8583) — `.eep`; время — RTC платы.
6. **Свой верх платы**, общий код через modules (`kg_mcu`, `img_sdc`, OSD, HDMI, PCM5102), Makefile. Первым — Mini G, затем Go и Mini. Mini G2: T3 = 0 (SDRAM ~CS).

## Архитектура

```
 archimedes_top ├── a23 (ARM2, кэш 16 КБ) ── MEMC ── wishbone 32 ── sdram.v ── SDRAM: RAM 4 МБ, ROM 2 МБ ← FL
 (Archie_MiSTer)├── VIDC (CLKPIX от DCM_CLKGEN) ── RGB 4:4:4 ── строковый буфер ── SRAM (кадровый буфер)
                │                                                     └── вывод 800×600@60 ── OSD ── HDMI / VGA
                ├── VIDC звук (8 каналов μ-law) ─────────────────────── HDMI / PCM5102 / сигма-дельта
                ├── IOC ── KBD_OUT / KBD_IN ── archie_kbd ── kg_mcu HID (клавиатура, мышь)
                ├── fdc1772 ── sd_* ──┐
                ├── podule_ide ───────┴── img_sdc / hdf_ata ── kg_mcu (file mounter)
                └── I2C ── EEPROM 24C0x ── .eep ; RTC ← kg_mcu
```

## Фазы

Ветка и один PR на фазу, слияние в конце фазы.

- **Ф0. Импорт и fit.** `upstream/` без правок, `sv2v.sh`, правки XST, Makefile, `core.json`, `make archie-xst`. Готово, когда XST собирает машину без защёлок и с ≥ 42 МГц.
- **Ф1. Симуляция.** Verilator: машина + модель SDRAM; тестовые ПЗУ на vasm (из `sw/` MiST) без RISC OS — CPU, MEMC, VIDC-кадр в PNG, IOC; с RISC OS пользователя (локально) — до рабочего стола; протокол клавиатуры.
- **Ф2. Mini G.** PLL (42 / 126 МГц), SDRAM, DCM_CLKGEN для VIDC, кадровый буфер в SRAM, вывод 800 × 600, HDMI со звуком, HID, OSD, ROM через `FL`. Первый запуск на плате: RISC OS, клавиатура, мышь.
- **Ф3. Дискеты и CMOS.** ADF A: / B:, запись, смена диска; CMOS в `.eep`, время с RTC.
- **Ф4. Жёсткий диск и джойстики.** IDE-подула, `.hdf`; джойстики через HID.
- **Ф5. Go / Mini и релиз.** Верхи Go (VGA, PCM5102) и Mini, `cores.json`, README / GUIDE. Потом: физический дисковод Go (800 КБ DD), режим 23, 50 Гц вывода.

## Открытые вопросы

- Режим вывода: 800 × 600 @ 60 или 50 Гц (проверить на мониторе пользователя).
- Частота SDRAM 126 МГц на Spartan-6 -2 — проверка в Ф2.
- Где взять RISC OS 3.11 (ROOL / riscos.com, «ROMs for emulators»).
