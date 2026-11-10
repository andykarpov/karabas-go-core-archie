module podule_ide (
	clk,
	reset,
	cpu_sel,
	cpu_we,
	cpu_adr,
	cpu_dat_i,
	cpu_dat_o,
	hdd_led,
	ide_req,
	ide_address,
	ide_write,
	ide_writedata,
	ide_read,
	ide_readdata
);
	input clk;
	input reset;
	input cpu_sel;
	input cpu_we;
	input [13:2] cpu_adr;
	input [15:0] cpu_dat_i;
	output wire [15:0] cpu_dat_o;
	output wire hdd_led;
	output wire [5:0] ide_req;
	input [4:0] ide_address;
	input ide_write;
	input [15:0] ide_writedata;
	input ide_read;
	output wire [15:0] ide_readdata;
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
	wire [15:0] data_out;
	assign cpu_dat_o = (~reg_sel ? {8'd0, rd_rom_q} : (!ide_reg ? data_out : {data_out[7:0], data_out[7:0]}));
	assign ide_req[5:3] = 0;
	ide ide(
		.clk(clk),
		.rst_n(~reset),
		.drq(hdd_led),
		.use_fast(0),
		.io_32(0),
		.io_address(ide_reg),
		.io_read(~cpu_we & reg_sel),
		.io_readdata(data_out),
		.io_write(cpu_we & reg_sel),
		.io_writedata(cpu_dat_i),
		.request(ide_req[2:0]),
		.mgmt_address(ide_address[3:0]),
		.mgmt_write(~ide_address[4] & ide_write),
		.mgmt_writedata(ide_writedata),
		.mgmt_read(~ide_address[4] & ide_read),
		.mgmt_readdata(ide_readdata)
	);
endmodule
