`timescale 1ns / 1ps
/*
 rtc_model.v: the RTC registers of kg_mcu (kg_mcu_rtc) for the sim: 256 bytes read a clock after the
 address, written by rtc_cs with rtc_wr_n low. At start: the CMOS defaults (rtl/karabas/cmos.hex, as
 the eeprom_init of the core file gives the mcu), over them the time of MC146818A in BCD:
 2026-11-10 12:34:56, Tuesday (register 6 = 3). writes counts the writes of the core.
*/
module rtc_model (
	input wire clk,
	input wire [7:0] rtc_a,
	input wire [7:0] rtc_di,
	output reg [7:0] rtc_do = 8'd0,
	input wire rtc_cs,
	input wire rtc_wr_n
);

reg [7:0] mem [0:255];
integer writes = 0;
initial begin
	$readmemh("rtl/karabas/cmos.hex", mem);
	mem[0] = 8'h56; mem[2] = 8'h34; mem[4] = 8'h12; mem[6] = 8'h03;
	mem[7] = 8'h10; mem[8] = 8'h11; mem[9] = 8'h26;
	mem[10] = 8'h26; mem[11] = 8'h02; mem[12] = 8'h00; mem[13] = 8'h80;
end

always @(posedge clk) begin
	if (rtc_cs && !rtc_wr_n) begin
		mem[rtc_a] <= rtc_di;
		writes = writes + 1;
	end
	rtc_do <= mem[rtc_a];
end

endmodule
