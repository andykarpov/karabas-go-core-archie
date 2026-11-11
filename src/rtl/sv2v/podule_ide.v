module podule_ide (
	clk,
	reset,
	cpu_sel,
	cpu_we,
	cpu_adr,
	cpu_dat_i,
	cpu_dat_o,
	ide_a,
	ide_cs,
	ide_rd,
	ide_wr,
	ide_wdata,
	ide_rdata
);
	input clk;
	input reset;
	input cpu_sel;
	input cpu_we;
	input [13:2] cpu_adr;
	input [15:0] cpu_dat_i;
	output wire [15:0] cpu_dat_o;
	output wire [2:0] ide_a;
	output wire ide_cs;
	output wire ide_rd;
	output wire ide_wr;
	output wire [15:0] ide_wdata;
	input [15:0] ide_rdata;
	reg [7:0] rd_rom [0:16383];
	initial $readmemh("rtl/riscdevide_rom.hex", rd_rom);
	wire reg_sel = cpu_sel && (cpu_adr[13:10] == 4'ha);
	wire page_sel = (cpu_sel && (cpu_adr[13:2] == 12'h800)) && cpu_we;
	reg [2:0] rd_page;
	always @(posedge clk)
		if (reset)
			rd_page <= 0;
		else if (page_sel)
			rd_page <= cpu_dat_i[2:0];
	reg [7:0] rd_rom_q;
	always @(posedge clk) rd_rom_q <= rd_rom[{rd_page, cpu_adr[12:2]}];
	wire [2:0] ide_reg = cpu_adr[4:2];
	wire [15:0] data_out = ide_rdata;
	assign cpu_dat_o = (~reg_sel ? {8'd0, rd_rom_q} : (!ide_reg ? data_out : {data_out[7:0], data_out[7:0]}));
	assign ide_a = ide_reg;
	assign ide_cs = reg_sel;
	assign ide_rd = ~cpu_we & reg_sel;
	assign ide_wr = cpu_we & reg_sel;
	assign ide_wdata = cpu_dat_i;
endmodule
