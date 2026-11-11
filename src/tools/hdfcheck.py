#!/usr/bin/env python3
# hdfcheck.py IMAGE: reads an IDEFS / FileCore new map hard disc image the way Linux fs/adfs does
# (super.c adfs_validate_bblk, map.c adfs_map_layout / lookup_zone / scan_free_map, dir_f.c) and
# prints the disc record, the zone and cross checks, the root directory and the free space.
# The check of mkhdf.py; exit 1 on an error.
import struct, sys

sys.path.insert(0, __file__.rsplit('/', 1)[0])

def zone_check(m, sec):
    s0 = s1 = s2 = s3 = 0
    rover = sec - 4
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
    while i < DS - 4:
        acc = ror13(acc) ^ struct.unpack_from('<I', d, i)[0]; i += 4
    return (acc ^ (acc >> 8) ^ (acc >> 16) ^ (acc >> 24)) & 0xff

def bit(m, n): return (m[n >> 3] >> (n & 7)) & 1
def bits(m, n, k): return sum(bit(m, n + i) << i for i in range(k))

errors = 0
def err(s):
    global errors
    errors += 1
    print("ERROR:", s)

img = open(sys.argv[1], 'rb').read()
bb = img[0xC00:0xE00]
r = 0
for i in range(510, -1, -1):
    r = (r & 0xff) + (r >> 8) + bb[i]
if (r & 0xff) != bb[511]: err("boot block check %02x, stored %02x" % (r & 0xff, bb[511]))
(l2sec, spt, heads, dens, idlen, l2bpmb, skew, boot, lowsec, nz, spare, root, size, did, name) = \
    struct.unpack_from('<BBBBBBBBBBHIIH10s', bb, 0x1C0)
sec = 1 << l2sec
print("disc '%s': %d-byte sectors, %d / %d, idlen %d, %d bytes per map bit, %d zones, spare %d, root 0x%X, size %d"
      % (name.decode('latin-1').rstrip(), sec, spt, heads, idlen, 1 << l2bpmb, nz, spare, root, size))
zone_size = sec * 8 - spare
map2blk = l2bpmb - l2sec
map_addr = (nz >> 1) * zone_size - (480 if nz > 1 else 0)
map_sec = map_addr << map2blk if map2blk >= 0 else map_addr >> -map2blk
zones = [img[(map_sec + z) * sec:(map_sec + z + 1) * sec] for z in range(nz)]
dm = []
total_bits = size >> l2bpmb
for z in range(nz):
    if z == 0: dm.append([0, 32 + 480, 32 + zone_size])
    else: dm.append([z * zone_size - 480, 32, 32 + zone_size])
dm[-1][2] = 32 + total_bits - ((nz - 1) * zone_size - 480)
if zones[0][4:64] != bb[0x1C0:0x1C0 + 60]: err("disc record of zone 0 differs from the boot block")
cross = 0
free = 0
frags = {}
for z, m in enumerate(zones):
    if zone_check(m, sec) != m[0]: err("zone %d check %02x, stored %02x" % (z, zone_check(m, sec), m[0]))
    cross ^= m[3]
    startblk, start, end = dm[z]
    link = bits(m, 8, 15)
    freelink = 8 + link if link else 0
    while start < end:
        f = bits(m, start, idlen)
        e = start + idlen
        while e < end and not bit(m, e): e += 1
        if e >= end: err("zone %d: fragment at %d runs over the zone end" % (z, start)); break
        n = e + 1 - start
        if start == freelink:
            free += n
            freelink = (freelink + f) if f else -1
        else:
            frags.setdefault(f, []).append((z, startblk + start - dm[z][1], n))
        start = e + 1
    if freelink > 0: err("zone %d: free link past the fragments" % z)
if cross != 0xff: err("cross check %02x" % cross)
print("fragments:", {k: v for k, v in frags.items()})
print("free %d bytes" % (free << l2bpmb))
# the root: id root >> 8, sector (root & 0xff) - 1 of the object
rid = root >> 8
if rid not in frags: err("no fragment of the root id %d" % rid)
else:
    z, blk, n = frags[rid][0]
    ra = (blk << l2bpmb) + ((root & 0xff) - 1) * sec
    d = img[ra:ra + 2048]
    if d[1:5] != b'Hugo' or d[2048 - 5:2048 - 1] != b'Hugo': err("root at 0x%X is not a 'Hugo' directory" % ra)
    elif dir_check(bytearray(d)) != d[2047]: err("root dir check %02x, stored %02x" % (dir_check(bytearray(d)), d[2047]))
    else: print("root directory at 0x%X ok" % ra)
    # the map copies at the start of the fragment
    if (blk << l2bpmb) != map_sec * sec: err("fragment %d at 0x%X, the map at 0x%X" % (rid, blk << l2bpmb, map_sec * sec))
sys.exit(1 if errors else 0)
