`timescale 1ns / 1ps
/*
 sram_model.v: the SRAM of the boards for verilator (two 2M x 8 chips = 2M x 16, asynchronous), cycle
 based on clk (the clock of the controller): MD is the word at MA while the /OE of a lane is low and
 its /WE high (combinational: the controller takes it on the next edge, as the 10 ns chips); a lane is
 written on each clock its /WE is low. errors: /WE low while MA or the driven data changed in that
 clock (the controller must hold them a clock around /WE), or both sides driving MD.
*/
module sram_model (
	input wire clk,
	input wire [20:0] ma,
	inout wire [15:0] md,
	input wire [1:0] mwr_n,
	input wire [1:0] mrd_n,
	input wire md_driven        // the controller drives MD (for the contention check)
);

reg [7:0] lo [0:2097151];
reg [7:0] hi [0:2097151];
integer errors = 0;

wire oe_lo = !mrd_n[0] && mwr_n[0];
wire oe_hi = !mrd_n[1] && mwr_n[1];
assign md[7:0] = oe_lo ? lo[ma] : 8'bz;
assign md[15:8] = oe_hi ? hi[ma] : 8'bz;

reg [20:0] ma_d = 21'd0;
reg [1:0] mwr_d = 2'b11;
always @(posedge clk) begin
	ma_d <= ma;
	mwr_d <= mwr_n;
	if (!mwr_n[0]) lo[ma] <= md[7:0];
	if (!mwr_n[1]) hi[ma] <= md[15:8];
	if ((mwr_n != 2'b11 || mwr_d != 2'b11) && ma != ma_d) errors = errors + 1;
	if (md_driven && (oe_lo || oe_hi)) errors = errors + 1;
end

endmodule
