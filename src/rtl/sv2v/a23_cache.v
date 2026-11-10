module a23_cache (
	i_clk,
	i_reset,
	i_select,
	i_exclusive,
	i_write_data,
	i_write_enable,
	i_address,
	i_address_nxt,
	i_byte_enable,
	i_cache_enable,
	i_cache_flush,
	o_read_data,
	i_core_stall,
	o_stall,
	o_wb_req,
	i_wb_address,
	i_wb_read_data,
	i_wb_stall
);
	parameter CACHE_LINES = 256;
	parameter CACHE_WORDS_PER_LINE = 4;
	parameter WAYS = 4;
	function [31:0] log2;
		input [31:0] num;
		integer i;
		integer out;
		begin
			out = 32'd0;
			for (i = 0; i < 30; i = i + 1)
				if (((2 ** i) > num) && (out == 0))
					out = i - 1;
			log2 = out;
		end
	endfunction
	parameter CACHE_ADDR_WIDTH = log2(CACHE_LINES);
	parameter WORD_SEL_WIDTH = log2(CACHE_WORDS_PER_LINE);
	parameter TAG_ADDR_WIDTH = ((32 - CACHE_ADDR_WIDTH) - WORD_SEL_WIDTH) - 2;
	parameter TAG_WIDTH = TAG_ADDR_WIDTH + 1;
	parameter CACHE_LINE_WIDTH = CACHE_WORDS_PER_LINE * 32;
	parameter TAG_ADDR32_LSB = (CACHE_ADDR_WIDTH + WORD_SEL_WIDTH) + 2;
	parameter CACHE_ADDR32_MSB = (CACHE_ADDR_WIDTH + WORD_SEL_WIDTH) + 1;
	parameter CACHE_ADDR32_LSB = WORD_SEL_WIDTH + 2;
	parameter WORD_SEL_MSB = WORD_SEL_WIDTH + 1;
	parameter WORD_SEL_LSB = 2;
	input i_clk;
	input i_reset;
	input i_select;
	input i_exclusive;
	input [31:0] i_write_data;
	input i_write_enable;
	input [31:0] i_address;
	input [31:0] i_address_nxt;
	input [3:0] i_byte_enable;
	input i_cache_enable;
	input i_cache_flush;
	output wire [31:0] o_read_data;
	input i_core_stall;
	output wire o_stall;
	output wire o_wb_req;
	input [31:0] i_wb_address;
	input [31:0] i_wb_read_data;
	input i_wb_stall;
	localparam [3:0] REGOP = 4'h0;
	localparam [3:0] MULT = 4'h1;
	localparam [3:0] SWAP = 4'h2;
	localparam [3:0] TRANS = 4'h3;
	localparam [3:0] MTRANS = 4'h4;
	localparam [3:0] BRANCH = 4'h5;
	localparam [3:0] CODTRANS = 4'h6;
	localparam [3:0] COREGOP = 4'h7;
	localparam [3:0] CORTRANS = 4'h8;
	localparam [3:0] SWI = 4'h9;
	localparam [3:0] AND = 4'h0;
	localparam [3:0] EOR = 4'h1;
	localparam [3:0] SUB = 4'h2;
	localparam [3:0] RSB = 4'h3;
	localparam [3:0] ADD = 4'h4;
	localparam [3:0] ADC = 4'h5;
	localparam [3:0] SBC = 4'h6;
	localparam [3:0] RSC = 4'h7;
	localparam [3:0] TST = 4'h8;
	localparam [3:0] TEQ = 4'h9;
	localparam [3:0] CMP = 4'ha;
	localparam [3:0] CMN = 4'hb;
	localparam [3:0] ORR = 4'hc;
	localparam [3:0] MOV = 4'hd;
	localparam [3:0] BIC = 4'he;
	localparam [3:0] MVN = 4'hf;
	localparam [3:0] EQ = 4'h0;
	localparam [3:0] NE = 4'h1;
	localparam [3:0] CS = 4'h2;
	localparam [3:0] CC = 4'h3;
	localparam [3:0] MI = 4'h4;
	localparam [3:0] PL = 4'h5;
	localparam [3:0] VS = 4'h6;
	localparam [3:0] VC = 4'h7;
	localparam [3:0] HI = 4'h8;
	localparam [3:0] LS = 4'h9;
	localparam [3:0] GE = 4'ha;
	localparam [3:0] LT = 4'hb;
	localparam [3:0] GT = 4'hc;
	localparam [3:0] LE = 4'hd;
	localparam [3:0] AL = 4'he;
	localparam [3:0] NV = 4'hf;
	localparam [1:0] LSL = 2'h0;
	localparam [1:0] LSR = 2'h1;
	localparam [1:0] ASR = 2'h2;
	localparam [1:0] RRX = 2'h3;
	localparam [1:0] ROR = 2'h3;
	localparam [1:0] SVC = 2'b11;
	localparam [1:0] IRQ = 2'b10;
	localparam [1:0] FIRQ = 2'b01;
	localparam [1:0] USR = 2'b00;
	localparam [5:0] OH_USR = 0;
	localparam [5:0] OH_IRQ = 1;
	localparam [5:0] OH_FIRQ = 2;
	localparam [5:0] OH_SVC = 3;
	function [31:0] pcf;
		input [31:0] pc_reg;
		pcf = {6'd0, pc_reg[25:2], 2'd0};
	endfunction
	function [14:0] decode;
		input [3:0] reg_sel;
		case (reg_sel)
			4'h0: decode = 15'h0001;
			4'h1: decode = 15'h0002;
			4'h2: decode = 15'h0004;
			4'h3: decode = 15'h0008;
			4'h4: decode = 15'h0010;
			4'h5: decode = 15'h0020;
			4'h6: decode = 15'h0040;
			4'h7: decode = 15'h0080;
			4'h8: decode = 15'h0100;
			4'h9: decode = 15'h0200;
			4'ha: decode = 15'h0400;
			4'hb: decode = 15'h0800;
			4'hc: decode = 15'h1000;
			4'hd: decode = 15'h2000;
			4'he: decode = 15'h4000;
			default: decode = 15'h0000;
		endcase
	endfunction
	function [3:0] oh_status_bits_mode;
		input [1:0] fn_status_bits_mode;
		oh_status_bits_mode = (fn_status_bits_mode == SVC ? 1'd1 << OH_SVC : (fn_status_bits_mode == IRQ ? 1'd1 << OH_IRQ : (fn_status_bits_mode == FIRQ ? 1'd1 << OH_FIRQ : 1'd1 << OH_USR)));
	endfunction
	function [111:0] mode_name;
		input [4:0] mode;
		mode_name = (mode == USR ? "User          " : (mode == SVC ? "Supervisor    " : (mode == IRQ ? "Interrupt     " : (mode == FIRQ ? "Fast Interrupt" : "UNKNOWN       "))));
	endfunction
	function conditional_execute;
		input [3:0] condition;
		input [3:0] flags;
		conditional_execute = ((((((((((((((condition == AL) || ((condition == EQ) && flags[2])) || ((condition == NE) && !flags[2])) || ((condition == CS) && flags[1])) || ((condition == CC) && !flags[1])) || ((condition == MI) && flags[3])) || ((condition == PL) && !flags[3])) || ((condition == VS) && flags[0])) || ((condition == VC) && !flags[0])) || (((condition == HI) && flags[1]) && !flags[2])) || ((condition == LS) && (!flags[1] || flags[2]))) || ((condition == GE) && (flags[3] == flags[0]))) || ((condition == LT) && (flags[3] != flags[0]))) || (((condition == GT) && !flags[2]) && (flags[3] == flags[0]))) || ((condition == LE) && (flags[2] || (flags[3] != flags[0])));
	endfunction
	localparam C_INIT = 0;
	localparam C_CORE = 1;
	localparam C_FILL = 2;
	localparam C_INVA = 3;
	localparam C_STATES = 4;
	localparam [3:0] CS_INIT = 4'd0;
	localparam [3:0] CS_IDLE = 4'd1;
	localparam [3:0] CS_FILL1 = 4'd2;
	localparam [3:0] CS_FILL2 = 4'd3;
	localparam [3:0] CS_FILL3 = 4'd4;
	localparam [3:0] CS_FILL4 = 4'd5;
	localparam [3:0] CS_FILL_COMPLETE = 4'd6;
	localparam [3:0] CS_TURN_AROUND = 4'd7;
	localparam [3:0] CS_WRITE_HIT1 = 4'd8;
	localparam [3:0] CS_EX_DELETE = 4'd9;
	reg [3:0] c_state = CS_IDLE;
	reg [3:0] source_sel = 1'd1 << C_CORE;
	reg [CACHE_ADDR_WIDTH:0] init_count = 'd0;
	wire [TAG_WIDTH - 1:0] tag_rdata_way [WAYS - 1:0];
	wire [CACHE_LINE_WIDTH - 1:0] data_rdata_way [WAYS - 1:0];
	wire [WAYS - 1:0] data_wenable_way;
	wire [WAYS - 1:0] data_hit_way;
	wire [WAYS - 1:0] tag_wenable_way;
	reg [WAYS - 1:0] select_way = 'd0;
	wire [WAYS - 1:0] next_way;
	reg [WAYS - 1:0] valid_bits_r = 'd0;
	reg [3:0] random_num = 4'hf;
	wire [CACHE_ADDR_WIDTH - 1:0] tag_address;
	wire [TAG_WIDTH - 1:0] tag_wdata;
	wire tag_wenable;
	wire [CACHE_LINE_WIDTH - 1:0] read_miss_wdata;
	wire [CACHE_LINE_WIDTH - 1:0] write_hit_wdata;
	wire [CACHE_LINE_WIDTH - 1:0] data_wdata;
	wire [CACHE_ADDR_WIDTH - 1:0] data_address;
	wire [31:0] write_data_word;
	wire hit;
	wire read_miss;
	wire write_miss;
	wire write_hit;
	reg [31:0] miss_address = 'd0;
	wire [CACHE_LINE_WIDTH - 1:0] hit_rdata;
	wire write_stall;
	wire cache_busy_stall;
	wire read_stall;
	wire enable;
	wire [CACHE_ADDR_WIDTH - 1:0] address;
	reg [CACHE_LINE_WIDTH - 1:0] wb_rdata_burst = 'd0;
	reg wb_read_buf_valid = 'd0;
	reg [31:0] wb_read_buf_address = 'd0;
	reg [31:0] wb_read_buf_data = 'd0;
	wire wb_read_buf_hit;
	wire exclusive_access;
	wire ex_read_hit;
	reg ex_read_hit_r = 'd0;
	reg [WAYS - 1:0] ex_read_hit_way = 'd0;
	reg [CACHE_ADDR_WIDTH - 1:0] ex_read_address;
	wire ex_read_hit_clear;
	wire ex_read_cache_busy;
	genvar _gv_i_2;
	assign address = (i_core_stall ? i_address[CACHE_ADDR32_MSB:CACHE_ADDR32_LSB] : i_address_nxt[CACHE_ADDR32_MSB:CACHE_ADDR32_LSB]);
	assign o_read_data = (wb_read_buf_hit ? wb_read_buf_data : (i_address[WORD_SEL_MSB:WORD_SEL_LSB] == 2'd0 ? hit_rdata[31:0] : (i_address[WORD_SEL_MSB:WORD_SEL_LSB] == 2'd1 ? hit_rdata[63:32] : (i_address[WORD_SEL_MSB:WORD_SEL_LSB] == 2'd2 ? hit_rdata[95:64] : hit_rdata[127:96]))));
	assign o_stall = ((read_stall || write_stall) || cache_busy_stall) || ex_read_cache_busy;
	assign o_wb_req = ((read_miss || write_miss) && (c_state == CS_IDLE)) || (c_state == CS_WRITE_HIT1);
	always @(posedge i_clk)
		if (i_reset || i_cache_flush) begin
			c_state <= CS_INIT;
			source_sel <= 1'd1 << C_INIT;
			init_count <= 'd0;
		end
		else
			case (c_state)
				CS_INIT:
					if (init_count < CACHE_LINES[CACHE_ADDR_WIDTH:0]) begin
						init_count <= init_count + 1'd1;
						source_sel <= 1'd1 << C_INIT;
					end
					else begin
						source_sel <= 1'd1 << C_CORE;
						c_state <= CS_TURN_AROUND;
					end
				CS_IDLE: begin
					source_sel <= 1'd1 << C_CORE;
					if (ex_read_hit || ex_read_hit_r) begin
						select_way <= data_hit_way | ex_read_hit_way;
						c_state <= CS_EX_DELETE;
						source_sel <= 1'd1 << C_INVA;
					end
					else if (read_miss) begin
						if (!i_wb_stall)
							c_state <= CS_FILL1;
					end
					else if (write_hit)
						c_state <= CS_WRITE_HIT1;
				end
				CS_FILL1:
					if (!i_wb_stall)
						c_state <= CS_FILL2;
				CS_FILL2:
					if (!i_wb_stall)
						c_state <= CS_FILL3;
				CS_FILL3:
					if (!i_wb_stall)
						c_state <= CS_FILL4;
				CS_FILL4:
					if (!i_wb_stall) begin
						c_state <= CS_FILL_COMPLETE;
						source_sel <= 1'd1 << C_FILL;
						select_way <= next_way;
						random_num <= {random_num[2], random_num[1], random_num[0], random_num[3] ^ random_num[2]};
					end
				CS_FILL_COMPLETE:
					if (!i_wb_stall) begin
						source_sel <= 1'd1 << C_CORE;
						c_state <= CS_TURN_AROUND;
					end
				CS_TURN_AROUND: c_state <= CS_IDLE;
				CS_EX_DELETE: begin
					c_state <= CS_TURN_AROUND;
					source_sel <= 1'd1 << C_CORE;
				end
				CS_WRITE_HIT1:
					if (!i_wb_stall)
						c_state <= CS_IDLE;
			endcase
	always @(posedge i_clk)
		if (!i_wb_stall)
			wb_rdata_burst <= {i_wb_read_data, wb_rdata_burst[127:32]};
	always @(posedge i_clk)
		if ((((c_state == CS_FILL1) || (c_state == CS_FILL2)) || (c_state == CS_FILL3)) || (c_state == CS_FILL4)) begin
			if (!i_wb_stall) begin
				wb_read_buf_valid <= 1'd1;
				wb_read_buf_address <= i_wb_address;
				wb_read_buf_data <= i_wb_read_data;
			end
		end
		else
			wb_read_buf_valid <= 1'd0;
	always @(posedge i_clk)
		if (o_wb_req)
			miss_address <= i_address;
	assign ex_read_hit_clear = c_state == CS_EX_DELETE;
	always @(posedge i_clk)
		if (ex_read_hit_clear) begin
			ex_read_hit_r <= 1'd0;
			ex_read_hit_way <= 'd0;
		end
		else if (ex_read_hit) begin
			ex_read_hit_r <= 1'd1;
			ex_read_hit_way <= data_hit_way;
		end
		else if ((c_state == CS_FILL_COMPLETE) && ex_read_hit_r)
			ex_read_hit_way <= select_way;
	always @(posedge i_clk)
		if (ex_read_hit)
			ex_read_address <= i_address[CACHE_ADDR32_MSB:CACHE_ADDR32_LSB];
	assign tag_address = (source_sel[C_FILL] ? miss_address[CACHE_ADDR32_MSB:CACHE_ADDR32_LSB] : (source_sel[C_INVA] ? ex_read_address : (source_sel[C_INIT] ? init_count[CACHE_ADDR_WIDTH - 1:0] : (source_sel[C_CORE] ? address : {CACHE_ADDR_WIDTH {1'd0}}))));
	assign data_address = (write_hit ? i_address[CACHE_ADDR32_MSB:CACHE_ADDR32_LSB] : (source_sel[C_FILL] ? miss_address[CACHE_ADDR32_MSB:CACHE_ADDR32_LSB] : (source_sel[C_CORE] ? address : {CACHE_ADDR_WIDTH {1'd0}})));
	assign tag_wdata = (source_sel[C_FILL] ? {1'd1, miss_address[31:TAG_ADDR32_LSB]} : {TAG_WIDTH {1'd0}});
	assign data_wdata = (write_hit && (c_state == CS_IDLE) ? write_hit_wdata : read_miss_wdata);
	assign read_miss_wdata = (miss_address[3:2] == 2'd0 ? wb_rdata_burst : (miss_address[3:2] == 2'd1 ? {wb_rdata_burst[95:0], wb_rdata_burst[127:96]} : (miss_address[3:2] == 2'd2 ? {wb_rdata_burst[63:0], wb_rdata_burst[127:64]} : {wb_rdata_burst[31:0], wb_rdata_burst[127:32]})));
	assign write_hit_wdata = (i_address[3:2] == 2'd0 ? {hit_rdata[127:32], write_data_word} : (i_address[3:2] == 2'd1 ? {hit_rdata[127:64], write_data_word, hit_rdata[31:0]} : (i_address[3:2] == 2'd2 ? {hit_rdata[127:96], write_data_word, hit_rdata[63:0]} : {write_data_word, hit_rdata[95:0]})));
	assign write_data_word = (i_byte_enable == 4'b0001 ? {o_read_data[31:8], i_write_data[7:0]} : (i_byte_enable == 4'b0010 ? {o_read_data[31:16], i_write_data[15:8], o_read_data[7:0]} : (i_byte_enable == 4'b0100 ? {o_read_data[31:24], i_write_data[23:16], o_read_data[15:0]} : (i_byte_enable == 4'b1000 ? {i_write_data[31:24], o_read_data[23:0]} : (i_byte_enable == 4'b0011 ? {o_read_data[31:16], i_write_data[15:0]} : (i_byte_enable == 4'b1100 ? {i_write_data[31:16], o_read_data[15:0]} : i_write_data))))));
	assign tag_wenable = (source_sel[C_INVA] ? 1'd1 : (source_sel[C_FILL] ? 1'd1 : (source_sel[C_INIT] ? 1'd1 : (source_sel[C_CORE] ? 1'd0 : 1'd0))));
	assign enable = i_select && i_cache_enable;
	assign exclusive_access = i_exclusive && i_cache_enable;
	assign wb_read_buf_hit = (enable && (wb_read_buf_address == i_address)) && wb_read_buf_valid;
	assign hit = |data_hit_way;
	assign write_hit = (enable && i_write_enable) && hit;
	assign write_miss = ((enable && i_write_enable) && !hit) && (c_state != CS_WRITE_HIT1);
	assign read_miss = (enable && !i_write_enable) && !(hit || wb_read_buf_hit);
	assign ex_read_hit = (exclusive_access && !i_write_enable) && (hit || wb_read_buf_hit);
	assign ex_read_cache_busy = (exclusive_access && !i_write_enable) && (c_state != CS_IDLE);
	assign write_stall = ((write_hit && (c_state != CS_WRITE_HIT1)) || (write_miss && (c_state != CS_IDLE))) || i_wb_stall;
	assign read_stall = read_miss;
	assign cache_busy_stall = (((c_state == CS_TURN_AROUND) || (c_state == CS_FILL1)) && enable) || (c_state == CS_INIT);
	generate
		for (_gv_i_2 = 0; _gv_i_2 < WAYS; _gv_i_2 = _gv_i_2 + 1) begin : rams
			localparam i = _gv_i_2;
			sram_line_en #(
				.DATA_WIDTH(TAG_WIDTH),
				.INITIALIZE_TO_ZERO(1),
				.ADDRESS_WIDTH(CACHE_ADDR_WIDTH)
			) u_tag(
				.i_clk(i_clk),
				.i_write_data(tag_wdata),
				.i_write_enable(tag_wenable_way[i]),
				.i_address(tag_address),
				.o_read_data(tag_rdata_way[i])
			);
			sram_line_en #(
				.DATA_WIDTH(CACHE_LINE_WIDTH),
				.ADDRESS_WIDTH(CACHE_ADDR_WIDTH)
			) u_data(
				.i_clk(i_clk),
				.i_write_data(data_wdata),
				.i_write_enable(data_wenable_way[i]),
				.i_address(data_address),
				.o_read_data(data_rdata_way[i])
			);
			assign tag_wenable_way[i] = tag_wenable && (select_way[i] || source_sel[C_INIT]);
			assign data_wenable_way[i] = (source_sel[C_FILL] && select_way[i]) || ((write_hit && data_hit_way[i]) && (c_state == CS_IDLE));
			assign data_hit_way[i] = (tag_rdata_way[i][TAG_WIDTH - 1] && (tag_rdata_way[i][TAG_ADDR_WIDTH - 1:0] == i_address[31:TAG_ADDR32_LSB])) && (c_state == CS_IDLE);
		end
		if (WAYS == 2) begin : valid_bits_2ways
			always @(posedge i_clk)
				if (c_state == CS_IDLE)
					valid_bits_r <= {tag_rdata_way[1][TAG_WIDTH - 1], tag_rdata_way[0][TAG_WIDTH - 1]};
		end
		else if (WAYS == 3) begin : valid_bits_3ways
			always @(posedge i_clk)
				if (c_state == CS_IDLE)
					valid_bits_r <= {tag_rdata_way[2][TAG_WIDTH - 1], tag_rdata_way[1][TAG_WIDTH - 1], tag_rdata_way[0][TAG_WIDTH - 1]};
		end
		else if (WAYS == 4) begin : valid_bits_4ways
			always @(posedge i_clk)
				if (c_state == CS_IDLE)
					valid_bits_r <= {tag_rdata_way[3][TAG_WIDTH - 1], tag_rdata_way[2][TAG_WIDTH - 1], tag_rdata_way[1][TAG_WIDTH - 1], tag_rdata_way[0][TAG_WIDTH - 1]};
		end
		else begin : valid_bits_8ways
			always @(posedge i_clk)
				if (c_state == CS_IDLE)
					valid_bits_r <= {tag_rdata_way[7][TAG_WIDTH - 1], tag_rdata_way[6][TAG_WIDTH - 1], tag_rdata_way[5][TAG_WIDTH - 1], tag_rdata_way[4][TAG_WIDTH - 1], tag_rdata_way[3][TAG_WIDTH - 1], tag_rdata_way[2][TAG_WIDTH - 1], tag_rdata_way[1][TAG_WIDTH - 1], tag_rdata_way[0][TAG_WIDTH - 1]};
		end
		if (WAYS == 2) begin : read_data_2ways
			assign hit_rdata = (data_hit_way[0] ? data_rdata_way[0] : (data_hit_way[1] ? data_rdata_way[1] : {CACHE_LINE_WIDTH {1'd1}}));
		end
		else if (WAYS == 3) begin : read_data_3ways
			assign hit_rdata = (data_hit_way[0] ? data_rdata_way[0] : (data_hit_way[1] ? data_rdata_way[1] : (data_hit_way[2] ? data_rdata_way[2] : {CACHE_LINE_WIDTH {1'd1}})));
		end
		else if (WAYS == 4) begin : read_data_4ways
			assign hit_rdata = (data_hit_way[0] ? data_rdata_way[0] : (data_hit_way[1] ? data_rdata_way[1] : (data_hit_way[2] ? data_rdata_way[2] : (data_hit_way[3] ? data_rdata_way[3] : {CACHE_LINE_WIDTH {1'd1}}))));
		end
		else begin : read_data_8ways
			assign hit_rdata = (data_hit_way[0] ? data_rdata_way[0] : (data_hit_way[1] ? data_rdata_way[1] : (data_hit_way[2] ? data_rdata_way[2] : (data_hit_way[3] ? data_rdata_way[3] : (data_hit_way[4] ? data_rdata_way[4] : (data_hit_way[5] ? data_rdata_way[5] : (data_hit_way[6] ? data_rdata_way[6] : (data_hit_way[7] ? data_rdata_way[7] : {CACHE_LINE_WIDTH {1'd1}}))))))));
		end
		if (WAYS == 2) begin : pick_way_2ways
			function [WAYS - 1:0] pick_way;
				input [WAYS - 1:0] valid_bits;
				input [3:0] random_num;
				if (valid_bits[0] == 1'd0)
					pick_way = 2'b01;
				else if (valid_bits[1] == 1'd0)
					pick_way = 2'b10;
				else
					case (random_num[3:1])
						3'd0, 3'd3, 3'd5, 3'd6: pick_way = 2'b10;
						default: pick_way = 2'b01;
					endcase
			endfunction
			assign next_way = pick_way(valid_bits_r, random_num);
		end
		else if (WAYS == 3) begin : pick_way_3ways
			function [WAYS - 1:0] pick_way;
				input [WAYS - 1:0] valid_bits;
				input [3:0] random_num;
				if (valid_bits[0] == 1'd0)
					pick_way = 3'b001;
				else if (valid_bits[1] == 1'd0)
					pick_way = 3'b010;
				else if (valid_bits[2] == 1'd0)
					pick_way = 3'b100;
				else
					case (random_num[3:1])
						3'd0, 3'd1, 3'd2: pick_way = 3'b010;
						3'd2, 3'd3, 3'd4: pick_way = 3'b100;
						default: pick_way = 3'b001;
					endcase
			endfunction
			assign next_way = pick_way(valid_bits_r, random_num);
		end
		else if (WAYS == 4) begin : pick_way_4ways
			function [WAYS - 1:0] pick_way;
				input [WAYS - 1:0] valid_bits;
				input [3:0] random_num;
				if (valid_bits[0] == 1'd0)
					pick_way = 4'b0001;
				else if (valid_bits[1] == 1'd0)
					pick_way = 4'b0010;
				else if (valid_bits[2] == 1'd0)
					pick_way = 4'b0100;
				else if (valid_bits[3] == 1'd0)
					pick_way = 4'b1000;
				else
					case (random_num[3:1])
						3'd0, 3'd1: pick_way = 4'b0100;
						3'd2, 3'd3: pick_way = 4'b1000;
						3'd4, 3'd5: pick_way = 4'b0001;
						default: pick_way = 4'b0010;
					endcase
			endfunction
			assign next_way = pick_way(valid_bits_r, random_num);
		end
		else begin : pick_way_8ways
			function [WAYS - 1:0] pick_way;
				input [WAYS - 1:0] valid_bits;
				input [3:0] random_num;
				if (valid_bits[0] == 1'd0)
					pick_way = 8'b00000001;
				else if (valid_bits[1] == 1'd0)
					pick_way = 8'b00000010;
				else if (valid_bits[2] == 1'd0)
					pick_way = 8'b00000100;
				else if (valid_bits[3] == 1'd0)
					pick_way = 8'b00001000;
				else if (valid_bits[4] == 1'd0)
					pick_way = 8'b00010000;
				else if (valid_bits[5] == 1'd0)
					pick_way = 8'b00100000;
				else if (valid_bits[6] == 1'd0)
					pick_way = 8'b01000000;
				else if (valid_bits[7] == 1'd0)
					pick_way = 8'b10000000;
				else
					case (random_num[3:1])
						3'd0: pick_way = 8'b00010000;
						3'd1: pick_way = 8'b00100000;
						3'd2: pick_way = 8'b01000000;
						3'd3: pick_way = 8'b10000000;
						3'd4: pick_way = 8'b00000001;
						3'd5: pick_way = 8'b00000010;
						3'd6: pick_way = 8'b00000100;
						default: pick_way = 8'b00001000;
					endcase
			endfunction
			assign next_way = pick_way(valid_bits_r, random_num);
		end
	endgenerate
	wire [47:0] xSOURCE_SEL;
	wire [159:0] xC_STATE;
	assign xSOURCE_SEL = (source_sel[C_CORE] ? "C_CORE" : (source_sel[C_INIT] ? "C_INIT" : (source_sel[C_FILL] ? "C_FILL" : (source_sel[C_INVA] ? "C_INVA" : "UNKNON"))));
	assign xC_STATE = (c_state == CS_INIT ? "CS_INIT" : (c_state == CS_IDLE ? "CS_IDLE" : (c_state == CS_FILL1 ? "CS_FILL1" : (c_state == CS_FILL2 ? "CS_FILL2" : (c_state == CS_FILL3 ? "CS_FILL3" : (c_state == CS_FILL4 ? "CS_FILL4" : (c_state == CS_FILL_COMPLETE ? "CS_FILL_COMPLETE" : (c_state == CS_EX_DELETE ? "CS_EX_DELETE" : (c_state == CS_TURN_AROUND ? "CS_TURN_AROUND" : (c_state == CS_WRITE_HIT1 ? "CS_WRITE_HIT1" : "UNKNOWN"))))))))));
	generate
		if (WAYS == 2) begin : check_hit_2ways
			always @(posedge i_clk)
				if ((data_hit_way[0] + data_hit_way[1]) > 4'd1)
					$display("Hit in more than one cache ways!");
		end
		else if (WAYS == 3) begin : check_hit_3ways
			always @(posedge i_clk)
				if (((data_hit_way[0] + data_hit_way[1]) + data_hit_way[2]) > 4'd1)
					$display("Hit in more than one cache ways!");
		end
		else if (WAYS == 4) begin : check_hit_4ways
			always @(posedge i_clk)
				if ((((data_hit_way[0] + data_hit_way[1]) + data_hit_way[2]) + data_hit_way[3]) > 4'd1)
					$display("Hit in more than one cache ways!");
		end
		else if (WAYS == 8) begin : check_hit_8ways
			always @(posedge i_clk)
				if ((((((((data_hit_way[0] + data_hit_way[1]) + data_hit_way[2]) + data_hit_way[3]) + data_hit_way[4]) + data_hit_way[5]) + data_hit_way[6]) + data_hit_way[7]) > 4'd1)
					$display("Hit in more than one cache ways!");
		end
		else begin : check_hit_nways
			initial begin
				$display("Unsupported number of ways %0d", WAYS);
				$display("Set A23_CACHE_WAYS in a23_config_defines.v to either 2,3,4 or 8");
			end
		end
	endgenerate
endmodule
