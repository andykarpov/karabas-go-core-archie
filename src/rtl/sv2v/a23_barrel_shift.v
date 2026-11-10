module a23_barrel_shift (
	i_in,
	i_carry_in,
	i_shift_amount,
	i_shift_imm_zero,
	i_function,
	o_out,
	o_carry_out
);
	input [31:0] i_in;
	input i_carry_in;
	input [7:0] i_shift_amount;
	input i_shift_imm_zero;
	input [1:0] i_function;
	output wire [31:0] o_out;
	output wire o_carry_out;
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
	wire [32:0] lsl_out;
	wire [32:0] lsr_out;
	wire [32:0] asr_out;
	wire [32:0] ror_out;
	assign lsl_out = (i_shift_imm_zero ? {i_carry_in, i_in} : (i_shift_amount == 8'd0 ? {i_carry_in, i_in} : (i_shift_amount == 8'd1 ? {i_in[31], i_in[30:0], 1'd0} : (i_shift_amount == 8'd2 ? {i_in[30], i_in[29:0], 2'd0} : (i_shift_amount == 8'd3 ? {i_in[29], i_in[28:0], 3'd0} : (i_shift_amount == 8'd4 ? {i_in[28], i_in[27:0], 4'd0} : (i_shift_amount == 8'd5 ? {i_in[27], i_in[26:0], 5'd0} : (i_shift_amount == 8'd6 ? {i_in[26], i_in[25:0], 6'd0} : (i_shift_amount == 8'd7 ? {i_in[25], i_in[24:0], 7'd0} : (i_shift_amount == 8'd8 ? {i_in[24], i_in[23:0], 8'd0} : (i_shift_amount == 8'd9 ? {i_in[23], i_in[22:0], 9'd0} : (i_shift_amount == 8'd10 ? {i_in[22], i_in[21:0], 10'd0} : (i_shift_amount == 8'd11 ? {i_in[21], i_in[20:0], 11'd0} : (i_shift_amount == 8'd12 ? {i_in[20], i_in[19:0], 12'd0} : (i_shift_amount == 8'd13 ? {i_in[19], i_in[18:0], 13'd0} : (i_shift_amount == 8'd14 ? {i_in[18], i_in[17:0], 14'd0} : (i_shift_amount == 8'd15 ? {i_in[17], i_in[16:0], 15'd0} : (i_shift_amount == 8'd16 ? {i_in[16], i_in[15:0], 16'd0} : (i_shift_amount == 8'd17 ? {i_in[15], i_in[14:0], 17'd0} : (i_shift_amount == 8'd18 ? {i_in[14], i_in[13:0], 18'd0} : (i_shift_amount == 8'd19 ? {i_in[13], i_in[12:0], 19'd0} : (i_shift_amount == 8'd20 ? {i_in[12], i_in[11:0], 20'd0} : (i_shift_amount == 8'd21 ? {i_in[11], i_in[10:0], 21'd0} : (i_shift_amount == 8'd22 ? {i_in[10], i_in[9:0], 22'd0} : (i_shift_amount == 8'd23 ? {i_in[9], i_in[8:0], 23'd0} : (i_shift_amount == 8'd24 ? {i_in[8], i_in[7:0], 24'd0} : (i_shift_amount == 8'd25 ? {i_in[7], i_in[6:0], 25'd0} : (i_shift_amount == 8'd26 ? {i_in[6], i_in[5:0], 26'd0} : (i_shift_amount == 8'd27 ? {i_in[5], i_in[4:0], 27'd0} : (i_shift_amount == 8'd28 ? {i_in[4], i_in[3:0], 28'd0} : (i_shift_amount == 8'd29 ? {i_in[3], i_in[2:0], 29'd0} : (i_shift_amount == 8'd30 ? {i_in[2], i_in[1:0], 30'd0} : (i_shift_amount == 8'd31 ? {i_in[1], i_in[0:0], 31'd0} : (i_shift_amount == 8'd32 ? {i_in[0], 32'd0} : 33'h000000000))))))))))))))))))))))))))))))))));
	assign lsr_out = (i_shift_imm_zero ? {i_in[31], 32'd0} : (i_shift_amount == 8'd0 ? {i_carry_in, i_in} : (i_shift_amount == 8'd1 ? {i_in[0], 1'd0, i_in[31:1]} : (i_shift_amount == 8'd2 ? {i_in[1], 2'd0, i_in[31:2]} : (i_shift_amount == 8'd3 ? {i_in[2], 3'd0, i_in[31:3]} : (i_shift_amount == 8'd4 ? {i_in[3], 4'd0, i_in[31:4]} : (i_shift_amount == 8'd5 ? {i_in[4], 5'd0, i_in[31:5]} : (i_shift_amount == 8'd6 ? {i_in[5], 6'd0, i_in[31:6]} : (i_shift_amount == 8'd7 ? {i_in[6], 7'd0, i_in[31:7]} : (i_shift_amount == 8'd8 ? {i_in[7], 8'd0, i_in[31:8]} : (i_shift_amount == 8'd9 ? {i_in[8], 9'd0, i_in[31:9]} : (i_shift_amount == 8'd10 ? {i_in[9], 10'd0, i_in[31:10]} : (i_shift_amount == 8'd11 ? {i_in[10], 11'd0, i_in[31:11]} : (i_shift_amount == 8'd12 ? {i_in[11], 12'd0, i_in[31:12]} : (i_shift_amount == 8'd13 ? {i_in[12], 13'd0, i_in[31:13]} : (i_shift_amount == 8'd14 ? {i_in[13], 14'd0, i_in[31:14]} : (i_shift_amount == 8'd15 ? {i_in[14], 15'd0, i_in[31:15]} : (i_shift_amount == 8'd16 ? {i_in[15], 16'd0, i_in[31:16]} : (i_shift_amount == 8'd17 ? {i_in[16], 17'd0, i_in[31:17]} : (i_shift_amount == 8'd18 ? {i_in[17], 18'd0, i_in[31:18]} : (i_shift_amount == 8'd19 ? {i_in[18], 19'd0, i_in[31:19]} : (i_shift_amount == 8'd20 ? {i_in[19], 20'd0, i_in[31:20]} : (i_shift_amount == 8'd21 ? {i_in[20], 21'd0, i_in[31:21]} : (i_shift_amount == 8'd22 ? {i_in[21], 22'd0, i_in[31:22]} : (i_shift_amount == 8'd23 ? {i_in[22], 23'd0, i_in[31:23]} : (i_shift_amount == 8'd24 ? {i_in[23], 24'd0, i_in[31:24]} : (i_shift_amount == 8'd25 ? {i_in[24], 25'd0, i_in[31:25]} : (i_shift_amount == 8'd26 ? {i_in[25], 26'd0, i_in[31:26]} : (i_shift_amount == 8'd27 ? {i_in[26], 27'd0, i_in[31:27]} : (i_shift_amount == 8'd28 ? {i_in[27], 28'd0, i_in[31:28]} : (i_shift_amount == 8'd29 ? {i_in[28], 29'd0, i_in[31:29]} : (i_shift_amount == 8'd30 ? {i_in[29], 30'd0, i_in[31:30]} : (i_shift_amount == 8'd31 ? {i_in[30], 31'd0, i_in[31]} : (i_shift_amount == 8'd32 ? {i_in[31], 32'd0} : 33'h000000000))))))))))))))))))))))))))))))))));
	assign asr_out = (i_shift_imm_zero ? {i_in[31], {32 {i_in[31]}}} : (i_shift_amount == 8'd0 ? {i_carry_in, i_in} : (i_shift_amount == 8'd1 ? {i_in[0], {2 {i_in[31]}}, i_in[30:1]} : (i_shift_amount == 8'd2 ? {i_in[1], {3 {i_in[31]}}, i_in[30:2]} : (i_shift_amount == 8'd3 ? {i_in[2], {4 {i_in[31]}}, i_in[30:3]} : (i_shift_amount == 8'd4 ? {i_in[3], {5 {i_in[31]}}, i_in[30:4]} : (i_shift_amount == 8'd5 ? {i_in[4], {6 {i_in[31]}}, i_in[30:5]} : (i_shift_amount == 8'd6 ? {i_in[5], {7 {i_in[31]}}, i_in[30:6]} : (i_shift_amount == 8'd7 ? {i_in[6], {8 {i_in[31]}}, i_in[30:7]} : (i_shift_amount == 8'd8 ? {i_in[7], {9 {i_in[31]}}, i_in[30:8]} : (i_shift_amount == 8'd9 ? {i_in[8], {10 {i_in[31]}}, i_in[30:9]} : (i_shift_amount == 8'd10 ? {i_in[9], {11 {i_in[31]}}, i_in[30:10]} : (i_shift_amount == 8'd11 ? {i_in[10], {12 {i_in[31]}}, i_in[30:11]} : (i_shift_amount == 8'd12 ? {i_in[11], {13 {i_in[31]}}, i_in[30:12]} : (i_shift_amount == 8'd13 ? {i_in[12], {14 {i_in[31]}}, i_in[30:13]} : (i_shift_amount == 8'd14 ? {i_in[13], {15 {i_in[31]}}, i_in[30:14]} : (i_shift_amount == 8'd15 ? {i_in[14], {16 {i_in[31]}}, i_in[30:15]} : (i_shift_amount == 8'd16 ? {i_in[15], {17 {i_in[31]}}, i_in[30:16]} : (i_shift_amount == 8'd17 ? {i_in[16], {18 {i_in[31]}}, i_in[30:17]} : (i_shift_amount == 8'd18 ? {i_in[17], {19 {i_in[31]}}, i_in[30:18]} : (i_shift_amount == 8'd19 ? {i_in[18], {20 {i_in[31]}}, i_in[30:19]} : (i_shift_amount == 8'd20 ? {i_in[19], {21 {i_in[31]}}, i_in[30:20]} : (i_shift_amount == 8'd21 ? {i_in[20], {22 {i_in[31]}}, i_in[30:21]} : (i_shift_amount == 8'd22 ? {i_in[21], {23 {i_in[31]}}, i_in[30:22]} : (i_shift_amount == 8'd23 ? {i_in[22], {24 {i_in[31]}}, i_in[30:23]} : (i_shift_amount == 8'd24 ? {i_in[23], {25 {i_in[31]}}, i_in[30:24]} : (i_shift_amount == 8'd25 ? {i_in[24], {26 {i_in[31]}}, i_in[30:25]} : (i_shift_amount == 8'd26 ? {i_in[25], {27 {i_in[31]}}, i_in[30:26]} : (i_shift_amount == 8'd27 ? {i_in[26], {28 {i_in[31]}}, i_in[30:27]} : (i_shift_amount == 8'd28 ? {i_in[27], {29 {i_in[31]}}, i_in[30:28]} : (i_shift_amount == 8'd29 ? {i_in[28], {30 {i_in[31]}}, i_in[30:29]} : (i_shift_amount == 8'd30 ? {i_in[29], {31 {i_in[31]}}, i_in[30]} : (i_shift_amount == 8'd31 ? {i_in[30], {32 {i_in[31]}}} : {i_in[31], {32 {i_in[31]}}})))))))))))))))))))))))))))))))));
	assign ror_out = (i_shift_imm_zero ? {i_in[0], i_carry_in, i_in[31:1]} : (i_shift_amount[7:0] == 8'd0 ? {i_carry_in, i_in} : (i_shift_amount[4:0] == 5'd0 ? {i_in[31], i_in} : (i_shift_amount[4:0] == 5'd1 ? {i_in[0], i_in[0], i_in[31:1]} : (i_shift_amount[4:0] == 5'd2 ? {i_in[1], i_in[1:0], i_in[31:2]} : (i_shift_amount[4:0] == 5'd3 ? {i_in[2], i_in[2:0], i_in[31:3]} : (i_shift_amount[4:0] == 5'd4 ? {i_in[3], i_in[3:0], i_in[31:4]} : (i_shift_amount[4:0] == 5'd5 ? {i_in[4], i_in[4:0], i_in[31:5]} : (i_shift_amount[4:0] == 5'd6 ? {i_in[5], i_in[5:0], i_in[31:6]} : (i_shift_amount[4:0] == 5'd7 ? {i_in[6], i_in[6:0], i_in[31:7]} : (i_shift_amount[4:0] == 5'd8 ? {i_in[7], i_in[7:0], i_in[31:8]} : (i_shift_amount[4:0] == 5'd9 ? {i_in[8], i_in[8:0], i_in[31:9]} : (i_shift_amount[4:0] == 5'd10 ? {i_in[9], i_in[9:0], i_in[31:10]} : (i_shift_amount[4:0] == 5'd11 ? {i_in[10], i_in[10:0], i_in[31:11]} : (i_shift_amount[4:0] == 5'd12 ? {i_in[11], i_in[11:0], i_in[31:12]} : (i_shift_amount[4:0] == 5'd13 ? {i_in[12], i_in[12:0], i_in[31:13]} : (i_shift_amount[4:0] == 5'd14 ? {i_in[13], i_in[13:0], i_in[31:14]} : (i_shift_amount[4:0] == 5'd15 ? {i_in[14], i_in[14:0], i_in[31:15]} : (i_shift_amount[4:0] == 5'd16 ? {i_in[15], i_in[15:0], i_in[31:16]} : (i_shift_amount[4:0] == 5'd17 ? {i_in[16], i_in[16:0], i_in[31:17]} : (i_shift_amount[4:0] == 5'd18 ? {i_in[17], i_in[17:0], i_in[31:18]} : (i_shift_amount[4:0] == 5'd19 ? {i_in[18], i_in[18:0], i_in[31:19]} : (i_shift_amount[4:0] == 5'd20 ? {i_in[19], i_in[19:0], i_in[31:20]} : (i_shift_amount[4:0] == 5'd21 ? {i_in[20], i_in[20:0], i_in[31:21]} : (i_shift_amount[4:0] == 5'd22 ? {i_in[21], i_in[21:0], i_in[31:22]} : (i_shift_amount[4:0] == 5'd23 ? {i_in[22], i_in[22:0], i_in[31:23]} : (i_shift_amount[4:0] == 5'd24 ? {i_in[23], i_in[23:0], i_in[31:24]} : (i_shift_amount[4:0] == 5'd25 ? {i_in[24], i_in[24:0], i_in[31:25]} : (i_shift_amount[4:0] == 5'd26 ? {i_in[25], i_in[25:0], i_in[31:26]} : (i_shift_amount[4:0] == 5'd27 ? {i_in[26], i_in[26:0], i_in[31:27]} : (i_shift_amount[4:0] == 5'd28 ? {i_in[27], i_in[27:0], i_in[31:28]} : (i_shift_amount[4:0] == 5'd29 ? {i_in[28], i_in[28:0], i_in[31:29]} : (i_shift_amount[4:0] == 5'd30 ? {i_in[29], i_in[29:0], i_in[31:30]} : {i_in[30], i_in[30:0], i_in[31:31]})))))))))))))))))))))))))))))))));
	assign {o_carry_out, o_out} = (i_function == LSL ? lsl_out : (i_function == LSR ? lsr_out : (i_function == ASR ? asr_out : ror_out)));
endmodule
