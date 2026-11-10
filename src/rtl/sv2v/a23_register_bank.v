module a23_register_bank (
	i_clk,
	i_reset,
	i_fetch_stall,
	i_mode_idec,
	i_mode_exec,
	i_mode_rds_exec,
	i_user_mode_regs_load,
	i_firq_not_user_mode,
	i_rm_sel,
	i_rds_sel,
	i_rn_sel,
	i_pc_wen,
	i_reg_bank_wen,
	i_pc,
	i_reg,
	i_status_bits_flags,
	i_status_bits_irq_mask,
	i_status_bits_firq_mask,
	o_rm,
	o_rs,
	o_rd,
	o_rn,
	o_pc
);
	input i_clk;
	input i_reset;
	input i_fetch_stall;
	input [1:0] i_mode_idec;
	input [1:0] i_mode_exec;
	input [3:0] i_mode_rds_exec;
	input i_user_mode_regs_load;
	input i_firq_not_user_mode;
	input [3:0] i_rm_sel;
	input [3:0] i_rds_sel;
	input [3:0] i_rn_sel;
	input i_pc_wen;
	input [14:0] i_reg_bank_wen;
	input [23:0] i_pc;
	input [31:0] i_reg;
	input [3:0] i_status_bits_flags;
	input i_status_bits_irq_mask;
	input i_status_bits_firq_mask;
	output wire [31:0] o_rm;
	output reg [31:0] o_rs;
	output reg [31:0] o_rd;
	output wire [31:0] o_rn;
	output wire [31:0] o_pc;
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
	reg [31:0] r0 = 32'hdeadbeef;
	reg [31:0] r1 = 32'hdeadbeef;
	reg [31:0] r2 = 32'hdeadbeef;
	reg [31:0] r3 = 32'hdeadbeef;
	reg [31:0] r4 = 32'hdeadbeef;
	reg [31:0] r5 = 32'hdeadbeef;
	reg [31:0] r6 = 32'hdeadbeef;
	reg [31:0] r7 = 32'hdeadbeef;
	reg [31:0] r8 = 32'hdeadbeef;
	reg [31:0] r9 = 32'hdeadbeef;
	reg [31:0] r10 = 32'hdeadbeef;
	reg [31:0] r11 = 32'hdeadbeef;
	reg [31:0] r12 = 32'hdeadbeef;
	reg [31:0] r13 = 32'hdeadbeef;
	reg [31:0] r14 = 32'hdeadbeef;
	reg [23:0] r15 = 24'hc0ffee;
	wire [31:0] r0_out;
	wire [31:0] r1_out;
	wire [31:0] r2_out;
	wire [31:0] r3_out;
	wire [31:0] r4_out;
	wire [31:0] r5_out;
	wire [31:0] r6_out;
	wire [31:0] r7_out;
	wire [31:0] r8_out;
	wire [31:0] r9_out;
	wire [31:0] r10_out;
	wire [31:0] r11_out;
	wire [31:0] r12_out;
	wire [31:0] r13_out;
	wire [31:0] r14_out;
	wire [31:0] r15_out_rm;
	wire [31:0] r15_out_rm_nxt;
	wire [31:0] r15_out_rn;
	wire [31:0] r8_rds;
	wire [31:0] r9_rds;
	wire [31:0] r10_rds;
	wire [31:0] r11_rds;
	wire [31:0] r12_rds;
	wire [31:0] r13_rds;
	wire [31:0] r14_rds;
	reg [31:0] r13_svc = 32'hdeadbeef;
	reg [31:0] r14_svc = 32'hdeadbeef;
	reg [31:0] r13_irq = 32'hdeadbeef;
	reg [31:0] r14_irq = 32'hdeadbeef;
	reg [31:0] r8_firq = 32'hdeadbeef;
	reg [31:0] r9_firq = 32'hdeadbeef;
	reg [31:0] r10_firq = 32'hdeadbeef;
	reg [31:0] r11_firq = 32'hdeadbeef;
	reg [31:0] r12_firq = 32'hdeadbeef;
	reg [31:0] r13_firq = 32'hdeadbeef;
	reg [31:0] r14_firq = 32'hdeadbeef;
	wire usr_exec;
	wire svc_exec;
	wire irq_exec;
	wire firq_exec;
	wire usr_idec;
	wire svc_idec;
	wire irq_idec;
	wire firq_idec;
	assign usr_idec = i_user_mode_regs_load || (i_mode_idec == USR);
	assign svc_idec = !i_user_mode_regs_load && (i_mode_idec == SVC);
	assign irq_idec = !i_user_mode_regs_load && (i_mode_idec == IRQ);
	assign firq_idec = i_firq_not_user_mode;
	assign usr_exec = i_mode_exec == USR;
	assign svc_exec = i_mode_exec == SVC;
	assign irq_exec = i_mode_exec == IRQ;
	assign firq_exec = i_mode_exec == FIRQ;
	always @(posedge i_clk)
		if (i_reset) begin
			r0 <= 32'hdeadbeef;
			r1 <= 32'hdeadbeef;
			r2 <= 32'hdeadbeef;
			r3 <= 32'hdeadbeef;
			r4 <= 32'hdeadbeef;
			r5 <= 32'hdeadbeef;
			r6 <= 32'hdeadbeef;
			r7 <= 32'hdeadbeef;
			r8 <= 32'hdeadbeef;
			r9 <= 32'hdeadbeef;
			r10 <= 32'hdeadbeef;
			r11 <= 32'hdeadbeef;
			r12 <= 32'hdeadbeef;
			r8_firq <= 32'hdeadbeef;
			r9_firq <= 32'hdeadbeef;
			r10_firq <= 32'hdeadbeef;
			r11_firq <= 32'hdeadbeef;
			r12_firq <= 32'hdeadbeef;
			r13 <= 32'hdeadbeef;
			r14 <= 32'hdeadbeef;
			r13_svc <= 32'hdeadbeef;
			r14_svc <= 32'hdeadbeef;
			r13_irq <= 32'hdeadbeef;
			r14_irq <= 32'hdeadbeef;
			r13_firq <= 32'hdeadbeef;
			r14_firq <= 32'hdeadbeef;
			r15 <= 24'h000000;
		end
		else if (!i_fetch_stall) begin
			r0 <= (i_reg_bank_wen[0] ? i_reg : r0);
			r1 <= (i_reg_bank_wen[1] ? i_reg : r1);
			r2 <= (i_reg_bank_wen[2] ? i_reg : r2);
			r3 <= (i_reg_bank_wen[3] ? i_reg : r3);
			r4 <= (i_reg_bank_wen[4] ? i_reg : r4);
			r5 <= (i_reg_bank_wen[5] ? i_reg : r5);
			r6 <= (i_reg_bank_wen[6] ? i_reg : r6);
			r7 <= (i_reg_bank_wen[7] ? i_reg : r7);
			r8 <= (i_reg_bank_wen[8] && !firq_idec ? i_reg : r8);
			r9 <= (i_reg_bank_wen[9] && !firq_idec ? i_reg : r9);
			r10 <= (i_reg_bank_wen[10] && !firq_idec ? i_reg : r10);
			r11 <= (i_reg_bank_wen[11] && !firq_idec ? i_reg : r11);
			r12 <= (i_reg_bank_wen[12] && !firq_idec ? i_reg : r12);
			r8_firq <= (i_reg_bank_wen[8] && firq_idec ? i_reg : r8_firq);
			r9_firq <= (i_reg_bank_wen[9] && firq_idec ? i_reg : r9_firq);
			r10_firq <= (i_reg_bank_wen[10] && firq_idec ? i_reg : r10_firq);
			r11_firq <= (i_reg_bank_wen[11] && firq_idec ? i_reg : r11_firq);
			r12_firq <= (i_reg_bank_wen[12] && firq_idec ? i_reg : r12_firq);
			r13 <= (i_reg_bank_wen[13] && usr_idec ? i_reg : r13);
			r14 <= (i_reg_bank_wen[14] && usr_idec ? i_reg : r14);
			r13_svc <= (i_reg_bank_wen[13] && svc_idec ? i_reg : r13_svc);
			r14_svc <= (i_reg_bank_wen[14] && svc_idec ? i_reg : r14_svc);
			r13_irq <= (i_reg_bank_wen[13] && irq_idec ? i_reg : r13_irq);
			r14_irq <= (i_reg_bank_wen[14] && irq_idec ? i_reg : r14_irq);
			r13_firq <= (i_reg_bank_wen[13] && firq_idec ? i_reg : r13_firq);
			r14_firq <= (i_reg_bank_wen[14] && firq_idec ? i_reg : r14_firq);
			r15 <= (i_pc_wen ? i_pc : r15);
		end
	assign r0_out = r0;
	assign r1_out = r1;
	assign r2_out = r2;
	assign r3_out = r3;
	assign r4_out = r4;
	assign r5_out = r5;
	assign r6_out = r6;
	assign r7_out = r7;
	assign r8_out = (firq_exec ? r8_firq : r8);
	assign r9_out = (firq_exec ? r9_firq : r9);
	assign r10_out = (firq_exec ? r10_firq : r10);
	assign r11_out = (firq_exec ? r11_firq : r11);
	assign r12_out = (firq_exec ? r12_firq : r12);
	assign r13_out = (usr_exec ? r13 : (svc_exec ? r13_svc : (irq_exec ? r13_irq : r13_firq)));
	assign r14_out = (usr_exec ? r14 : (svc_exec ? r14_svc : (irq_exec ? r14_irq : r14_firq)));
	assign r15_out_rm = {i_status_bits_flags, i_status_bits_irq_mask, i_status_bits_firq_mask, r15, i_mode_exec};
	assign r15_out_rm_nxt = {i_status_bits_flags, i_status_bits_irq_mask, i_status_bits_firq_mask, i_pc, i_mode_exec};
	assign r15_out_rn = {6'd0, r15, 2'd0};
	assign r8_rds = (i_mode_rds_exec[OH_FIRQ] ? r8_firq : r8);
	assign r9_rds = (i_mode_rds_exec[OH_FIRQ] ? r9_firq : r9);
	assign r10_rds = (i_mode_rds_exec[OH_FIRQ] ? r10_firq : r10);
	assign r11_rds = (i_mode_rds_exec[OH_FIRQ] ? r11_firq : r11);
	assign r12_rds = (i_mode_rds_exec[OH_FIRQ] ? r12_firq : r12);
	assign r13_rds = (i_mode_rds_exec[OH_USR] ? r13 : (i_mode_rds_exec[OH_SVC] ? r13_svc : (i_mode_rds_exec[OH_IRQ] ? r13_irq : r13_firq)));
	assign r14_rds = (i_mode_rds_exec[OH_USR] ? r14 : (i_mode_rds_exec[OH_SVC] ? r14_svc : (i_mode_rds_exec[OH_IRQ] ? r14_irq : r14_firq)));
	assign o_pc = r15_out_rn;
	assign o_rm = (i_rm_sel == 4'd0 ? r0_out : (i_rm_sel == 4'd1 ? r1_out : (i_rm_sel == 4'd2 ? r2_out : (i_rm_sel == 4'd3 ? r3_out : (i_rm_sel == 4'd4 ? r4_out : (i_rm_sel == 4'd5 ? r5_out : (i_rm_sel == 4'd6 ? r6_out : (i_rm_sel == 4'd7 ? r7_out : (i_rm_sel == 4'd8 ? r8_out : (i_rm_sel == 4'd9 ? r9_out : (i_rm_sel == 4'd10 ? r10_out : (i_rm_sel == 4'd11 ? r11_out : (i_rm_sel == 4'd12 ? r12_out : (i_rm_sel == 4'd13 ? r13_out : (i_rm_sel == 4'd14 ? r14_out : r15_out_rm)))))))))))))));
	always @(*)
		case (i_rds_sel)
			4'd0: o_rs = r0_out;
			4'd1: o_rs = r1_out;
			4'd2: o_rs = r2_out;
			4'd3: o_rs = r3_out;
			4'd4: o_rs = r4_out;
			4'd5: o_rs = r5_out;
			4'd6: o_rs = r6_out;
			4'd7: o_rs = r7_out;
			4'd8: o_rs = r8_rds;
			4'd9: o_rs = r9_rds;
			4'd10: o_rs = r10_rds;
			4'd11: o_rs = r11_rds;
			4'd12: o_rs = r12_rds;
			4'd13: o_rs = r13_rds;
			4'd14: o_rs = r14_rds;
			default: o_rs = r15_out_rn;
		endcase
	always @(*)
		case (i_rds_sel)
			4'd0: o_rd = r0_out;
			4'd1: o_rd = r1_out;
			4'd2: o_rd = r2_out;
			4'd3: o_rd = r3_out;
			4'd4: o_rd = r4_out;
			4'd5: o_rd = r5_out;
			4'd6: o_rd = r6_out;
			4'd7: o_rd = r7_out;
			4'd8: o_rd = r8_rds;
			4'd9: o_rd = r9_rds;
			4'd10: o_rd = r10_rds;
			4'd11: o_rd = r11_rds;
			4'd12: o_rd = r12_rds;
			4'd13: o_rd = r13_rds;
			4'd14: o_rd = r14_rds;
			default: o_rd = r15_out_rm_nxt;
		endcase
	assign o_rn = (i_rn_sel == 4'd0 ? r0_out : (i_rn_sel == 4'd1 ? r1_out : (i_rn_sel == 4'd2 ? r2_out : (i_rn_sel == 4'd3 ? r3_out : (i_rn_sel == 4'd4 ? r4_out : (i_rn_sel == 4'd5 ? r5_out : (i_rn_sel == 4'd6 ? r6_out : (i_rn_sel == 4'd7 ? r7_out : (i_rn_sel == 4'd8 ? r8_out : (i_rn_sel == 4'd9 ? r9_out : (i_rn_sel == 4'd10 ? r10_out : (i_rn_sel == 4'd11 ? r11_out : (i_rn_sel == 4'd12 ? r12_out : (i_rn_sel == 4'd13 ? r13_out : (i_rn_sel == 4'd14 ? r14_out : r15_out_rn)))))))))))))));
endmodule
