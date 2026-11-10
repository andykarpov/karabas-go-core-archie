`timescale 1ns / 1ps
`default_nettype none
/*
 archie_loader.v

 The RISC OS ROM file (the FL item, a byte stream from kg_mcu: file_wr with file_addr / file_data) into
 the ROM of the SDRAM (wishbone word address 0x100000 + offset / 4, bank 1 of archie_sdram, where MEMC
 reads the ROM), while the machine is held in reset (the top owns the wishbone bus then).

 The mcu gives no backpressure and a burst byte may come every ten clocks or so, while a wishbone write
 takes about eight: bytes of one 32-bit word are collected (with their byte selects) and the words wait
 in a FIFO of 16. A word goes out when a byte of another word comes or after IDLE clocks without a byte
 (the last word of the file). Bytes past ROM_BYTES are dropped. overflow is set if the FIFO was full.
 done is set at the end of a file (active falling; the mcu sends it well after the last byte) once
 the word collector and the FIFO are empty.
*/
module archie_loader #(
	parameter [31:0] ROM_BYTES = 32'h00200000,
	parameter [21:0] ROM_WORD = 22'h100000,
	parameter [7:0] IDLE = 8'd200
) (
	input wire clk,
	input wire reset,

	input wire active,                // a file of the ROM slot is being loaded
	input wire wr,
	input wire [31:0] addr,
	input wire [7:0] data,

	output reg wb_cyc = 1'b0,
	output wire wb_stb,
	output wire wb_we,
	output reg [3:0] wb_sel = 4'd0,
	output reg [23:2] wb_adr = 22'd0,
	output reg [31:0] wb_dat = 32'd0,
	input wire wb_ack,

	output reg busy = 1'b0,           // a word is collected or queued
	output reg done = 1'b0,           // a whole file went in
	output reg overflow = 1'b0
);

assign wb_stb = wb_cyc;
assign wb_we = 1'b1;

// the word being collected
reg have = 1'b0;
reg [19:0] w_word = 20'd0;            // offset / 4
reg [31:0] w_data = 32'd0;
reg [3:0] w_sel = 4'd0;
reg [7:0] idle = 8'd0;

// the FIFO: { sel, word, data }
reg [55:0] fifo [0:15];
reg [3:0] wp = 4'd0, rp = 4'd0;
wire empty = wp == rp;
wire full = (wp + 4'd1) == rp;
reg push = 1'b0;
reg [55:0] push_w = 56'd0;
reg active_d = 1'b0;
reg ended = 1'b0;                     // the file ended (active fell), done once all is out

wire in_rom = addr < ROM_BYTES;
wire [3:0] lane = 4'b0001 << addr[1:0];

always @(posedge clk) begin
	push <= 1'b0;
	active_d <= active;
	if (reset) begin
		have <= 1'b0;
		wp <= 4'd0;
		rp <= 4'd0;
		wb_cyc <= 1'b0;
		done <= 1'b0;
		ended <= 1'b0;
		overflow <= 1'b0;
	end else begin
		if (active && !active_d) begin
			done <= 1'b0;
			ended <= 1'b0;
		end
		if (!active && active_d) ended <= 1'b1;

		// collect
		if (wr && active && in_rom) begin
			idle <= 8'd0;
			if (have && addr[21:2] != w_word) begin
				push <= 1'b1;
				push_w <= { w_sel, w_word, w_data };
				w_sel <= lane;
			end else
				w_sel <= w_sel | lane;
			have <= 1'b1;
			w_word <= addr[21:2];
			case (addr[1:0])
			2'd0: w_data[7:0] <= data;
			2'd1: w_data[15:8] <= data;
			2'd2: w_data[23:16] <= data;
			default: w_data[31:24] <= data;
			endcase
		end else if (have) begin
			if (idle == IDLE || (w_sel == 4'b1111 && idle == 8'd16)) begin
				push <= 1'b1;
				push_w <= { w_sel, w_word, w_data };
				have <= 1'b0;
				idle <= 8'd0;
			end else
				idle <= idle + 8'd1;
		end

		if (push) begin
			if (full) overflow <= 1'b1;
			else begin
				fifo[wp] <= push_w;
				wp <= wp + 4'd1;
			end
		end

		// write out
		if (wb_cyc) begin
			if (wb_ack) wb_cyc <= 1'b0;
		end else if (!empty) begin
			wb_cyc <= 1'b1;
			wb_sel <= fifo[rp][55:52];
			wb_adr <= ROM_WORD + { 2'b00, fifo[rp][51:32] };
			wb_dat <= fifo[rp][31:0];
			rp <= rp + 4'd1;
		end

		if (ended && !active && !have && !push && empty && !wb_cyc) begin
			done <= 1'b1;
			ended <= 1'b0;
		end
	end
	busy <= have || push || !empty || wb_cyc;
end

endmodule
