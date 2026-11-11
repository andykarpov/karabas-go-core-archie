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
	reg [23:0] r15 = 24'hc0ffee;
	reg [31:0] rf [0:31];
	wire usr_exec = i_mode_exec == USR;
	wire svc_exec = i_mode_exec == SVC;
	wire irq_exec = i_mode_exec == IRQ;
	wire firq_exec = i_mode_exec == FIRQ;
	wire usr_idec = i_user_mode_regs_load || (i_mode_idec == USR);
	wire svc_idec = !i_user_mode_regs_load && (i_mode_idec == SVC);
	wire irq_idec = !i_user_mode_regs_load && (i_mode_idec == IRQ);
	wire firq_idec = i_firq_not_user_mode;
	function [4:0] slot;
		input [3:0] sel;
		input u;
		input s;
		input i;
		input f;
		if ((!sel[3] || ((sel[3:2] == 2'b10) && !f)) || ((sel == 4'd12) && !f))
			slot = {1'b0, sel};
		else if (sel <= 4'd12)
			slot = {2'b10, sel[2:0]};
		else if (u)
			slot = {1'b0, sel};
		else if (s)
			slot = {3'b111, sel[1:0]};
		else if (i)
			slot = {3'b110, sel[1:0]};
		else
			slot = {2'b10, sel[2:0]};
	endfunction
	reg [3:0] wsel;
	integer k;
	always @(*) begin
		wsel = 4'd0;
		for (k = 0; k < 15; k = k + 1)
			if (i_reg_bank_wen[k])
				wsel = k;
	end
	wire wen = |i_reg_bank_wen;
	wire [4:0] w_slot = slot(wsel, usr_idec, svc_idec, irq_idec, firq_idec);
	wire [4:0] rm_slot = slot(i_rm_sel, usr_exec, svc_exec, irq_exec, firq_exec);
	wire [4:0] rn_slot = slot(i_rn_sel, usr_exec, svc_exec, irq_exec, firq_exec);
	wire [4:0] ds_slot = slot(i_rds_sel, i_mode_rds_exec[OH_USR], i_mode_rds_exec[OH_SVC], i_mode_rds_exec[OH_IRQ], i_mode_rds_exec[OH_FIRQ]);
	always @(posedge i_clk)
		if (i_reset)
			r15 <= 24'h000000;
		else if (!i_fetch_stall) begin
			if (wen)
				rf[w_slot] <= i_reg;
			r15 <= (i_pc_wen ? i_pc : r15);
		end
	wire [31:0] rm_ram = rf[rm_slot];
	wire [31:0] rn_ram = rf[rn_slot];
	wire [31:0] ds_ram = rf[ds_slot];
	wire [31:0] r15_out_rm = {i_status_bits_flags, i_status_bits_irq_mask, i_status_bits_firq_mask, r15, i_mode_exec};
	wire [31:0] r15_out_rm_nxt = {i_status_bits_flags, i_status_bits_irq_mask, i_status_bits_firq_mask, i_pc, i_mode_exec};
	wire [31:0] r15_out_rn = {6'd0, r15, 2'd0};
	assign o_pc = r15_out_rn;
	assign o_rm = (i_rm_sel == 4'd15 ? r15_out_rm : rm_ram);
	assign o_rn = (i_rn_sel == 4'd15 ? r15_out_rn : rn_ram);
	always @(*) o_rs = (i_rds_sel == 4'd15 ? r15_out_rn : ds_ram);
	always @(*) o_rd = (i_rds_sel == 4'd15 ? r15_out_rm_nxt : ds_ram);
endmodule
