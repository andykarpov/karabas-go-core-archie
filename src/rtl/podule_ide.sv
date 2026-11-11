//
// ide.sv
//
// Copyright (c) 2019 György Szombathelyi
//
// This source file is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

// altera message_off 10030
module podule_ide (
	input         clk, // system clock.
	input         reset,

	input         cpu_sel,
	input         cpu_we,
	input  [13:2] cpu_adr,
	input  [15:0] cpu_dat_i,
	output [15:0] cpu_dat_o,

	// karabas: the IDE bus of the podule goes out to hdf_ata of karabas-go-modules (an ATA disk on an
	// image of the mcu, in the board top); the ide of MiSTer needs the HPS to run the ATA commands.
	// A register access lasts the whole CPU cycle: hdf_ata answers a clock after the address and
	// takes the end of the strobe (as the ide of MiSTer did, the read data a clock after io_read)
	output  [2:0] ide_a,
	output        ide_cs,
	output        ide_rd,
	output        ide_wr,
	output [15:0] ide_wdata,
	input  [15:0] ide_rdata
);

// RISC Developments IDE Interface in Podule 0
reg [7:0] rd_rom[16384];
// karabas: XST misreads the srecord file (a comment, "@addr" lines of 23 bytes: "constant value is
// truncated", half the ROM lost, the podule seen as "Simple podule &5", no IDEFS): the same bytes one
// per line (rtl/karabas/riscdevide_rom.hex, from rtl/riscdevide_rom.hex)
initial $readmemh("rtl/karabas/riscdevide_rom.hex", rd_rom);

wire reg_sel  = cpu_sel && cpu_adr[13:10] == 4'hA;
wire page_sel = cpu_sel && cpu_adr[13:02] == 12'h800 && cpu_we ;

reg [2:0] rd_page;
always @(posedge clk) begin 
	if (reset)         rd_page <= 0;
	else if (page_sel) rd_page <= cpu_dat_i[2:0];
end

reg [7:0] rd_rom_q;
always @(posedge clk) rd_rom_q <= rd_rom[{rd_page, cpu_adr[12:2]}];

wire [2:0]  ide_reg = cpu_adr[4:2];
wire [15:0] data_out = ide_rdata;

assign cpu_dat_o = ~reg_sel ? {8'd0, rd_rom_q} : ((!ide_reg) ? data_out : { data_out[7:0], data_out[7:0] });

assign ide_a     = ide_reg;
assign ide_cs    = reg_sel;
assign ide_rd    = ~cpu_we & reg_sel;
assign ide_wr    = cpu_we & reg_sel;
assign ide_wdata = cpu_dat_i;

endmodule
