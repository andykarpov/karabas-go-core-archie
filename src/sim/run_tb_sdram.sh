#!/bin/bash
# The checks of archie_sdram (tb_sdram/): random wishbone traffic and frame buffer lines on the
# SDRAM model with its timing checks. ./run_tb_sdram.sh [wb_clk cycles, default 200000] (seconds)
set -e
cd "$(dirname "$0")"
mkdir -p build/tb_sdram
verilator -O2 -Wno-fatal -Wno-lint -Wno-style -Wno-BLKANDNBLK -Wno-MULTIDRIVEN --no-timing \
	--top-module tb_sdram ${CHUNK:+-GCHUNK=$CHUNK} -Mdir build/tb_sdram --cc tb_sdram/tb_sdram.v sdram_model.v ../rtl/karabas/archie_sdram.v \
	--exe $PWD/tb_sdram/tb_sdram.cpp -o Vtb_sdram > build/tb_sdram/verilator.log 2>&1 || { tail -30 build/tb_sdram/verilator.log; exit 1; }
make -s -j8 -C build/tb_sdram -f Vtb_sdram.mk > build/tb_sdram/make.log 2>&1 || { tail -30 build/tb_sdram/make.log; exit 1; }
exec build/tb_sdram/Vtb_sdram "$@"
