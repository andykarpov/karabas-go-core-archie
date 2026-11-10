module mode23_cursor_serializer (
	clk,
	rst,
	ce,
	enable,
	phase,
	row_valid,
	row_data,
	lookup,
	opaque
);
	input clk;
	input rst;
	input ce;
	input enable;
	input [1:0] phase;
	input row_valid;
	input [63:0] row_data;
	output wire [1:0] lookup;
	output wire opaque;
	reg [7:0] elapsed = 0;
	always @(posedge clk)
		if (rst || !enable)
			elapsed <= 0;
		else if (ce && (elapsed < 8'd131))
			elapsed <= elapsed + 1'd1;
	wire [7:0] first_dot = {6'd0, phase};
	wire [7:0] end_dot = first_dot + 8'd128;
	wire visible = ((enable && row_valid) && (elapsed >= first_dot)) && (elapsed < end_dot);
	wire [6:0] row_dot = elapsed - first_dot;
	wire [5:0] row_bit = {row_dot[6:2], 1'b0};
	wire [63:0] shifted_row = row_data >> row_bit;
	assign lookup = (visible ? shifted_row[1:0] : 2'd0);
	assign opaque = visible && (shifted_row[1:0] != 2'd0);
endmodule
