module a23_wishbone (
	i_clk,
	i_reset,
	i_select,
	i_write_data,
	i_write_enable,
	i_byte_enable,
	i_data_access,
	i_exclusive,
	i_address,
	i_translate,
	o_stall,
	o_abort,
	i_cache_req,
	o_wb_adr,
	o_wb_sel,
	o_wb_we,
	i_wb_dat,
	o_wb_dat,
	o_wb_cyc,
	o_wb_stb,
	i_wb_ack,
	i_wb_err,
	o_wb_tga
);
	input i_clk;
	input i_reset;
	input i_select;
	input [31:0] i_write_data;
	input i_write_enable;
	input [3:0] i_byte_enable;
	input i_data_access;
	input i_exclusive;
	input [31:0] i_address;
	input i_translate;
	output wire o_stall;
	output wire o_abort;
	input i_cache_req;
	output reg [31:0] o_wb_adr;
	output reg [3:0] o_wb_sel;
	output reg o_wb_we;
	input [31:0] i_wb_dat;
	output reg [31:0] o_wb_dat;
	output reg o_wb_cyc;
	output reg o_wb_stb;
	input i_wb_ack;
	input i_wb_err;
	output reg o_wb_tga;
	localparam [3:0] WB_IDLE = 3'd0;
	localparam [3:0] WB_BURST1 = 3'd1;
	localparam [3:0] WB_BURST2 = 3'd2;
	localparam [3:0] WB_BURST3 = 3'd3;
	localparam [3:0] WB_WAIT_ACK = 3'd4;
	reg [2:0] wishbone_st = WB_IDLE;
	wire core_read_request;
	wire core_write_request;
	wire cache_read_request;
	wire cache_write_request;
	wire start_access;
	reg servicing_cache = 'd0;
	wire [3:0] byte_enable;
	reg exclusive_access = 'd0;
	wire read_ack;
	wire wait_write_ack;
	wire wb_wait;
	reg [31:0] wbuf_addr_r = 'd0;
	reg [3:0] wbuf_sel_r = 'd0;
	reg wbuf_busy_r = 'd0;
	assign read_ack = !o_wb_we && i_wb_ack;
	wire write_ack = o_wb_we && i_wb_ack;
	assign o_stall = (((((core_write_request && !write_ack) || (core_read_request && !read_ack)) || (core_read_request && servicing_cache)) || (core_write_request && servicing_cache)) || (cache_write_request && (wishbone_st == WB_WAIT_ACK))) || wbuf_busy_r;
	assign core_read_request = i_select && !i_write_enable;
	assign core_write_request = i_select && i_write_enable;
	assign cache_read_request = i_cache_req && !i_write_enable;
	assign cache_write_request = i_cache_req && i_write_enable;
	assign wb_wait = o_wb_stb && !i_wb_ack;
	assign start_access = ((core_read_request || core_write_request) || i_cache_req) && !wb_wait;
	assign byte_enable = (wbuf_busy_r ? wbuf_sel_r : (core_write_request || cache_write_request ? i_byte_enable : 4'hf));
	always @(posedge i_clk)
		if ((wb_wait && !wbuf_busy_r) && (core_write_request || cache_write_request)) begin
			wbuf_addr_r <= i_address;
			wbuf_sel_r <= i_byte_enable;
			wbuf_busy_r <= 1'd1;
		end
		else if (!o_wb_stb)
			wbuf_busy_r <= 1'd0;
	always @(posedge i_clk)
		if (start_access)
			o_wb_dat <= i_write_data;
	assign wait_write_ack = (o_wb_stb && o_wb_we) && !i_wb_ack;
	always @(posedge i_clk)
		if (i_reset) begin
			wishbone_st <= WB_IDLE;
			o_wb_adr <= 32'd0;
			o_wb_sel <= 4'd0;
			o_wb_we <= 1'd0;
			o_wb_cyc <= 1'd0;
			o_wb_stb <= 1'd0;
			o_wb_tga <= 1'b0;
		end
		else
			case (wishbone_st)
				WB_IDLE: begin
					if (start_access) begin
						o_wb_stb <= 1'd1;
						o_wb_cyc <= 1'd1;
						o_wb_sel <= byte_enable;
						o_wb_tga <= i_translate;
					end
					else if (!wait_write_ack) begin
						o_wb_stb <= 1'd0;
						o_wb_tga <= 1'b0;
						o_wb_cyc <= exclusive_access;
					end
					servicing_cache <= cache_read_request && !wait_write_ack;
					if (wait_write_ack)
						wishbone_st <= WB_WAIT_ACK;
					else if (cache_read_request) begin
						wishbone_st <= WB_BURST1;
						exclusive_access <= 1'd0;
					end
					else if (core_read_request) begin
						wishbone_st <= WB_WAIT_ACK;
						exclusive_access <= i_exclusive;
					end
					else if (core_write_request)
						exclusive_access <= i_exclusive;
					if (start_access) begin
						if (wbuf_busy_r) begin
							o_wb_we <= 1'd1;
							o_wb_adr[31:2] <= wbuf_addr_r[31:2];
						end
						else begin
							o_wb_we <= core_write_request || cache_write_request;
							o_wb_adr[31:2] <= i_address[31:2];
						end
						o_wb_adr[1:0] <= (byte_enable == 4'b0001 ? 2'd0 : (byte_enable == 4'b0010 ? 2'd1 : (byte_enable == 4'b0100 ? 2'd2 : (byte_enable == 4'b1000 ? 2'd3 : (byte_enable == 4'b0011 ? 2'd0 : (byte_enable == 4'b1100 ? 2'd2 : i_address[1:0]))))));
					end
				end
				WB_BURST1:
					if (i_wb_ack) begin
						o_wb_adr[3:2] <= o_wb_adr[3:2] + 1'd1;
						wishbone_st <= WB_BURST2;
					end
				WB_BURST2:
					if (i_wb_ack) begin
						o_wb_adr[3:2] <= o_wb_adr[3:2] + 1'd1;
						wishbone_st <= WB_BURST3;
					end
				WB_BURST3:
					if (i_wb_ack) begin
						o_wb_adr[3:2] <= o_wb_adr[3:2] + 1'd1;
						wishbone_st <= WB_WAIT_ACK;
					end
				WB_WAIT_ACK:
					if (i_wb_ack | i_wb_err) begin
						wishbone_st <= WB_IDLE;
						o_wb_stb <= 1'd0;
						o_wb_cyc <= exclusive_access;
						o_wb_we <= 1'd0;
						servicing_cache <= 1'd0;
					end
			endcase
	assign o_abort = i_wb_err & o_wb_cyc;
	wire [111:0] xAS_STATE;
	assign xAS_STATE = (wishbone_st == WB_IDLE ? "WB_IDLE" : (wishbone_st == WB_BURST1 ? "WB_BURST1" : (wishbone_st == WB_BURST2 ? "WB_BURST2" : (wishbone_st == WB_BURST3 ? "WB_BURST3" : (wishbone_st == WB_WAIT_ACK ? "WB_WAIT_ACK" : "UNKNOWN")))));
endmodule
