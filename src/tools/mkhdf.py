#!/usr/bin/env python3
# mkhdf.py IMAGE [SIZE_MB] [NAME]: an empty IDEFS hard disc (FileCore new map, 512-byte sectors,
# 'Hugo' directories) for Hard disc 0 / 1 of the archie core (default 64 MB, name Karabas).
# The IDE Filer of the podule ROM cannot format a disc (Format needs !IDEForm of the IDE utilities
# floppy), so start from this image. Geometry 16 heads, 63 sectors (what hdf_ata reports): IDEFS
# sets it from the disc record. Then: *Configure IDEFSDiscs 1 (once), mount, reset.
#
# The layout (as RISC OS FileCore, read the same way by Linux fs/adfs):
# - the boot block at 0xC00: an empty defect list (&20000000), the disc record at +0x1C0, the check
#   byte at +0x1FF (sum of the 511 bytes with end-around carry);
# - the map: one 512-byte sector per zone, zone_size = 4096 - zone_spare bits; map bit b of the disc
#   is 2^log2bpmb bytes; zone 0 holds the disc record in bytes 4..63 and its bits start at 512 (disc
#   address 0), zone z > 0 starts at bit 32 with disc bit z * zone_size - 480. The disc ends with
#   the last zone (disc_size = (nzones * zone_size - 480) << log2bpmb, the image may be longer);
# - two copies of the map and the root directory at the start of zone nzones / 2: fragment id 2,
#   root = 0x200 | (2 * nzones + 1); the boot block: fragment id 1 at the start of zone 0;
# - each zone: a free link at bit 8 (offset to the first free fragment, top bit set), the free
#   fragments linked by the offset in their id field, a zone check byte, and the cross check bytes
#   of all zones XOR to 0xFF.
import struct, sys

SEC = 512
HEADS, SPT = 16, 63
IDLEN = 15
ZONE_SPARE = 0x640
ZONE_BITS = SEC * 8 - ZONE_SPARE
DR_BITS = 60 * 8

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

def boot_check(b):
    r = 0
    for i in range(510, -1, -1):
        r = (r & 0xff) + (r >> 8) + b[i]
    return r & 0xff

def setbits(m, start, n, value):
    for i in range(n):
        if (value >> i) & 1:
            m[(start + i) >> 3] |= 1 << ((start + i) & 7)

def setbit(m, n):
    m[n >> 3] |= 1 << (n & 7)

def ror13(a): return ((a >> 13) | (a << 19)) & 0xffffffff

def dir_check(d):
    DS = len(d)
    acc = 0
    last = 5
    while d[last] != 0: last += 26
    i = 0
    while i + 4 <= last:
        acc = ror13(acc) ^ struct.unpack_from('<I', d, i)[0]; i += 4
    while i < last:
        acc = ror13(acc) ^ d[i]; i += 1
    i = DS - 40
    while i < DS - 4:   # the tail: 9 words from 2008 (as Linux fs/adfs/dir_f.c)
        acc = ror13(acc) ^ struct.unpack_from('<I', d, i)[0]; i += 4
    return (acc ^ (acc >> 8) ^ (acc >> 16) ^ (acc >> 24)) & 0xff

def layout(img_size):
    # the smallest map bit size that keeps the map to 127 zones
    for l2 in range(9, 16):
        bits = img_size >> l2
        nz = (bits + DR_BITS) // ZONE_BITS
        if 1 <= nz <= 127:
            return l2, nz
    sys.exit("image too large")

def main():
    if len(sys.argv) < 2:
        sys.exit("usage: mkhdf.py IMAGE [SIZE_MB] [NAME]")
    mb = int(sys.argv[2]) if len(sys.argv) > 2 else 64
    name = (sys.argv[3] if len(sys.argv) > 3 else "Karabas").encode()[:10]
    if mb > 512:
        sys.exit("RISC OS 3 FileCore discs are 512 MB at most")
    cyls = mb * 1024 * 1024 // (HEADS * SPT * SEC)
    img_size = cyls * HEADS * SPT * SEC
    l2, nz = layout(img_size)
    bpmb = 1 << l2
    disc_size = (nz * ZONE_BITS - DR_BITS) << l2
    assert disc_size <= img_size
    mapz = nz >> 1
    root = 0x200 | (2 * nz + 1)

    dr = struct.pack('<BBBBBBBBBBHIIH10sIIBBBBII8s',
        9, SPT, HEADS, 0, IDLEN, l2, 0, 0, 0, nz, ZONE_SPARE, root, disc_size, 0x4B47,
        name.ljust(10, b' '), 0, 0, 0, 0, 0, 0, 0, 0, b'\0' * 8)
    assert len(dr) == 60

    def frag_bits(nbytes):
        return max(IDLEN + 1, -(-nbytes // bpmb))

    zones = []
    for z in range(nz):
        m = bytearray(SEC)
        start = 32 + DR_BITS if z == 0 else 32
        end = 32 + ZONE_BITS
        used = start
        if z == 0:
            m[4:64] = dr
            n = frag_bits(0xC00 + SEC)            # the boot block: id 1
            setbits(m, used, IDLEN, 1); setbit(m, used + n - 1); used += n
        if z == mapz:
            n = frag_bits(2 * nz * SEC + 2048)    # the map copies and the root: id 2
            setbits(m, used, IDLEN, 2); setbit(m, used + n - 1); used += n
        assert end - used >= IDLEN + 1
        # one free fragment to the end of the zone, no next one
        setbit(m, end - 1)
        link = used - 8
        m[1] = link & 0xff
        m[2] = (link >> 8) | 0x80
        m[3] = 0xff if z == nz - 1 else 0x00     # cross check: all zones XOR 0xFF
        m[0] = zone_check(m)
        zones.append(m)
    mp = b''.join(zones)

    # disc address of zone mapz = its first map bit
    map_addr = (mapz * ZONE_BITS - (DR_BITS if nz > 1 else 0)) << l2

    img = bytearray(img_size)
    bb = bytearray(SEC)
    struct.pack_into('<I', bb, 0, 0x20000000)    # the defect list: empty
    bb[0x1C0:0x1C0 + 60] = dr
    bb[0x1FF] = boot_check(bb)
    img[0xC00:0xC00 + SEC] = bb
    img[map_addr:map_addr + len(mp)] = mp
    img[map_addr + len(mp):map_addr + 2 * len(mp)] = mp

    DS = 2048
    d = bytearray(DS)
    d[1:5] = b'Hugo'
    t = DS - 41
    d[t + 3:t + 6] = root.to_bytes(3, 'little')
    d[t + 6:t + 6 + 19] = b'$\r'.ljust(19, b'\0')
    d[t + 25:t + 35] = b'$\r'.ljust(10, b'\0')
    d[t + 36:t + 40] = b'Hugo'
    d[DS - 1] = dir_check(d)
    ra = map_addr + 2 * len(mp)
    img[ra:ra + DS] = d

    open(sys.argv[1], 'wb').write(img)
    print("%s: %d bytes (%d / %d / %d), disc %d bytes, %d zones, %d bytes per map bit, map at 0x%X, root 0x%X"
          % (sys.argv[1], img_size, cyls, HEADS, SPT, disc_size, nz, bpmb, map_addr, root))

main()
