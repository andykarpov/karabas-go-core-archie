`timescale 1ns / 1ps
/*
 archie_cmos.v

 The CMOS RAM of the Archimedes on the I2C bus of the IOC: EEPROM_24C0x of Archie_MiSTer (as a 24C02,
 256 bytes) with its memory, filled at start from cmos.hex (cmos.mif of Archie_MiSTer: the RISC OS 3.11
 defaults). The enable of the EEPROM is clk / 4, as in Archie.sv.
 Ф1: no load / save and no clock yet (Ф3: .eep through kg_mcu, the PCF8583 time from the board RTC).
*/

module archie_cmos (
	input wire clk,
	input wire reset,
	input wire scl,       // I2C_CLOCK of archimedes_top
	input wire sda_in,    // I2C_DOUT
	output wire sda_out,  // I2C_DIN
	output reg [7:0] changes = 8'd0  // writes to bytes 16..255 (the cmos_cnt of Archie.sv)
);

reg [1:0] cnt = 2'd0;
reg ce = 1'b0;
always @(posedge clk) begin
	cnt <= cnt + 2'd1;
	ce <= cnt == 2'd0;
end

wire [7:0] ram_addr, data_to_ram;
wire ram_read, ram_write;
reg [7:0] data_from_ram = 8'd0;

reg [7:0] mem [0:255];
initial $readmemh("rtl/karabas/cmos.hex", mem);

always @(posedge clk) begin
	if (ram_write) mem[ram_addr] <= data_to_ram;
	data_from_ram <= mem[ram_addr];
	if (ce && ram_write && ram_addr >= 8'd16) changes <= changes + 8'd1;
end

EEPROM_24C0x eeprom (
	.type_24C01(1'b0),
	.clk(clk),
	.ce(ce),
	.reset(reset),
	.SCL(scl),
	.SDA_in(sda_in),
	.SDA_out(sda_out),
	.E_id(3'd0),
	.WC_n(1'b0),
	.data_from_ram(data_from_ram),
	.data_to_ram(data_to_ram),
	.ram_addr(ram_addr),
	.ram_read(ram_read),
	.ram_write(ram_write),
	.ram_done(1'b1)
);

endmodule
