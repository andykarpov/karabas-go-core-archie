`timescale 1ns / 1ps
// tb_fdd.v (iverilog): archie_fdd between a model of the sector side of img_sdc and the fifo of
// fdc1772 (fdc1772_dpram, 10 bits: two 512-byte halves). The model behaves as img_sdc:
// - read: sdc_busy up, the 512 bytes as sdc_byte_in_strobe with sdc_byte_addr / data, a byte every
//   GAP clocks, sdc_busy down on the edge after the last strobe (S_OADDR with wpos 512);
// - write: sdc_busy up, the sector copied out as img_sdc does (S_CADDR: the address, OUT_LATENCY - 1
//   clocks, the byte taken on the next edge), sdc_busy down.
// Half 0 is read, then half 1 (s_odd as fdc1772 sets it), then both are written back and compared.
//   iverilog -g2012 -o tb tb_fdd.v ../../rtl/karabas/archie_fdd.v && vvp tb
module tb_fdd;
parameter GAP = 3;
parameter OUT_LATENCY = 3;
reg clk = 0;
always #12.5 clk = ~clk;

reg sdc_busy = 0, strobe = 0;
reg [2:0] slot = 3'd0;
reg [8:0] baddr = 9'd0;
reg [7:0] bdata = 8'd0;
wire [7:0] out_data;
wire sd_ack, sd_buff_wr;
wire [7:0] sd_buff_addr;
wire [15:0] sd_buff_dout, sd_buff_din;
reg s_odd = 0;

archie_fdd dut (
	.clk(clk), .sdc_img_mounted(8'd0), .sdc_img_size(64'd0), .img_wp_all(8'd0),
	.sdc_busy(sdc_busy), .sdc_slot(slot), .sdc_byte_in_strobe(strobe), .sdc_byte_addr(baddr),
	.sdc_byte_in_data(bdata), .sdc_byte_out_data(out_data), .sel(),
	.img_mounted(), .img_size(), .img_wp(), .sd_ack(sd_ack), .sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout), .sd_buff_wr(sd_buff_wr), .sd_buff_din(sd_buff_din)
);

// the fifo of fdc1772 (port a as there: written by sd_dout_strobe & sd_ack)
reg [7:0] ram_lo [0:511];
reg [7:0] ram_hi [0:511];
reg [7:0] qa_lo = 0, qa_hi = 0;
wire [8:0] fifo_sdptr = { s_odd, sd_buff_addr };
wire wren_a = sd_buff_wr & sd_ack;
always @(posedge clk) begin
	if (wren_a) begin ram_lo[fifo_sdptr] <= sd_buff_dout[7:0]; ram_hi[fifo_sdptr] <= sd_buff_dout[15:8]; end
	qa_lo <= wren_a ? sd_buff_dout[7:0] : ram_lo[fifo_sdptr];
	qa_hi <= wren_a ? sd_buff_dout[15:8] : ram_hi[fifo_sdptr];
end
assign sd_buff_din = { qa_hi, qa_lo };

function [7:0] pat(input [9:0] i);
	pat = i[7:0] ^ { 3'd0, i[9:8], 3'd5 } ^ 8'h5A;
endfunction

reg [7:0] got [0:1023];
integer i, h, errors = 0, lost = 0, k;

task read_half(input integer half);
	begin
		@(posedge clk) sdc_busy <= 1;
		repeat (4) @(posedge clk);
		for (i = 0; i < 512; i = i + 1) begin
			@(posedge clk) begin strobe <= 1; baddr <= i; bdata <= pat(half * 512 + i); end
			// img_sdc: the strobe one clock; after the last byte sdc_busy falls on the next edge
			@(posedge clk) begin strobe <= 0; if (i == 511) sdc_busy <= 0; end
			if (i != 511) repeat (GAP - 2) @(posedge clk);
		end
		repeat (6) @(posedge clk);
	end
endtask

task write_half(input integer half);
	begin
		@(posedge clk) sdc_busy <= 1;
		repeat (2) @(posedge clk);
		for (i = 0; i < 512; i = i + 1) begin
			@(posedge clk) baddr <= i;                 // S_CADDR
			repeat (OUT_LATENCY - 1) @(posedge clk);  // S_CDATA wlat
			@(posedge clk) got[half * 512 + i] = out_data;   // taken on this edge
		end
		@(posedge clk) sdc_busy <= 0;
		repeat (6) @(posedge clk);
	end
endtask

initial begin
	repeat (5) @(posedge clk);
	for (h = 0; h < 2; h = h + 1) begin
		s_odd = h;
		read_half(h);
	end
	// what the fifo got
	for (k = 0; k < 1024; k = k + 1) begin
		if (((k & 1) ? ram_hi[k >> 1] : ram_lo[k >> 1]) !== pat(k)) begin
			if (lost < 4) $display("read: byte %0d is %h, want %h", k, (k & 1) ? ram_hi[k >> 1] : ram_lo[k >> 1], pat(k));
			lost = lost + 1;
		end
	end
	for (h = 0; h < 2; h = h + 1) begin
		s_odd = h;
		write_half(h);
	end
	for (k = 0; k < 1024; k = k + 1)
		if (got[k] !== pat(k)) begin
			if (errors < 4) $display("write: byte %0d is %h, want %h", k, got[k], pat(k));
			errors = errors + 1;
		end
	$display("tb_fdd GAP %0d OUT_LATENCY %0d: read %0d bad bytes, write %0d bad bytes: %s", GAP, OUT_LATENCY,
		lost, errors, (lost == 0 && errors == 0) ? "PASS" : "FAIL");
	$finish;
end
endmodule
