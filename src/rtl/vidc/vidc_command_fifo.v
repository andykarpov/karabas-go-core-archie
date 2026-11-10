`timescale 1ns / 1ps

// Small asynchronous command FIFO for CPU writes to pixel-domain VIDC
// registers. The video side drains one complete 32-bit command per clock.
module vidc_command_fifo #(
	parameter ADDR_WIDTH = 3
)
(
	input             wr_clk,
	input             wr_rst,
	input             wr_en,
	input      [31:0] wr_data,

	input             rd_clk,
	input             rd_rst,
	output reg        rd_valid,
	output reg [31:0] rd_data
);

localparam PTR_WIDTH = ADDR_WIDTH + 1;

reg [31:0] memory [0:(1 << ADDR_WIDTH)-1];
reg [PTR_WIDTH-1:0] wr_bin = 0;
reg [PTR_WIDTH-1:0] wr_gray = 0;
reg [PTR_WIDTH-1:0] rd_bin = 0;
reg [PTR_WIDTH-1:0] rd_gray = 0;

(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED" *)
reg [PTR_WIDTH-1:0] rd_gray_sync1 = 0;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED" *)
reg [PTR_WIDTH-1:0] rd_gray_sync2 = 0;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED" *)
reg [PTR_WIDTH-1:0] wr_gray_sync1 = 0;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED" *)
reg [PTR_WIDTH-1:0] wr_gray_sync2 = 0;

wire [PTR_WIDTH-1:0] wr_bin_next = wr_bin + 1'd1;
wire [PTR_WIDTH-1:0] wr_gray_next = (wr_bin_next >> 1) ^ wr_bin_next;
wire                 wr_full = (wr_gray_next ==
	{~rd_gray_sync2[PTR_WIDTH-1:PTR_WIDTH-2], rd_gray_sync2[PTR_WIDTH-3:0]});
wire                 rd_empty = (rd_gray == wr_gray_sync2);

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
			wr_bin <= wr_bin_next;
			wr_gray <= wr_gray_next;
		end
	end
end

always @(posedge rd_clk) begin
	if(rd_rst) begin
		rd_bin <= 0;
		rd_gray <= 0;
		rd_valid <= 0;
		rd_data <= 0;
		wr_gray_sync1 <= 0;
		wr_gray_sync2 <= 0;
	end
	else begin
		wr_gray_sync1 <= wr_gray;
		wr_gray_sync2 <= wr_gray_sync1;
		rd_valid <= 0;

		if(!rd_empty) begin
			rd_data <= memory[rd_bin[ADDR_WIDTH-1:0]];
			rd_valid <= 1;
			rd_bin <= rd_bin + 1'd1;
			rd_gray <= ((rd_bin + 1'd1) >> 1) ^ (rd_bin + 1'd1);
		end
	end
end

endmodule
