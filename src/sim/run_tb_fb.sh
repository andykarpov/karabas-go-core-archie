#!/bin/bash
# The checks of archie_fb (tb_fb/): rasters of VIDC modes through the frame buffer on the SDRAM model,
# the 800 x 600 output compared pixel by pixel. About half a minute in all.
set -e
cd "$(dirname "$0")"
mkdir -p build/tb_fb
verilator -O2 -Wno-fatal -Wno-lint -Wno-style -Wno-BLKANDNBLK -Wno-MULTIDRIVEN --no-timing \
	--top-module tb_fb ${CHUNK:+-GCHUNK=$CHUNK} -Mdir build/tb_fb --cc tb_fb/tb_fb.v sdram_model.v ../rtl/karabas/archie_sdram.v \
	../rtl/karabas/archie_fb.v ../rtl/karabas/archie_ce.v \
	--exe $PWD/tb_fb/tb_fb.cpp -o Vtb_fb > build/tb_fb/verilator.log 2>&1 || { tail -30 build/tb_fb/verilator.log; exit 1; }
make -s -j8 -C build/tb_fb -f Vtb_fb.mk > build/tb_fb/make.log 2>&1 || { tail -30 build/tb_fb/make.log; exit 1; }
B=build/tb_fb/Vtb_fb
rc=0
#            name     base sel h_total h_start w   v_total v_start h
echo "JOB-STAGE: mode12"; $B mode12  0 2 1024 200 640 312 40 256 build/tb_fb/mode12.ppm || rc=1
[ -n "$ONLY12" ] && exit $rc; echo "JOB-STAGE: mode13"; $B mode13  0 0 512  100 320 312 40 256 build/tb_fb/mode13.ppm || rc=1
echo "JOB-STAGE: vga";    $B vga     1 3 800  144 640 525 35 480 build/tb_fb/vga.ppm || rc=1
echo "JOB-STAGE: svga";   $B svga    2 3 1024 200 800 625 24 600 build/tb_fb/svga.ppm || rc=1
exit $rc
