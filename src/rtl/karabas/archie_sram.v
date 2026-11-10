`timescale 1ns / 1ps
`default_nettype none
/*
 archie_sram.v

 The RAM of the Archimedes (4 MB) in the SRAM of the board (two 2M x 8 chips = one 2M x 16, 10 ns,
 asynchronous; MD[7:0] / MWR_N[0] / MRD_N[0] the low byte), on the wishbone clock (clk_sys, 40 MHz:
 no clock domain crossing). The SDRAM keeps the ROM and the frame buffer only (archie_sdram).

 Wishbone as archie_sdram (the behaviour of the sdram.v of Archie_MiSTer that MEMC expects): a new
 request is a rising cyc & stb; a read answers four 32-bit words, an ack on four clocks in a row,
 starting at the asked word and wrapping in its 16-byte line; a write (one word with the byte
 selects) one ack. wb_adr[21:2] is the word of the 4 MB (bank wb_adr[23:22] = 0 is decoded by the top).

 Read: one halfword per clock (25 ns): MA from an IOB flip-flop, MD into an IOB flip-flop on the next
 edge (clock to pad + 10 ns + pad to flip-flop, TS_SRAM_OUT / TS_SRAM_IN of the ucf); eight halfwords
 of the line in burst order, then the four acks: the first ack ten clocks after the request.
 Write: per halfword with byte selects three clocks: MA and MD out with /OE off, /WE of the lanes low,
 /WE high (address and data held a clock around /WE); the ack after the last one.
*/
module archie_sram (
	input wire clk,

	input wire wb_cyc,
	input wire wb_stb,
	input wire wb_we,
	input wire [3:0] wb_sel,
	input wire [21:2] wb_adr,
	input wire [31:0] wb_dat_i,
	output reg [31:0] wb_dat_o = 32'd0,
	output reg wb_ack = 1'b0,

	output wire [20:0] MA,
	inout wire [15:0] MD,
	output wire [1:0] MWR_N,
	output wire [1:0] MRD_N
);

(* IOB = "TRUE" *) reg [20:0] ma_r = 21'd0;
(* IOB = "TRUE" *) reg [1:0] mwr_r = 2'b11;
(* IOB = "TRUE" *) reg [1:0] mrd_r = 2'b00;
(* IOB = "TRUE" *) reg [15:0] md_out = 16'd0;
(* IOB = "TRUE", equivalent_register_removal = "no" *) reg [15:0] md_oe_n = 16'hFFFF;
(* IOB = "TRUE" *) reg [15:0] md_in = 16'd0;

assign MA = ma_r;
assign MWR_N = mwr_r;
assign MRD_N = mrd_r;
genvar i;
generate
	for (i = 0; i < 16; i = i + 1) begin : g_md
		assign MD[i] = md_oe_n[i] ? 1'bz : md_out[i];
	end
endgenerate

localparam [2:0] S_IDLE = 3'd0, S_RD = 3'd1, S_RDEND = 3'd2, S_W1 = 3'd3, S_W2 = 3'd4, S_W3 = 3'd5, S_ACK = 3'd6;

reg [2:0] st = S_IDLE;
reg req_prev = 1'b0;
wire wb_req = wb_cyc & wb_stb & ~wb_ack;
reg [21:2] q_adr = 20'd0;
reg [31:0] q_dat = 32'd0;
reg [3:0] q_sel = 4'd0;
reg q_hi = 1'b0;                  // write: the halfword being written
reg [2:0] rd_n = 3'd0;            // read: the next halfword asked
reg [2:0] dt_n = 3'd0;            // read: the halfword in md_in
reg [1:0] rd_pipe = 2'b00;        // read: an address went out one / two clocks ago
reg [31:0] rd_word [0:3];         // the four words, in burst order
reg [1:0] ack_n = 2'd0, ack_w = 2'd0;

// halfword k of the read: the asked word first, wrapping in the line of four words
wire [20:0] rd_ma = { q_adr[21:4], q_adr[3:2] + rd_n[2:1], rd_n[0] };

always @(posedge clk) begin
	wb_ack <= 1'b0;
	req_prev <= wb_req;
	md_in <= MD;
	rd_pipe <= { rd_pipe[0], 1'b0 };

	// read data: md_in holds the halfword of the address that went out two clocks ago
	if (rd_pipe[1]) begin
		if (dt_n[0]) rd_word[dt_n[2:1]][31:16] <= md_in;
		else rd_word[dt_n[2:1]][15:0] <= md_in;
		dt_n <= dt_n + 3'd1;
	end

	if (!(wb_cyc & wb_stb)) ack_n <= 2'd0;
	if (ack_n != 2'd0 && (wb_cyc & wb_stb)) begin
		wb_ack <= 1'b1;
		wb_dat_o <= rd_word[ack_w];
		ack_w <= ack_w + 2'd1;
		ack_n <= ack_n - 2'd1;
	end

	case (st)
	S_IDLE:
		if (wb_req && !req_prev && ack_n == 2'd0) begin
			q_adr <= wb_adr;
			q_dat <= wb_dat_i;
			q_sel <= wb_sel;
			rd_n <= 3'd0;
			dt_n <= 3'd0;
			if (wb_we) begin
				if (wb_sel[1:0] != 2'b00) begin
					q_hi <= 1'b0;
					ma_r <= { wb_adr[21:2], 1'b0 };
					md_out <= wb_dat_i[15:0];
				end else begin
					q_hi <= 1'b1;
					ma_r <= { wb_adr[21:2], 1'b1 };
					md_out <= wb_dat_i[31:16];
				end
				md_oe_n <= 16'h0000;
				mrd_r <= 2'b11;
				st <= wb_sel == 4'd0 ? S_ACK : S_W1;
			end else
				st <= S_RD;
		end

	// eight addresses, one per clock
	S_RD: begin
		ma_r <= rd_ma;
		rd_pipe[0] <= 1'b1;
		rd_n <= rd_n + 3'd1;
		if (rd_n == 3'd7) st <= S_RDEND;
	end
	S_RDEND:
		// the last halfword is stored in this clock or the next
		if (rd_pipe == 2'b00 && dt_n == 3'd0) begin
			wb_ack <= 1'b1;
			wb_dat_o <= rd_word[0];
			ack_w <= 2'd1;
			ack_n <= 2'd3;
			st <= S_IDLE;
		end

	S_W1: begin
		mwr_r <= q_hi ? ~q_sel[3:2] : ~q_sel[1:0];
		st <= S_W2;
	end
	S_W2: begin
		mwr_r <= 2'b11;
		st <= S_W3;
	end
	S_W3:
		// address and data held; the high halfword next, or the end
		if (!q_hi && q_sel[3:2] != 2'b00) begin
			q_hi <= 1'b1;
			ma_r <= { q_adr[21:2], 1'b1 };
			md_out <= q_dat[31:16];
			st <= S_W1;
		end else begin
			md_oe_n <= 16'hFFFF;
			mrd_r <= 2'b00;
			st <= S_ACK;
		end
	default: begin // S_ACK: the write
		md_oe_n <= 16'hFFFF;
		mrd_r <= 2'b00;
		if (wb_cyc & wb_stb) wb_ack <= 1'b1;
		st <= S_IDLE;
	end
	endcase
end

endmodule
