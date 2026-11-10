`timescale 1ns / 1ps
// tb_loader.v (iverilog): archie_loader + archie_sdram + sdram_model. A file of N bytes comes as the
// file loader of kg_mcu gives it (file_wr one clock per byte while active, a byte every GAP clocks),
// then active falls; done must rise and bank 1 must hold the bytes. The reset of the machine is
// the expression of karabas_minig_top.
module tb_loader;
parameter N = 4096;
parameter GAP = 9;
parameter END_DELAY = 3;   // clocks from the last byte to active falling (the mcu: many)
reg clk_mem = 0, clk_sys = 0;
always #6.25 clk_mem = ~clk_mem;
always @(posedge clk_mem) clk_sys <= ~clk_sys;
reg areset = 1;
reg active = 0, wr = 0;
reg [31:0] addr = 0;
reg [7:0] data = 0;
wire ld_cyc, ld_stb, ld_we, busy, done, overflow;
wire [3:0] sel; wire [23:2] adr; wire [31:0] dat;
wire wb_ack; wire [31:0] wb_din;
wire ready;
reg rom_ok = 0;
always @(posedge clk_sys) if (done) rom_ok <= 1;
reg sr1 = 0, sr = 0;
always @(posedge clk_sys) begin sr1 <= ready; sr <= sr1; end
reg [7:0] rst_cnt = 8'hFF;
wire rst_req = areset || !sr || active || busy || !rom_ok;
always @(posedge clk_sys) if (rst_req) rst_cnt <= 8'hFF; else if (rst_cnt != 0) rst_cnt <= rst_cnt - 1;
wire machine_reset = rst_cnt != 0;
archie_loader ld (.clk(clk_sys), .reset(areset), .active(active), .wr(wr), .addr(addr), .data(data),
	.wb_cyc(ld_cyc), .wb_stb(ld_stb), .wb_we(ld_we), .wb_sel(sel), .wb_adr(adr), .wb_dat(dat),
	.wb_ack(wb_ack & machine_reset), .busy(busy), .done(done), .overflow(overflow));
wire [12:0] a; wire [1:0] ba, dqm; wire ras_n, cas_n, we_n; wire [15:0] dq;
archie_sdram #(.INIT_CLOCKS(15'd200)) sd (.clk(clk_mem), .wb_clk(clk_sys), .reset(areset), .ready(ready),
	.wb_cyc(machine_reset ? ld_cyc : 1'b0), .wb_stb(machine_reset ? ld_stb : 1'b0), .wb_we(ld_we), .wb_sel(sel),
	.wb_adr(adr), .wb_dat_i(dat), .wb_dat_o(wb_din), .wb_ack(wb_ack),
	.fbw_req(1'b0), .fbw_row(12'd0), .fbw_len(11'd0), .fbw_buf(1'b0), .fbw_addr(), .fbw_data(16'd0), .fbw_busy(),
	.fbr_req(1'b0), .fbr_row(12'd0), .fbr_len(11'd0), .fbr_buf(1'b0), .fbr_we(), .fbr_addr(), .fbr_data(), .fbr_busy(),
	.sdr_a(a), .sdr_ba(ba), .sdr_dq(dq), .sdr_dqm(dqm), .sdr_ras_n(ras_n), .sdr_cas_n(cas_n), .sdr_we_n(we_n));
sdram_model model (.clk(clk_mem), .ba(ba), .a(a), .dqm(dqm), .ras_n(ras_n), .cas_n(cas_n), .we_n(we_n), .dq(dq));
function [7:0] pat(input [31:0] i); pat = i[7:0] ^ i[15:8] ^ 8'h5A; endfunction
integer i, g, bad;
reg [23:0] idx; reg [15:0] w;
initial begin
	repeat (20) @(posedge clk_sys);
	areset = 0;
	wait (ready);
	repeat (10) @(posedge clk_sys);
	active = 1;
	for (i = 0; i < N; i = i + 1) begin
		@(posedge clk_sys); wr <= 1; addr <= i; data <= pat(i);
		@(posedge clk_sys); wr <= 0;
		for (g = 2; g < GAP; g = g + 1) @(posedge clk_sys);
	end
	repeat (END_DELAY) @(posedge clk_sys);
	active = 0;
	for (i = 0; i < 20000 && !rom_ok; i = i + 1) @(posedge clk_sys);
	bad = 0;
	for (i = 0; i < N; i = i + 2) begin
		// word 0x100000 + i/4: bank 1, row (i >> 10) & fff, column { (i>>2) & ff, (i>>1) & 1 }
		idx = (24'd1 << 22) | (((i >> 10) & 12'hFFF) << 9) | (((i >> 2) & 8'hFF) << 1) | ((i >> 1) & 1);
		w = model.mem[idx];
		if (w[7:0] !== pat(i) || (i + 1 < N && w[15:8] !== pat(i + 1))) begin
			if (bad < 5) $display("byte %0d: %04x want %04x", i, w, { pat(i + 1), pat(i) });
			bad = bad + 1;
		end
	end
	$display("%s: %0d bytes, done %0d rom_ok %0d machine_reset %0d overflow %0d, %0d bad words, SDRAM errors %0d",
		(bad == 0 && rom_ok && !overflow && model.errors == 0) ? "PASS" : "FAIL", N, done, rom_ok, machine_reset, overflow, bad, model.errors);
	$finish;
end
initial begin #50000000 $display("FAIL: timeout, done %0d busy %0d", done, busy); $finish; end
endmodule
