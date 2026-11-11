`timescale 1ns / 1ps
/*
 sdc_file_model.v: the sector side of img_sdc (one index) for the verilator model, on a file: the
 image of +hdf=FILE (read and written in place), mounted MOUNT_AT clocks after the start with its size.
 As img_sdc: a read raises sdc_busy, gives the 512 bytes as sdc_byte_in_strobe with sdc_byte_addr /
 data (a byte every 3 clocks), drops sdc_busy with a sdc_done pulse; a write raises sdc_busy, copies
 the sector out by sdc_byte_addr (OUT_LATENCY 3: the byte taken on the third edge), stores it, then
 sdc_done. A sector past the end of the file reads as zeros with sdc_error.
 reads / writes count the sectors.
*/
module sdc_file_model #(
	parameter MOUNT_AT = 4000
) (
	input wire clk,
	output reg img_mounted = 1'b0,
	output reg [63:0] img_size = 64'd0,
	input wire sdc_rd,
	input wire sdc_wr,
	input wire [31:0] sdc_sector,
	output reg sdc_busy = 1'b0,
	output reg sdc_done = 1'b0,
	output reg sdc_error = 1'b0,
	output reg sdc_byte_in_strobe = 1'b0,
	output reg [8:0] sdc_byte_addr = 9'd0,
	output reg [7:0] sdc_byte_in_data = 8'd0,
	input wire [7:0] sdc_byte_out_data
);

integer fd = 0, size = 0, clocks = 0, i, c, r;
integer reads = 0, writes = 0;
reg [1023:0] name;
reg [7:0] buf8 [0:511];
reg have = 1'b0;

initial begin
	if ($value$plusargs("hdf=%s", name)) begin
		fd = $fopen(name, "r+b");
		if (fd == 0) $display("sdc_file_model: cannot open the image");
		else begin
			r = $fseek(fd, 0, 2);
			size = $ftell(fd);
			have = 1'b1;
			$display("sdc_file_model: image of %0d bytes", size);
		end
	end
end

localparam S_IDLE = 0, S_OUT = 1, S_IN = 2, S_END = 3;
integer state = S_IDLE, pos = 0, wait_n = 0;
reg wr = 1'b0;
reg [31:0] lba = 32'd0;
reg bad = 1'b0;

always @(posedge clk) begin
	clocks <= clocks + 1;
	img_mounted <= 1'b0;
	sdc_done <= 1'b0;
	sdc_byte_in_strobe <= 1'b0;
	if (have && clocks == MOUNT_AT) begin
		img_mounted <= 1'b1;
		img_size <= size;
	end
	case (state)
	S_IDLE:
		if (sdc_rd || sdc_wr) begin
			sdc_busy <= 1'b1;
			wr = sdc_wr;
			lba = sdc_sector;
			bad = (lba + 1) * 512 > size;
			pos = 0;
			wait_n = 0;
			if (!wr) begin
				for (i = 0; i < 512; i = i + 1) buf8[i] = 8'd0;
				if (!bad) begin
					r = $fseek(fd, lba * 512, 0);
					for (i = 0; i < 512; i = i + 1) begin
						c = $fgetc(fd);
						buf8[i] = c[7:0];
					end
				end
				reads = reads + 1;
				state = S_OUT;
			end else
				state = S_IN;
		end
	S_OUT:
		if (wait_n != 0) wait_n = wait_n - 1;
		else if (pos == 512) begin
			sdc_busy <= 1'b0;
			sdc_done <= 1'b1;
			sdc_error <= bad;
			state = S_IDLE;
		end else begin
			sdc_byte_in_strobe <= 1'b1;
			sdc_byte_addr <= pos;
			sdc_byte_in_data <= buf8[pos];
			pos = pos + 1;
			wait_n = 2;
		end
	S_IN:
		// the address, two clocks, the byte on the third edge (img_sdc S_CADDR / S_CDATA)
		if (wait_n == 0) begin
			if (pos == 512) begin
				if (!bad) begin
					r = $fseek(fd, lba * 512, 0);
					for (i = 0; i < 512; i = i + 1) $fwrite(fd, "%c", buf8[i]);
					$fflush(fd);
				end
				writes = writes + 1;
				sdc_busy <= 1'b0;
				sdc_done <= 1'b1;
				sdc_error <= bad;
				state = S_IDLE;
			end else begin
				sdc_byte_addr <= pos;
				wait_n = 3;
			end
		end else begin
			wait_n = wait_n - 1;
			if (wait_n == 0) begin
				buf8[pos] = sdc_byte_out_data;
				pos = pos + 1;
			end
		end
	default: ;
	endcase
end

endmodule
