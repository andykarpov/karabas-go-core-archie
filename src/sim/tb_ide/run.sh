#!/bin/bash
# tb_ide: archie_ide + hdf_ata on sdc_file_model, a 2 MB test image (byte o of LBA n: (n + o) & 255,
# odd bytes (n ^ o) & 255), for a few lengths of the CPU cycle. Seconds.
set -e
cd "$(dirname "$0")"
python3 -I -c "
import sys
b = bytearray()
for n in range(4096):
    b += bytes(((n + o) if o % 2 == 0 else (n ^ o)) & 255 for o in range(512))
open('test.hdf', 'wb').write(b)
"
fail=0
# STB 4 is the shortest read hdf_ata takes; the podule reads of the machine last 10 clocks or more
for p in "-P tb_ide.STB=4 -P tb_ide.GAP=1" "-P tb_ide.STB=11 -P tb_ide.GAP=1" "-P tb_ide.STB=7 -P tb_ide.GAP=3"; do
	iverilog -g2012 $p -o tb tb_ide.v ../../rtl/karabas/archie_ide.v ../sdc_file_model.v ../../../modules/rtl/mcu/hdf_ata.v
	vvp -n tb +hdf=test.hdf | grep -v "^VCD\|sdc_file_model: image" | tee out.txt
	grep -q ": 0 errors" out.txt || fail=1
done
rm -f tb out.txt test.hdf
exit $fail
