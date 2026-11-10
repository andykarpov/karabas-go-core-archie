`timescale 1ns / 1ps

// Dual-clock 32-bit-to-8-bit FIFO used by the VIDC video and cursor DMA.
// Pointer state crosses clock domains only in Gray code. The read pointer
// advances to the next 32-bit word after all four bytes have been consumed.
module vidc_async_fifo #(
	parameter ADDR_WIDTH = 3
)
(
	input             wr_clk,
	input             wr_rst,
	input             wr_en,
	input      [31:0] wr_data,
	output            wr_can_burst,

	input             rd_clk,
	input             rd_rst,
	input             rd_en,
	output reg  [7:0] rd_data
);

localparam PTR_WIDTH = ADDR_WIDTH + 1;

reg [31:0] memory [0:(1 << ADDR_WIDTH)-1];

reg [PTR_WIDTH-1:0] wr_bin = 0;
reg [PTR_WIDTH-1:0] wr_gray = 0;
reg [PTR_WIDTH-1:0] rd_bin = 0;
reg [PTR_WIDTH-1:0] rd_gray = 0;
reg [1:0]           rd_byte = 0;

(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED" *)
reg [PTR_WIDTH-1:0] rd_gray_sync1 = 0;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED" *)
reg [PTR_WIDTH-1:0] rd_gray_sync2 = 0;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED" *)
reg [PTR_WIDTH-1:0] wr_gray_sync1 = 0;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED" *)
reg [PTR_WIDTH-1:0] wr_gray_sync2 = 0;

function [PTR_WIDTH-1:0] gray_to_bin;
	input [PTR_WIDTH-1:0] gray;
	integer bit_index;
	begin
		gray_to_bin[PTR_WIDTH-1] = gray[PTR_WIDTH-1];
		for(bit_index = PTR_WIDTH-2; bit_index >= 0; bit_index = bit_index - 1)
			gray_to_bin[bit_index] = gray_to_bin[bit_index+1] ^ gray[bit_index];
	end
endfunction

wire [PTR_WIDTH-1:0] rd_bin_wr = gray_to_bin(rd_gray_sync2);
wire [PTR_WIDTH-1:0] used_words = wr_bin - rd_bin_wr;
wire [PTR_WIDTH-1:0] fifo_capacity = {1'b1, {ADDR_WIDTH{1'b0}}};
wire [PTR_WIDTH-1:0] free_words = fifo_capacity - used_words;
wire                 wr_full = (free_words == 0);
wire                 rd_empty = (rd_gray == wr_gray_sync2);

assign wr_can_burst = (free_words >= 4);

always @(posedge wr_clk) begin
	if(wr_rst) begin
		wr_bin <= 0;
		wr_gray <= 0;
		rd_gray_sync1 <= 0;
		rd_gray_sync2 <= 0;
	end
	else begin
		rd_gray_sync1 <= rd_gray;
		rd_gray_sync2 <= rd_gray_sync1;

		if(wr_en && !wr_full) begin
			memory[wr_bin[ADDR_WIDTH-1:0]] <= wr_data;
			wr_bin <= wr_bin + 1'd1;
			wr_gray <= ((wr_bin + 1'd1) >> 1) ^ (wr_bin + 1'd1);
		end
	end
end

always @(posedge rd_clk) begin
	if(rd_rst) begin
		rd_bin <= 0;
		rd_gray <= 0;
		rd_byte <= 0;
		rd_data <= 0;
		wr_gray_sync1 <= 0;
		wr_gray_sync2 <= 0;
	end
	else begin
		wr_gray_sync1 <= wr_gray;
		wr_gray_sync2 <= wr_gray_sync1;

		if(rd_en) begin
			if(!rd_empty) begin
				case(rd_byte)
					2'd0: rd_data <= memory[rd_bin[ADDR_WIDTH-1:0]][7:0];
					2'd1: rd_data <= memory[rd_bin[ADDR_WIDTH-1:0]][15:8];
					2'd2: rd_data <= memory[rd_bin[ADDR_WIDTH-1:0]][23:16];
					2'd3: rd_data <= memory[rd_bin[ADDR_WIDTH-1:0]][31:24];
				endcase

				if(rd_byte == 2'd3) begin
					rd_byte <= 0;
					rd_bin <= rd_bin + 1'd1;
					rd_gray <= ((rd_bin + 1'd1) >> 1) ^ (rd_bin + 1'd1);
				end
				else rd_byte <= rd_byte + 1'd1;
			end
			else rd_data <= 0;
		end
	end
end

endmodule
