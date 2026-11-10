// tb_fb.cpp: checks of archie_fb (run_tb_fb.sh): a raster of the given VIDC-like timing in, the
// 800 x 600 output compared pixel by pixel with the picture the geometry rules of archie_fb give.
//   Vtb_fb NAME BASECLK SELPIX H_TOTAL H_START W V_TOTAL V_START H [PPM]
// clk_mem 84 MHz, clk_sys 42 MHz (rising with clk_mem), clk_pix 40 MHz; times in ps.
#include <cstdio>
#include <cstdlib>
#include <cstdint>
#include <vector>
#include "Vtb_fb.h"
#include "Vtb_fb___024root.h"
#include "Vtb_fb_tb_fb.h"
#include "Vtb_fb_sdram_model.h"
#include "verilated.h"

static Vtb_fb *tb;
static const uint64_t T_MEM_HALF = 5952, T_PIX_HALF = 12500;

int main(int argc, char **argv) {
	Verilated::commandArgs(argc, argv);
	if (argc < 10) { fprintf(stderr, "usage: NAME BASECLK SELPIX H_TOTAL H_START W V_TOTAL V_START H [PPM]\n"); return 2; }
	const char *name = argv[1];
	tb = new Vtb_fb;
	tb->baseclk = atoi(argv[2]); tb->selpix = atoi(argv[3]);
	tb->h_total = atoi(argv[4]); tb->h_start = atoi(argv[5]); tb->w = atoi(argv[6]);
	tb->v_total = atoi(argv[7]); tb->v_start = atoi(argv[8]); tb->h = atoi(argv[9]);
	const char *ppm = argc > 10 ? argv[10] : nullptr;
	int W = tb->w, H = tb->h, seed = 5;
	tb->seed = seed;

	// the expected geometry (archie_fb)
	int xd = W <= 400, yd = H <= 300;
	int dw = W * (xd ? 2 : 1), dh = H * (yd ? 2 : 1);
	int pw = dw > 800 ? 800 : dw, ph = dh > 600 ? 600 : dh;
	int x0 = (800 - pw) / 2, y0 = (600 - ph) / 2;
	int cx = (dw - pw) >> xd, cy = (dh - ph) >> yd;

	std::vector<uint32_t> img(800 * 600);
	uint64_t t = 0, n_mem = 0, n_pix = 0;
	int reset_left = 200;
	tb->reset = 1;
	int ox = 0, oy = -1, last_vs = 0, last_hs = 0, frames = 0, line_de = 0;
	int result = -1;
	while (frames < 12 && result < 0) {
		uint64_t t_mem = (n_mem + 1) * T_MEM_HALF, t_pix = (n_pix + 1) * T_PIX_HALF;
		bool pix_edge = t_pix <= t_mem, mem_edge = t_mem <= t_pix;
		t = pix_edge ? t_pix : t_mem;
		if (mem_edge) {
			n_mem++;
			tb->clk_mem = !(n_mem & 1) ? 1 : 0;      // rising at even n
			tb->clk_sys = ((n_mem & 3) == 0 || (n_mem & 3) == 1) ? 1 : 0;   // rising at n % 4 == 0
		}
		if (pix_edge) { n_pix++; tb->clk_pix = !(n_pix & 1) ? 1 : 0; }
		tb->eval();
		if (mem_edge) {
			if ((n_mem & 1) == 0 && reset_left > 0 && --reset_left == 0) tb->reset = 0;
			static int tr_n = 0, we_n = 0, first_a = -1, last_a = -1, trace_frame = 6;
			if ((n_mem & 1) == 0 && getenv("FBTRACE") && frames == trace_frame) {
				if (tb->t_fbr_we) { if (first_a < 0) first_a = tb->t_fbr_addr; last_a = tb->t_fbr_addr; we_n++; }
				if (tb->t_fbr_req && tr_n < 12) {
					printf("  req at vc %d hc %d; the one before: %d words %03x..%03x\n", tb->t_vc, tb->t_hc, we_n, first_a, last_a);
					tr_n++; we_n = 0; first_a = -1;
				}
			}
		}
		if (pix_edge) {
			if (tb->clk_pix) {
			// a rising edge of clk_pix: the outputs of the clock before
			if (tb->vs && !last_vs) {
				if (oy >= 0 && frames >= 1) {
					// check the frame (once the source has had time to fill a frame)
					if (frames >= 6) {
						int bad = 0, bx = 0, by = 0;
						uint32_t got_b = 0, want_b = 0;
						for (int y = 0; y < 600; y++)
							for (int x = 0; x < 800; x++) {
								uint32_t want = 0;
								if (x >= x0 && x < x0 + pw && y >= y0 && y < y0 + ph) {
									int sx = (x - x0) / (xd ? 2 : 1) + cx, sy = (y - y0) / (yd ? 2 : 1) + cy;
									int r = (sx & 15) ^ seed, g = sy & 15, b = ((sx >> 4) & 15) ^ ((sy >> 4) & 15);
									want = (r * 17 << 16) | (g * 17 << 8) | (b * 17);
								}
								if (img[y * 800 + x] != want) {
									if (!bad) { bx = x; by = y; got_b = img[y * 800 + x]; want_b = want; }
									bad++;
								}
							}
						if (ppm) {
							FILE *f = fopen(ppm, "wb");
							fprintf(f, "P6\n800 600\n255\n");
							for (int i = 0; i < 800 * 600; i++) { uint8_t p[3] = { (uint8_t)(img[i] >> 16), (uint8_t)(img[i] >> 8), (uint8_t)img[i] }; fwrite(p, 3, 1, f); }
							fclose(f);
						}
						printf("%-10s src %dx%d (cap %dx%d, dropped %d): picture %dx%d at %d,%d: %s", name, W, H,
							tb->cap_w, tb->cap_h, tb->dropped, pw, ph, x0, y0, bad ? "FAIL" : "PASS");
						if (bad) printf(", %d bad pixels, first at %d,%d: %06x want %06x", bad, bx, by, got_b, want_b);
						printf(", SDRAM errors %d, %.1f ms\n", tb->sdr_errors, t / 1e9);
						result = (bad || tb->sdr_errors) ? 1 : 0;
						if (bad) {
							// the frames in the SDRAM: which lines differ from the source
							auto &m = tb->rootp->tb_fb->model->mem;
							for (int f = 0; f < 3; f++) {
								int nbad = 0, fl = -1, fx = -1;
								for (int sy = 0; sy < H; sy++)
									for (int sx = 0; sx < W; sx++) {
										uint32_t idx = (2u << 22) | ((uint32_t)((f << 11) | (sy << 1) | (sx >> 9)) << 9) | (sx & 511);
										int r = (sx & 15) ^ seed, g = sy & 15, b = ((sx >> 4) & 15) ^ ((sy >> 4) & 15);
										if (m[idx] != ((r << 8) | (g << 4) | b)) { if (fl < 0) { fl = sy; fx = sx; } nbad++; }
									}
								printf("  SDRAM frame %d: %d bad words, first line %d x %d\n", f, nbad, fl, fx);
							}
						}
					}
				}
				frames++;
				oy = -1;
			}
			if (tb->hs && !last_hs) { if (line_de) oy++; line_de = 0; ox = 0; }
			if (tb->de) {
				if (oy < 0) oy = 0;
				if (ox < 800 && oy < 600) img[oy * 800 + ox] = tb->rgb;
				ox++;
				line_de = 1;
			}
			last_vs = tb->vs;
			last_hs = tb->hs;
			}
		}
	}
	if (result < 0) { printf("%-10s FAIL: only %d output frames\n", name, frames); result = 1; }
	tb->final();
	delete tb;
	return result;
}
