module memc_translator (
	clkcpu,
	wr,
	page_size,
	spvmd,
	osmd,
	mem_write,
	addr_i,
	addr_o,
	valid
);
	input clkcpu;
	input wr;
	input [1:0] page_size;
	input spvmd;
	input osmd;
	input mem_write;
	input [25:0] addr_i;
	output wire [25:0] addr_o;
	output wire valid;
	localparam PAGE_TABLE_SIZE = 128;
	wire [6:0] ppn = (page_size == 2'b00 ? {addr_i[6:0]} : (page_size == 2'b01 ? {addr_i[0], addr_i[6:1]} : (page_size == 2'b10 ? {addr_i[1:0], addr_i[6:2]} : {addr_i[1], addr_i[2], addr_i[0], addr_i[6:3]})));
	wire [127:0] en_v;
	genvar _gv_c_1;
	generate
		for (_gv_c_1 = 0; _gv_c_1 < PAGE_TABLE_SIZE; _gv_c_1 = _gv_c_1 + 1) begin : pgentry
			localparam c = _gv_c_1;
			reg [14:0] r = 0;
			wire prot = (((spvmd | (osmd & ~mem_write)) | ((osmd & mem_write) & r[14])) | ((~r[14] & r[13]) & ~mem_write)) | (~r[14] & ~r[13]);
			wire en = (r[12:3] == addr_i[24:15]) & prot;
			wire sel = ppn[6:0] == c[6:0];
			wire [25:0] addr = {4'b0000, c[6:0], addr_i[14:0]};
			assign en_v[c] = en;
			always @(posedge clkcpu)
				if (wr & sel) begin
					r <= {addr_i[9:8], addr_i[11:10], addr_i[22:12]};
					$display("writing to table entry %d := %x (%x)", c, {addr_i[9:8], addr_i[11:10], addr_i[22:12]}, addr_i);
				end
		end
	endgenerate
	function [2:0] lowest8;
		input [7:0] v;
		integer k;
		begin
			lowest8 = 3'd0;
			for (k = 7; k >= 0; k = k - 1)
				if (v[k])
					lowest8 = k[2:0];
		end
	endfunction
	function [3:0] lowest16;
		input [15:0] v;
		integer k;
		begin
			lowest16 = 4'd0;
			for (k = 15; k >= 0; k = k - 1)
				if (v[k])
					lowest16 = k[3:0];
		end
	endfunction
	wire [15:0] g_any;
	wire [2:0] g_idx [0:15];
	genvar _gv_g_2;
	generate
		for (_gv_g_2 = 0; _gv_g_2 < 16; _gv_g_2 = _gv_g_2 + 1) begin : grp
			localparam g = _gv_g_2;
			assign g_any[g] = |en_v[g * 8+:8];
			assign g_idx[g] = lowest8(en_v[g * 8+:8]);
		end
	endgenerate
	wire [3:0] gi = lowest16(g_any);
	assign valid = |g_any;
	assign addr_o = (valid ? {4'b0000, gi, g_idx[gi], addr_i[14:0]} : 26'd0);
endmodule
