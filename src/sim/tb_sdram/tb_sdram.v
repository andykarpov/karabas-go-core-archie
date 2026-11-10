`timescale 1ns / 1ps
// tb_sdram.v: archie_sdram on sdram_model; the wishbone master and the checks are in tb_sdram.cpp.
// cap: the capture buffer (read a clock after the address), lb: the output line buffer.
module tb_sdram #(parameter CHUNK = 6'd32) (
	input wire clk,
	input wire wb_clk,
	input wire reset,
	output wire ready,
	input wire wb_cyc,
	input wire wb_stb,
	input wire wb_we,
	input wire [3:0] wb_sel,
	input wire [23:2] wb_adr,
	input wire [31:0] wb_dat_i,
	output wire [31:0] wb_dat_o,
	output wire wb_ack,
	input wire fbw_req,
	input wire [11:0] fbw_row,
	input wire [10:0] fbw_len,
	input wire fbw_buf,
	output wire fbw_busy,
	input wire fbr_req,
	input wire [11:0] fbr_row,
	input wire [10:0] fbr_len,
	input wire fbr_buf,
	output wire fbr_busy,
	output wire [31:0] sdr_errors,
	output wire [31:0] sdr_refreshes
);
reg [15:0] cap [0:2047] /* verilator public */;
reg [15:0] lb [0:2047] /* verilator public */;
wire [10:0] fbw_addr, fbr_addr;
reg [15:0] fbw_data = 16'd0;
wire fbr_we;
wire [15:0] fbr_data;
always @(posedge clk) begin
	fbw_data <= cap[fbw_addr];
	if (fbr_we) lb[fbr_addr] <= fbr_data;
end
wire [12:0] a;
wire [1:0] ba, dqm;
wire ras_n, cas_n, we_n;
wire [15:0] dq;
archie_sdram #(.INIT_CLOCKS(15'd200), .CHUNK(CHUNK)) dut (
	.clk(clk), .wb_clk(wb_clk), .reset(reset), .ready(ready),
	.wb_cyc(wb_cyc), .wb_stb(wb_stb), .wb_we(wb_we), .wb_sel(wb_sel), .wb_adr(wb_adr),
	.wb_dat_i(wb_dat_i), .wb_dat_o(wb_dat_o), .wb_ack(wb_ack),
	.fbw_req(fbw_req), .fbw_row(fbw_row), .fbw_len(fbw_len), .fbw_buf(fbw_buf), .fbw_addr(fbw_addr),
	.fbw_data(fbw_data), .fbw_busy(fbw_busy),
	.fbr_req(fbr_req), .fbr_row(fbr_row), .fbr_len(fbr_len), .fbr_buf(fbr_buf), .fbr_we(fbr_we),
	.fbr_addr(fbr_addr), .fbr_data(fbr_data), .fbr_busy(fbr_busy),
	.sdr_a(a), .sdr_ba(ba), .sdr_dq(dq), .sdr_dqm(dqm), .sdr_ras_n(ras_n), .sdr_cas_n(cas_n), .sdr_we_n(we_n)
);
sdram_model model (.clk(clk), .ba(ba), .a(a), .dqm(dqm), .ras_n(ras_n), .cas_n(cas_n), .we_n(we_n), .dq(dq));
assign sdr_errors = model.errors;
assign sdr_refreshes = model.refreshes;
endmodule
