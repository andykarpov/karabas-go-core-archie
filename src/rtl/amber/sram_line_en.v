// karabas: inferred block RAM instead of the altsyncram of Archie_MiSTer, with the behaviour of the
// generic model of mist-devel/archimedes bench/support/sram_line_en.v (the Amber original): the read
// word one clock after the address (the cache gives i_address_nxt), zeros while writing.
// The altsyncram has outdata_reg_a = CLOCK0; the latency is checked in the Ф1 simulation.

module sram_line_en
#(
parameter DATA_WIDTH            = 128,
parameter ADDRESS_WIDTH         = 7,
parameter INITIALIZE_TO_ZERO    = 0
)
(
input                           i_clk,
input      [ADDRESS_WIDTH-1:0]  i_address,
input      [DATA_WIDTH-1:0]     i_write_data,
input                           i_write_enable,
output reg [DATA_WIDTH-1:0]     o_read_data
);

reg [DATA_WIDTH-1:0] mem [0:2**ADDRESS_WIDTH-1];

integer i;
initial begin
	for (i = 0; i < 2**ADDRESS_WIDTH; i = i + 1)
		mem[i] = {DATA_WIDTH{1'b0}};
	o_read_data = {DATA_WIDTH{1'b0}};
end

always @(posedge i_clk) begin
	o_read_data <= i_write_enable ? {DATA_WIDTH{1'd0}} : mem[i_address];
	if (i_write_enable)
		mem[i_address] <= i_write_data;
end

endmodule
