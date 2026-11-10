module fdc1772_dpram (
	clock,
	address_a,
	data_a,
	wren_a,
	q_a,
	address_b,
	data_b,
	wren_b,
	q_b
);
	parameter ADDRWIDTH = 9;
	input clock;
	input [ADDRWIDTH - 2:0] address_a;
	input [15:0] data_a;
	input wren_a;
	output reg [15:0] q_a;
	input [ADDRWIDTH - 1:0] address_b;
	input [7:0] data_b;
	input wren_b;
	output reg [7:0] q_b;
	reg [7:0] ram_lo [0:(1 << (ADDRWIDTH - 1)) - 1];
	reg [7:0] ram_hi [0:(1 << (ADDRWIDTH - 1)) - 1];
	reg [7:0] qa_lo;
	reg [7:0] qa_hi;
	reg [7:0] qb_lo;
	reg [7:0] qb_hi;
	reg qb_sel;
	always @(*) q_a = {qa_hi, qa_lo};
	always @(*) q_b = (qb_sel ? qb_hi : qb_lo);
	always @(posedge clock) begin
		if (wren_a)
			ram_lo[address_a] <= data_a[7:0];
		qa_lo <= (wren_a ? data_a[7:0] : ram_lo[address_a]);
	end
	always @(posedge clock) begin
		if (wren_a)
			ram_hi[address_a] <= data_a[15:8];
		qa_hi <= (wren_a ? data_a[15:8] : ram_hi[address_a]);
	end
	always @(posedge clock) begin
		if (wren_b & ~address_b[0])
			ram_lo[address_b[ADDRWIDTH - 1:1]] <= data_b;
		qb_lo <= (wren_b & ~address_b[0] ? data_b : ram_lo[address_b[ADDRWIDTH - 1:1]]);
	end
	always @(posedge clock) begin
		if (wren_b & address_b[0])
			ram_hi[address_b[ADDRWIDTH - 1:1]] <= data_b;
		qb_hi <= (wren_b & address_b[0] ? data_b : ram_hi[address_b[ADDRWIDTH - 1:1]]);
		qb_sel <= address_b[0];
	end
endmodule
