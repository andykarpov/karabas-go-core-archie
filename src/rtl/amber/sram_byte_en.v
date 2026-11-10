// karabas: inferred block RAM instead of the altsyncram of Archie_MiSTer, with the behaviour of the
// generic model of mist-devel/archimedes bench/support/sram_byte_en.v (the Amber original): the read
// word one clock after the address, zeros while writing. One memory per byte lane (a part-select
// write of one wide memory is what XST cannot map to block RAM).

module sram_byte_en
#(
parameter DATA_WIDTH    = 128,
parameter ADDRESS_WIDTH = 7
)
(
input                           i_clk,
input      [DATA_WIDTH-1:0]     i_write_data,
input                           i_write_enable,
input      [ADDRESS_WIDTH-1:0]  i_address,
input      [DATA_WIDTH/8-1:0]   i_byte_enable,
output     [DATA_WIDTH-1:0]     o_read_data
);

genvar g;
generate
for (g = 0; g < DATA_WIDTH/8; g = g + 1) begin : lane
	reg [7:0] mem [0:2**ADDRESS_WIDTH-1];
	reg [7:0] q = 8'd0;
	always @(posedge i_clk) begin
		q <= i_write_enable ? 8'd0 : mem[i_address];
		if (i_write_enable & i_byte_enable[g])
			mem[i_address] <= i_write_data[g*8 +: 8];
	end
	assign o_read_data[g*8 +: 8] = q;
end
endgenerate

endmodule
