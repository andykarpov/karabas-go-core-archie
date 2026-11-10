module a23_fetch (
	i_clk,
	i_reset,
	i_address,
	i_address_valid,
	i_address_nxt,
	i_write_data,
	i_write_enable,
	o_read_data,
	i_priviledged,
	i_exclusive,
	i_byte_enable,
	i_data_access,
	i_translate,
	i_cache_enable,
	i_cache_flush,
	i_cacheable_area,
	i_system_rdy,
	o_fetch_abort,
	o_fetch_stall,
	o_wb_adr,
	o_wb_sel,
	o_wb_we,
	i_wb_dat,
	o_wb_dat,
	o_wb_cyc,
	o_wb_stb,
	o_wb_tga,
	i_wb_ack,
	i_wb_err
);
	input i_clk;
	input i_reset;
	input [31:0] i_address;
	input i_address_valid;
	input [31:0] i_address_nxt;
	input [31:0] i_write_data;
	input i_write_enable;
	output wire [31:0] o_read_data;
	input i_priviledged;
	input i_exclusive;
	input [3:0] i_byte_enable;
	input i_data_access;
	input i_translate;
	input i_cache_enable;
	input i_cache_flush;
	input [31:0] i_cacheable_area;
	input i_system_rdy;
	output wire o_fetch_abort;
	output wire o_fetch_stall;
	output wire [31:0] o_wb_adr;
	output wire [3:0] o_wb_sel;
	output wire o_wb_we;
	input [31:0] i_wb_dat;
	output wire [31:0] o_wb_dat;
	output wire o_wb_cyc;
	output wire o_wb_stb;
	output wire o_wb_tga;
	input i_wb_ack;
	input i_wb_err;
	localparam MAIN_MSB = 26;
	localparam BOOT_MSB = 13;
	localparam MAIN_BASE = 32'h00000000;
	localparam PHYS_BASE = 32'h02000000;
	localparam IO_BASE = 32'h03000000;
	localparam ROM_BASE = 32'h03400000;
	localparam ROM_TOP = 32'h04000000;
	function in_rom_mem;
		input [31:0] address;
		in_rom_mem = (address >= ROM_BASE) && (address < ROM_TOP);
	endfunction
	function in_main_mem;
		input [31:0] address;
		in_main_mem = (address >= MAIN_BASE) && (address < IO_BASE);
	endfunction
	function in_cachable_mem;
		input [31:0] address;
		in_cachable_mem = 0;
	endfunction
	wire cache_stall;
	wire wb_stall;
	wire [31:0] cache_read_data;
	wire sel_cache;
	wire sel_wb;
	wire cache_wb_req;
	wire address_cachable;
	wire wb_abort;
	assign address_cachable = in_cachable_mem(i_address) && i_cacheable_area[i_address[25:21]];
	assign sel_cache = ((address_cachable && i_address_valid) && i_cache_enable) && !i_exclusive;
	assign sel_wb = (!sel_cache && i_address_valid) && !cache_stall;
	assign o_read_data = (sel_cache ? cache_read_data : (sel_wb ? i_wb_dat : 32'hffeeddcc));
	assign o_fetch_stall = (!i_system_rdy || wb_stall) || cache_stall;
	assign o_fetch_abort = wb_abort;
	a23_cache u_cache(
		.i_clk(i_clk),
		.i_reset(i_reset),
		.i_select(sel_cache),
		.i_exclusive(i_exclusive),
		.i_write_data(i_write_data),
		.i_write_enable(i_write_enable),
		.i_address(i_address),
		.i_address_nxt(i_address_nxt),
		.i_byte_enable(i_byte_enable),
		.i_cache_enable(i_cache_enable),
		.i_cache_flush(i_cache_flush),
		.o_read_data(cache_read_data),
		.o_stall(cache_stall),
		.i_core_stall(o_fetch_stall),
		.o_wb_req(cache_wb_req),
		.i_wb_address(o_wb_adr),
		.i_wb_read_data(i_wb_dat),
		.i_wb_stall(o_wb_stb & ~i_wb_ack)
	);
	a23_wishbone u_wishbone(
		.i_clk(i_clk),
		.i_reset(i_reset),
		.i_select(sel_wb),
		.i_write_data(i_write_data),
		.i_write_enable(i_write_enable),
		.i_byte_enable(i_byte_enable),
		.i_data_access(i_data_access),
		.i_exclusive(i_exclusive),
		.i_translate(i_translate),
		.i_address(i_address),
		.o_stall(wb_stall),
		.o_abort(wb_abort),
		.i_cache_req(cache_wb_req),
		.o_wb_adr(o_wb_adr),
		.o_wb_sel(o_wb_sel),
		.o_wb_we(o_wb_we),
		.i_wb_dat(i_wb_dat),
		.o_wb_dat(o_wb_dat),
		.o_wb_cyc(o_wb_cyc),
		.o_wb_stb(o_wb_stb),
		.i_wb_ack(i_wb_ack),
		.i_wb_err(i_wb_err),
		.o_wb_tga(o_wb_tga)
	);
endmodule
