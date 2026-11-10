// tb_sdram.cpp: checks of archie_sdram (run_tb_sdram.sh): random wishbone reads (four words, wrapping
// in the line) and writes (byte selects) against a shadow memory, while frame buffer lines are
// written from the capture buffer and read back into the line buffer; the SDRAM model counts timing
// errors. clk 84 MHz (period 2 ticks), wb_clk 42 MHz (period 4, rising with clk).
#include <cstdio>
#include <cstdlib>
#include <cstdint>
#include <vector>
#include "Vtb_sdram.h"
#include "Vtb_sdram___024root.h"
#include "Vtb_sdram_tb_sdram.h"
#include "verilated.h"

static Vtb_sdram *tb;
static uint64_t ticks = 0;
static uint32_t rnd = 12345;
static uint32_t rng(void) { rnd ^= rnd << 13; rnd ^= rnd >> 17; rnd ^= rnd << 5; return rnd; }

// one tick = half a clk period; wb logic is evaluated by the caller at wb_clk rising edges
static void half(void) {
	ticks++;
	tb->clk = (ticks & 1) ? 1 : 0;
	tb->wb_clk = ((ticks & 3) == 1 || (ticks & 3) == 2) ? 1 : 0;
	tb->eval();
}

static std::vector<uint32_t> shadow(1 << 22);   // 16 MB of words
static int errors = 0;
static int wb_reads = 0, wb_writes = 0, fb_lines = 0, fb_checked = 0;
static int lat = 0, lat_max = 0;
static long lat_sum = 0, lat_n = 0;

int main(int argc, char **argv) {
	Verilated::commandArgs(argc, argv);
	tb = new Vtb_sdram;
	int cycles = argc > 1 ? atoi(argv[1]) : 200000;   // wb_clk cycles
	bool no_fb = argc > 2 && argv[2][0] == 'n';           // "nofb": wishbone only
	for (size_t i = 0; i < shadow.size(); i++) shadow[i] = 0;
	tb->reset = 1;
	for (int i = 0; i < 40; i++) half();
	tb->reset = 0;
	while (!tb->ready) half();
	// the model memory starts at 0 (Verilator)
	auto &cap = tb->rootp->tb_sdram->cap;
	auto &lb = tb->rootp->tb_sdram->lb;

	enum { IDLE, REQ } wst = IDLE;
	int acks = 0, need = 0;
	uint32_t adr = 0, dat = 0, sel = 0;
	bool we = false;
	int fb_phase = 0;   // 0 write a line, 1 wait, 2 read it, 3 wait + check
	uint32_t fb_row = 0, fb_len = 0, fb_seed = 0;
	int wb_gap = 0;

	for (int c = 0; c < cycles && errors < 10; c++) {
		// wb_clk rising edge: ticks & 3 == 1 after the next half(); drive inputs before it
		tb->fbw_req = 0;
		tb->fbr_req = 0;
		// frame buffer traffic (clk domain, but held for a wb_clk: the controller takes a req when idle)
		if (no_fb) ;
		else if (fb_phase == 0 && !tb->fbw_busy) {
			fb_row = rng() & 0xfff;
			fb_len = 1 + rng() % 1024;
			fb_seed = rng();
			int b = rng() & 1;
			for (uint32_t i = 0; i < 1024; i++) cap[b * 1024 + i] = (uint16_t)(fb_seed + i * 7919);
			tb->fbw_req = 1; tb->fbw_row = fb_row; tb->fbw_len = fb_len; tb->fbw_buf = b;
			fb_phase = 1;
		} else if (fb_phase == 1 && !tb->fbw_busy) {
			for (int i = 0; i < 2048; i++) lb[i] = 0xdead;
			tb->fbr_req = 1; tb->fbr_row = fb_row; tb->fbr_len = fb_len; tb->fbr_buf = 1;
			fb_phase = 3;
		} else if (fb_phase == 3 && !tb->fbr_busy && !tb->fbr_req) {
			for (uint32_t i = 0; i < fb_len; i++) {
				uint16_t want = (uint16_t)(fb_seed + i * 7919);
				if (lb[1024 + i] != want) {
					if (errors < 10) printf("FB row %03x len %u word %u: %04x, want %04x\n", fb_row, fb_len, i, lb[1024 + i], want);
					errors++;
					break;
				}
			}
			fb_checked++;
			fb_phase = 0;
		}

		half();              // the rising edge of clk and wb_clk: sample the outputs, then drive
		// wishbone master, in step with wb_clk (outputs seen after the rising edge)
		if (wst == REQ && acks == 0) lat++;
		if (wst == REQ && tb->wb_ack) {
			if (acks == 0) { if (lat > lat_max) lat_max = lat; lat_sum += lat; lat_n++; }
			if (!we) {
				uint32_t a = (adr & ~3u) | ((adr + acks) & 3u);
				if (tb->wb_dat_o != shadow[a]) {
					if (errors < 10) printf("WB read %06x (+%d): %08x, want %08x\n", a << 2, acks, tb->wb_dat_o, shadow[a]);
					errors++;
				}
			}
			acks++;
			if (acks == need) {
				wst = IDLE;
				tb->wb_cyc = 0; tb->wb_stb = 0;
				wb_gap = rng() % 4;
			}
		}
		if (wst == IDLE) {
			if (wb_gap > 0) wb_gap--;
			else {
				// a small set of addresses in RAM / ROM banks so that reads hit written words
				adr = (rng() & 0x3ff) | ((rng() & 1) << 20);
				we = rng() & 1;
				sel = we ? (rng() & 15) : 15;
				if (we && sel == 0) sel = 15;
				dat = rng();
				if (we) {
					for (int b = 0; b < 4; b++)
						if (sel & (1 << b)) shadow[adr] = (shadow[adr] & ~(0xffu << (8 * b))) | (dat & (0xffu << (8 * b)));
					wb_writes++;
				} else
					wb_reads++;
				tb->wb_cyc = 1; tb->wb_stb = 1; tb->wb_we = we; tb->wb_sel = sel; tb->wb_adr = adr; tb->wb_dat_i = dat;
				acks = 0; need = we ? 1 : 4; lat = 0;
				wst = REQ;
			}
		}
		half(); half(); half();
	}
	int sdr_err = tb->sdr_errors;
	printf("wb first ack: mean %.1f, max %d wb_clk\n", lat_n ? (double)lat_sum / lat_n : 0.0, lat_max);
	printf("%s: %d wb reads, %d wb writes, %d frame buffer lines, %d refreshes, %d data errors, %d SDRAM timing errors, %.2f ms\n",
		(errors || sdr_err) ? "FAIL" : "PASS", wb_reads, wb_writes, fb_checked, tb->sdr_refreshes, errors, sdr_err,
		ticks / 2 * 11.905e-6);
	tb->final();
	delete tb;
	return (errors || sdr_err) ? 1 : 0;
}
