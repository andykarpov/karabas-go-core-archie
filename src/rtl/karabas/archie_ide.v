`timescale 1ns / 1ps
`default_nettype none
/*
 archie_ide.v

 The discs of the IDE podule (podule_ide: the RISC Developments interface, its IDEFS in the podule
 ROM) on hdf_ata of karabas-go-modules: ATA devices 0 / 1 on images of the mcu, sdc indices 4 / 5 of
 img_sdc (the caller passes busy / done / error / strobe of those indices only).

 - the podule bus: a register access lasts the CPU cycle (ide_cs with ide_rd or ide_wr). hdf_ata
   reads the register a clock after the address (the ide of MiSTer did the same) and does the
   access a clock after the end of its strobe, when the cycle is over: the register, chip select and
   write data are held for that clock. Two accesses have a clock between them at least, and a read
   needs 4 clocks or more (the next data word comes 3 clocks after the end of a read): an access of
   the podule is a wishbone cycle of MEMC at address 0, the reads of archie_sram answer 10 clocks
   after the request;
 - no control block (the podule maps the eight command block registers only), no interrupt (IDEFS
   polls the status);
 - the geometry: 16 heads / 63 sectors (no RDB on these images) until IDEFS sets that of its disc
   record (INITIALIZE DEVICE PARAMETERS).
*/
module archie_ide (
	input wire clk,
	input wire reset,          // power on: forgets the images
	input wire ata_reset,      // the reset of the machine

	input wire [2:0] ide_a,
	input wire ide_cs,
	input wire ide_rd,
	input wire ide_wr,
	input wire [15:0] ide_wdata,
	output wire [15:0] ide_rdata,

	input wire [1:0] img_mounted,
	input wire [63:0] img_size,
	output wire [1:0] sdc_rd,
	output wire [1:0] sdc_wr,
	output wire [31:0] sdc_sector,
	input wire sdc_busy,
	input wire sdc_done,
	input wire sdc_error,
	input wire sdc_byte_in_strobe,
	input wire [8:0] sdc_byte_addr,
	input wire [7:0] sdc_byte_in_data,
	output wire [7:0] sdc_byte_out_data,

	output wire led
);

reg [2:0] a_d = 3'd0;
reg cs_d = 1'b0;
reg [15:0] wdata_d = 16'd0;
always @(posedge clk) begin
	a_d <= ide_a;
	cs_d <= ide_cs;
	wdata_d <= ide_wdata;
end

hdf_ata #(
	.DEF_HEADS(5'd16),
	.DEF_SPT(8'd63),
	.SYNC_BUS(0)
) ata (
	.clk(clk),
	.reset(reset),
	.ata_reset(ata_reset),
	.dev0_en(1'b1),
	.dev(),
	.dev1_here(),
	.a(ide_cs ? ide_a : a_d),
	.cs_n({ 1'b1, ~(ide_cs | cs_d) }),
	.rd_n(~ide_rd),
	.wr_n(~ide_wr),
	.din(ide_cs ? ide_wdata : wdata_d),
	.dout(ide_rdata),
	.img_mounted(img_mounted),
	.img_size(img_size),
	.sdc_rd(sdc_rd),
	.sdc_wr(sdc_wr),
	.sdc_sector(sdc_sector),
	.sdc_busy(sdc_busy),
	.sdc_done(sdc_done),
	.sdc_error(sdc_error),
	.sdc_byte_in_strobe(sdc_byte_in_strobe),
	.sdc_byte_addr(sdc_byte_addr),
	.sdc_byte_in_data(sdc_byte_in_data),
	.sdc_byte_out_data(sdc_byte_out_data),
	.led(led)
);

endmodule
