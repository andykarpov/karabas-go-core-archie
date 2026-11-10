module a23_decode (
	i_clk,
	i_reset,
	i_read_data,
	i_fetch_stall,
	i_fetch_abort,
	i_irq,
	i_firq,
	i_dabt,
	i_iabt,
	i_adex,
	i_execute_address,
	i_abt_status,
	i_execute_status_bits,
	i_multiply_done,
	o_read_data,
	o_read_data_alignment,
	o_imm32,
	o_imm_shift_amount,
	o_shift_imm_zero,
	o_condition,
	o_exclusive_exec,
	o_data_access_exec,
	o_status_bits_mode,
	o_status_bits_irq_mask,
	o_status_bits_firq_mask,
	o_rm_sel,
	o_rds_sel,
	o_rn_sel,
	o_rm_sel_nxt,
	o_rds_sel_nxt,
	o_rn_sel_nxt,
	o_barrel_shift_amount_sel,
	o_barrel_shift_data_sel,
	o_barrel_shift_function,
	o_alu_function,
	o_use_carry_in,
	o_multiply_function,
	o_interrupt_vector_sel,
	o_address_sel,
	o_pc_sel,
	o_byte_enable_sel,
	o_status_bits_sel,
	o_reg_write_sel,
	o_user_mode_regs_load,
	o_user_mode_regs_store_nxt,
	o_firq_not_user_mode,
	o_write_data_wen,
	o_base_address_wen,
	o_pc_wen,
	o_writeback_sel,
	o_reg_bank_wen,
	o_reg_bank_wsel,
	o_status_bits_flags_wen,
	o_status_bits_mode_wen,
	o_status_bits_irq_mask_wen,
	o_status_bits_firq_mask_wen,
	o_copro_opcode1,
	o_copro_opcode2,
	o_copro_crn,
	o_copro_crm,
	o_copro_num,
	o_copro_operation,
	o_copro_write_data_wen,
	o_iabt_trigger,
	o_iabt_address,
	o_iabt_status,
	o_dabt_trigger,
	o_dabt_address,
	o_dabt_status
);
	input i_clk;
	input i_reset;
	input [31:0] i_read_data;
	input i_fetch_stall;
	input i_fetch_abort;
	input i_irq;
	input i_firq;
	input i_dabt;
	input i_iabt;
	input i_adex;
	input [31:0] i_execute_address;
	input [7:0] i_abt_status;
	input [31:0] i_execute_status_bits;
	input i_multiply_done;
	output reg [31:0] o_read_data;
	output reg [4:0] o_read_data_alignment;
	output reg [31:0] o_imm32;
	output reg [4:0] o_imm_shift_amount;
	output reg o_shift_imm_zero;
	output reg [3:0] o_condition;
	output reg o_exclusive_exec;
	output reg o_data_access_exec;
	output reg [1:0] o_status_bits_mode;
	output reg o_status_bits_irq_mask;
	output reg o_status_bits_firq_mask;
	output reg [3:0] o_rm_sel;
	output reg [3:0] o_rds_sel;
	output reg [3:0] o_rn_sel;
	output wire [3:0] o_rm_sel_nxt;
	output wire [3:0] o_rds_sel_nxt;
	output wire [3:0] o_rn_sel_nxt;
	output reg [1:0] o_barrel_shift_amount_sel;
	output reg [1:0] o_barrel_shift_data_sel;
	output reg [1:0] o_barrel_shift_function;
	output reg [8:0] o_alu_function;
	output reg o_use_carry_in;
	output reg [1:0] o_multiply_function;
	output reg [2:0] o_interrupt_vector_sel;
	output reg [3:0] o_address_sel;
	output reg [1:0] o_pc_sel;
	output reg [1:0] o_byte_enable_sel;
	output reg [2:0] o_status_bits_sel;
	output reg [2:0] o_reg_write_sel;
	output reg o_user_mode_regs_load;
	output reg o_user_mode_regs_store_nxt;
	output reg o_firq_not_user_mode;
	output reg o_write_data_wen;
	output reg o_base_address_wen;
	output reg o_pc_wen;
	output reg o_writeback_sel;
	output reg [14:0] o_reg_bank_wen;
	output reg [3:0] o_reg_bank_wsel;
	output reg o_status_bits_flags_wen;
	output reg o_status_bits_mode_wen;
	output reg o_status_bits_irq_mask_wen;
	output reg o_status_bits_firq_mask_wen;
	output reg [2:0] o_copro_opcode1;
	output reg [2:0] o_copro_opcode2;
	output reg [3:0] o_copro_crn;
	output reg [3:0] o_copro_crm;
	output reg [3:0] o_copro_num;
	output reg [1:0] o_copro_operation;
	output reg o_copro_write_data_wen;
	output wire o_iabt_trigger;
	output wire [31:0] o_iabt_address;
	output wire [7:0] o_iabt_status;
	output wire o_dabt_trigger;
	output wire [31:0] o_dabt_address;
	output wire [7:0] o_dabt_status;
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
	localparam [4:0] RST_WAIT1 = 5'd0;
	localparam [4:0] RST_WAIT2 = 5'd1;
	localparam [4:0] INT_WAIT1 = 5'd2;
	localparam [4:0] INT_WAIT2 = 5'd3;
	localparam [4:0] EXECUTE = 5'd4;
	localparam [4:0] PRE_FETCH_EXEC = 5'd5;
	localparam [4:0] MEM_WAIT1 = 5'd6;
	localparam [4:0] MEM_WAIT2 = 5'd7;
	localparam [4:0] PC_STALL1 = 5'd8;
	localparam [4:0] PC_STALL2 = 5'd9;
	localparam [4:0] MTRANS_EXEC1 = 5'd10;
	localparam [4:0] MTRANS_EXEC2 = 5'd11;
	localparam [4:0] MTRANS_EXEC3 = 5'd12;
	localparam [4:0] MTRANS_EXEC3B = 5'd13;
	localparam [4:0] MTRANS_EXEC4 = 5'd14;
	localparam [4:0] MTRANS5_ABORT = 5'd15;
	localparam [4:0] MULT_PROC1 = 5'd16;
	localparam [4:0] MULT_PROC2 = 5'd17;
	localparam [4:0] MULT_STORE = 5'd19;
	localparam [4:0] MULT_ACCUMU = 5'd20;
	localparam [4:0] SWAP_WRITE = 5'd22;
	localparam [4:0] SWAP_WAIT1 = 5'd23;
	localparam [4:0] SWAP_WAIT2 = 5'd24;
	localparam [4:0] COPRO_WAIT = 5'd25;
	wire [31:0] instruction;
	wire instruction_iabt;
	wire instruction_adex;
	wire [31:0] instruction_address;
	wire [7:0] instruction_iabt_status;
	wire [1:0] instruction_sel;
	reg [3:0] itype;
	wire [3:0] opcode;
	wire [7:0] imm8;
	wire [31:0] offset12;
	wire [31:0] offset24;
	wire [4:0] shift_imm;
	wire opcode_compare;
	wire mem_op;
	wire load_op;
	wire store_op;
	wire write_pc;
	wire immediate_shifter_operand;
	wire rds_use_rs;
	wire branch;
	wire mem_op_pre_indexed;
	wire mem_op_post_indexed;
	wire [31:0] imm32_nxt;
	wire [4:0] imm_shift_amount_nxt;
	wire shift_imm_zero_nxt;
	wire [3:0] condition_nxt;
	reg exclusive_exec_nxt;
	reg data_access_exec_nxt;
	reg [1:0] barrel_shift_function_nxt;
	wire [8:0] alu_function_nxt;
	reg use_carry_in_nxt;
	reg [1:0] multiply_function_nxt;
	reg [1:0] status_bits_mode_nxt;
	reg status_bits_irq_mask_nxt;
	reg status_bits_firq_mask_nxt;
	reg [1:0] barrel_shift_amount_sel_nxt;
	reg [1:0] barrel_shift_data_sel_nxt;
	reg [3:0] address_sel_nxt;
	reg [1:0] pc_sel_nxt;
	reg writeback_sel_nxt;
	reg [1:0] byte_enable_sel_nxt;
	reg [2:0] status_bits_sel_nxt;
	reg [2:0] reg_write_sel_nxt;
	reg user_mode_regs_load_nxt;
	wire firq_not_user_mode_nxt;
	reg alu_swap_sel_nxt;
	reg alu_not_sel_nxt;
	reg [1:0] alu_cin_sel_nxt;
	reg alu_cout_sel_nxt;
	reg [3:0] alu_out_sel_nxt;
	reg write_data_wen_nxt;
	reg copro_write_data_wen_nxt;
	reg base_address_wen_nxt;
	reg pc_wen_nxt;
	reg [3:0] reg_bank_wsel_nxt;
	reg status_bits_flags_wen_nxt;
	reg status_bits_mode_wen_nxt;
	reg status_bits_irq_mask_wen_nxt;
	reg status_bits_firq_mask_wen_nxt;
	reg saved_current_instruction_wen;
	reg pre_fetch_instruction_wen;
	reg [4:0] control_state = RST_WAIT1;
	reg [4:0] control_state_nxt;
	wire dabt;
	reg dabt_reg = 'd0;
	reg iabt_reg = 'd0;
	reg adex_reg = 'd0;
	reg [31:0] abt_address_reg = 'd0;
	reg [7:0] abt_status_reg = 'd0;
	reg [31:0] saved_current_instruction = 'd0;
	reg saved_current_instruction_iabt = 'd0;
	reg saved_current_instruction_adex = 'd0;
	reg [31:0] saved_current_instruction_address = 'd0;
	reg [7:0] saved_current_instruction_iabt_status = 'd0;
	reg [31:0] pre_fetch_instruction = 'd0;
	reg pre_fetch_instruction_iabt = 'd0;
	reg pre_fetch_instruction_adex = 'd0;
	reg [31:0] pre_fetch_instruction_address = 'd0;
	reg [7:0] pre_fetch_instruction_iabt_status = 'd0;
	wire instruction_valid;
	wire instruction_execute;
	reg [3:0] mtrans_reg;
	reg [3:0] mtrans_reg_d1 = 'd0;
	reg [3:0] mtrans_reg_d2 = 'd0;
	reg [31:0] mtrans_instruction_nxt;
	wire [31:0] mtrans_base_reg_change;
	wire [4:0] mtrans_num_registers;
	wire use_saved_current_instruction;
	wire use_pre_fetch_instruction;
	wire interrupt;
	wire [1:0] interrupt_mode;
	wire [2:0] next_interrupt;
	reg irq = 'd0;
	reg firq = 'd0;
	wire firq_request;
	wire irq_request;
	wire swi_request;
	wire und_request;
	wire dabt_request;
	reg [1:0] copro_operation_nxt;
	reg mtrans_r15 = 'd0;
	reg mtrans_r15_nxt;
	reg restore_base_address = 'd0;
	reg restore_base_address_nxt;
	wire regop_set_flags;
	assign o_iabt_trigger = (instruction_iabt && (o_status_bits_mode == SVC)) && (control_state == INT_WAIT1);
	assign o_iabt_address = instruction_address;
	assign o_iabt_status = instruction_iabt_status;
	assign o_dabt_trigger = dabt_reg;
	assign o_dabt_address = abt_address_reg;
	assign o_dabt_status = abt_status_reg;
	assign use_saved_current_instruction = instruction_execute && ((((((((((((((((((control_state == MEM_WAIT1) || (control_state == MEM_WAIT2)) || (control_state == MTRANS_EXEC1)) || (control_state == MTRANS_EXEC2)) || (control_state == MTRANS_EXEC3)) || (control_state == MTRANS_EXEC3B)) || (control_state == MTRANS_EXEC4)) || (control_state == MTRANS5_ABORT)) || (control_state == MULT_PROC1)) || (control_state == MULT_PROC2)) || (control_state == MULT_ACCUMU)) || (control_state == MULT_STORE)) || (control_state == INT_WAIT1)) || (control_state == INT_WAIT2)) || (control_state == SWAP_WRITE)) || (control_state == SWAP_WAIT1)) || (control_state == SWAP_WAIT2)) || (control_state == COPRO_WAIT));
	assign use_pre_fetch_instruction = control_state == PRE_FETCH_EXEC;
	assign instruction_sel = (use_saved_current_instruction ? 2'd1 : (use_pre_fetch_instruction ? 2'd2 : 2'd0));
	assign instruction = (instruction_sel == 2'd0 ? o_read_data : (instruction_sel == 2'd1 ? saved_current_instruction : pre_fetch_instruction));
	assign instruction_iabt = (instruction_sel == 2'd0 ? iabt_reg : (instruction_sel == 2'd1 ? saved_current_instruction_iabt : pre_fetch_instruction_iabt));
	assign instruction_address = (instruction_sel == 2'd0 ? abt_address_reg : (instruction_sel == 2'd1 ? saved_current_instruction_address : pre_fetch_instruction_address));
	assign instruction_iabt_status = (instruction_sel == 2'd0 ? abt_status_reg : (instruction_sel == 2'd1 ? saved_current_instruction_iabt_status : pre_fetch_instruction_iabt_status));
	assign instruction_adex = (instruction_sel == 2'd0 ? adex_reg : (instruction_sel == 2'd1 ? saved_current_instruction_adex : pre_fetch_instruction_adex));
	always @(*)
		casez ({instruction[27:20], instruction[7:4]})
			12'b00010z001001: itype = SWAP;
			12'b000000zz1001: itype = MULT;
			12'b00zzzzzzzzzz: itype = REGOP;
			12'b01zzzzzzzzzz: itype = TRANS;
			12'b100zzzzzzzzz: itype = MTRANS;
			12'b101zzzzzzzzz: itype = BRANCH;
			12'b110zzzzzzzzz: itype = CODTRANS;
			12'b1110zzzzzzz0: itype = COREGOP;
			12'b1110zzzzzzz1: itype = CORTRANS;
			default: itype = SWI;
		endcase
	assign opcode = instruction[24:21];
	assign condition_nxt = instruction[31:28];
	assign o_rm_sel_nxt = instruction[3:0];
	assign o_rn_sel_nxt = (branch ? 4'd15 : instruction[19:16]);
	assign o_rds_sel_nxt = (control_state == SWAP_WRITE ? instruction[3:0] : (itype == MTRANS ? mtrans_reg : (branch ? 4'd15 : (rds_use_rs ? instruction[11:8] : instruction[15:12]))));
	assign shift_imm = instruction[11:7];
	wire shift_extend = ((~instruction[25] & ~instruction[4]) & ~(|instruction[11:7])) & (instruction[6:5] == 2'b11);
	assign offset12 = {20'h00000, instruction[11:0]};
	assign offset24 = {{6 {instruction[23]}}, instruction[23:0], 2'd0};
	assign imm8 = instruction[7:0];
	assign immediate_shifter_operand = instruction[25];
	assign rds_use_rs = (((itype == REGOP) && !instruction[25]) && instruction[4]) || ((itype == MULT) && (((control_state == MULT_PROC1) || (control_state == MULT_PROC2)) || (instruction_valid && !interrupt)));
	assign branch = itype == BRANCH;
	assign opcode_compare = (((opcode == CMP) || (opcode == CMN)) || (opcode == TEQ)) || (opcode == TST);
	assign mem_op = itype == TRANS;
	assign load_op = mem_op && instruction[20];
	assign store_op = mem_op && !instruction[20];
	assign write_pc = pc_wen_nxt && (pc_sel_nxt != 2'd0);
	assign regop_set_flags = (itype == REGOP) && instruction[20];
	assign mem_op_pre_indexed = instruction[24] && instruction[21];
	assign mem_op_post_indexed = !instruction[24];
	assign imm32_nxt = (itype == MULT ? 32'd0 : (itype == MTRANS ? {mtrans_base_reg_change} : (itype == BRANCH ? {offset24} : (itype == TRANS ? {offset12} : (instruction[11:8] == 4'h0 ? {24'h000000, imm8[7:0]} : (instruction[11:8] == 4'h1 ? {imm8[1:0], 24'h000000, imm8[7:2]} : (instruction[11:8] == 4'h2 ? {imm8[3:0], 24'h000000, imm8[7:4]} : (instruction[11:8] == 4'h3 ? {imm8[5:0], 24'h000000, imm8[7:6]} : (instruction[11:8] == 4'h4 ? {imm8[7:0], 24'h000000} : (instruction[11:8] == 4'h5 ? {2'h0, imm8[7:0], 22'h000000} : (instruction[11:8] == 4'h6 ? {4'h0, imm8[7:0], 20'h00000} : (instruction[11:8] == 4'h7 ? {6'h00, imm8[7:0], 18'h00000} : (instruction[11:8] == 4'h8 ? {8'h00, imm8[7:0], 16'h0000} : (instruction[11:8] == 4'h9 ? {10'h000, imm8[7:0], 14'h0000} : (instruction[11:8] == 4'ha ? {12'h000, imm8[7:0], 12'h000} : (instruction[11:8] == 4'hb ? {14'h0000, imm8[7:0], 10'h000} : (instruction[11:8] == 4'hc ? {16'h0000, imm8[7:0], 8'h00} : (instruction[11:8] == 4'hd ? {18'h00000, imm8[7:0], 6'h00} : (instruction[11:8] == 4'he ? {20'h00000, imm8[7:0], 4'h0} : {22'h000000, imm8[7:0], 2'h0})))))))))))))))))));
	assign imm_shift_amount_nxt = shift_imm;
	assign shift_imm_zero_nxt = (imm_shift_amount_nxt == 5'd0) && (barrel_shift_amount_sel_nxt == 2'd2);
	assign alu_function_nxt = {alu_swap_sel_nxt, alu_not_sel_nxt, alu_cin_sel_nxt, alu_cout_sel_nxt, alu_out_sel_nxt};
	always @(*)
		casez (instruction[15:0])
			16'bzzzzzzzzzzzzzzz1: mtrans_reg = 4'h0;
			16'bzzzzzzzzzzzzzz10: mtrans_reg = 4'h1;
			16'bzzzzzzzzzzzzz100: mtrans_reg = 4'h2;
			16'bzzzzzzzzzzzz1000: mtrans_reg = 4'h3;
			16'bzzzzzzzzzzz10000: mtrans_reg = 4'h4;
			16'bzzzzzzzzzz100000: mtrans_reg = 4'h5;
			16'bzzzzzzzzz1000000: mtrans_reg = 4'h6;
			16'bzzzzzzzz10000000: mtrans_reg = 4'h7;
			16'bzzzzzzz100000000: mtrans_reg = 4'h8;
			16'bzzzzzz1000000000: mtrans_reg = 4'h9;
			16'bzzzzz10000000000: mtrans_reg = 4'ha;
			16'bzzzz100000000000: mtrans_reg = 4'hb;
			16'bzzz1000000000000: mtrans_reg = 4'hc;
			16'bzz10000000000000: mtrans_reg = 4'hd;
			16'bz100000000000000: mtrans_reg = 4'he;
			default: mtrans_reg = 4'hf;
		endcase
	always @(*)
		casez (instruction[15:0])
			16'bzzzzzzzzzzzzzzz1: mtrans_instruction_nxt = {instruction[31:16], instruction[15:1], 1'd0};
			16'bzzzzzzzzzzzzzz10: mtrans_instruction_nxt = {instruction[31:16], instruction[15:2], 2'd0};
			16'bzzzzzzzzzzzzz100: mtrans_instruction_nxt = {instruction[31:16], instruction[15:3], 3'd0};
			16'bzzzzzzzzzzzz1000: mtrans_instruction_nxt = {instruction[31:16], instruction[15:4], 4'd0};
			16'bzzzzzzzzzzz10000: mtrans_instruction_nxt = {instruction[31:16], instruction[15:5], 5'd0};
			16'bzzzzzzzzzz100000: mtrans_instruction_nxt = {instruction[31:16], instruction[15:6], 6'd0};
			16'bzzzzzzzzz1000000: mtrans_instruction_nxt = {instruction[31:16], instruction[15:7], 7'd0};
			16'bzzzzzzzz10000000: mtrans_instruction_nxt = {instruction[31:16], instruction[15:8], 8'd0};
			16'bzzzzzzz100000000: mtrans_instruction_nxt = {instruction[31:16], instruction[15:9], 9'd0};
			16'bzzzzzz1000000000: mtrans_instruction_nxt = {instruction[31:16], instruction[15:10], 10'd0};
			16'bzzzzz10000000000: mtrans_instruction_nxt = {instruction[31:16], instruction[15:11], 11'd0};
			16'bzzzz100000000000: mtrans_instruction_nxt = {instruction[31:16], instruction[15:12], 12'd0};
			16'bzzz1000000000000: mtrans_instruction_nxt = {instruction[31:16], instruction[15:13], 13'd0};
			16'bzz10000000000000: mtrans_instruction_nxt = {instruction[31:16], instruction[15:14], 14'd0};
			16'bz100000000000000: mtrans_instruction_nxt = {instruction[31:16], instruction[15], 15'd0};
			default: mtrans_instruction_nxt = {instruction[31:16], 16'd0};
		endcase
	assign mtrans_num_registers = (((((((((((((({4'd0, instruction[15]} + {4'd0, instruction[14]}) + {4'd0, instruction[13]}) + {4'd0, instruction[12]}) + {4'd0, instruction[11]}) + {4'd0, instruction[10]}) + {4'd0, instruction[9]}) + {4'd0, instruction[8]}) + {4'd0, instruction[7]}) + {4'd0, instruction[6]}) + {4'd0, instruction[5]}) + {4'd0, instruction[4]}) + {4'd0, instruction[3]}) + {4'd0, instruction[2]}) + {4'd0, instruction[1]}) + {4'd0, instruction[0]};
	assign mtrans_base_reg_change = {25'd0, mtrans_num_registers, 2'd0};
	assign firq_request = firq && !i_execute_status_bits[26];
	assign irq_request = irq && !i_execute_status_bits[27];
	assign swi_request = itype == SWI;
	assign dabt_request = dabt_reg || i_dabt;
	assign und_request = ((itype == CODTRANS) || (itype == COREGOP)) || ((itype == CORTRANS) && (instruction[11:8] != 4'd15));
	assign next_interrupt = (dabt_request ? 3'd1 : (firq_request ? 3'd2 : (irq_request ? 3'd3 : (instruction_adex ? 3'd4 : (instruction_iabt ? 3'd5 : (und_request ? 3'd6 : (swi_request ? 3'd7 : 3'd0)))))));
	assign interrupt = ((next_interrupt != 3'd0) && (next_interrupt != 3'd7)) && (next_interrupt != 3'd6);
	assign interrupt_mode = (next_interrupt == 3'd2 ? FIRQ : (next_interrupt == 3'd3 ? IRQ : (next_interrupt == 3'd4 ? SVC : (next_interrupt == 3'd5 ? SVC : (next_interrupt == 3'd6 ? SVC : (next_interrupt == 3'd7 ? SVC : (next_interrupt == 3'd1 ? SVC : USR)))))));
	always @(*) begin
		status_bits_mode_nxt = i_execute_status_bits[1:0];
		status_bits_irq_mask_nxt = o_status_bits_irq_mask;
		status_bits_firq_mask_nxt = o_status_bits_firq_mask;
		exclusive_exec_nxt = 1'd0;
		data_access_exec_nxt = 1'd0;
		copro_operation_nxt = 'd0;
		saved_current_instruction_wen = 1'd0;
		pre_fetch_instruction_wen = 1'd0;
		mtrans_r15_nxt = mtrans_r15;
		restore_base_address_nxt = restore_base_address;
		barrel_shift_amount_sel_nxt = 'd0;
		barrel_shift_data_sel_nxt = 'd0;
		barrel_shift_function_nxt = 'd0;
		use_carry_in_nxt = 'd0;
		multiply_function_nxt = 'd0;
		address_sel_nxt = 'd0;
		pc_sel_nxt = 'd0;
		writeback_sel_nxt = 'd0;
		byte_enable_sel_nxt = 'd0;
		status_bits_sel_nxt = 'd0;
		reg_write_sel_nxt = 'd0;
		user_mode_regs_load_nxt = 'd0;
		o_user_mode_regs_store_nxt = 'd0;
		alu_swap_sel_nxt = 'd0;
		alu_not_sel_nxt = 'd0;
		alu_cin_sel_nxt = 'd0;
		alu_cout_sel_nxt = 'd0;
		alu_out_sel_nxt = 'd0;
		write_data_wen_nxt = 'd0;
		copro_write_data_wen_nxt = 'd0;
		base_address_wen_nxt = 'd0;
		pc_wen_nxt = 'd1;
		reg_bank_wsel_nxt = 'hf;
		status_bits_flags_wen_nxt = 'd0;
		status_bits_mode_wen_nxt = 'd0;
		status_bits_irq_mask_wen_nxt = 'd0;
		status_bits_firq_mask_wen_nxt = 'd0;
		if (instruction_valid && !interrupt) begin
			if (itype == REGOP) begin
				if (!opcode_compare) begin
					if (instruction[15:12] == 4'd15) begin
						pc_sel_nxt = 2'd1;
						address_sel_nxt = 4'd1;
					end
					else
						reg_bank_wsel_nxt = instruction[15:12];
				end
				if (!immediate_shifter_operand)
					barrel_shift_function_nxt = instruction[6:5];
				if (!immediate_shifter_operand)
					barrel_shift_data_sel_nxt = 2'd2;
				if (!immediate_shifter_operand && instruction[4])
					barrel_shift_amount_sel_nxt = 2'd1;
				if (!immediate_shifter_operand && !instruction[4])
					barrel_shift_amount_sel_nxt = 2'd2;
				if ((((((((opcode == AND) || (opcode == EOR)) || (opcode == TST)) || (opcode == TEQ)) || (opcode == ORR)) || (opcode == MOV)) || (opcode == BIC)) || (opcode == MVN))
					status_bits_sel_nxt = 3'd5;
				if ((opcode == ADD) || (opcode == CMN)) begin
					alu_out_sel_nxt = 4'd1;
					use_carry_in_nxt = shift_extend;
				end
				if (opcode == ADC) begin
					alu_out_sel_nxt = 4'd1;
					alu_cin_sel_nxt = 2'd2;
					use_carry_in_nxt = 1'd1;
				end
				if ((opcode == SUB) || (opcode == CMP)) begin
					alu_out_sel_nxt = 4'd1;
					alu_cin_sel_nxt = 2'd1;
					alu_not_sel_nxt = 1'd1;
					use_carry_in_nxt = shift_extend;
				end
				if (opcode == SBC) begin
					alu_out_sel_nxt = 4'd1;
					alu_cin_sel_nxt = 2'd2;
					alu_not_sel_nxt = 1'd1;
					use_carry_in_nxt = 1'd1;
				end
				if (opcode == RSB) begin
					alu_out_sel_nxt = 4'd1;
					alu_cin_sel_nxt = 2'd1;
					alu_not_sel_nxt = 1'd1;
					alu_swap_sel_nxt = 1'd1;
					use_carry_in_nxt = 1'd1;
				end
				if (opcode == RSC) begin
					alu_out_sel_nxt = 4'd1;
					alu_cin_sel_nxt = 2'd2;
					alu_not_sel_nxt = 1'd1;
					alu_swap_sel_nxt = 1'd1;
					use_carry_in_nxt = 1'd1;
				end
				if ((opcode == AND) || (opcode == TST)) begin
					alu_out_sel_nxt = 4'd8;
					alu_cout_sel_nxt = 1'd1;
					use_carry_in_nxt = 1'd1;
				end
				if ((opcode == EOR) || (opcode == TEQ)) begin
					alu_out_sel_nxt = 4'd6;
					alu_cout_sel_nxt = 1'd1;
					use_carry_in_nxt = 1'd1;
				end
				if (opcode == ORR) begin
					alu_out_sel_nxt = 4'd7;
					alu_cout_sel_nxt = 1'd1;
					use_carry_in_nxt = 1'd1;
				end
				if (opcode == BIC) begin
					alu_out_sel_nxt = 4'd8;
					alu_not_sel_nxt = 1'd1;
					alu_cout_sel_nxt = 1'd1;
					use_carry_in_nxt = 1'd1;
				end
				if (opcode == MOV) begin
					alu_cout_sel_nxt = 1'd1;
					use_carry_in_nxt = 1'd1;
				end
				if (opcode == MVN) begin
					alu_not_sel_nxt = 1'd1;
					alu_cout_sel_nxt = 1'd1;
					use_carry_in_nxt = 1'd1;
				end
			end
			if (mem_op) begin
				saved_current_instruction_wen = 1'd1;
				pc_wen_nxt = 1'd0;
				data_access_exec_nxt = 1'd1;
				alu_out_sel_nxt = 4'd1;
				if (!instruction[23]) begin
					alu_cin_sel_nxt = 2'd1;
					alu_not_sel_nxt = 1'd1;
				end
				if (store_op) begin
					write_data_wen_nxt = 1'd1;
					if ((itype == TRANS) && instruction[22])
						byte_enable_sel_nxt = 2'd1;
				end
				if (mem_op_pre_indexed || mem_op_post_indexed) begin
					if (o_rn_sel_nxt == 4'd15)
						pc_sel_nxt = 2'd1;
					else
						reg_bank_wsel_nxt = o_rn_sel_nxt;
				end
				if ((itype == TRANS) & mem_op_post_indexed)
					writeback_sel_nxt = instruction[21];
				if (mem_op_post_indexed)
					address_sel_nxt = 4'd4;
				else
					address_sel_nxt = 4'd1;
				if (instruction[25] && (itype == TRANS))
					barrel_shift_data_sel_nxt = 2'd2;
				if (((itype == TRANS) && instruction[25]) && (shift_imm != 5'd0)) begin
					barrel_shift_function_nxt = instruction[6:5];
					barrel_shift_amount_sel_nxt = 2'd2;
				end
			end
			if (itype == BRANCH) begin
				pc_sel_nxt = 2'd1;
				address_sel_nxt = 4'd1;
				alu_out_sel_nxt = 4'd1;
				if (instruction[24]) begin
					reg_bank_wsel_nxt = 4'd14;
					reg_write_sel_nxt = 3'd1;
				end
			end
			if (itype == MTRANS) begin
				saved_current_instruction_wen = 1'd1;
				pc_wen_nxt = 1'd0;
				data_access_exec_nxt = 1'd1;
				alu_out_sel_nxt = 4'd1;
				mtrans_r15_nxt = instruction[15];
				base_address_wen_nxt = 1'd1;
				restore_base_address_nxt = instruction[20] && (instruction[15:0] & (1'd1 << instruction[19:16]));
				if (instruction[23]) begin
					if (instruction[24])
						address_sel_nxt = 4'd7;
					else
						address_sel_nxt = 4'd4;
				end
				else begin
					alu_cin_sel_nxt = 2'd1;
					alu_not_sel_nxt = 1'd1;
					if (!instruction[24])
						address_sel_nxt = 4'd6;
					else
						address_sel_nxt = 4'd1;
				end
				if (!instruction[20])
					write_data_wen_nxt = 1'd1;
				if ({instruction[22:20], instruction[15]} == 4'b1010)
					user_mode_regs_load_nxt = 1'd1;
				if ({instruction[22:20]} == 3'b100)
					o_user_mode_regs_store_nxt = 1'd1;
				if (instruction[21])
					reg_bank_wsel_nxt = o_rn_sel_nxt;
			end
			if (itype == MULT) begin
				multiply_function_nxt[0] = 1'd1;
				saved_current_instruction_wen = 1'd1;
				pc_wen_nxt = 1'd0;
				if (instruction[21])
					multiply_function_nxt[1] = 1'd1;
			end
			if (itype == SWAP) begin
				saved_current_instruction_wen = 1'd1;
				pc_wen_nxt = 1'd0;
				data_access_exec_nxt = 1'd1;
				barrel_shift_data_sel_nxt = 2'd2;
				address_sel_nxt = 4'd4;
				exclusive_exec_nxt = 1'd1;
			end
			if ((itype == CORTRANS) && !und_request) begin
				saved_current_instruction_wen = 1'd1;
				pc_wen_nxt = 1'd0;
				address_sel_nxt = 4'd3;
				if (instruction[20])
					copro_operation_nxt = 2'd1;
				else begin
					copro_operation_nxt = 2'd0;
					copro_write_data_wen_nxt = 1'd1;
				end
			end
			if ((itype == SWI) || und_request) begin
				reg_write_sel_nxt = 3'd1;
				reg_bank_wsel_nxt = 4'd14;
				address_sel_nxt = 4'd2;
				pc_sel_nxt = 2'd2;
				status_bits_mode_nxt = interrupt_mode;
				status_bits_mode_wen_nxt = 1'd1;
				status_bits_irq_mask_nxt = 1'd1;
				status_bits_irq_mask_wen_nxt = 1'd1;
			end
			if (regop_set_flags) begin
				status_bits_flags_wen_nxt = 1'd1;
				if (instruction[15:12] == 4'd15) begin
					status_bits_sel_nxt = 3'd1;
					if (i_execute_status_bits[1:0] != USR) begin
						status_bits_mode_wen_nxt = 1'd1;
						status_bits_irq_mask_wen_nxt = 1'd1;
						status_bits_firq_mask_wen_nxt = 1'd1;
					end
				end
			end
		end
		if ((instruction_valid && interrupt) && (next_interrupt != 3'd6)) begin
			saved_current_instruction_wen = 1'd1;
			if (next_interrupt == 3'd4)
				reg_write_sel_nxt = 3'd7;
			else
				reg_write_sel_nxt = 3'd1;
			reg_bank_wsel_nxt = 4'd14;
			address_sel_nxt = 4'd2;
			pc_sel_nxt = 2'd2;
			status_bits_mode_nxt = interrupt_mode;
			status_bits_mode_wen_nxt = 1'd1;
			status_bits_irq_mask_nxt = 1'd1;
			status_bits_irq_mask_wen_nxt = 1'd1;
			if (next_interrupt == 3'd2) begin
				status_bits_firq_mask_nxt = 1'd1;
				status_bits_firq_mask_wen_nxt = 1'd1;
			end
		end
		if (control_state == MEM_WAIT1) begin
			pre_fetch_instruction_wen = 1'd1;
			if (instruction_execute) begin
				address_sel_nxt = 4'd3;
				pc_wen_nxt = 1'd0;
			end
		end
		if ((control_state == MEM_WAIT2) && load_op) begin
			barrel_shift_data_sel_nxt = 2'd1;
			barrel_shift_amount_sel_nxt = 2'd3;
			if (i_execute_address[1:0] != 2'd0)
				barrel_shift_function_nxt = ROR;
			if ((itype == TRANS) && instruction[22])
				alu_out_sel_nxt = 4'd3;
			if (!dabt) begin
				if (instruction[15:12] == 4'd15) begin
					pc_sel_nxt = 2'd1;
					address_sel_nxt = 4'd1;
				end
				else
					reg_bank_wsel_nxt = instruction[15:12];
			end
		end
		if (control_state == MTRANS_EXEC1) begin
			pre_fetch_instruction_wen = 1'd1;
			if (instruction_execute) begin
				address_sel_nxt = 4'd5;
				pc_wen_nxt = 1'd0;
				data_access_exec_nxt = 1'd1;
				if (!instruction[20])
					write_data_wen_nxt = 1'd1;
				if ({instruction[22:20], mtrans_r15} == 4'b1010)
					user_mode_regs_load_nxt = 1'd1;
				if ({instruction[22:20]} == 3'b100)
					o_user_mode_regs_store_nxt = 1'd1;
			end
		end
		if (control_state == MTRANS_EXEC2) begin
			address_sel_nxt = 4'd5;
			pc_wen_nxt = 1'd0;
			data_access_exec_nxt = 1'd1;
			barrel_shift_data_sel_nxt = 2'd1;
			if (instruction[20]) begin
				if (!dabt)
					reg_bank_wsel_nxt = mtrans_reg_d2;
			end
			else
				write_data_wen_nxt = 1'd1;
			if ({instruction[22], instruction[20], mtrans_r15} == 3'b110)
				user_mode_regs_load_nxt = 1'd1;
			if ({instruction[22], instruction[20]} == 2'b10)
				o_user_mode_regs_store_nxt = 1'd1;
		end
		if ((control_state == MTRANS_EXEC3) && instruction_execute) begin
			address_sel_nxt = 4'd3;
			pc_wen_nxt = 1'd0;
			barrel_shift_data_sel_nxt = 2'd1;
			if (instruction[20] && !dabt)
				reg_bank_wsel_nxt = mtrans_reg_d2;
			if ({instruction[22], instruction[20], mtrans_r15} == 3'b110)
				user_mode_regs_load_nxt = 1'd1;
			if ({instruction[22], instruction[20]} == 2'b10)
				o_user_mode_regs_store_nxt = 1'd1;
		end
		if ((control_state == MTRANS_EXEC3B) && instruction_execute) begin
			pre_fetch_instruction_wen = 1'd1;
			address_sel_nxt = 4'd3;
			pc_wen_nxt = 1'd0;
			if ({instruction[22], instruction[20], mtrans_r15} == 3'b110)
				user_mode_regs_load_nxt = 1'd1;
			if ({instruction[22], instruction[20]} == 2'b10)
				o_user_mode_regs_store_nxt = 1'd1;
		end
		if (control_state == MTRANS_EXEC4) begin
			barrel_shift_data_sel_nxt = 2'd1;
			if (instruction[20]) begin
				if (!dabt) begin
					if (mtrans_reg_d2 == 4'd15) begin
						address_sel_nxt = 4'd1;
						pc_sel_nxt = 2'd1;
						pc_wen_nxt = 1'd1;
						if (instruction[22]) begin
							status_bits_sel_nxt = 3'd1;
							status_bits_flags_wen_nxt = 1'd1;
							if (i_execute_status_bits[1:0] != USR) begin
								status_bits_mode_wen_nxt = 1'd1;
								status_bits_irq_mask_wen_nxt = 1'd1;
								status_bits_firq_mask_wen_nxt = 1'd1;
							end
						end
					end
					else
						reg_bank_wsel_nxt = mtrans_reg_d2;
				end
			end
			if (dabt)
				pc_wen_nxt = 1'd0;
			if ({instruction[22], instruction[20], mtrans_r15} == 3'b110)
				user_mode_regs_load_nxt = 1'd1;
			if ({instruction[22], instruction[20]} == 2'b10)
				o_user_mode_regs_store_nxt = 1'd1;
		end
		if (control_state == MTRANS5_ABORT) begin
			if (restore_base_address) begin
				reg_write_sel_nxt = 3'd6;
				reg_bank_wsel_nxt = instruction[19:16];
			end
		end
		if ((control_state == MULT_PROC1) && instruction_execute) begin
			pre_fetch_instruction_wen = 1'd1;
			pc_wen_nxt = 1'd0;
			multiply_function_nxt = o_multiply_function;
		end
		if (control_state == MULT_PROC2) begin
			pc_wen_nxt = 1'd0;
			address_sel_nxt = 4'd3;
			multiply_function_nxt = o_multiply_function;
		end
		if (control_state == MULT_STORE) begin
			reg_write_sel_nxt = 3'd2;
			multiply_function_nxt = o_multiply_function;
			if (itype == MULT)
				reg_bank_wsel_nxt = instruction[19:16];
			else
				reg_bank_wsel_nxt = instruction[15:12];
			if (instruction[20]) begin
				status_bits_sel_nxt = 3'd4;
				status_bits_flags_wen_nxt = 1'd1;
			end
		end
		if (control_state == MULT_ACCUMU) begin
			multiply_function_nxt = o_multiply_function;
			pc_wen_nxt = 1'd0;
			address_sel_nxt = 4'd3;
		end
		if ((control_state == SWAP_WRITE) && instruction_execute) begin
			barrel_shift_data_sel_nxt = 2'd2;
			address_sel_nxt = 4'd4;
			write_data_wen_nxt = 1'd1;
			data_access_exec_nxt = 1'd1;
			if (instruction[22])
				byte_enable_sel_nxt = 2'd1;
			if (instruction_execute)
				pc_wen_nxt = 1'd0;
			pre_fetch_instruction_wen = 1'd1;
		end
		if (control_state == SWAP_WAIT1) begin
			barrel_shift_data_sel_nxt = 2'd1;
			barrel_shift_amount_sel_nxt = 2'd3;
			if (i_execute_address[1:0] != 2'd0)
				barrel_shift_function_nxt = ROR;
			if (instruction_execute) begin
				address_sel_nxt = 4'd3;
				pc_wen_nxt = 1'd0;
			end
			if (instruction[22])
				alu_out_sel_nxt = 4'd3;
			if (!dabt) begin
				if (instruction[15:12] == 4'd15) begin
					pc_sel_nxt = 2'd1;
					address_sel_nxt = 4'd1;
				end
				else
					reg_bank_wsel_nxt = instruction[15:12];
			end
		end
		if ((control_state == COPRO_WAIT) && instruction_execute) begin
			pre_fetch_instruction_wen = 1'd1;
			if (instruction[20]) begin
				if (instruction[15:12] == 4'd15) begin
					status_bits_sel_nxt = 3'd3;
					status_bits_flags_wen_nxt = 1'd1;
					if (i_execute_status_bits[1:0] != USR) begin
						status_bits_mode_wen_nxt = 1'd1;
						status_bits_irq_mask_wen_nxt = 1'd1;
						status_bits_firq_mask_wen_nxt = 1'd1;
					end
				end
				else
					reg_bank_wsel_nxt = instruction[15:12];
				reg_write_sel_nxt = 3'd5;
			end
			else
				copro_operation_nxt = 2'd2;
		end
		if (control_state == INT_WAIT1)
			status_bits_mode_nxt = o_status_bits_mode;
	end
	assign firq_not_user_mode_nxt = !user_mode_regs_load_nxt && (status_bits_mode_nxt == FIRQ);
	assign instruction_execute = conditional_execute(o_condition, i_execute_status_bits[31:28]);
	assign instruction_valid = ((control_state == EXECUTE) || (control_state == PRE_FETCH_EXEC)) || (!instruction_execute && ((((((((control_state == PC_STALL1) || (control_state == MEM_WAIT1)) || (control_state == COPRO_WAIT)) || (control_state == SWAP_WRITE)) || (control_state == MULT_PROC1)) || (control_state == MTRANS_EXEC1)) || (control_state == MTRANS_EXEC3)) || (control_state == MTRANS_EXEC3B)));
	always @(*) begin
		control_state_nxt = control_state;
		if (control_state == RST_WAIT1)
			control_state_nxt = RST_WAIT2;
		if (control_state == RST_WAIT2)
			control_state_nxt = EXECUTE;
		if (control_state == INT_WAIT1)
			control_state_nxt = INT_WAIT2;
		if (control_state == INT_WAIT2)
			control_state_nxt = EXECUTE;
		if (control_state == COPRO_WAIT)
			control_state_nxt = PRE_FETCH_EXEC;
		if (control_state == PC_STALL1)
			control_state_nxt = PC_STALL2;
		if (control_state == PC_STALL2)
			control_state_nxt = EXECUTE;
		if (control_state == SWAP_WRITE)
			control_state_nxt = SWAP_WAIT1;
		if (control_state == SWAP_WAIT1)
			control_state_nxt = SWAP_WAIT2;
		if (control_state == MULT_STORE)
			control_state_nxt = PRE_FETCH_EXEC;
		if (control_state == MTRANS5_ABORT)
			control_state_nxt = PRE_FETCH_EXEC;
		if (control_state == MEM_WAIT1)
			control_state_nxt = MEM_WAIT2;
		if ((control_state == MEM_WAIT2) || (control_state == SWAP_WAIT2)) begin
			if (write_pc)
				control_state_nxt = PC_STALL1;
			else
				control_state_nxt = PRE_FETCH_EXEC;
		end
		if (control_state == MTRANS_EXEC1) begin
			if (mtrans_instruction_nxt[15:0] != 16'd0)
				control_state_nxt = MTRANS_EXEC2;
			else
				control_state_nxt = MTRANS_EXEC3;
		end
		if ((control_state == MTRANS_EXEC2) && (mtrans_num_registers == 5'd1))
			control_state_nxt = MTRANS_EXEC3;
		if (control_state == MTRANS_EXEC3)
			control_state_nxt = MTRANS_EXEC4;
		if (control_state == MTRANS_EXEC3B)
			control_state_nxt = MTRANS_EXEC4;
		if (control_state == MTRANS_EXEC4) begin
			if (dabt)
				control_state_nxt = MTRANS5_ABORT;
			else if (write_pc)
				control_state_nxt = PC_STALL1;
			else
				control_state_nxt = PRE_FETCH_EXEC;
		end
		if (control_state == MULT_PROC1) begin
			if (!instruction_execute)
				control_state_nxt = PRE_FETCH_EXEC;
			else
				control_state_nxt = MULT_PROC2;
		end
		if (control_state == MULT_PROC2) begin
			if (i_multiply_done) begin
				if (o_multiply_function[1])
					control_state_nxt = MULT_ACCUMU;
				else
					control_state_nxt = MULT_STORE;
			end
		end
		if (control_state == MULT_ACCUMU)
			control_state_nxt = MULT_STORE;
		if (instruction_valid) begin
			control_state_nxt = EXECUTE;
			if (mem_op)
				control_state_nxt = MEM_WAIT1;
			if (write_pc)
				control_state_nxt = PC_STALL1;
			if (itype == MTRANS) begin
				if (mtrans_num_registers != 5'd0) begin
					if (mtrans_num_registers == 5'd1)
						control_state_nxt = MTRANS_EXEC3B;
					else
						control_state_nxt = MTRANS_EXEC1;
				end
				else
					control_state_nxt = MTRANS_EXEC3;
			end
			if (itype == MULT)
				control_state_nxt = MULT_PROC1;
			if (itype == SWAP)
				control_state_nxt = SWAP_WRITE;
			if ((itype == CORTRANS) && !und_request)
				control_state_nxt = COPRO_WAIT;
			if (interrupt)
				control_state_nxt = INT_WAIT1;
		end
	end
	always @(posedge i_clk)
		if (i_reset) begin
			control_state <= RST_WAIT1;
			o_read_data <= 1'd0;
			o_read_data_alignment <= 1'd0;
			o_imm32 <= 32'd0;
			o_imm_shift_amount <= 5'd0;
			o_shift_imm_zero <= 1'd0;
			o_condition <= 4'he;
			o_exclusive_exec <= 1'd0;
			o_data_access_exec <= 1'd0;
			o_status_bits_mode <= 2'b11;
			o_status_bits_irq_mask <= 1'd1;
			o_status_bits_firq_mask <= 1'd1;
			o_rm_sel <= 4'd0;
			o_rds_sel <= 4'd0;
			o_rn_sel <= 4'd0;
			o_barrel_shift_amount_sel <= 2'd0;
			o_barrel_shift_data_sel <= 2'd0;
			o_barrel_shift_function <= 2'd0;
			o_alu_function <= 9'd0;
			o_use_carry_in <= 1'd0;
			o_multiply_function <= 2'd0;
			o_interrupt_vector_sel <= 3'd0;
			o_address_sel <= 4'd2;
			o_pc_sel <= 2'd2;
			o_byte_enable_sel <= 2'd0;
			o_status_bits_sel <= 3'd0;
			o_write_data_wen <= 1'd0;
			o_base_address_wen <= 1'd0;
			o_pc_wen <= 1'd0;
			o_writeback_sel <= 1'd0;
			o_reg_bank_wen <= 15'd0;
			o_reg_bank_wsel <= 4'd0;
			o_status_bits_flags_wen <= 1'd0;
			o_status_bits_mode_wen <= 1'd0;
			o_status_bits_irq_mask_wen <= 1'd0;
			o_status_bits_firq_mask_wen <= 1'd0;
			o_copro_opcode1 <= 3'd0;
			o_copro_opcode2 <= 3'd0;
			o_copro_crn <= 4'd0;
			o_copro_crm <= 4'd0;
			o_copro_num <= 4'd0;
			o_copro_operation <= 2'd0;
			o_copro_write_data_wen <= 1'd0;
		end
		else if (!i_fetch_stall | i_fetch_abort) begin
			o_read_data <= i_read_data;
			o_read_data_alignment <= {i_execute_address[1:0], 3'd0};
			abt_address_reg <= i_execute_address;
			iabt_reg <= i_iabt;
			adex_reg <= i_adex;
			abt_status_reg <= i_abt_status;
			o_status_bits_mode <= status_bits_mode_nxt;
			o_status_bits_irq_mask <= status_bits_irq_mask_nxt;
			o_status_bits_firq_mask <= status_bits_firq_mask_nxt;
			o_imm32 <= imm32_nxt;
			o_imm_shift_amount <= imm_shift_amount_nxt;
			o_shift_imm_zero <= shift_imm_zero_nxt;
			o_condition <= (i_fetch_abort ? NV : (instruction_valid && !interrupt ? condition_nxt : AL));
			o_exclusive_exec <= exclusive_exec_nxt;
			o_data_access_exec <= data_access_exec_nxt;
			o_rm_sel <= o_rm_sel_nxt;
			o_rds_sel <= o_rds_sel_nxt;
			o_rn_sel <= o_rn_sel_nxt;
			o_barrel_shift_amount_sel <= barrel_shift_amount_sel_nxt;
			o_barrel_shift_data_sel <= barrel_shift_data_sel_nxt;
			o_barrel_shift_function <= barrel_shift_function_nxt;
			o_alu_function <= alu_function_nxt;
			o_use_carry_in <= use_carry_in_nxt;
			o_multiply_function <= multiply_function_nxt;
			o_interrupt_vector_sel <= next_interrupt;
			o_address_sel <= address_sel_nxt;
			o_pc_sel <= pc_sel_nxt;
			o_writeback_sel <= writeback_sel_nxt;
			o_byte_enable_sel <= byte_enable_sel_nxt;
			o_status_bits_sel <= status_bits_sel_nxt;
			o_reg_write_sel <= reg_write_sel_nxt;
			o_user_mode_regs_load <= user_mode_regs_load_nxt;
			o_firq_not_user_mode <= firq_not_user_mode_nxt;
			o_write_data_wen <= write_data_wen_nxt;
			o_base_address_wen <= base_address_wen_nxt;
			o_pc_wen <= pc_wen_nxt;
			o_reg_bank_wsel <= reg_bank_wsel_nxt;
			o_reg_bank_wen <= decode(reg_bank_wsel_nxt);
			o_status_bits_flags_wen <= status_bits_flags_wen_nxt;
			o_status_bits_mode_wen <= status_bits_mode_wen_nxt;
			o_status_bits_irq_mask_wen <= status_bits_irq_mask_wen_nxt;
			o_status_bits_firq_mask_wen <= status_bits_firq_mask_wen_nxt;
			o_copro_opcode1 <= instruction[23:21];
			o_copro_opcode2 <= instruction[7:5];
			o_copro_crn <= instruction[19:16];
			o_copro_crm <= instruction[3:0];
			o_copro_num <= instruction[11:8];
			o_copro_operation <= copro_operation_nxt;
			o_copro_write_data_wen <= copro_write_data_wen_nxt;
			mtrans_r15 <= mtrans_r15_nxt;
			restore_base_address <= restore_base_address_nxt;
			control_state <= control_state_nxt;
			mtrans_reg_d1 <= mtrans_reg;
			mtrans_reg_d2 <= mtrans_reg_d1;
		end
	always @(posedge i_clk)
		if (!i_fetch_stall) begin
			if (itype == MTRANS) begin
				saved_current_instruction <= mtrans_instruction_nxt;
				saved_current_instruction_iabt <= instruction_iabt;
				saved_current_instruction_adex <= instruction_adex;
				saved_current_instruction_address <= instruction_address;
				saved_current_instruction_iabt_status <= instruction_iabt_status;
			end
			else if (saved_current_instruction_wen) begin
				saved_current_instruction <= instruction;
				saved_current_instruction_iabt <= instruction_iabt;
				saved_current_instruction_adex <= instruction_adex;
				saved_current_instruction_address <= instruction_address;
				saved_current_instruction_iabt_status <= instruction_iabt_status;
			end
			if (pre_fetch_instruction_wen) begin
				pre_fetch_instruction <= o_read_data;
				pre_fetch_instruction_iabt <= iabt_reg;
				pre_fetch_instruction_adex <= adex_reg;
				pre_fetch_instruction_address <= abt_address_reg;
				pre_fetch_instruction_iabt_status <= abt_status_reg;
			end
		end
	always @(posedge i_clk)
		if (!i_fetch_stall | i_dabt) begin
			irq <= i_irq;
			firq <= i_firq;
			if ((control_state == INT_WAIT1) && (o_status_bits_mode == SVC))
				dabt_reg <= 1'd0;
			else
				dabt_reg <= dabt_reg || i_dabt;
		end
	assign dabt = dabt_reg || i_dabt;
	function [3:0] hex_chars_to_4bits;
		input [7:0] hex_chars;
		case (hex_chars)
			"0": hex_chars_to_4bits = 4'h0;
			"1": hex_chars_to_4bits = 4'h1;
			"2": hex_chars_to_4bits = 4'h2;
			"3": hex_chars_to_4bits = 4'h3;
			"4": hex_chars_to_4bits = 4'h4;
			"5": hex_chars_to_4bits = 4'h5;
			"6": hex_chars_to_4bits = 4'h6;
			"7": hex_chars_to_4bits = 4'h7;
			"8": hex_chars_to_4bits = 4'h8;
			"9": hex_chars_to_4bits = 4'h9;
			"a": hex_chars_to_4bits = 4'ha;
			"b": hex_chars_to_4bits = 4'hb;
			"c": hex_chars_to_4bits = 4'hc;
			"d": hex_chars_to_4bits = 4'hd;
			"e": hex_chars_to_4bits = 4'he;
			"f": hex_chars_to_4bits = 4'hf;
			"A": hex_chars_to_4bits = 4'ha;
			"B": hex_chars_to_4bits = 4'hb;
			"C": hex_chars_to_4bits = 4'hc;
			"D": hex_chars_to_4bits = 4'hd;
			"E": hex_chars_to_4bits = 4'he;
			"F": hex_chars_to_4bits = 4'hf;
		endcase
	endfunction
	function [31:0] hex_chars_to_32bits;
		input [63:0] hex_chars;
		begin
			hex_chars_to_32bits[31:28] = hex_chars_to_4bits(hex_chars[63:56]);
			hex_chars_to_32bits[27:24] = hex_chars_to_4bits(hex_chars[55:48]);
			hex_chars_to_32bits[23:20] = hex_chars_to_4bits(hex_chars[47:40]);
			hex_chars_to_32bits[19:16] = hex_chars_to_4bits(hex_chars[39:32]);
			hex_chars_to_32bits[15:12] = hex_chars_to_4bits(hex_chars[31:24]);
			hex_chars_to_32bits[11:8] = hex_chars_to_4bits(hex_chars[23:16]);
			hex_chars_to_32bits[7:4] = hex_chars_to_4bits(hex_chars[15:8]);
			hex_chars_to_32bits[3:0] = hex_chars_to_4bits(hex_chars[7:0]);
		end
	endfunction
	function [7:0] hex_chars_to_8bits;
		input [15:0] hex_chars;
		begin
			hex_chars_to_8bits[7:4] = hex_chars_to_4bits(hex_chars[15:8]);
			hex_chars_to_8bits[3:0] = hex_chars_to_4bits(hex_chars[7:0]);
		end
	endfunction
	function [959:0] align_line;
		input [959:0] line;
		case (1'd1)
			line[7:0] == 8'd0: align_line = 960'd0;
			line[15:8] == 8'd0: align_line = {line[7:0], 952'd0};
			line[23:16] == 8'd0: align_line = {line[15:0], 944'd0};
			line[31:24] == 8'd0: align_line = {line[23:0], 936'd0};
			line[39:32] == 8'd0: align_line = {line[31:0], 928'd0};
			line[47:40] == 8'd0: align_line = {line[39:0], 920'd0};
			line[55:48] == 8'd0: align_line = {line[47:0], 912'd0};
			line[63:56] == 8'd0: align_line = {line[55:0], 904'd0};
			line[71:64] == 8'd0: align_line = {line[63:0], 896'd0};
			line[79:72] == 8'd0: align_line = {line[71:0], 888'd0};
			line[87:80] == 8'd0: align_line = {line[79:0], 880'd0};
			line[95:88] == 8'd0: align_line = {line[87:0], 872'd0};
			line[103:96] == 8'd0: align_line = {line[95:0], 864'd0};
			line[111:104] == 8'd0: align_line = {line[103:0], 856'd0};
			line[119:112] == 8'd0: align_line = {line[111:0], 848'd0};
			line[127:120] == 8'd0: align_line = {line[119:0], 840'd0};
			line[135:128] == 8'd0: align_line = {line[127:0], 832'd0};
			line[143:136] == 8'd0: align_line = {line[135:0], 824'd0};
			line[151:144] == 8'd0: align_line = {line[143:0], 816'd0};
			line[159:152] == 8'd0: align_line = {line[151:0], 808'd0};
			line[167:160] == 8'd0: align_line = {line[159:0], 800'd0};
			line[175:168] == 8'd0: align_line = {line[167:0], 792'd0};
			line[183:176] == 8'd0: align_line = {line[175:0], 784'd0};
			line[191:184] == 8'd0: align_line = {line[183:0], 776'd0};
			line[199:192] == 8'd0: align_line = {line[191:0], 768'd0};
			line[207:200] == 8'd0: align_line = {line[199:0], 760'd0};
			line[215:208] == 8'd0: align_line = {line[207:0], 752'd0};
			line[223:216] == 8'd0: align_line = {line[215:0], 744'd0};
			line[231:224] == 8'd0: align_line = {line[223:0], 736'd0};
			line[239:232] == 8'd0: align_line = {line[231:0], 728'd0};
			line[247:240] == 8'd0: align_line = {line[239:0], 720'd0};
			line[255:248] == 8'd0: align_line = {line[247:0], 712'd0};
			line[263:256] == 8'd0: align_line = {line[255:0], 704'd0};
			line[271:264] == 8'd0: align_line = {line[263:0], 696'd0};
			line[279:272] == 8'd0: align_line = {line[271:0], 688'd0};
			line[287:280] == 8'd0: align_line = {line[279:0], 680'd0};
			line[295:288] == 8'd0: align_line = {line[287:0], 672'd0};
			line[303:296] == 8'd0: align_line = {line[295:0], 664'd0};
			line[311:304] == 8'd0: align_line = {line[303:0], 656'd0};
			line[319:312] == 8'd0: align_line = {line[311:0], 648'd0};
			line[327:320] == 8'd0: align_line = {line[319:0], 640'd0};
			line[335:328] == 8'd0: align_line = {line[327:0], 632'd0};
			line[343:336] == 8'd0: align_line = {line[335:0], 624'd0};
			line[351:344] == 8'd0: align_line = {line[343:0], 616'd0};
			line[359:352] == 8'd0: align_line = {line[351:0], 608'd0};
			line[367:360] == 8'd0: align_line = {line[359:0], 600'd0};
			line[375:368] == 8'd0: align_line = {line[367:0], 592'd0};
			line[383:376] == 8'd0: align_line = {line[375:0], 584'd0};
			line[391:384] == 8'd0: align_line = {line[383:0], 576'd0};
			line[399:392] == 8'd0: align_line = {line[391:0], 568'd0};
			line[407:400] == 8'd0: align_line = {line[399:0], 560'd0};
			line[415:408] == 8'd0: align_line = {line[407:0], 552'd0};
			line[423:416] == 8'd0: align_line = {line[415:0], 544'd0};
			line[431:424] == 8'd0: align_line = {line[423:0], 536'd0};
			line[439:432] == 8'd0: align_line = {line[431:0], 528'd0};
			line[447:440] == 8'd0: align_line = {line[439:0], 520'd0};
			line[455:448] == 8'd0: align_line = {line[447:0], 512'd0};
			line[463:456] == 8'd0: align_line = {line[455:0], 504'd0};
			line[471:464] == 8'd0: align_line = {line[463:0], 496'd0};
			line[479:472] == 8'd0: align_line = {line[471:0], 488'd0};
			line[487:480] == 8'd0: align_line = {line[479:0], 480'd0};
			line[495:488] == 8'd0: align_line = {line[487:0], 472'd0};
			line[503:496] == 8'd0: align_line = {line[495:0], 464'd0};
			line[511:504] == 8'd0: align_line = {line[503:0], 456'd0};
			line[519:512] == 8'd0: align_line = {line[511:0], 448'd0};
			line[527:520] == 8'd0: align_line = {line[519:0], 440'd0};
			line[535:528] == 8'd0: align_line = {line[527:0], 432'd0};
			line[543:536] == 8'd0: align_line = {line[535:0], 424'd0};
			line[551:544] == 8'd0: align_line = {line[543:0], 416'd0};
			line[559:552] == 8'd0: align_line = {line[551:0], 408'd0};
			line[567:560] == 8'd0: align_line = {line[559:0], 400'd0};
			line[575:568] == 8'd0: align_line = {line[567:0], 392'd0};
			line[583:576] == 8'd0: align_line = {line[575:0], 384'd0};
			line[591:584] == 8'd0: align_line = {line[583:0], 376'd0};
			line[599:592] == 8'd0: align_line = {line[591:0], 368'd0};
			line[607:600] == 8'd0: align_line = {line[599:0], 360'd0};
			line[615:608] == 8'd0: align_line = {line[607:0], 352'd0};
			line[623:616] == 8'd0: align_line = {line[615:0], 344'd0};
			line[631:624] == 8'd0: align_line = {line[623:0], 336'd0};
			line[639:632] == 8'd0: align_line = {line[631:0], 328'd0};
			line[647:640] == 8'd0: align_line = {line[639:0], 320'd0};
			line[655:648] == 8'd0: align_line = {line[647:0], 312'd0};
			line[663:656] == 8'd0: align_line = {line[655:0], 304'd0};
			line[671:664] == 8'd0: align_line = {line[663:0], 296'd0};
			line[679:672] == 8'd0: align_line = {line[671:0], 288'd0};
			line[687:680] == 8'd0: align_line = {line[679:0], 280'd0};
			line[695:688] == 8'd0: align_line = {line[687:0], 272'd0};
			line[703:696] == 8'd0: align_line = {line[695:0], 264'd0};
			line[711:704] == 8'd0: align_line = {line[703:0], 256'd0};
			line[719:712] == 8'd0: align_line = {line[711:0], 248'd0};
			line[727:720] == 8'd0: align_line = {line[719:0], 240'd0};
			line[735:728] == 8'd0: align_line = {line[727:0], 232'd0};
			line[743:736] == 8'd0: align_line = {line[735:0], 224'd0};
			line[751:744] == 8'd0: align_line = {line[743:0], 216'd0};
			line[759:752] == 8'd0: align_line = {line[751:0], 208'd0};
			line[767:760] == 8'd0: align_line = {line[759:0], 200'd0};
			line[775:768] == 8'd0: align_line = {line[767:0], 192'd0};
			line[783:776] == 8'd0: align_line = {line[775:0], 184'd0};
			line[791:784] == 8'd0: align_line = {line[783:0], 176'd0};
			line[799:792] == 8'd0: align_line = {line[791:0], 168'd0};
			line[807:800] == 8'd0: align_line = {line[799:0], 160'd0};
			line[815:808] == 8'd0: align_line = {line[807:0], 152'd0};
			line[823:816] == 8'd0: align_line = {line[815:0], 144'd0};
			line[831:824] == 8'd0: align_line = {line[823:0], 136'd0};
			line[839:832] == 8'd0: align_line = {line[831:0], 128'd0};
			line[847:840] == 8'd0: align_line = {line[839:0], 120'd0};
			line[855:848] == 8'd0: align_line = {line[847:0], 112'd0};
			line[863:856] == 8'd0: align_line = {line[855:0], 104'd0};
			line[871:864] == 8'd0: align_line = {line[863:0], 96'd0};
			line[879:872] == 8'd0: align_line = {line[871:0], 88'd0};
			line[887:880] == 8'd0: align_line = {line[879:0], 80'd0};
			line[895:888] == 8'd0: align_line = {line[887:0], 72'd0};
			line[903:896] == 8'd0: align_line = {line[895:0], 64'd0};
			line[911:904] == 8'd0: align_line = {line[903:0], 56'd0};
			line[919:912] == 8'd0: align_line = {line[911:0], 48'd0};
			line[927:920] == 8'd0: align_line = {line[919:0], 40'd0};
			line[935:928] == 8'd0: align_line = {line[927:0], 32'd0};
			line[943:936] == 8'd0: align_line = {line[935:0], 24'd0};
			line[951:944] == 8'd0: align_line = {line[943:0], 16'd0};
			line[959:952] == 8'd0: align_line = {line[951:0], 8'd0};
			default: align_line = 960'd0;
		endcase
	endfunction
	wire [119:0] xCONTROL_STATE;
	wire [119:0] xMODE;
	assign xCONTROL_STATE = (control_state == RST_WAIT1 ? "RST_WAIT1" : (control_state == RST_WAIT2 ? "RST_WAIT2" : (control_state == INT_WAIT1 ? "INT_WAIT1" : (control_state == INT_WAIT2 ? "INT_WAIT2" : (control_state == EXECUTE ? "EXECUTE" : (control_state == PRE_FETCH_EXEC ? "PRE_FETCH_EXEC" : (control_state == MEM_WAIT1 ? "MEM_WAIT1" : (control_state == MEM_WAIT2 ? "MEM_WAIT2" : (control_state == PC_STALL1 ? "PC_STALL1" : (control_state == PC_STALL2 ? "PC_STALL2" : (control_state == MTRANS_EXEC1 ? "MTRANS_EXEC1" : (control_state == MTRANS_EXEC2 ? "MTRANS_EXEC2" : (control_state == MTRANS_EXEC3 ? "MTRANS_EXEC3" : (control_state == MTRANS_EXEC3B ? "MTRANS_EXEC3B" : (control_state == MTRANS_EXEC4 ? "MTRANS_EXEC4" : (control_state == MTRANS5_ABORT ? "MTRANS5_ABORT" : (control_state == MULT_PROC1 ? "MULT_PROC1" : (control_state == MULT_PROC2 ? "MULT_PROC2" : (control_state == MULT_STORE ? "MULT_STORE" : (control_state == MULT_ACCUMU ? "MULT_ACCUMU" : (control_state == SWAP_WRITE ? "SWAP_WRITE" : (control_state == SWAP_WAIT1 ? "SWAP_WAIT1" : (control_state == SWAP_WAIT2 ? "SWAP_WAIT2" : (control_state == COPRO_WAIT ? "COPRO_WAIT" : "UNKNOWN "))))))))))))))))))))))));
	assign xMODE = mode_name(o_status_bits_mode);
	always @(posedge i_clk)
		if ((control_state == EXECUTE) && ((instruction[0] === 1'bx) || (instruction[31] === 1'bx)))
			$display("Instruction with x's =%08h", instruction);
endmodule
