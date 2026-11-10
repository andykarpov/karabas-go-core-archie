// sim_archie.cpp - verilator harness of sim_top.v: the Archimedes machine of Ф1 on a memory model.
//
//   sim_archie --rom FILE [--ms N] [--ppm PREFIX] [--every N] [--kbd] [--i2c] [--i2c-raw] [--pc-hist FROM_MS] [--dump-ram] [--key MS:CODE[:HOLDMS]] ...
//              [--report MS] [--expect-scan] [--expect-frames N] [--expect-nonblack N]
//
// --rom: a 2 MB RISC OS image (or a smaller test ROM), little endian, put at 0x400000 of the model
// (where MEMC maps the ROM). --ms: the run length in ms of machine time (42 MHz clock).
// --ppm writes every N-th frame (default 25) as PREFIX_NNNN.ppm: the pixels inside VIDEO_EN of the
// VIDC raster, one per pixel enable. --kbd prints the bytes of the keyboard link. --key presses the
// Archimedes key CODE (hex, row << 4 | column) at MS for HOLDMS (default 100). --expect-scan: fail
// unless RISC OS enabled the key scan; --expect-frames: fail if fewer frames came;
// --expect-nonblack N: fail unless the last frame has at least N non-black pixels.

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <string>
#include <vector>
#include <ctime>
#include <map>
#include <algorithm>
#include "Vsim_top.h"
#include "Vsim_top___024root.h"
#include "Vsim_top_sim_top.h"
#include "verilated.h"

static Vsim_top *tb;
static double sim_ms = 0;
static const double TICK_MS = 1000.0 / 42000000.0;

static const char *ppm_prefix = nullptr;
static int ppm_every = 25;
static int frames = 0;
static bool kbd_trace = false;
static double report_ms = 100;
static bool i2c_trace = false;
static bool i2c_raw = false;
static double hist_from = -1;
static bool dump_ram = false;
static long wr_region[256];  // writes per 64 KB of the 16 MB space since the last report
// exception vectors: entered when r15 jumps into 0x00..0x1c from outside
static const char *vec_name[8] = { "reset", "undef", "swi", "pabort", "dabort", "addrex", "irq", "firq" };
static long vec_count[8];
static uint32_t prev_pc = 0, prev_prev_pc = 0;
static int vec_print = 0;
static void vec_step(void) {
	uint32_t pc = tb->cpu_pc;
	if (pc == prev_pc) return;
	if (pc < 0x20 && prev_pc >= 0x20) {
		int v = pc >> 2;
		if (v >= 0 && v < 8) {
			vec_count[v]++;
			if (v != 2 && v != 6 && vec_print < 40) {
				printf("%9.3f ms exception %s from pc %07x (%07x)\n", sim_ms, vec_name[v], prev_pc, prev_prev_pc);
				vec_print++;
			}
		}
	}
	prev_prev_pc = prev_pc;
	prev_pc = pc;
}
static std::map<uint32_t, long> pc_hist;
static uint32_t last_pc = 0;

// ---- I2C decoder (the bus = master & slave, open drain)
static int i2c_lscl = 1, i2c_lsda = 1, i2c_bits = 0, i2c_byte = 0, i2c_in = 0;
static std::string i2c_line;
static void i2c_step(void) {
	int scl = tb->i2c_scl, sda = tb->i2c_sda_m & tb->i2c_sda_s;
	static int lm = -1, ls = -1, lc = -1;
	if (i2c_raw && (tb->i2c_sda_m != lm || tb->i2c_sda_s != ls || scl != lc)) {
		printf("%9.4f ms scl %d sda_m %d sda_s %d\n", sim_ms, scl, tb->i2c_sda_m, tb->i2c_sda_s);
		lm = tb->i2c_sda_m; ls = tb->i2c_sda_s; lc = scl;
	}
	if (scl && i2c_lscl && i2c_lsda && !sda) { i2c_line = "S"; i2c_bits = 0; i2c_in = 1; }
	else if (scl && i2c_lscl && !i2c_lsda && sda) {
		if (i2c_trace) printf("%9.3f ms i2c %s P\n", sim_ms, i2c_line.c_str());
		i2c_line.clear(); i2c_in = 0;
	} else if (scl && !i2c_lscl && i2c_in) {
		if (i2c_bits < 8) { i2c_byte = (i2c_byte << 1) | sda; i2c_bits++; }
		else {
			char b[16]; snprintf(b, sizeof b, " %02x%c", i2c_byte & 0xff, sda ? 'N' : 'A');
			if (i2c_line.size() < 4000) i2c_line += b;
			i2c_bits = 0; i2c_byte = 0;
		}
	}
	i2c_lscl = scl; i2c_lsda = sda;
}

struct Key { double ms; int code; double hold; bool down_sent, up_sent; };
static std::vector<Key> keys;

// ---- video capture: pixels inside VIDEO_EN of the VIDC raster
static const int MAXW = 1300, MAXH = 1000;
static std::vector<uint8_t> fb(MAXW * MAXH * 3);
static int fx = 0, fy = 0, last_hs = 1, last_vs = 1;
static int minx, maxx, miny, maxy;
static long last_nonblack = 0;

static void frame_reset(void) {
	minx = MAXW; maxx = -1; miny = MAXH; maxy = -1;
	std::fill(fb.begin(), fb.end(), 0);
}

static void frame_end(void) {
	long nonblack = 0;
	int w = maxx - minx + 1, h = maxy - miny + 1;
	if (w > 0 && h > 0)
		for (int y = miny; y <= maxy; y++)
			for (int x = minx; x <= maxx; x++) {
				uint8_t *p = &fb[(y * MAXW + x) * 3];
				if (p[0] | p[1] | p[2]) nonblack++;
			}
	last_nonblack = nonblack;
	bool write = ppm_prefix && w > 0 && h > 0 && (frames % ppm_every) == 0;
	printf("%9.3f ms frame %d: %dx%d base %d sel %d, %ld non-black", sim_ms, frames, w > 0 ? w : 0,
		h > 0 ? h : 0, tb->baseclk, tb->selpix, nonblack);
	if (write) {
		char name[512];
		snprintf(name, sizeof name, "%s_%04d.ppm", ppm_prefix, frames);
		FILE *f = fopen(name, "wb");
		if (f) {
			fprintf(f, "P6\n%d %d\n255\n", w, h);
			for (int y = miny; y <= maxy; y++)
				fwrite(&fb[(y * MAXW + minx) * 3], 3, w, f);
			fclose(f);
			printf(" -> %s", name);
		} else
			perror(name);
	}
	printf("\n");
	fflush(stdout);
	frames++;
	frame_reset();
}

static void capture(void) {
	if (!tb->ce_pix) return;
	if (tb->de && fx < MAXW && fy < MAXH) {
		uint8_t *p = &fb[(fy * MAXW + fx) * 3];
		p[0] = tb->r * 17; p[1] = tb->g * 17; p[2] = tb->b * 17;
		if (fx < minx) minx = fx;
		if (fx > maxx) maxx = fx;
		if (fy < miny) miny = fy;
		if (fy > maxy) maxy = fy;
	}
	fx++;
}

static void tick(void) {
	tb->clk = 0;
	tb->eval();
	tb->clk = 1;
	tb->eval();
	sim_ms += TICK_MS;

	capture();
	if (last_hs && !tb->hs_n) { fx = 0; fy++; }
	if (last_vs && !tb->vs_n) { frame_end(); fy = 0; }
	last_hs = tb->hs_n;
	last_vs = tb->vs_n;
}

static bool load_rom(const char *name) {
	FILE *f = fopen(name, "rb");
	if (!f) { perror(name); return false; }
	std::vector<uint8_t> d(4 << 20);
	size_t n = fread(d.data(), 1, d.size(), f);
	fclose(f);
	auto &m = tb->rootp->sim_top->mem;
	for (size_t i = 0; i < (n + 3) / 4; i++)
		m[0x100000 + i] = d[4 * i] | (d[4 * i + 1] << 8) | (d[4 * i + 2] << 16) | ((uint32_t)d[4 * i + 3] << 24);
	printf("ROM %s: %zu bytes at 0x400000\n", name, n);
	return true;
}

int main(int argc, char **argv) {
	Verilated::commandArgs(argc, argv);
	tb = new Vsim_top;
	const char *rom = nullptr;
	double run_ms = 100;
	bool expect_scan = false;
	int expect_frames = -1;
	long expect_nonblack = -1;
	for (int i = 1; i < argc; i++) {
		if (!strcmp(argv[i], "--rom") && i + 1 < argc) rom = argv[++i];
		else if (!strcmp(argv[i], "--ms") && i + 1 < argc) run_ms = atof(argv[++i]);
		else if (!strcmp(argv[i], "--ppm") && i + 1 < argc) ppm_prefix = argv[++i];
		else if (!strcmp(argv[i], "--every") && i + 1 < argc) ppm_every = atoi(argv[++i]);
		else if (!strcmp(argv[i], "--kbd")) kbd_trace = true;
		else if (!strcmp(argv[i], "--i2c")) i2c_trace = true;
		else if (!strcmp(argv[i], "--i2c-raw")) i2c_raw = true;
		else if (!strcmp(argv[i], "--dump-ram")) dump_ram = true;
		else if (!strcmp(argv[i], "--pc-hist") && i + 1 < argc) hist_from = atof(argv[++i]);
		else if (!strcmp(argv[i], "--report") && i + 1 < argc) report_ms = atof(argv[++i]);
		else if (!strcmp(argv[i], "--key") && i + 1 < argc) {
			Key k = { 0, 0, 100, false, false };
			char *s = argv[++i];
			k.ms = strtod(s, &s);
			if (*s == ':') k.code = strtol(s + 1, &s, 16);
			if (*s == ':') k.hold = strtod(s + 1, &s);
			keys.push_back(k);
		}
		else if (!strcmp(argv[i], "--expect-scan")) expect_scan = true;
		else if (!strcmp(argv[i], "--expect-frames") && i + 1 < argc) expect_frames = atoi(argv[++i]);
		else if (!strcmp(argv[i], "--expect-nonblack") && i + 1 < argc) expect_nonblack = atol(argv[++i]);
		else { fprintf(stderr, "unknown argument %s\n", argv[i]); return 2; }
	}
	if (!rom) { fprintf(stderr, "--rom FILE needed\n"); return 2; }
	if (!load_rom(rom)) return 2;
	frame_reset();

	tb->reset = 1;
	for (int i = 0; i < 100; i++) tick();
	tb->reset = 0;

	time_t t0 = time(nullptr);
	double next_report = report_ms;
	int last_rx = 0, last_scan = 0, last_mouse = 0;
	while (sim_ms < run_ms) {
		tb->key_strobe = 0;
		for (auto &k : keys) {
			if (!k.down_sent && sim_ms >= k.ms) {
				tb->key_strobe = 1; tb->key_code = k.code; tb->key_up = 0; k.down_sent = true;
				printf("%9.3f ms key %02x down\n", sim_ms, k.code);
				break;
			}
			if (k.down_sent && !k.up_sent && sim_ms >= k.ms + k.hold) {
				tb->key_strobe = 1; tb->key_code = k.code; tb->key_up = 1; k.up_sent = true;
				printf("%9.3f ms key %02x up\n", sim_ms, k.code);
				break;
			}
		}
		tick();
		i2c_step();
		vec_step();
		if (tb->wr_strobe) wr_region[(tb->wr_addr >> 14) & 255]++;
		if (hist_from >= 0 && sim_ms >= hist_from && tb->cpu_pc != last_pc) { pc_hist[tb->cpu_pc]++; last_pc = tb->cpu_pc; }
		if (kbd_trace) {
			if (tb->kbd_rx_strobe && !last_rx) printf("%9.3f ms kbd <- %02x\n", sim_ms, tb->kbd_rx_data);
			if (tb->kbd_tx_strobe) printf("%9.3f ms kbd -> %02x\n", sim_ms, tb->kbd_tx_data);
		}
		last_rx = tb->kbd_rx_strobe;
		if (tb->kbd_scan != last_scan || tb->kbd_mouse != last_mouse) {
			printf("%9.3f ms keyboard scan %d mouse %d\n", sim_ms, tb->kbd_scan, tb->kbd_mouse);
			last_scan = tb->kbd_scan;
			last_mouse = tb->kbd_mouse;
		}
		if (sim_ms >= next_report) {
			printf("%9.3f ms (%ld s), pc %07x, cmos writes %d, exceptions", sim_ms, (long)(time(nullptr) - t0), tb->cpu_pc, tb->cmos_changes);
			for (int v = 0; v < 8; v++) if (vec_count[v]) printf(" %s %ld", vec_name[v], vec_count[v]);
			printf("\n           writes per 64 KB:");
			for (int r = 0; r < 256; r++) if (wr_region[r]) printf(" %06x:%ld", r << 16, wr_region[r]);
			printf("\n");
			memset(wr_region, 0, sizeof wr_region);
			fflush(stdout);
			next_report += report_ms;
		}
	}
	if (dump_ram) {
		auto &m = tb->rootp->sim_top->mem;
		printf("RAM words != 0 per 64 KB (0..4 MB):\n");
		for (int blk = 0; blk < 64; blk++) {
			int n = 0;
			for (int i = 0; i < 16384; i++) if (m[blk * 16384 + i]) n++;
			printf("%s%06x:%5d", blk % 8 ? "  " : "\n  ", blk << 16, n);
		}
		printf("\nMEMC vinit %05x vstart %05x vend %05x\n", tb->vid_init, tb->vid_start, tb->vid_end);
		FILE *f = fopen("sim/build/ram.bin", "wb");
		if (f) { for (int i = 0; i < 1048576; i++) { uint32_t w = m[i]; fwrite(&w, 4, 1, f); } fclose(f); }
	}
	if (!pc_hist.empty()) {
		std::vector<std::pair<long, uint32_t>> v;
		for (auto &e : pc_hist) v.push_back({e.second, e.first});
		std::sort(v.rbegin(), v.rend());
		printf("pc histogram from %.3f ms (%zu addresses):\n", hist_from, v.size());
		for (size_t i = 0; i < v.size() && i < 40; i++) printf("  %07x %ld\n", v[i].second, v[i].first);
	}
	int rc = 0;
	if (expect_scan && !last_scan) { printf("FAIL: key scan not enabled\n"); rc = 1; }
	if (expect_frames >= 0 && frames < expect_frames) { printf("FAIL: %d frames < %d\n", frames, expect_frames); rc = 1; }
	if (expect_nonblack >= 0 && last_nonblack < expect_nonblack) {
		printf("FAIL: %ld non-black pixels < %ld\n", last_nonblack, expect_nonblack); rc = 1;
	}
	printf("%s at %.3f ms, %d frames, %ld s\n", rc ? "FAILED" : "done", sim_ms, frames, (long)(time(nullptr) - t0));
	tb->final();
	delete tb;
	return rc;
}
