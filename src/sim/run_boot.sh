#!/bin/bash
# Builds the verilator model of sim_top.v (the machine of rtl/sv2v = the files of archie.prj, plus the
# karabas parts rtl/karabas) and runs sim_archie with the given arguments (see sim_archie.cpp).
# The build goes to src/sim/build. The ROM: --rom FILE, default $ARCHIE_ROM or
# ~/Downloads/karabas-sd-archie/archie/riscos.rom (the user's RISC OS 3.11, never in the repo).
#   ./run_boot.sh --ms 200 --ppm build/frame --every 10
set -e
cd "$(dirname "$0")"
SRC=..
mkdir -p build
PRJ=$(sed -n 's/^verilog work "\(.*\)"/\1/p' $SRC/archie.prj)
KG="rtl/karabas/archie_ce.v rtl/karabas/archie_cmos.v rtl/karabas/archie_kbd.v"
# SDRAM=1: the memory of the boards (sim_top_sdram.v: archie_sdram, sdram_model, archie_fb), else sim_top.v
if [ -n "$SDRAM" ]; then
	TOP=sim_top_sdram; OBJ=obj_sdram; DEFS=-DSIM_SDRAM
	KG="$KG rtl/karabas/archie_sdram.v rtl/karabas/archie_fb.v sim/sdram_model.v sim/sim_top_sdram.v"
else
	TOP=sim_top; OBJ=obj; DEFS=
	KG="$KG sim/sim_top.v"
fi
STAMP=build/$OBJ/V$TOP
if [ ! -x $STAMP ] || [ -n "$(cd $SRC && find $PRJ $KG sim/sim_archie.cpp sim/run_boot.sh -newer sim/$STAMP 2>/dev/null)" ]; then
	echo "JOB-STAGE: build"
	(cd $SRC && verilator -O2 -Wno-fatal -Wno-lint -Wno-style -Wno-BLKANDNBLK -Wno-MULTIDRIVEN \
		--no-timing --top-module $TOP -Mdir sim/build/$OBJ --cc $PRJ $KG ${DEFS:+-CFLAGS $DEFS} \
		--exe $PWD/sim/sim_archie.cpp -o V$TOP > sim/build/verilator.log 2>&1) || { tail -30 build/verilator.log; exit 1; }
	make -s -j8 -C build/$OBJ -f V$TOP.mk > build/make.log 2>&1 || { tail -30 build/make.log; exit 1; }
fi
ROM=${ARCHIE_ROM:-$HOME/Downloads/karabas-sd-archie/archie/riscos.rom}
HAVE_ROM=
for a in "$@"; do [ "$a" = "--rom" ] && HAVE_ROM=1; done
echo "JOB-STAGE: sim"
# run from src/ so that the $readmem paths (rtl/...) resolve
cd $SRC
[ -n "$HAVE_ROM" ] && ROMARG=() || ROMARG=(--rom "$ROM")
# the $display traces of the upstream (MEMC, VIDC, cache) are dropped unless TRACE=1
set -o pipefail
if [ -n "$TRACE" ]; then exec sim/build/$OBJ/V$TOP "${ROMARG[@]}" "$@"; fi
sim/build/$OBJ/V$TOP "${ROMARG[@]}" "$@" | grep --line-buffered -v -E \
	'^(MEMC Control Register|Sstart|SendN|Sound buffer swap|Writing the|VIDC SFR|Cache Flush|FIFO has|writing to table entry|Fault (status|address)|Write 0x|Read  0x)'
