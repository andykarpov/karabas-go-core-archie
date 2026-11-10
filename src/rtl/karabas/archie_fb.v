`timescale 1ns / 1ps
`default_nettype none
/*
 archie_fb.v

 The frame buffer of the Archimedes core: the picture of the VIDC (any mode the program sets) into
 bank 2 of the SDRAM through archie_sdram, out as VESA 800 x 600 at 60 Hz (40.0 MHz, 1056 x 628,
 positive syncs), so the monitor always gets one standard mode (the user's rule).

 Capture (clk_sys, the VIDC with its pixel enable ce): the pixels inside VIDEO_EN (de). A line
 is a run of de; its pixels (12-bit RGB in 16-bit words, up to 1024) go into one half of the capture
 buffer (block RAM, read by clk_mem), and at the end of the run a request (a toggle with the frame,
 the line and the length) asks the SDRAM side to write it to row { frame, line } (two SDRAM rows of
 512 words). A frame ends at the start of vsync: its height and the width of its last line are
 kept, it becomes the done frame, and the writer takes the frame that is neither done nor shown
 (three frames). A line that comes while the one before is still being written is dropped.

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
reg wt1 = 1'b0, wt2 = 1'b0, wt3 = 1'b0;
reg rt1 = 1'b0, rt2 = 1'b0, rt3 = 1'b0;
reg w_pend = 1'b0, r_pend = 1'b0;
reg [11:0] o_row_m = 12'd0;
reg [10:0] o_len_m = 11'd0;
reg o_buf_m = 1'b0;


localparam [10:0] H_TOTAL = 11'd1056, H_ACT = 11'd800, H_SS = 11'd840, H_SE = 11'd968;
localparam [9:0] V_TOTAL = 10'd628, V_ACT = 10'd600, V_SS = 10'd601, V_SE = 10'd605;

reg [10:0] hc = 11'd0;
reg [9:0] vc = 10'd0;
reg [1:0] fr_out = 2'd2;      // the frame shown
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

reg [15:0] cap_mem [0:2047];
reg de_d = 1'b0, vs_d = 1'b1;
reg [10:0] x = 11'd0;
reg [9:0] y = 10'd0;
reg cbuf = 1'b0;
reg [1:0] fw = 2'd0;          // the frame being written
reg [1:0] fd = 2'd1;          // the done frame
reg [1:0] fr_sys1 = 2'd2, fr_sys = 2'd2;   // the shown frame, seen in clk_sys
reg [10:0] w_last = 11'd0;
reg wtog = 1'b0;              // a line to write
reg [11:0] w_row = 12'd0;
reg [10:0] w_len = 11'd0;
reg w_buf = 1'b0;
reg vtog = 1'b0;              // a frame done: fd / cap_w / cap_h new
reg busy_s1 = 1'b0, busy_s = 1'b0, pend_s1 = 1'b0, pend_s = 1'b0;

always @(posedge clk_sys) begin
	fr_sys1 <= fr_out;
	fr_sys <= fr_sys1;
	busy_s1 <= w_pend | fbw_busy;
	busy_s <= busy_s1;
	vs_d <= vs_n_i;
	if (ce) begin
		de_d <= de_i;
		if (de_i) begin
			if (x != 11'd1024) begin
				cap_mem[{ cbuf, x[9:0] }] <= { 4'h0, r_i, g_i, b_i };
				x <= x + 11'd1;
			end
		end else if (de_d) begin
			// the end of a line: write it unless the one before is still on its way
			if (y != 10'd1023) begin
				if (busy_s) dropped <= dropped + 8'd1;
				else begin
					w_row <= { fw, y };
					w_len <= x;
					w_buf <= cbuf;
					wtog <= ~wtog;
					cbuf <= ~cbuf;
				end
				y <= y + 10'd1;
			end
			w_last <= x;
			x <= 11'd0;
		end
	end
	// the start of vsync: the frame is done
	if (vs_d && !vs_n_i) begin
		if (y != 10'd0) begin
			cap_w <= w_last;
			cap_h <= y;
			fd <= fw;
			// the next frame: neither the new done one (fw) nor the shown one
			fw <= (fw != 2'd0 && fr_sys != 2'd0) ? 2'd0 : (fw != 2'd1 && fr_sys != 2'd1) ? 2'd1 : 2'd2;
			vtog <= ~vtog;
		end
		y <= 10'd0;
		x <= 11'd0;
	end
end

// ================================================================ SDRAM side (clk_mem)

always @(posedge clk_mem) begin
	fbw_data <= cap_mem[fbw_addr];
	if (fbr_we) line_mem[fbr_addr] <= fbr_data;

	wt1 <= wtog; wt2 <= wt1; wt3 <= wt2;
	rt1 <= rtog; rt2 <= rt1; rt3 <= rt2;
	fbw_req <= 1'b0;
	fbr_req <= 1'b0;
	if (wt2 != wt3) begin
		w_pend <= 1'b1;
		fbw_row <= w_row;
		fbw_len <= w_len;
		fbw_buf <= w_buf;
	end else if (w_pend && !fbw_busy && !fbw_req) begin
		fbw_req <= 1'b1;
		w_pend <= 1'b0;
	end
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
