`timescale 1ns / 1ps
`default_nettype none
/*
 archie_fb.v

 The frame buffer of the Archimedes core: the picture of the VIDC (any mode the program sets) into
 bank 2 of the SDRAM through archie_sdram, out as VESA 800 x 600 at 60 Hz (40.0 MHz, 1056 x 628,
 positive syncs), so the monitor always gets one standard mode (the user's rule).

 Capture (clk_sys, the VIDC with its pixel enable ce): the pixels inside VIDEO_EN (de). A line
 is a run of de; its pixels (12-bit RGB in 16-bit words, up to 1024) go into one of four slots of the
 capture buffer (block RAM, read by clk_mem); at the end of the run the slot is queued (its row
 { frame, line } and length in a descriptor, the write pointer to clk_mem in Gray code) and the SDRAM
 side writes the queued lines in order to their rows (two SDRAM rows of 512 words). Up to three lines
 wait while the fourth slot fills. A frame ends at the start of vsync: if all of its lines were
 queued, its height and the width of its last line are kept and it becomes the done frame, and the
 writer takes a frame that is neither the new done one, the done one before (the output may just
 have taken it) nor the shown one (four frames). A line that finds the queue full is dropped, and
 its frame is not shown: the writer does it again (the picture stays on the last whole frame).

 Output (clk_pix): the shown frame is taken at the start of each output frame (the done one). A
 picture narrower than 401 pixels is shown with each pixel twice, one lower than 301 lines with each
 line twice; it sits in the middle of 800 x 600 (cropped if larger), black around it. The line of the
 picture for output line y + 1 is read from the SDRAM into one half of the line buffer while line y
 shows (a toggle request to the SDRAM side).

 SDRAM side (clk_mem): the requests of both, as fbw_* / fbr_* of archie_sdram.
 rgb / hs / vs / de of the output are high active, three clocks after the counters.
*/
module archie_fb (
	input wire clk_sys,
	input wire clk_mem,
	input wire clk_pix,

	// the VIDC (clk_sys)
	input wire ce,
	input wire [3:0] r_i,
	input wire [3:0] g_i,
	input wire [3:0] b_i,
	input wire de_i,
	input wire vs_n_i,

	// to archie_sdram (clk_mem)
	output reg fbw_req = 1'b0,
	output reg [11:0] fbw_row = 12'd0,
	output reg [10:0] fbw_len = 11'd0,
	output reg fbw_buf = 1'b0,
	input wire [10:0] fbw_addr,
	output reg [15:0] fbw_data = 16'd0,
	input wire fbw_busy,
	output reg fbr_req = 1'b0,
	output reg [11:0] fbr_row = 12'd0,
	output reg [10:0] fbr_len = 11'd0,
	output reg fbr_buf = 1'b0,
	input wire fbr_we,
	input wire [10:0] fbr_addr,
	input wire [15:0] fbr_data,
	input wire fbr_busy,

	// the output (clk_pix)
	output reg [23:0] rgb = 24'd0,
	output reg hs = 1'b0,
	output reg vs = 1'b0,
	output reg de = 1'b0,

	// for the tests (clk_sys): the size of the last frame
	output reg [10:0] cap_w = 11'd0,
	output reg [9:0] cap_h = 10'd0,
	output reg [7:0] dropped = 8'd0
);

// ================================================================ declarations

reg [15:0] line_mem [0:2047];
reg rt1 = 1'b0, rt2 = 1'b0, rt3 = 1'b0;
reg r_pend = 1'b0;
// the line queue, clk_mem side (rp_g is read by clk_sys)
reg [2:0] rp = 3'd0, rp_g = 3'd0;


localparam [10:0] H_TOTAL = 11'd1056, H_ACT = 11'd800, H_SS = 11'd840, H_SE = 11'd968;
localparam [9:0] V_TOTAL = 10'd628, V_ACT = 10'd600, V_SS = 10'd601, V_SE = 10'd605;

reg [10:0] hc = 11'd0;
reg [9:0] vc = 10'd0;
reg [1:0] fr_out = 2'd2;      // the frame shown
reg frt = 1'b0;               // toggled when fr_out changes
reg vt1 = 1'b0, vt2 = 1'b0, vt3 = 1'b0;
reg [1:0] fd_p = 2'd1;
reg [10:0] sw = 11'd0, sw_p = 11'd0;     // the size of the done frame (taken with it)
reg [9:0] sh = 10'd0, sh_p = 10'd0;
reg valid = 1'b0, valid_p = 1'b0;

// the geometry of the shown frame
reg xd = 1'b0, yd = 1'b0;               // doubled
reg [10:0] pw = 11'd0;                  // shown width (pixels of the output)
reg [9:0] ph = 10'd0;
reg [10:0] x0 = 11'd0;                  // left / top of the picture; past the left / top edge if larger
reg [9:0] y0 = 10'd0;
reg [10:0] cx = 11'd0;                  // the crop: first source pixel / line shown
reg [9:0] cy = 10'd0;

reg rtog = 1'b0;
reg [11:0] o_row = 12'd0;
reg [10:0] o_len = 11'd0;
reg o_buf = 1'b0;


// ================================================================ capture (clk_sys)

reg [15:0] cap_mem [0:4095];
reg de_d = 1'b0, vs_d = 1'b1;
reg [10:0] x = 11'd0;
reg [9:0] y = 10'd0;
reg [1:0] fw = 2'd0;          // the frame being written
reg [1:0] fd = 2'd1;          // the done frame
reg [1:0] fr_sys = 2'd2;      // the shown frame, seen in clk_sys (taken on frt)
reg frt1 = 1'b0, frt2 = 1'b0, frt3 = 1'b0;
reg bad = 1'b0;               // a line of this frame was dropped
reg [10:0] w_last = 11'd0;
reg vtog = 1'b0;              // a frame done: fd / cap_w / cap_h new
// the line queue: slot wp[1:0] fills, rp .. wp - 1 wait (rp from clk_mem)
reg [2:0] wp = 3'd0, wp_g = 3'd0;
reg [2:0] rpg1 = 3'd0, rpg2 = 3'd0;
wire [2:0] rp_s = { rpg2[2], rpg2[2] ^ rpg2[1], rpg2[2] ^ rpg2[1] ^ rpg2[0] };
reg [11:0] q_row [0:3];
reg [10:0] q_len [0:3];
wire [2:0] q_used = wp - rp_s;
// the frame the writer takes next: not the new done one, the done one before, the shown one
wire [1:0] f_next = (fw != 2'd0 && fd != 2'd0 && fr_sys != 2'd0) ? 2'd0 :
                    (fw != 2'd1 && fd != 2'd1 && fr_sys != 2'd1) ? 2'd1 :
                    (fw != 2'd2 && fd != 2'd2 && fr_sys != 2'd2) ? 2'd2 : 2'd3;

always @(posedge clk_sys) begin
	frt1 <= frt; frt2 <= frt1; frt3 <= frt2;
	if (frt2 != frt3) fr_sys <= fr_out;   // fr_out is stable for a frame after frt toggles
	rpg1 <= rp_g; rpg2 <= rpg1;
	wp_g <= wp ^ (wp >> 1);
	vs_d <= vs_n_i;
	if (ce) begin
		de_d <= de_i;
		if (de_i) begin
			if (x != 11'd1024) begin
				cap_mem[{ wp[1:0], x[9:0] }] <= { 4'h0, r_i, g_i, b_i };
				x <= x + 11'd1;
			end
		end else if (de_d) begin
			// the end of a line: queue it unless three lines wait
			if (y != 10'd1023) begin
				if (q_used >= 3'd3) begin
					if (dropped != 8'hFF) dropped <= dropped + 8'd1;
					bad <= 1'b1;
				end else begin
					q_row[wp[1:0]] <= { fw, y };
					q_len[wp[1:0]] <= x;
					wp <= wp + 3'd1;
				end
				y <= y + 10'd1;
			end
			w_last <= x;
			x <= 11'd0;
		end
	end
	// the start of vsync: the frame is done (if whole)
	if (vs_d && !vs_n_i) begin
		if (y != 10'd0 && !bad) begin
			cap_w <= w_last;
			cap_h <= y;
			fd <= fw;
			fw <= f_next;
			vtog <= ~vtog;
		end
		bad <= 1'b0;
		y <= 10'd0;
		x <= 11'd0;
	end
end

// ================================================================ SDRAM side (clk_mem)

reg [2:0] wpg1 = 3'd0, wpg2 = 3'd0;
wire [2:0] wp_m = { wpg2[2], wpg2[2] ^ wpg2[1], wpg2[2] ^ wpg2[1] ^ wpg2[0] };
reg [1:0] w_st = 2'd0;
reg [1:0] slot_m = 2'd0;

always @(posedge clk_mem) begin
	fbw_data <= cap_mem[{ slot_m, fbw_addr[9:0] }];
	if (fbr_we) line_mem[fbr_addr] <= fbr_data;

	wpg1 <= wp_g; wpg2 <= wpg1;
	rp_g <= rp ^ (rp >> 1);
	rt1 <= rtog; rt2 <= rt1; rt3 <= rt2;
	fbw_req <= 1'b0;
	fbr_req <= 1'b0;
	// the queued lines in order: a request, the SDRAM side busy, done
	case (w_st)
	2'd0:
		if (rp != wp_m && !fbw_busy) begin
			fbw_row <= q_row[rp[1:0]];
			fbw_len <= q_len[rp[1:0]];
			slot_m <= rp[1:0];
			fbw_req <= 1'b1;
			w_st <= 2'd1;
		end
	2'd1: w_st <= 2'd2;               // fbw_busy rises in this clock
	default:
		if (!fbw_busy) begin
			rp <= rp + 3'd1;
			w_st <= 2'd0;
		end
	endcase
	if (rt2 != rt3) begin
		r_pend <= 1'b1;
		fbr_row <= o_row;
		fbr_len <= o_len;
		fbr_buf <= o_buf;
	end else if (r_pend && !fbr_busy && !fbr_req) begin
		fbr_req <= 1'b1;
		r_pend <= 1'b0;
	end
end

// ================================================================ output (clk_pix)

// the source line shown on output line v_next (0..599), 7FF outside the picture
wire [9:0] v_next = (vc == V_TOTAL - 10'd1) ? 10'd0 : vc + 10'd1;
wire [9:0] v_rel = v_next - y0;
wire v_in = v_next >= y0 && v_next < y0 + ph;
wire [10:0] s_next = v_in ? { 1'b0, (yd ? { 1'b0, v_rel[9:1] } : v_rel) + cy } : 11'h7FF;

wire [10:0] hx = hc - x0;
wire [10:0] src_x = (xd ? { 1'b0, hx[10:1] } : hx) + cx;

// pipeline: counters -> line buffer address -> data -> rgb
reg [10:0] rd_addr = 11'd0;
reg in_pic1 = 1'b0, in_pic2 = 1'b0;
reg de1 = 1'b0, de2 = 1'b0, hs1 = 1'b0, hs2 = 1'b0, vs1 = 1'b0, vs2 = 1'b0;
reg [15:0] pix = 16'd0;
reg [10:0] s_cur = 11'h7FF;
reg show_buf = 1'b0;

always @(posedge clk_pix) begin
	vt1 <= vtog; vt2 <= vt1; vt3 <= vt2;
	if (vt2 != vt3) begin
		fd_p <= fd;
		sw_p <= cap_w;
		sh_p <= cap_h;
		valid_p <= 1'b1;
	end

	// counters
	if (hc == H_TOTAL - 11'd1) begin
		hc <= 11'd0;
		vc <= v_next;
	end else
		hc <= hc + 11'd1;

	// the start of an output frame (the line before line 0): take the done frame and its size
	if (hc == 11'd0 && vc == V_TOTAL - 10'd2) begin
		fr_out <= fd_p;
		if (fd_p != fr_out) frt <= ~frt;
		valid <= valid_p;
		sw <= sw_p;
		sh <= sh_p;
		xd <= sw_p <= 11'd400;
		yd <= sh_p <= 10'd300;
	end
	if (hc == 11'd1 && vc == V_TOTAL - 10'd2) begin
		pw <= (xd ? { sw[9:0], 1'b0 } : sw) > H_ACT ? H_ACT : (xd ? { sw[9:0], 1'b0 } : sw);
		ph <= (yd ? { sh[8:0], 1'b0 } : sh) > V_ACT ? V_ACT : (yd ? { sh[8:0], 1'b0 } : sh);
	end
	if (hc == 11'd2 && vc == V_TOTAL - 10'd2) begin
		x0 <= (H_ACT - pw) >> 1;
		y0 <= (V_ACT - ph) >> 1;
		cx <= ((xd ? { sw[9:0], 1'b0 } : sw) - pw) >> (xd ? 1 : 0);
		cy <= ((yd ? { sh[8:0], 1'b0 } : sh) - ph) >> (yd ? 1 : 0);
	end

	// at the start of a line: fetch the source line of the next output line if it is a new one
	if (hc == 11'd8) begin
		if (s_next != 11'h7FF && s_next != s_cur && valid) begin
			o_row <= { fr_out, s_next[9:0] };
			o_len <= sw;
			o_buf <= ~show_buf;
			rtog <= ~rtog;
		end
	end
	// the line it was fetched for begins: show that half
	if (hc == H_TOTAL - 11'd1) begin
		if (s_next != 11'h7FF && s_next != s_cur) show_buf <= ~show_buf;
		s_cur <= s_next;
	end

	// pixel pipeline
	in_pic1 <= vc < V_ACT && hc < H_ACT && s_cur != 11'h7FF && hc >= x0 && hc < x0 + pw && valid;
	rd_addr <= { show_buf, src_x[9:0] };
	de1 <= vc < V_ACT && hc < H_ACT;
	hs1 <= hc >= H_SS && hc < H_SE;
	vs1 <= vc >= V_SS && vc < V_SE;
	pix <= line_mem[rd_addr];
	in_pic2 <= in_pic1;
	de2 <= de1; hs2 <= hs1; vs2 <= vs1;
	rgb <= in_pic2 ? { pix[11:8], pix[11:8], pix[7:4], pix[7:4], pix[3:0], pix[3:0] } : 24'd0;
	de <= de2; hs <= hs2; vs <= vs2;
end

endmodule
