`timescale 1ns / 1ps
// tb_fb.v: archie_fb + archie_sdram + sdram_model with a raster generator in place of the VIDC (clk_sys,
// one pixel per ce): h_total pixels a line (de for w of them from h_start), v_total lines (de on h
// lines from v_start), vsync low on lines 0..2. The pixel at (x, y) of the de window is pat(x, y).
module tb_fb #(parameter CHUNK = 6'd16) (
	input wire clk_mem,
	input wire clk_sys,
	input wire clk_pix,
	input wire reset,
	input wire [1:0] baseclk,
	input wire [1:0] selpix,
	input wire [10:0] h_total,
	input wire [10:0] h_start,
	input wire [10:0] w,
	input wire [9:0] v_total,
	input wire [9:0] v_start,
	input wire [9:0] h,
	input wire [3:0] seed,
	output wire [23:0] rgb,
	output wire hs,
	output wire vs,
	output wire de,
	output wire [10:0] cap_w,
	output wire [9:0] cap_h,
	output wire [7:0] dropped,
	output wire [31:0] sdr_errors,
	output wire ready,
	output wire t_fbr_req,
	output wire t_fbr_we,
	output wire [10:0] t_fbr_addr,
	output wire [10:0] t_hc,
	output wire [9:0] t_vc,
	output wire t_show,
	output wire [10:0] t_scur
);
assign t_fbr_req = fbr_req;
assign t_fbr_we = fbr_we;
assign t_fbr_addr = fbr_addr;
assign t_hc = fb.hc;
assign t_vc = fb.vc;
assign t_show = fb.show_buf;
assign t_scur = fb.s_cur;
wire ce, ce_aud;
archie_ce #(.CLK_HZ(42000000)) u_ce (.clk(clk_sys), .reset(reset), .baseclk(baseclk), .selpix(selpix), .ce_pix(ce), .ce_aud(ce_aud));
reg [10:0] gx = 11'd0;
reg [9:0] gy = 10'd0;
reg [3:0] r = 4'd0, g = 4'd0, b = 4'd0;
reg gde = 1'b0, gvs = 1'b1;
wire [10:0] px = gx - h_start;
wire [9:0] py = gy - v_start;
always @(posedge clk_sys) if (ce) begin
	if (gx == h_total - 11'd1) begin
		gx <= 11'd0;
		gy <= (gy == v_total - 10'd1) ? 10'd0 : gy + 10'd1;
	end else gx <= gx + 11'd1;
	gde <= gx >= h_start && gx < h_start + w && gy >= v_start && gy < v_start + h;
	r <= px[3:0] ^ seed;
	g <= py[3:0];
	b <= px[7:4] ^ py[7:4];
	gvs <= !(gy < 10'd3);
end
wire fbw_req, fbr_req, fbw_buf, fbr_buf, fbw_busy, fbr_busy, fbr_we;
wire [11:0] fbw_row, fbr_row;
wire [10:0] fbw_len, fbr_len, fbw_addr, fbr_addr;
wire [15:0] fbw_data, fbr_data;
archie_fb fb (
	.clk_sys(clk_sys), .clk_mem(clk_mem), .clk_pix(clk_pix),
	.ce(ce), .r_i(r), .g_i(g), .b_i(b), .de_i(gde), .vs_n_i(gvs),
	.fbw_req(fbw_req), .fbw_row(fbw_row), .fbw_len(fbw_len), .fbw_buf(fbw_buf), .fbw_addr(fbw_addr),
	.fbw_data(fbw_data), .fbw_busy(fbw_busy),
	.fbr_req(fbr_req), .fbr_row(fbr_row), .fbr_len(fbr_len), .fbr_buf(fbr_buf), .fbr_we(fbr_we),
	.fbr_addr(fbr_addr), .fbr_data(fbr_data), .fbr_busy(fbr_busy),
	.rgb(rgb), .hs(hs), .vs(vs), .de(de), .cap_w(cap_w), .cap_h(cap_h), .dropped(dropped)
);
wire [12:0] a;
wire [1:0] ba, dqm;
wire ras_n, cas_n, we_n;
wire [15:0] dq;
archie_sdram #(.INIT_CLOCKS(15'd200), .CHUNK(CHUNK)) sdram (
	.clk(clk_mem), .wb_clk(clk_sys), .reset(reset), .ready(ready),
	.wb_cyc(1'b0), .wb_stb(1'b0), .wb_we(1'b0), .wb_sel(4'd0), .wb_adr(22'd0), .wb_dat_i(32'd0),
	.wb_dat_o(), .wb_ack(),
	.fbw_req(fbw_req), .fbw_row(fbw_row), .fbw_len(fbw_len), .fbw_buf(fbw_buf), .fbw_addr(fbw_addr),
	.fbw_data(fbw_data), .fbw_busy(fbw_busy),
	.fbr_req(fbr_req), .fbr_row(fbr_row), .fbr_len(fbr_len), .fbr_buf(fbr_buf), .fbr_we(fbr_we),
	.fbr_addr(fbr_addr), .fbr_data(fbr_data), .fbr_busy(fbr_busy),
	.sdr_a(a), .sdr_ba(ba), .sdr_dq(dq), .sdr_dqm(dqm), .sdr_ras_n(ras_n), .sdr_cas_n(cas_n), .sdr_we_n(we_n)
);
sdram_model model (.clk(clk_mem), .ba(ba), .a(a), .dqm(dqm), .ras_n(ras_n), .cas_n(cas_n), .we_n(we_n), .dq(dq));
assign sdr_errors = model.errors;
endmodule
