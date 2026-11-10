#!/usr/bin/env python3
# mkadf.py IMAGE [NAME]: an empty ADFS E format floppy (800K: 80 x 2 x 5 x 1024, new map, 77 entry
# 'Hugo' directories) for Floppy A / B. The fdc1772 of the core does not write tracks (Write Track is
# a no-op as in Archie_MiSTer), so a disc cannot be formatted in RISC OS: start from this image.
import struct, sys
SEC = 1024; SIZE = 819200
img = bytearray(SIZE)

def zone_check(m):
    s0 = s1 = s2 = s3 = 0
    rover = SEC - 4
    while rover > 0:
        s0 += m[rover + 0] + (s3 >> 8); s3 &= 0xff
        s1 += m[rover + 1] + (s0 >> 8); s0 &= 0xff
        s2 += m[rover + 2] + (s1 >> 8); s1 &= 0xff
        s3 += m[rover + 3] + (s2 >> 8); s2 &= 0xff
        rover -= 4
    s0 += (s3 >> 8)
    s1 += m[1] + (s0 >> 8)
    s2 += m[2] + (s1 >> 8)
    s3 += m[3] + (s2 >> 8)
    return (s0 ^ s1 ^ s2 ^ s3) & 0xff

def setbit(m, n):
    m[n >> 3] |= 1 << (n & 7)

name = (sys.argv[2] if len(sys.argv) > 2 else "Karabas").encode()[:10]
m = bytearray(SEC)
dr = struct.pack('<BBBBBBBBBBHIIH10sIIBBBBII8s',
    10, 5, 2, 2, 15, 7, 1, 0, 0, 1, 0x520, 0x203, SIZE, 0x4B47,
    name.ljust(10, b' '), 0, 0, 0, 0, 0, 0, 0, 0, b'\0' * 8)
assert len(dr) == 60, len(dr)
m[4:64] = dr
ALLOC0 = 64 * 8                     # the allocation bits of zone 0 start after the disc record
NBITS = SIZE >> 7                   # 128 bytes per map bit
# fragment 2 (the map copies and the root directory): 4 sectors = 32 bits, id 2 in 15 bits
frag_len = 4 * SEC >> 7
for b in range(15):
    if (2 >> b) & 1: setbit(m, ALLOC0 + b)
setbit(m, ALLOC0 + frag_len - 1)
# the free fragment: the rest, no next free fragment (link 0)
free0 = ALLOC0 + frag_len
setbit(m, ALLOC0 + NBITS - 1)
link = free0 - 8
m[1] = link & 0xff
m[2] = (link >> 8) | 0x80
m[3] = 0xff                         # CrossCheck (one zone)
m[0] = zone_check(m)
img[0:SEC] = m
img[SEC:2 * SEC] = m

# the root directory '$' (2048 bytes, 'Hugo')
DS = 2048
d = bytearray(DS)
d[0] = 0
d[1:5] = b'Hugo'
d[5] = 0
t = DS - 41
d[t] = 0
d[t + 3:t + 6] = (0x203).to_bytes(3, 'little')
d[t + 6:t + 6 + 19] = b'$\r'.ljust(19, b'\0')
d[t + 25:t + 35] = b'$\r'.ljust(10, b'\0')
d[t + 35] = 0
d[t + 36:t + 40] = b'Hugo'

def ror13(a): return ((a >> 13) | (a << 19)) & 0xffffffff
def dir_check(d):
    acc = 0
    last = 5
    while d[last] != 0: last += 26
    i = 0
    while i + 4 <= last:
        acc = ror13(acc) ^ struct.unpack_from('<I', d, i)[0]; i += 4
    while i < last:
        acc = ror13(acc) ^ d[i]; i += 1
    i = DS - 40
    while i < DS - 4:   # the tail: 9 words from 2008 (as Linux fs/adfs/dir_f.c, not the PRM)
        acc = ror13(acc) ^ struct.unpack_from('<I', d, i)[0]; i += 4
    return (acc ^ (acc >> 8) ^ (acc >> 16) ^ (acc >> 24)) & 0xff
d[DS - 1] = dir_check(d)
img[2 * SEC:2 * SEC + DS] = d
open(sys.argv[1], 'wb').write(img)
print("zone check %02x, free link %04x, dir check %02x" % (m[0], link | 0x8000, d[DS - 1]))
