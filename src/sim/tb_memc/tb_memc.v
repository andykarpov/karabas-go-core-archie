`timescale 1ns / 1ps
// tb_memc: the page table decode of memc_translator (rtl/sv2v, the tree of the karabas change)
// against the original 128-way ?: chain (memc_translator_old, made by run.sh from git 81feb14):
// random tables (few distinct logical pages, so that several entries match), all modes, random
// addresses. Prints "tb_memc: 0 errors".
module tb_memc;
reg clk = 0;
reg wr = 0;
reg [1:0] page_size = 0;
reg spvmd = 0, osmd = 0, mem_write = 0;
reg [25:0] addr_i = 0;
wire [25:0] a_new, a_old;
wire v_new, v_old;

memc_translator     dut (.clkcpu(clk), .wr(wr), .page_size(page_size), .spvmd(spvmd), .osmd(osmd), .mem_write(mem_write), .addr_i(addr_i), .addr_o(a_new), .valid(v_new));
memc_translator_old ref (.clkcpu(clk), .wr(wr), .page_size(page_size), .spvmd(spvmd), .osmd(osmd), .mem_write(mem_write), .addr_i(addr_i), .addr_o(a_old), .valid(v_old));

always #5 clk = ~clk;

integer errors = 0, checks = 0, i, n, t;
reg [6:0] ppn;
reg [9:0] lpn;
initial begin
	for (t = 0; t < 20; t = t + 1) begin
		// fill the table: entry ppn gets a logical page from a small set and random protection
		page_size = 2'd0;
		for (i = 0; i < 128; i = i + 1) begin
			@(negedge clk);
			ppn = i;
			lpn = $random % (t < 10 ? 8 : 300);
			// addr_i of a page table write: [6:0] ppn, [9:8] prot, [11:10] lpn high, [22:12] lpn low
			addr_i = 26'd0;
			addr_i[6:0] = ppn;
			addr_i[9:8] = $random;
			addr_i[11:10] = lpn[9:8] & 2'd0;
			addr_i[22:12] = { 3'd0, lpn[7:0] } | ({ $random } & 11'h700 & {11{t[0]}});
			wr = 1'b1;
			@(negedge clk);
			wr = 1'b0;
		end
		// look up
		for (n = 0; n < 4000; n = n + 1) begin
			@(negedge clk);
			page_size = $random;
			spvmd = $random; osmd = $random; mem_write = $random;
			addr_i = $random;
			addr_i[24:15] = (n & 1) ? ($random % (t < 10 ? 8 : 300)) : $random;
			#1;
			checks = checks + 1;
			if (a_new !== a_old || v_new !== v_old) begin
				errors = errors + 1;
				if (errors < 10) $display("mismatch: addr %h: new %h %b old %h %b", addr_i, a_new, v_new, a_old, v_old);
			end
		end
	end
	$display("tb_memc: %0d checks, %0d matches", checks, checks - errors);
	$display("tb_memc: %0d errors", errors);
	$finish;
end
endmodule
