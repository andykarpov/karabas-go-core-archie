module vidc_audio (
	cpu_clk,
	cpu_wr,
	cpu_data,
	aud_clk,
	aud_ce,
	aud_rst,
	aud_data,
	aud_en,
	aud_right,
	aud_left
);
	input cpu_clk;
	input cpu_wr;
	input [31:0] cpu_data;
	input aud_clk;
	input aud_ce;
	input aud_rst;
	input [7:0] aud_data;
	output reg aud_en;
	output reg [15:0] aud_right;
	output reg [15:0] aud_left;
	localparam SOUND_SAMFREQ = 4'b1100;
	localparam SOUND_REGISTERS = 5'b01100;
	reg [2:0] channel;
	reg [2:0] vidc_sir [0:7];
	reg [8:0] vidc_sfr;
	reg [7:0] aud_delay_count;
	always @(posedge cpu_clk)
		if (cpu_wr) begin
			if ({cpu_data[31:29], cpu_data[25:24]} == SOUND_REGISTERS) begin
				$display("Writing the stereo image registers: 0x%08x", cpu_data);
				vidc_sir[cpu_data[28:26] - 1'd1] <= cpu_data[2:0];
			end
			if (cpu_data[31:28] == SOUND_SAMFREQ) begin
				$display("VIDC SFR: %x", cpu_data[7:0]);
				if (cpu_data[8])
					vidc_sfr <= cpu_data[8:0];
			end
		end
	function [15:0] mu2lin;
		input [7:0] value;
		begin
			mu2lin = 16'h00ff << value[7:5];
			mu2lin = {4'b0000, mu2lin[15:8], 4'b0000} + ({12'd0, value[4:1]} << value[7:5]);
			if (value[0])
				mu2lin = 16'd0 - mu2lin;
		end
	endfunction
	always @(posedge aud_clk) begin : block
		reg [15:0] data;
		reg [15:0] al;
		reg [15:0] ar;
		reg ce_d;
		ce_d <= 0;
		if (aud_rst | ~vidc_sfr[8]) begin
			channel <= 0;
			aud_en <= 0;
			aud_delay_count <= 8'hff;
			ce_d <= 0;
			al <= 0;
			ar <= 0;
			aud_left <= 0;
			aud_right <= 0;
		end
		else if (aud_ce) begin
			aud_en <= 0;
			aud_delay_count <= aud_delay_count - 1'd1;
			if (aud_delay_count == 8'd0) begin
				ce_d <= aud_ce;
				data <= mu2lin(aud_data);
				aud_en <= 1'b1;
				aud_delay_count <= vidc_sfr[7:0];
				if (!channel) begin
					aud_right <= ar;
					aud_left <= al;
					ar <= 0;
					al <= 0;
				end
			end
		end
		else if (ce_d) begin
			channel <= channel + 1'd1;
			case (vidc_sir[channel])
				1: al <= $signed(al) + $signed(data);
				2: begin
					al <= ($signed(al) + $signed(data[15:1])) + $signed(data[15:2]);
					ar <= $signed(ar) + $signed(data[15:2]);
				end
				3: begin
					al <= ($signed(al) + $signed(data[15:1])) + $signed(data[15:3]);
					ar <= ($signed(ar) + $signed(data[15:1])) - $signed(data[15:3]);
				end
				4: begin
					al <= $signed(al) + $signed(data[15:1]);
					ar <= $signed(ar) + $signed(data[15:1]);
				end
				5: begin
					al <= ($signed(al) + $signed(data[15:1])) - $signed(data[15:3]);
					ar <= ($signed(ar) + $signed(data[15:1])) + $signed(data[15:3]);
				end
				6: begin
					al <= $signed(al) + $signed(data[15:2]);
					ar <= ($signed(ar) + $signed(data[15:1])) + $signed(data[15:2]);
				end
				7: ar <= $signed(ar) + $signed(data);
			endcase
		end
	end
endmodule
