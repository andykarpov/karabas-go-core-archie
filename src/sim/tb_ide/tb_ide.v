`timescale 1ns / 1ps
// tb_ide.v (iverilog): archie_ide (hdf_ata behind the podule bus) on sdc_file_model with a test image.
// The podule accesses are CPU cycles: the strobe STB clocks long, GAP clocks between two (1 at least).
// IDENTIFY (the size in words 60/61), READ SECTORS of LBA 5 (the pattern of the image), WRITE SECTORS
// of LBA 7 and its read back, a CHS read after INITIALIZE DEVICE PARAMETERS (heads 8, 32 sectors).
//   ./run.sh   (makes the image, prints "tb_ide STB n GAP n: N errors")
module tb_ide;
parameter STB = 4;
parameter GAP = 1;
reg clk = 0;
always #12.5 clk = ~clk;

reg [2:0] a = 0;
reg cs = 0, rd = 0, wr = 0;
reg [15:0] wdata = 0;
wire [15:0] rdata;
wire mnt, busy, done, err, strobe;
wire [63:0] size;
wire [1:0] s_rd, s_wr;
wire [31:0] sector;
wire [8:0] baddr;
wire [7:0] bin, bout;

archie_ide dut (
	.clk(clk), .reset(1'b0), .ata_reset(1'b0),
	.ide_a(a), .ide_cs(cs), .ide_rd(rd), .ide_wr(wr), .ide_wdata(wdata), .ide_rdata(rdata),
	.img_mounted({ 1'b0, mnt }), .img_size(size), .sdc_rd(s_rd), .sdc_wr(s_wr), .sdc_sector(sector),
	.sdc_busy(busy), .sdc_done(done), .sdc_error(err), .sdc_byte_in_strobe(strobe),
	.sdc_byte_addr(baddr), .sdc_byte_in_data(bin), .sdc_byte_out_data(bout), .led()
);
sdc_file_model #(.MOUNT_AT(20)) img (
	.clk(clk), .img_mounted(mnt), .img_size(size), .sdc_rd(s_rd[0]), .sdc_wr(s_wr[0]), .sdc_sector(sector),
	.sdc_busy(busy), .sdc_done(done), .sdc_error(err), .sdc_byte_in_strobe(strobe),
	.sdc_byte_addr(baddr), .sdc_byte_in_data(bin), .sdc_byte_out_data(bout)
);

integer errors = 0, i, t;
reg [15:0] v;
reg [15:0] w [0:255];

// a CPU cycle: address and strobe for STB clocks, the data taken in the last one (the ack)
task cyc(input we, input [2:0] r, input [15:0] d, output [15:0] q);
	begin
		@(posedge clk) begin a <= r; cs <= 1; rd <= !we; wr <= we; wdata <= d; end
		repeat (STB - 1) @(posedge clk);
		#1 q = rdata;
		@(posedge clk) begin cs <= 0; rd <= 0; wr <= 0; a <= $random; wdata <= $random; end
		repeat (GAP - 1) @(posedge clk);
	end
endtask
task wreg(input [2:0] r, input [7:0] d); reg [15:0] q; begin cyc(1, r, { 8'h00, d }, q); end endtask
task rreg(input [2:0] r, output [15:0] q); begin cyc(0, r, 16'd0, q); end endtask
task wait_ready(input integer drq);
	begin
		t = 0;
		rreg(7, v);
		while ((v[7] || (drq && !v[3])) && t < 200000) begin rreg(7, v); t = t + 1; end
		if (t == 200000) begin $display("timeout, status %h", v); errors = errors + 1; end
		if (v[0]) begin rreg(1, v); $display("ERR, error %h", v); errors = errors + 1; end
	end
endtask
task read_block; begin for (i = 0; i < 256; i = i + 1) rreg(0, w[i]); end endtask
// the bytes of run.sh: even o (lba + o) & 255 (the low byte of the word), odd o (lba ^ o) & 255
function [15:0] pat(input [31:0] lba, input integer k);
	reg [7:0] lo, hi;
	begin
		lo = lba[7:0] + 2 * k;
		hi = lba[7:0] ^ (2 * k + 1);
		pat = { hi, lo };
	end
endfunction
task check_block(input [31:0] lba, input integer xorv);
	begin
		for (i = 0; i < 256; i = i + 1)
			if (w[i] !== (pat(lba, i) ^ xorv)) begin
				if (errors < 10) $display("lba %0d word %0d: %h, want %h", lba, i, w[i], pat(lba, i) ^ xorv);
				errors = errors + 1;
			end
	end
endtask

initial begin
	repeat (40) @(posedge clk);
	wait_ready(0);
	// IDENTIFY
	wreg(6, 8'hA0); wreg(7, 8'hEC); wait_ready(1); read_block;
	if ({ w[61], w[60] } !== 32'd4096) begin $display("IDENTIFY sectors %0d, want 4096", { w[61], w[60] }); errors = errors + 1; end
	// READ SECTORS LBA 5
	wreg(2, 1); wreg(3, 5); wreg(4, 0); wreg(5, 0); wreg(6, 8'hE0); wreg(7, 8'h20);
	wait_ready(1); read_block; check_block(5, 0);
	// WRITE SECTORS LBA 7: the pattern of LBA 7 inverted
	wreg(2, 1); wreg(3, 7); wreg(4, 0); wreg(5, 0); wreg(6, 8'hE0); wreg(7, 8'h30);
	wait_ready(1);
	for (i = 0; i < 256; i = i + 1) cyc(1, 0, pat(7, i) ^ 16'hFFFF, v);
	wait_ready(0);
	wreg(2, 1); wreg(3, 7); wreg(4, 0); wreg(5, 0); wreg(6, 8'hE0); wreg(7, 8'h20);
	wait_ready(1); read_block; check_block(7, 16'hFFFF);
	// INITIALIZE DEVICE PARAMETERS: 8 heads, 32 sectors; CHS 1/2/3 = LBA (1 * 8 + 2) * 32 + 2 = 322
	wreg(2, 32); wreg(6, 8'hA7); wreg(7, 8'h91); wait_ready(0);
	wreg(2, 1); wreg(3, 3); wreg(4, 1); wreg(5, 0); wreg(6, 8'hA2); wreg(7, 8'h20);
	wait_ready(1); read_block; check_block(322, 0);
	$display("tb_ide STB %0d GAP %0d: %0d errors (%0d sectors read, %0d written)", STB, GAP, errors,
		img.reads, img.writes);
	$finish;
end
initial begin #200000000; $display("tb_ide: hang"); $finish; end
endmodule
