module sram_byte_en (
	i_clk,
	i_write_data,
	i_write_enable,
	i_address,
	i_byte_enable,
	o_read_data
);
	parameter DATA_WIDTH = 128;
	parameter ADDRESS_WIDTH = 7;
	input i_clk;
	input [DATA_WIDTH - 1:0] i_write_data;
	input i_write_enable;
	input [ADDRESS_WIDTH - 1:0] i_address;
	input [(DATA_WIDTH / 8) - 1:0] i_byte_enable;
	output wire [DATA_WIDTH - 1:0] o_read_data;
	genvar _gv_g_1;
	generate
		for (_gv_g_1 = 0; _gv_g_1 < (DATA_WIDTH / 8); _gv_g_1 = _gv_g_1 + 1) begin : lane
			localparam g = _gv_g_1;
			reg [7:0] mem [0:(2 ** ADDRESS_WIDTH) - 1];
			reg [7:0] q = 8'd0;
			always @(posedge i_clk) begin
				q <= (i_write_enable ? 8'd0 : mem[i_address]);
				if (i_write_enable & i_byte_enable[g])
					mem[i_address] <= i_write_data[g * 8+:8];
			end
			assign o_read_data[g * 8+:8] = q;
		end
	endgenerate
endmodule
