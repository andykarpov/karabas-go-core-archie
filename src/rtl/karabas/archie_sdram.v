`timescale 1ns / 1ps
`default_nettype none
/*
 archie_sdram.v

 The SDRAM of the board (MT48LC16M16A2: 16 bits, 4 banks x 8192 rows x 512 columns) for the whole
 Archimedes: the RAM (4 MB, bank 0), the RISC OS ROM (bank 1) and the frame buffer (bank 2). One
 controller on clk (84 MHz, twice wb_clk and from the same PLL), three ports:

 - wishbone (wb_clk, 42 MHz: MEMC of archimedes_top and the ROM loader), with the behaviour of the
   sdram.v of Archie_MiSTer that the machine expects: a read answers four 32-bit words, an ack on four
   wb_clk in a row, starting at the asked word and wrapping in its 16-byte line; a write (one 32-bit
   word with the byte selects) one ack. Address map as MiSTer: bank wb_adr[23:22], row wb_adr[21:10],
   column { wb_adr[9:2], half }. Handshake as MiSTer: a new request (stb & cyc & ~ack rising) toggles
   req_t in wb_clk; clk serves it and toggles done_t; wb_clk then sends the acks.
 - frame buffer write (clk): fbw_req (a pulse, while not fbw_busy) with fbw_row ({ frame, line }:
   the SDRAM rows { fbw_row, half } of bank 2), fbw_len (words, up to 1024) and fbw_buf: the words
   come from the capture buffer, fbw_addr = { fbw_buf, word } with fbw_data a clock later.
   fbw_busy until the line is in.
 - frame buffer read (clk): fbr_req with fbr_row / fbr_len / fbr_buf: the words go out as
   fbr_we / fbr_addr ({ fbr_buf, word }) / fbr_data. fbr_busy until done.
 A frame buffer line is served in runs (an ACTIVE, READs or WRITEs one per clock, a PRECHARGE): a run
 ends at the end of the SDRAM row, at the end of the line, after CHUNK words, or as soon as the machine
 asks (wb_pend) or a refresh is due, so a request of the machine waits a few clocks only (the VIDC
 FIFOs). Between runs: a refresh due first, then the machine, then the frame buffer read (it has a
 deadline: the next output line), then the write. A line longer than 512 words goes on in the next row.

 Timing (clk 11.9 ns): tRCD 2, tRP 2, tRC 6 (ACTIVE to ACTIVE), tWR 2, tRFC 6 clocks; CAS latency 2,
 burst 1: a run of READ / WRITE commands one per clock in an open row, the last with auto precharge.
 SDR_CLK is clk inverted (ODDR2 in the top): commands, address and write data in IOB flip-flops on
 the rising edge of clk have half a period of setup and hold at the SDRAM; read data are taken by an
 IOB flip-flop on the falling edge of clk, RD_DELAY clocks after the READ (msx2_fb_sdram.v).
 Refresh: 8192 in 64 ms (one per REFRESH_CLOCKS), owed ones made when idle.
*/
module archie_sdram #(
	parameter INIT_CLOCKS = 15'd18000,    // 214 us at 84 MHz
	parameter REFRESH_CLOCKS = 10'd640,   // 7.6 us
	parameter CHUNK = 7'd64,
	parameter RD_DELAY = 3
) (
	input wire clk,
	input wire wb_clk,
	input wire reset,                     // clk
	output wire ready,                    // init done (clk)

	// wishbone (wb_clk)
	input wire wb_cyc,
	input wire wb_stb,
	input wire wb_we,
	input wire [3:0] wb_sel,
	input wire [23:2] wb_adr,
	input wire [31:0] wb_dat_i,
	output reg [31:0] wb_dat_o = 32'd0,
	output reg wb_ack = 1'b0,

	// frame buffer write (clk)
	input wire fbw_req,
	input wire [11:0] fbw_row,
	input wire [10:0] fbw_len,
	input wire fbw_buf,
	output reg [10:0] fbw_addr = 11'd0,
	input wire [15:0] fbw_data,
	output wire fbw_busy,

	// frame buffer read (clk)
	input wire fbr_req,
	input wire [11:0] fbr_row,
	input wire [10:0] fbr_len,
	input wire fbr_buf,
	output reg fbr_we = 1'b0,
	output reg [10:0] fbr_addr = 11'd0,
	output reg [15:0] fbr_data = 16'd0,
	output wire fbr_busy,

	// SDRAM
	output wire [12:0] sdr_a,
	output wire [1:0] sdr_ba,
	inout wire [15:0] sdr_dq,
	output wire [1:0] sdr_dqm,
	output wire sdr_ras_n,
	output wire sdr_cas_n,
	output wire sdr_we_n
);

localparam [2:0] CMD_NOP = 3'b111, CMD_ACTIVE = 3'b011, CMD_READ = 3'b101, CMD_WRITE = 3'b100,
	CMD_PRECHARGE = 3'b010, CMD_REFRESH = 3'b001, CMD_MODE = 3'b000;

localparam [3:0] S_INIT = 0, S_INIT_PRE = 1, S_INIT_REF1 = 2, S_INIT_REF2 = 3, S_INIT_MODE = 4,
	S_IDLE = 5, S_WAIT = 6, S_WB_RD = 7, S_WB_WR = 8, S_WB_RDEND = 9, S_FBR = 10, S_FB_PRE = 11,
	S_FBW_PRE = 12, S_FBW = 13;

// ---------------------------------------------------------------- wishbone side (wb_clk)

reg req_t = 1'b0;                     // toggled for each new request
reg done_wb1 = 1'b0, done_wb2 = 1'b0;
reg done_t = 1'b0;                    // clk: toggled when a request is served
reg [31:0] rd_word [0:3];             // clk: the four words of a read, in burst order
reg [1:0] ack_n = 2'd0;               // wb_clk: acks still to send
reg [1:0] ack_w = 2'd0;
reg req_prev = 1'b0;
wire wb_req = wb_cyc & wb_stb & ~wb_ack;

always @(posedge wb_clk) begin
	wb_ack <= 1'b0;
	req_prev <= wb_req;
	if (wb_req && !req_prev && ack_n == 2'd0)
		req_t <= ~req_t;
	done_wb1 <= done_t;
	done_wb2 <= done_wb1;
	if (!(wb_cyc & wb_stb)) ack_n <= 2'd0;
	if (done_wb1 != done_wb2 && (wb_cyc & wb_stb)) begin
		wb_ack <= 1'b1;
		wb_dat_o <= rd_word[0];
		ack_w <= 2'd1;
		ack_n <= wb_we ? 2'd0 : 2'd3;
	end else if (ack_n != 2'd0 && (wb_cyc & wb_stb)) begin
		wb_ack <= 1'b1;
		wb_dat_o <= rd_word[ack_w];
		ack_w <= ack_w + 2'd1;
		ack_n <= ack_n - 2'd1;
	end
end

// ---------------------------------------------------------------- SDRAM pins

(* IOB = "TRUE" *) reg [12:0] a_r = 13'd0;
(* IOB = "TRUE" *) reg [1:0] ba_r = 2'b00;
(* IOB = "TRUE" *) reg [1:0] dqm_r = 2'b11;
(* IOB = "TRUE" *) reg ras_r = 1'b1;
(* IOB = "TRUE" *) reg cas_r = 1'b1;
(* IOB = "TRUE" *) reg we_r = 1'b1;
(* IOB = "TRUE" *) reg [15:0] dq_out = 16'd0;
(* IOB = "TRUE", equivalent_register_removal = "no" *) reg [15:0] dq_oe_n = 16'hFFFF;
(* IOB = "TRUE" *) reg [15:0] dq_neg = 16'd0;

assign sdr_a = a_r;
assign sdr_ba = ba_r;
assign sdr_dqm = dqm_r;
assign sdr_ras_n = ras_r;
assign sdr_cas_n = cas_r;
assign sdr_we_n = we_r;
genvar i;
generate
	for (i = 0; i < 16; i = i + 1) begin : g_dq
		assign sdr_dq[i] = dq_oe_n[i] ? 1'bz : dq_out[i];
	end
endgenerate

always @(negedge clk)
	dq_neg <= sdr_dq;

// ---------------------------------------------------------------- controller (clk)

reg [3:0] state = S_INIT;
reg [3:0] next_state = S_IDLE;
reg [14:0] cnt = 15'd0;
reg [9:0] ref_cnt = 10'd0;
reg [2:0] ref_owed = 3'd0;
reg init_done = 1'b0;
assign ready = init_done;

// the wishbone request, seen in clk (wb_clk signals are stable for two clk)
reg req_c1 = 1'b0, req_seen = 1'b0;
wire wb_pend = req_c1 != req_seen;
reg [23:2] w_adr = 22'd0;
reg [31:0] w_dat = 32'd0;
reg [3:0] w_sel = 4'd0;
reg w_we = 1'b0;

// frame buffer lines: the row of the line, the next word (= { half, column }), the words left,
// the commands left in the chunk
reg fbw_pend = 1'b0, fbr_pend = 1'b0;
reg [11:0] fbw_r = 12'd0, fbr_r = 12'd0;
reg [9:0] fbw_pos = 10'd0, fbr_pos = 10'd0;
reg [10:0] fbw_left = 11'd0, fbr_left = 11'd0;
reg fbw_b = 1'b0, fbr_b = 1'b0;
reg [6:0] run = 7'd0;
reg [2:0] act_cnt = 3'd0;             // clocks since the ACTIVE of a frame buffer run (to 7)
reg [1:0] wr_cnt = 2'd0;              // clocks since its last WRITE (to 3)
reg fb_wr = 1'b0;                     // the run is a write
assign fbw_busy = fbw_pend;
assign fbr_busy = fbr_pend;
reg [9:0] fbr_next = 10'd0;           // the word of the next read data
// the last command of a run: the end of the line, of the row, of CHUNK, a request of the machine,
// a refresh due
wire fbr_last = fbr_left == 11'd1 || fbr_pos[8:0] == 9'd511 || run == 7'd1 || wb_pend || ref_owed != 3'd0;
wire fbw_last = fbw_left == 11'd1 || fbw_pos[8:0] == 9'd511 || run == 7'd1 || wb_pend || ref_owed != 3'd0;
reg [RD_DELAY:0] rd_pipe = 0;         // a READ RD_DELAY clocks ago (frame buffer)
reg [RD_DELAY:0] wb_pipe = 0;         // a READ RD_DELAY clocks ago (wishbone)
reg [2:0] wb_cmd_n = 3'd0;            // the halfword of the next wishbone READ / WRITE
reg [2:0] wb_dat_n = 3'd0;            // the halfword the next read data are

task cmd(input [2:0] c);
	begin
		ras_r <= c[2];
		cas_r <= c[1];
		we_r <= c[0];
	end
endtask

// the column of halfword k of the wishbone read: the asked word first, wrapping in the line of 4 words
wire [8:0] wb_col_k = { w_adr[9:4], w_adr[3:2] + wb_cmd_n[2:1], wb_cmd_n[0] };

always @(posedge clk) begin
	req_c1 <= req_t;
	if (fbw_req && !fbw_pend && fbw_len != 11'd0) begin
		fbw_pend <= 1'b1;
		fbw_r <= fbw_row;
		fbw_pos <= 10'd0;
		fbw_left <= fbw_len;
		fbw_b <= fbw_buf;
	end
	if (fbr_req && !fbr_pend && fbr_len != 11'd0) begin
		fbr_pend <= 1'b1;
		fbr_r <= fbr_row;
		fbr_pos <= 10'd0;
		fbr_left <= fbr_len;
		fbr_b <= fbr_buf;
		fbr_next <= 10'd0;
	end

	if (ref_cnt == REFRESH_CLOCKS)
		ref_cnt <= 10'd0;
	else
		ref_cnt <= ref_cnt + 1'd1;

	// read data
	rd_pipe <= { rd_pipe[RD_DELAY-1:0], 1'b0 };
	wb_pipe <= { wb_pipe[RD_DELAY-1:0], 1'b0 };
	fbr_we <= 1'b0;
	if (rd_pipe[RD_DELAY-1]) begin
		fbr_we <= 1'b1;
		fbr_data <= dq_neg;
		fbr_addr <= { fbr_b, fbr_next };
		fbr_next <= fbr_next + 10'd1;
	end
	if (wb_pipe[RD_DELAY-1]) begin
		if (wb_dat_n[0])
			rd_word[wb_dat_n[2:1]][31:16] <= dq_neg;
		else
			rd_word[wb_dat_n[2:1]][15:0] <= dq_neg;
		wb_dat_n <= wb_dat_n + 3'd1;
	end

	cmd(CMD_NOP);
	dq_oe_n <= 16'hFFFF;
	dqm_r <= 2'b00;
	if (act_cnt != 3'd7) act_cnt <= act_cnt + 3'd1;
	if (wr_cnt != 2'd3) wr_cnt <= wr_cnt + 2'd1;
	// a frame buffer read is over when its last data are in
	if (state == S_IDLE && fbr_pend && fbr_left == 11'd0 && rd_pipe == 0) fbr_pend <= 1'b0;

	if (reset) begin
		state <= S_INIT;
		cnt <= 15'd0;
		init_done <= 1'b0;
		fbw_pend <= 1'b0;
		fbr_pend <= 1'b0;
		req_seen <= req_c1;
		dqm_r <= 2'b11;
	end else case (state)
		S_INIT: begin
			dqm_r <= 2'b11;
			cnt <= cnt + 1'd1;
			if (cnt == INIT_CLOCKS) state <= S_INIT_PRE;
		end
		S_INIT_PRE: begin
			cmd(CMD_PRECHARGE);
			a_r[10] <= 1'b1;
			cnt <= 15'd3;
			next_state <= S_INIT_REF1;
			state <= S_WAIT;
		end
		S_INIT_REF1: begin
			cmd(CMD_REFRESH);
			cnt <= 15'd8;
			next_state <= S_INIT_REF2;
			state <= S_WAIT;
		end
		S_INIT_REF2: begin
			cmd(CMD_REFRESH);
			cnt <= 15'd8;
			next_state <= S_INIT_MODE;
			state <= S_WAIT;
		end
		S_INIT_MODE: begin
			cmd(CMD_MODE);
			ba_r <= 2'b00;
			a_r <= 13'b000_0_00_010_0_000;   // burst writes as reads (length 1), CAS 2, sequential, burst 1
			cnt <= 15'd3;
			next_state <= S_IDLE;
			state <= S_WAIT;
		end

		S_WAIT: begin
			if (cnt == 15'd0) begin
				state <= next_state;
				if (next_state == S_IDLE) init_done <= 1'b1;
			end else
				cnt <= cnt - 1'd1;
		end

		S_IDLE: begin
			if (ref_owed != 3'd0) begin
				cmd(CMD_REFRESH);
				cnt <= 15'd5;                 // tRFC
				next_state <= S_IDLE;
				state <= S_WAIT;
			end else if (wb_pend) begin
				req_seen <= req_c1;
				w_adr <= wb_adr;
				w_dat <= wb_dat_i;
				w_sel <= wb_sel;
				w_we <= wb_we;
				cmd(CMD_ACTIVE);
				ba_r <= wb_adr[23:22];
				a_r <= { 1'b0, wb_adr[21:10] };
				wb_cmd_n <= 3'd0;
				wb_dat_n <= 3'd0;
				cnt <= 15'd0;                 // tRCD: one clock between
				next_state <= wb_we ? S_WB_WR : S_WB_RD;
				state <= S_WAIT;
			end else if (fbr_pend && fbr_left != 11'd0) begin
				cmd(CMD_ACTIVE);
				ba_r <= 2'b10;
				a_r <= { fbr_r, fbr_pos[9] };
				run <= CHUNK;
				act_cnt <= 3'd0;
				fb_wr <= 1'b0;
				state <= S_WAIT;
				cnt <= 15'd0;
				next_state <= S_FBR;
			end else if (fbw_pend && !fbr_pend) begin
				cmd(CMD_ACTIVE);
				ba_r <= 2'b10;
				a_r <= { fbw_r, fbw_pos[9] };
				run <= CHUNK;
				act_cnt <= 3'd0;
				fb_wr <= 1'b1;
				fbw_addr <= { fbw_b, fbw_pos };
				state <= S_WAIT;
				cnt <= 15'd0;
				next_state <= S_FBW_PRE;
			end
		end

		// wishbone read: eight READs, the last with auto precharge
		S_WB_RD: begin
			cmd(CMD_READ);
			a_r <= { 2'b00, wb_cmd_n == 3'd7, 1'b0, wb_col_k };   // A10: auto precharge
			wb_pipe[0] <= 1'b1;
			wb_cmd_n <= wb_cmd_n + 3'd1;
			if (wb_cmd_n == 3'd7) state <= S_WB_RDEND;
		end
		S_WB_RDEND: begin
			if (wb_pipe == 0) begin
				done_t <= ~done_t;
				cnt <= 15'd0;                 // tRP after the auto precharge (tRC holds too)
				next_state <= S_IDLE;
				state <= S_WAIT;
			end
		end

		// wishbone write: two WRITEs (low, high halfword), the second with auto precharge
		S_WB_WR: begin
			cmd(CMD_WRITE);
			dq_oe_n <= 16'h0000;
			if (wb_cmd_n == 3'd0) begin
				a_r <= { 4'b0000, w_adr[9:2], 1'b0 };
				dq_out <= w_dat[15:0];
				dqm_r <= ~w_sel[1:0];
				wb_cmd_n <= 3'd1;
			end else begin
				a_r <= { 4'b0010, w_adr[9:2], 1'b1 };
				dq_out <= w_dat[31:16];
				dqm_r <= ~w_sel[3:2];
				done_t <= ~done_t;
				cnt <= 15'd4;                 // tWR + tRP (and tRC from the ACTIVE)
				next_state <= S_IDLE;
				state <= S_WAIT;
			end
		end

		// frame buffer read: READs of the open row (no auto precharge: tRAS), the data come in by rd_pipe
		S_FBR: begin
			cmd(CMD_READ);
			a_r <= { 4'b0000, fbr_pos[8:0] };
			rd_pipe[0] <= 1'b1;
			fbr_pos <= fbr_pos + 10'd1;
			fbr_left <= fbr_left - 11'd1;
			run <= run - 7'd1;
			if (fbr_last) state <= S_FB_PRE;
		end

		// the end of a frame buffer run: PRECHARGE of bank 2 once tRAS (4 clocks from the ACTIVE) and,
		// after a write, tWR (2 clocks from the last WRITE) are met; tRP
		S_FB_PRE: begin
			if (act_cnt >= 3'd4 && (!fb_wr || wr_cnt >= 2'd2)) begin
				cmd(CMD_PRECHARGE);
				ba_r <= 2'b10;
				a_r[10] <= 1'b0;
				cnt <= 15'd0;                 // tRP: the IDLE clock and this one
				next_state <= S_IDLE;
				state <= S_WAIT;
			end
		end

		// frame buffer write: the capture buffer takes the first address now, its data come with
		// the first WRITE; WRITEs of the open row
		S_FBW_PRE: begin
			fbw_addr <= fbw_addr + 11'd1;
			state <= S_FBW;
		end
		S_FBW: begin
			cmd(CMD_WRITE);
			a_r <= { 4'b0000, fbw_pos[8:0] };
			dq_out <= fbw_data;
			dq_oe_n <= 16'h0000;
			wr_cnt <= 2'd0;
			fbw_addr <= fbw_addr + 11'd1;
			fbw_pos <= fbw_pos + 10'd1;
			fbw_left <= fbw_left - 11'd1;
			run <= run - 7'd1;
			if (fbw_last) begin
				if (fbw_left == 11'd1) fbw_pend <= 1'b0;
				state <= S_FB_PRE;
			end
		end

		default: state <= S_IDLE;
	endcase

	ref_owed <= ref_owed + (ref_cnt == REFRESH_CLOCKS && ref_owed != 3'd7 ? 3'd1 : 3'd0)
	            - (!reset && state == S_IDLE && ref_owed != 3'd0 ? 3'd1 : 3'd0);
end

endmodule
