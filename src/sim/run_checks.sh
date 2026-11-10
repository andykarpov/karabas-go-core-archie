#!/bin/bash
# The Ф1 checks of the machine with RISC OS 3.11 (the user's ROM, see run_boot.sh).
#   ./run_checks.sh          quick: 1 s of machine time (about 1 minute): the keyboard handshake and
#                            key scan, 50 Hz frames, then the VGA mode of the default CMOS
#   ./run_checks.sh --long   also the desktop: 5.5 s (6..17 minutes, ask first): the banner
#                            "RISC OS 4096K" at about 4.1 s, the grey desktop with the pointer at 5.1 s
set -e
cd "$(dirname "$0")"
echo "JOB-STAGE: quick"
./run_boot.sh --ms 1000 --report 500 --expect-scan --expect-frames 45 | grep -v " frame "
if [ "$1" = "--long" ]; then
	echo "JOB-STAGE: desktop"
	./run_boot.sh --ms 5500 --report 500 --ppm sim/build/desktop --every 50 --expect-nonblack 300000 | grep -v " frame [0-9]*:.*black$"
fi
