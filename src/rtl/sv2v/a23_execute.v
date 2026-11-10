module a23_execute (
	i_clk,
	i_reset,
	i_read_data,
	i_read_data_alignment,
	i_copro_read_data,
	i_data_access_exec,
	o_copro_write_data,
	o_write_data,
	o_address,
	o_adex,
	o_address_valid,
	o_address_nxt,
	o_priviledged,
	o_exclusive,
	o_write_enable,
	o_translate,
	o_byte_enable,
	o_data_access,
	o_status_bits,
	o_multiply_done,
	i_fetch_stall,
	i_fetch_abort,
	i_status_bits_mode,
	i_status_bits_irq_mask,
	i_status_bits_firq_mask,
	i_imm32,
	i_imm_shift_amount,
	i_shift_imm_zero,
	i_condition,
	i_exclusive_exec,
	i_use_carry_in,
	i_rm_sel,
	i_rds_sel,
	i_rn_sel,
	i_rm_sel_nxt,
	i_rds_sel_nxt,
	i_rn_sel_nxt,
	i_barrel_shift_amount_sel,
	i_barrel_shift_data_sel,
	i_barrel_shift_function,
	i_alu_function,
	i_multiply_function,
	i_interrupt_vector_sel,
	i_address_sel,
	i_pc_sel,
	i_writeback_sel,
	i_byte_enable_sel,
	i_status_bits_sel,
	i_reg_write_sel,
	i_user_mode_regs_load,
	i_user_mode_regs_store_nxt,
	i_firq_not_user_mode,
	i_write_data_wen,
	i_base_address_wen,
	i_pc_wen,
	i_reg_bank_wen,
	i_reg_bank_wsel,
	i_status_bits_flags_wen,
	i_status_bits_mode_wen,
	i_status_bits_irq_mask_wen,
	i_status_bits_firq_mask_wen,
	i_copro_write_data_wen
);
	input i_clk;
	input i_reset;
	input [31:0] i_read_data;
	input [4:0] i_read_data_alignment;
	input [31:0] i_copro_read_data;
	input i_data_access_exec;
	output reg [31:0] o_copro_write_data;
	output reg [31:0] o_write_data;
	output reg [31:0] o_address;
	output reg o_adex;
	output reg o_address_valid;
	output wire [31:0] o_address_nxt;
	output reg o_priviledged;
	output reg o_exclusive;
	output reg o_write_enable;
	output reg o_translate;
	output reg [3:0] o_byte_enable;
	output reg o_data_access;
	output wire [31:0] o_status_bits;
	output wire o_multiply_done;
	input i_fetch_stall;
	input i_fetch_abort;
	input [1:0] i_status_bits_mode;
	input i_status_bits_irq_mask;
	input i_status_bits_firq_mask;
	input [31:0] i_imm32;
	input [4:0] i_imm_shift_amount;
	input i_shift_imm_zero;
	input [3:0] i_condition;
	input i_exclusive_exec;
	input i_use_carry_in;
	input [3:0] i_rm_sel;
	input [3:0] i_rds_sel;
	input [3:0] i_rn_sel;
	input [3:0] i_rm_sel_nxt;
	input [3:0] i_rds_sel_nxt;
	input [3:0] i_rn_sel_nxt;
	input [1:0] i_barrel_shift_amount_sel;
	input [1:0] i_barrel_shift_data_sel;
	input [1:0] i_barrel_shift_function;
	input [8:0] i_alu_function;
	input [1:0] i_multiply_function;
	input [2:0] i_interrupt_vector_sel;
	input [3:0] i_address_sel;
	input [1:0] i_pc_sel;
	input i_writeback_sel;
	input [1:0] i_byte_enable_sel;
	input [2:0] i_status_bits_sel;
	input [2:0] i_reg_write_sel;
	input i_user_mode_regs_load;
	input i_user_mode_regs_store_nxt;
	input i_firq_not_user_mode;
	input i_write_data_wen;
	input i_base_address_wen;
	input i_pc_wen;
	input [14:0] i_reg_bank_wen;
	input [3:0] i_reg_bank_wsel;
	input i_status_bits_flags_wen;
	input i_status_bits_mode_wen;
	input i_status_bits_irq_mask_wen;
	input i_status_bits_firq_mask_wen;
	input i_copro_write_data_wen;
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
	wire [31:0] write_data_nxt;
	wire [3:0] byte_enable_nxt;
	wire [31:0] pc_plus4;
	wire [31:0] pc_minus4;
	wire [31:0] address_plus4;
	wire [31:0] alu_plus4;
	wire [31:0] rn_plus4;
	wire [31:0] alu_out;
	wire [3:0] alu_flags;
	wire [31:0] rm;
	wire [31:0] rs;
	wire [31:0] rd;
	wire [31:0] rn;
	wire [31:0] pc;
	wire [31:0] pc_nxt;
	wire write_enable_nxt;
	wire [31:0] interrupt_vector;
	wire [7:0] shift_amount;
	wire [31:0] barrel_shift_in;
	wire [31:0] barrel_shift_out;
	wire barrel_shift_carry;
	wire [3:0] status_bits_flags_nxt;
	reg [3:0] status_bits_flags = 'd0;
	wire [1:0] status_bits_mode_nxt;
	wire [1:0] status_bits_mode_nr;
	reg [1:0] status_bits_mode = SVC;
	wire [1:0] status_bits_mode_rds_nxt;
	wire [1:0] status_bits_mode_rds_nr;
	reg [1:0] status_bits_mode_rds;
	wire [3:0] status_bits_mode_rds_oh_nxt;
	reg [3:0] status_bits_mode_rds_oh = 1'd1 << OH_SVC;
	wire status_bits_mode_rds_oh_update;
	wire status_bits_irq_mask_nxt;
	reg status_bits_irq_mask = 1'd1;
	wire status_bits_firq_mask_nxt;
	reg status_bits_firq_mask = 1'd1;
	wire execute;
	wire [31:0] reg_write_nxt;
	wire pc_wen;
	wire [14:0] reg_bank_wen;
	wire [31:0] multiply_out;
	wire [1:0] multiply_flags;
	reg [31:0] base_address = 'd0;
	wire priviledged_nxt;
	wire priviledged_update;
	wire address_update;
	wire base_address_update;
	wire write_data_update;
	wire copro_write_data_update;
	wire translate_update;
	wire byte_enable_update;
	wire data_access_update;
	wire write_enable_update;
	wire exclusive_update;
	wire status_bits_flags_update;
	wire status_bits_mode_update;
	wire status_bits_irq_mask_update;
	wire status_bits_firq_mask_update;
	wire [1:0] status_bits_out;
	wire [31:0] alu_out_pc_filtered;
	wire adex_nxt;
	wire carry_in;
	assign status_bits_out = ((i_status_bits_mode_wen && (i_status_bits_sel == 3'd1)) && execute ? alu_out[1:0] : status_bits_mode);
	assign o_status_bits = {status_bits_flags, status_bits_irq_mask, status_bits_firq_mask, 24'd0, status_bits_out};
	assign status_bits_flags_nxt = (i_status_bits_sel == 3'd0 ? alu_flags : (i_status_bits_sel == 3'd1 ? alu_out[31:28] : (i_status_bits_sel == 3'd3 ? i_copro_read_data[31:28] : (i_status_bits_sel == 3'd4 ? {multiply_flags, status_bits_flags[1:0]} : (i_status_bits_sel == 3'd5 ? {alu_flags[3:1], status_bits_flags[0]} : 4'b1111)))));
	assign status_bits_mode_nxt = (i_status_bits_sel == 3'd0 ? i_status_bits_mode : (i_status_bits_sel == 3'd5 ? i_status_bits_mode : (i_status_bits_sel == 3'd1 ? alu_out[1:0] : i_copro_read_data[1:0])));
	assign status_bits_mode_rds_nxt = (i_user_mode_regs_store_nxt ? USR : (status_bits_mode_update ? status_bits_mode_nxt : status_bits_mode));
	assign status_bits_mode_rds_oh_nxt = oh_status_bits_mode(status_bits_mode_rds_nxt);
	assign status_bits_irq_mask_nxt = (i_status_bits_sel == 3'd0 ? i_status_bits_irq_mask : (i_status_bits_sel == 3'd5 ? i_status_bits_irq_mask : (i_status_bits_sel == 3'd1 ? alu_out[27] : i_copro_read_data[27])));
	assign status_bits_firq_mask_nxt = (i_status_bits_sel == 3'd0 ? i_status_bits_firq_mask : (i_status_bits_sel == 3'd5 ? i_status_bits_firq_mask : (i_status_bits_sel == 3'd1 ? alu_out[26] : i_copro_read_data[26])));
	assign pc_plus4 = pc + 32'd4;
	assign pc_minus4 = pc - 32'd4;
	assign address_plus4 = o_address + 32'd4;
	assign alu_plus4 = alu_out + 32'd4;
	assign rn_plus4 = rn + 32'd4;
	assign shift_amount = (i_barrel_shift_amount_sel == 2'd0 ? 8'd0 : (i_barrel_shift_amount_sel == 2'd1 ? rs[7:0] : (i_barrel_shift_amount_sel == 2'd2 ? {3'd0, i_imm_shift_amount} : {3'd0, i_read_data_alignment})));
	assign barrel_shift_in = (i_barrel_shift_data_sel == 2'd0 ? i_imm32 : (i_barrel_shift_data_sel == 2'd1 ? i_read_data : rm));
	assign interrupt_vector = (i_interrupt_vector_sel == 3'd0 ? 32'h00000000 : (i_interrupt_vector_sel == 3'd1 ? 32'h00000010 : (i_interrupt_vector_sel == 3'd2 ? 32'h0000001c : (i_interrupt_vector_sel == 3'd3 ? 32'h00000018 : (i_interrupt_vector_sel == 3'd5 ? 32'h0000000c : (i_interrupt_vector_sel == 3'd6 ? 32'h00000004 : (i_interrupt_vector_sel == 3'd7 ? 32'h00000008 : 32'h00000014)))))));
	assign alu_out_pc_filtered = (pc_wen && (i_pc_sel == 2'd1) ? pcf(alu_out) : alu_out);
	assign o_address_nxt = (!execute ? (i_fetch_abort ? pc : pc_plus4) : (i_address_sel == 4'd0 ? pc_plus4 : (i_address_sel == 4'd1 ? alu_out_pc_filtered : (i_address_sel == 4'd2 ? interrupt_vector : (i_address_sel == 4'd3 ? pc : (i_address_sel == 4'd4 ? rn : (i_address_sel == 4'd5 ? address_plus4 : (i_address_sel == 4'd6 ? alu_plus4 : rn_plus4))))))));
	assign adex_nxt = |o_address_nxt[31:26] && !i_data_access_exec;
	assign pc_nxt = (!execute ? (i_fetch_abort ? pc : pc_plus4) : (i_pc_sel == 2'd0 ? pc_plus4 : (i_pc_sel == 2'd1 ? alu_out : interrupt_vector)));
	wire [31:0] save_int_pc;
	wire [31:0] save_int_pc_m4;
	assign save_int_pc = {status_bits_flags, status_bits_irq_mask, status_bits_firq_mask, pc[25:2], status_bits_mode};
	assign save_int_pc_m4 = {status_bits_flags, status_bits_irq_mask, status_bits_firq_mask, pc_minus4[25:2], status_bits_mode};
	assign reg_write_nxt = (i_reg_write_sel == 3'd0 ? alu_out : (i_reg_write_sel == 3'd1 ? save_int_pc_m4 : (i_reg_write_sel == 3'd2 ? multiply_out : (i_reg_write_sel == 3'd3 ? o_status_bits : (i_reg_write_sel == 3'd5 ? i_copro_read_data : (i_reg_write_sel == 3'd6 ? base_address : save_int_pc))))));
	assign byte_enable_nxt = (i_byte_enable_sel == 2'd0 ? 4'b1111 : (i_byte_enable_sel == 2'd2 ? (o_address_nxt[1] == 1'd0 ? 4'b0011 : 4'b1100) : (o_address_nxt[1:0] == 2'd0 ? 4'b0001 : (o_address_nxt[1:0] == 2'd1 ? 4'b0010 : (o_address_nxt[1:0] == 2'd2 ? 4'b0100 : 4'b1000)))));
	assign write_data_nxt = (i_byte_enable_sel == 2'd0 ? rd : {4 {rd[7:0]}});
	assign execute = conditional_execute(i_condition, status_bits_flags);
	wire fetch_stall = i_fetch_stall & ~i_fetch_abort;
	assign pc_wen = i_pc_wen || !execute;
	assign reg_bank_wen = {{15 {execute}} & i_reg_bank_wen};
	assign priviledged_nxt = (i_status_bits_mode_wen ? status_bits_mode_nxt : status_bits_mode) != USR;
	assign write_enable_nxt = execute && i_write_data_wen;
	assign translate_update = !fetch_stall && execute;
	assign priviledged_update = !fetch_stall;
	assign data_access_update = !fetch_stall && execute;
	assign write_enable_update = !fetch_stall;
	assign write_data_update = (!fetch_stall && execute) && i_write_data_wen;
	assign exclusive_update = !fetch_stall && execute;
	assign address_update = !fetch_stall;
	assign byte_enable_update = (!fetch_stall && execute) && i_write_data_wen;
	assign copro_write_data_update = (!fetch_stall && execute) && i_copro_write_data_wen;
	assign base_address_update = (!fetch_stall && execute) && i_base_address_wen;
	assign status_bits_flags_update = (!fetch_stall && execute) && i_status_bits_flags_wen;
	assign status_bits_mode_update = (!fetch_stall && execute) && i_status_bits_mode_wen;
	assign status_bits_mode_rds_oh_update = !fetch_stall;
	assign status_bits_irq_mask_update = (!fetch_stall && execute) && i_status_bits_irq_mask_wen;
	assign status_bits_firq_mask_update = (!fetch_stall && execute) && i_status_bits_firq_mask_wen;
	assign status_bits_mode_rds_nr = (status_bits_mode_rds_oh_update ? status_bits_mode_rds_nxt : status_bits_mode_rds);
	assign status_bits_mode_nr = (status_bits_mode_update ? status_bits_mode_nxt : status_bits_mode);
	always @(posedge i_clk)
		if (i_reset) begin
			o_copro_write_data <= 32'd0;
			o_write_data <= 32'd0;
			o_address <= 32'hdeaddead;
			o_adex <= 1'd0;
			o_address_valid <= 1'd0;
			o_priviledged <= 1'd0;
			o_exclusive <= 1'd0;
			o_write_enable <= 1'd0;
			o_translate <= 1'd0;
			o_byte_enable <= 4'd0;
			o_data_access <= 1'd0;
		end
		else begin
			o_priviledged <= (priviledged_update ? priviledged_nxt : o_priviledged);
			o_exclusive <= (exclusive_update ? i_exclusive_exec : o_exclusive);
			o_data_access <= (data_access_update ? i_data_access_exec : o_data_access);
			o_write_enable <= (write_enable_update ? write_enable_nxt : o_write_enable);
			o_write_data <= (write_data_update ? write_data_nxt : o_write_data);
			o_address <= (address_update ? o_address_nxt : o_address);
			o_adex <= (address_update ? adex_nxt : o_adex);
			o_address_valid <= (address_update ? 1'd1 : o_address_valid);
			o_translate <= (translate_update ? ~i_writeback_sel & (status_bits_mode != USR) : o_translate);
			o_byte_enable <= (byte_enable_update ? byte_enable_nxt : o_byte_enable);
			o_copro_write_data <= (copro_write_data_update ? write_data_nxt : o_copro_write_data);
			base_address <= (base_address_update ? rn : base_address);
			status_bits_flags <= (status_bits_flags_update ? status_bits_flags_nxt : status_bits_flags);
			status_bits_mode <= status_bits_mode_nr;
			status_bits_mode_rds_oh <= (status_bits_mode_rds_oh_update ? status_bits_mode_rds_oh_nxt : status_bits_mode_rds_oh);
			status_bits_mode_rds <= status_bits_mode_rds_nr;
			status_bits_irq_mask <= (status_bits_irq_mask_update ? status_bits_irq_mask_nxt : status_bits_irq_mask);
			status_bits_firq_mask <= (status_bits_firq_mask_update ? status_bits_firq_mask_nxt : status_bits_firq_mask);
		end
	assign carry_in = (i_use_carry_in ? status_bits_flags[1] : 1'd0);
	a23_barrel_shift u_barrel_shift(
		.i_in(barrel_shift_in),
		.i_carry_in(carry_in),
		.i_shift_amount(shift_amount),
		.i_shift_imm_zero(i_shift_imm_zero),
		.i_function(i_barrel_shift_function),
		.o_out(barrel_shift_out),
		.o_carry_out(barrel_shift_carry)
	);
	wire barrel_shift_carry_real = (i_barrel_shift_data_sel == 2'd0 ? (i_imm_shift_amount[4:1] == 0 ? status_bits_flags[1] : i_imm32[31]) : barrel_shift_carry);
	a23_alu u_alu(
		.i_a_in(rn),
		.i_b_in(barrel_shift_out),
		.i_barrel_shift_carry(barrel_shift_carry_real),
		.i_status_bits_carry(status_bits_flags[1]),
		.i_function(i_alu_function),
		.o_out(alu_out),
		.o_flags(alu_flags)
	);
	a23_multiply u_multiply(
		.i_clk(i_clk),
		.i_fetch_stall(i_fetch_stall),
		.i_a_in(rs),
		.i_b_in(rm),
		.i_function(i_multiply_function),
		.i_execute(execute),
		.o_out(multiply_out),
		.o_flags(multiply_flags),
		.o_done(o_multiply_done)
	);
	a23_register_bank u_register_bank(
		.i_clk(i_clk),
		.i_reset(i_reset),
		.i_fetch_stall(fetch_stall),
		.i_rm_sel(i_rm_sel),
		.i_rds_sel(i_rds_sel),
		.i_rn_sel(i_rn_sel),
		.i_pc_wen(pc_wen),
		.i_reg_bank_wen(reg_bank_wen),
		.i_pc(pc_nxt[25:2]),
		.i_reg(reg_write_nxt),
		.i_mode_idec(i_status_bits_mode),
		.i_mode_exec(status_bits_mode),
		.i_status_bits_flags(status_bits_flags),
		.i_status_bits_irq_mask(status_bits_irq_mask),
		.i_status_bits_firq_mask(status_bits_firq_mask),
		.i_firq_not_user_mode(i_firq_not_user_mode),
		.i_mode_rds_exec(status_bits_mode_rds_oh),
		.i_user_mode_regs_load(i_user_mode_regs_load),
		.o_rm(rm),
		.o_rs(rs),
		.o_rd(rd),
		.o_rn(rn),
		.o_pc(pc)
	);
	wire [15:0] xCONDITION;
	wire [31:0] xMODE;
	assign xCONDITION = (i_condition == EQ ? "EQ" : (i_condition == NE ? "NE" : (i_condition == CS ? "CS" : (i_condition == CC ? "CC" : (i_condition == MI ? "MI" : (i_condition == PL ? "PL" : (i_condition == VS ? "VS" : (i_condition == VC ? "VC" : (i_condition == HI ? "HI" : (i_condition == LS ? "LS" : (i_condition == GE ? "GE" : (i_condition == LT ? "LT" : (i_condition == GT ? "GT" : (i_condition == LE ? "LE" : (i_condition == AL ? "AL" : "NV ")))))))))))))));
	assign xMODE = (status_bits_mode == SVC ? "SVC" : (status_bits_mode == IRQ ? "IRQ" : (status_bits_mode == FIRQ ? "FIRQ" : (status_bits_mode == USR ? "USR" : "XXX"))));
endmodule
