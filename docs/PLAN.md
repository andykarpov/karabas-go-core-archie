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
3. **Видео: кадровый буфер.** VIDC работает на одной частоте (42 МГц, как CPU) с CE пикселя от дробного счётчика (`archie_ce.v`, скорости таблицы `vratio` MiSTer: 24 / 25,175 / 36 МГц × 1/3…1): частоты строк и кадров настоящие, дрожание CE на такт кадровому буферу не мешает. DCM_CLKGEN не нужен (решение Ф1, проверено в симуляции). Пиксели (RGB 4:4:4) пишутся в SRAM через строковый буфер BRAM; вывод — всегда один режим, предлагаю **800 × 600 @ 60 Гц (40 МГц)**: в него влезают все обычные режимы (640 × 256 удвоением строк → 640 × 512, 640 × 480, 800 × 600, 320 × 256 удвоением пикселей), рамка — цветом бордюра. Режим 23 (1152 × 896 моно) — позже или никогда. Полоса SRAM: запись ≤ 24 Мпикс/с только в активной части строки VIDC, чтение 29 Мпикс/с; SRAM 10 нс, доступ на 100 МГц — 2 такта: укладывается с запасом пакетами по строкам. Если монитор пользователя примет, вариант 50 Гц (без рывков 50 → 60).
4. **Клавиатура и мышь** — автомат протокола клавиатуры Archimedes в RTL (`archie_kbd.v`: HRST / RAK1 / RAK2, KDDA / KUDA с BACK / SACK / SMAK, мышь пакетами RQMP / MDAT) поверх `kg_mcu_hid`: HID-код → код клавиши Archimedes (таблица по `archie.c`).
5. **Файлы.** ROM — `FL` (`/archie/riscos.rom`, автозагрузка). Дискеты A: / B: — `.adf` 800 КБ (`fdc1772` → `img_sdc`, как atarist). Жёсткий диск — IDE-подула MiSTer (`podule_ide` + ПЗУ riscdevide) → `hdf_ata` / `img_sdc`, `.hdf`. CMOS (EEPROM 24C0x / PCF8583) — `.eep`; время — RTC платы.
6. **Свой верх платы**, общий код через modules (`kg_mcu`, `img_sdc`, OSD, HDMI, PCM5102), Makefile. Первым — Mini G, затем Go и Mini. Mini G2: T3 = 0 (SDRAM ~CS).

## Архитектура

```
 archimedes_top ├── a23 (ARM2, кэш 16 КБ) ── MEMC ── wishbone 32 ── sdram.v ── SDRAM: RAM 4 МБ, ROM 2 МБ ← FL
 (Archie_MiSTer)├── VIDC (CE от archie_ce, 42 МГц) ── RGB 4:4:4 ── строковый буфер ── SRAM (кадровый буфер)
                │                                                     └── вывод 800×600@60 ── OSD ── HDMI / VGA
                ├── VIDC звук (8 каналов μ-law) ─────────────────────── HDMI / PCM5102 / сигма-дельта
                ├── IOC ── KBD_OUT / KBD_IN ── archie_kbd ── kg_mcu HID (клавиатура, мышь)
                ├── fdc1772 ── sd_* ──┐
                ├── podule_ide ───────┴── img_sdc / hdf_ata ── kg_mcu (file mounter)
                └── I2C ── EEPROM 24C0x ── .eep ; RTC ← kg_mcu
```

## Фазы

Ветка и один PR на фазу, слияние в конце фазы.

- **Ф0. Импорт и fit — готово (2026-11-10, ветка `f0-import`).** rtl Archie_MiSTer без правок (92bd8e5), `src/tools/sv2v.sh` → `src/rtl/sv2v/`, правки XST (список выше), Makefile, `core.json`. `make archie-xst`: 8946 LUT (59 %), 5382 FF, 16 RAMB16, защёлок нет, 53,1 МГц. `sdram.v` MiSTer не в sv2v (XST: `inout` как reg) — переделка в Ф2.
- **Ф1. Симуляция — готово (2026-11-10, ветка `f1-sim`).** Verilator: `src/sim/sim_top.v` (машина из `rtl/sv2v` на одном клоке 42 МГц, модель wishbone-стороны `sdram.v` MiSTer: 4 слова на чтение с переносом в 16-байтовой строке, ROM с 0x400000), `sim_archie.cpp` + `run_boot.sh` (кадры PPM, трассы клавиатуры и I2C, счётчик исключений, гистограмма PC, записи по 64 КБ, дамп RAM), `run_checks.sh` (быстрая 1 с ≈ 1 мин; `--long` — рабочий стол). Наши части в `src/rtl/karabas/`: `archie_kbd.v` (протокол клавиатуры `archie.c` в логике), `archie_cmos.v` (EEPROM_24C0x + cmos.mif MiSTer), `archie_ce.v` (CE пикселя и звука VIDC от одной частоты, дробные счётчики). RISC OS 3.11 пользователя: рукопожатие клавиатуры и опрос клавиш на 18 мс, задержка POST 0,5 с, VIDC 640 × 480 (25,175 МГц, CMOS по умолчанию) на 838 мс, баннер «RISC OS 4096K» + «Risc Developments IDEFS» на 4,1 с, серый рабочий стол с указателем на 5,1 с. Исключения: только undefined от FPEmulator (проба FPA), это норма. Скорость модели 6–17 мс машинного времени в секунду (зависит от загрузки машины).
- **Ф2. Mini G — готово (2026-11-10, PR #3, #4).** Клоки 40 / 80 МГц (42 / 84 из 50 МГц не получить), `archie_sdram.v` (80 МГц: ROM и кадровый буфер), `archie_sram.v` (RAM 4 МБ в SRAM платы на clk_sys, PR #4), `archie_fb.v` (захват VIDC → 4 кадра в SDRAM → 800 × 600 @ 60, очередь из 4 строк, кадр с потерянной строкой не показывается), HDMI со звуком, `archie_hid.v`, `archie_kbd.v`, OSD, ROM через `FL` (`archie_loader.v`). На плате: рабочий стол RISC OS 3.11, клавиатура, мышь, звук, окна двигаются без следа.
- **Ф3. Дискеты и CMOS — готово (2026-11-11, ветка `f3-floppy-cmos`).** Floppy A / B (`F` 0 / 1, `.adf` 800 КБ): `img_sdc` + `archie_fdd.v` (байты `img_sdc` → 16-битный буфер `fdc1772`, `sd_ack` на такт дольше, иначе терялись байты 510 / 511), тест `src/sim/tb_fdd`. WRITE TRACK в `fdc1772` — заглушка (как в MiSTer): форматировать в RISC OS нельзя, пустой диск — `src/tools/mkadf.py`. CMOS и часы: `archie_cmos.v` — PCF8583 поверх регистров RTC `kg_mcu` (`rtc_mode` 0, MC146818A): RAM CMOS 0x10..0xFF в банке EEPROM ядра (`eeprom_bank` 4 → `/config/archie.eep`, начальное содержимое `cmos.bin` = cmos.mif MiSTer), время из регистров MC146818A, год RISC OS (CMOS 0xC0 / 0xC1) из регистра 9, запись времени из RISC OS ставит часы платы; машина ждёт старта MCU (`BUSY`). На плате: `*time` = время хоста, чтение / запись / новый каталог на дискете сохраняются в образе, смена диска A, `*Configure` переживает перезагрузку и смену ядра. Mini G: 88 % LUT, 99 % слайсов, map `-t 6` (с `-t 4` трассировка застряла).
- **Ф4. Жёсткий диск и джойстики — готово (2026-11-11, ветка `f4-area`).** Сначала площадь: свой `a23_register_bank.v` (32 × 32 в распределённой RAM) и пакеты HDMI island в триггерах (modules #26): 13252 → 11872 LUT. IDE-подула: шина `podule_ide` выведена из `archimedes_top` → `rtl/karabas/archie_ide.v` → `hdf_ata` модулей (адрес / CS / данные держатся на такт после строба: `hdf_ata` действует на такт позже) → `img_sdc`, слоты 4 / 5, OSD «Hard disc 0 / 1» (`.hdf`, Menu+F3 / F4). `hdf_ata` получил FORMAT TRACK 0x50 (modules #28). ПЗУ riscdevide — простой hex `rtl/karabas/riscdevide_rom.hex`: srecord-файл XST читал неверно (с Ф0 подула была «Simple podule»). IDE Filer не форматирует (нужен `!IDEForm` с дискеты утилит) → пустой диск `src/tools/mkhdf.py`, проверка `src/tools/hdfcheck.py` (как Linux fs/adfs). Тест `src/sim/tb_ide`. На плате: IDEFS 1.24, диск 64 МБ, `*Cat`, `*Free`, `*Cdir`, `SAVE`, образ после записи проходит `hdfcheck`. Mini G 13152 LUT (87 %), 21 RAMB16. Джойстики подключены ещё в Ф2 (порядок битов MiSTer).
- **Ф5. Go / Mini и релиз.** Верхи Go (VGA, PCM5102) и Mini, `cores.json`, README / GUIDE. Потом: физический дисковод Go (800 КБ DD), режим 23, 50 Гц вывода.

## Открытые вопросы

- Режим вывода: 800 × 600 @ 60 или 50 Гц (проверить на мониторе пользователя).
- Частота SDRAM 126 МГц на Spartan-6 -2 — проверка в Ф2.
- Где взять RISC OS 3.11 (ROOL / riscos.com, «ROMs for emulators»).
- ~~Задержка чтения памяти кэша a23~~: чтение за один такт (как стенд MiST) — RISC OS грузится до рабочего стола (Ф1).
