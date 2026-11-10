#!/bin/bash
# Converts the Archie_MiSTer RTL (SystemVerilog and the SV-flavoured .v files) to Verilog-2001 for XST
# with sv2v (/opt/sv2v/sv2v): one file per module in rtl/sv2v/. The tops: archimedes_top (the machine)
# and the parts the board tops use (EEPROM_24C0x). sdram.v (MiSTer) is adapted for the boards in Ф2.
# rtl/sv2v/ is generated and in git; change the sources (with a "karabas:" comment), then run this.
set -e
cd "$(dirname "$0")/../rtl"
SV2V=${SV2V:-/opt/sv2v/sv2v}
SRC="amber/a23_alu.v amber/a23_barrel_shift.v amber/a23_barrel_shift_fpga.v amber/a23_cache.v
 amber/a23_coprocessor.v amber/a23_core.v amber/a23_decode.v amber/a23_execute.v amber/a23_fetch.v
 amber/a23_multiply.v amber/a23_ram_register_bank.v amber/a23_register_bank.v amber/a23_wishbone.v
 amber/sram_byte_en.v amber/sram_line_en.v
 archimedes_top.v memc.v memc_translator.v ioc.v ioc_irq.v latches.v
 vidc/vidc.v vidc/vidc_async_fifo.v vidc/vidc_audio.v vidc/vidc_command_fifo.v vidc/vidc_dmachannel.v
 vidc/vidc_fifo.v vidc/vidc_timing.v vidc/mode23_cursor_serializer.v
 fdc/fdc1772.sv fdc/floppy.v podule_ide.sv ide.v EEPROM_24C0x.sv"
rm -rf sv2v && mkdir sv2v
$SV2V -I amber --top=archimedes_top --top=EEPROM_24C0x $SRC -w sv2v 2>&1 | grep -v -E '^\s*$|Warning: Number literal|^ *[0-9]* \||^\s*\|' || true
ls sv2v | wc -l
# archie.prj: the machine alone (make archie-xst) and the source list of the simulations
{ echo 'verilog work "../modules/rtl/mem/dpram.v"'; for f in sv2v/*.v; do echo "verilog work \"rtl/$f\""; done; } > ../archie.prj
# the board projects: their rtl/sv2v lines replaced by the current list (the other lines kept, in place)
for p in ../karabas_*.prj; do
	[ -f "$p" ] || continue
	python3 -I - "$p" ../archie.prj <<'PY'
import sys
board, machine = sys.argv[1], sys.argv[2]
lines = open(board).read().splitlines()
sv = [l for l in open(machine).read().splitlines() if 'rtl/sv2v/' in l]
out, done = [], False
for l in lines:
    if 'rtl/sv2v/' in l:
        if not done:
            out += sv
            done = True
        continue
    out.append(l)
open(board, 'w').write('\n'.join(out) + '\n')
PY
done
