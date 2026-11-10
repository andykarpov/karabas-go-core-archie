`timescale 1ns / 1ps
/*
 archie_ce.v

 The pixel and audio clock enables of the VIDC from one fixed clock (CLK_HZ), with fractional
 accumulators: no clock of its own per VIDC mode. The video goes into a frame buffer, so a pixel
 enable that jitters by one clock does not matter; the rates (the line and frame rates) are those
 of the real VIDC. MiSTer makes the same enables (cepix_60 / ceaud in Archie.sv) next to its native
 per-family PLL clocks.

 Pixel rate = the base clock of latch C (VIDBASECLK: 0 / 3 = 24 MHz, 1 = 25.175 MHz, 2 = 36 MHz)
 times the VIDC pixel rate selection (SELPIX: 1/3, 1/2, 2/3, 1), the vratio table of Archie.sv.
 It must stay below CLK_HZ (36 MHz < 42 MHz). Mode 23 (hires_mono, 96 MHz dots) is not supported:
 its enable runs at 24 MHz, the dots between are lost.

 Audio enable: 1 MHz (base 24 / 36 MHz) or 1.048958 MHz (base 25.175 MHz), the aratio table.
*/

module archie_ce #(
	parameter integer CLK_HZ = 42000000
) (
	input wire clk,
	input wire reset,
	input wire [1:0] baseclk,   // VIDBASECLK_O of archimedes_top
	input wire [1:0] selpix,    // SELPIX_O
	output reg ce_pix = 1'b0,   // CEPIX_I and CEVID_I
	output reg ce_aud = 1'b0    // CEAUD_I
);

reg [25:0] rate;
always @(*) begin
	case ({baseclk, selpix})
	4'b0100: rate = 26'd8391667;
	4'b0101: rate = 26'd12587500;
	4'b0110: rate = 26'd16783333;
	4'b0111: rate = 26'd25175000;
	4'b1000: rate = 26'd12000000;
	4'b1001: rate = 26'd18000000;
	4'b1010: rate = 26'd24000000;
	4'b1011: rate = 26'd36000000;
	4'b0000, 4'b1100: rate = 26'd8000000;
	4'b0001, 4'b1101: rate = 26'd12000000;
	4'b0010, 4'b1110: rate = 26'd16000000;
	default: rate = 26'd24000000;
	endcase
end

wire [20:0] arate = (baseclk == 2'd1) ? 21'd1048958 : 21'd1000000;

reg [26:0] acc = 27'd0;
reg [26:0] aacc = 27'd0;
wire [26:0] acc_next = acc + rate;
wire [26:0] aacc_next = aacc + arate;

always @(posedge clk) begin
	ce_pix <= 1'b0;
	ce_aud <= 1'b0;
	if (reset) begin
		acc <= 27'd0;
		aacc <= 27'd0;
	end else begin
		if (acc_next >= CLK_HZ) begin
			acc <= acc_next - CLK_HZ;
			ce_pix <= 1'b1;
		end else
			acc <= acc_next;
		if (aacc_next >= CLK_HZ) begin
			aacc <= aacc_next - CLK_HZ;
			ce_aud <= 1'b1;
		end else
			aacc <= aacc_next;
	end
end

endmodule
