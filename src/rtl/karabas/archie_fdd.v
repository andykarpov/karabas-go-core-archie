`timescale 1ns / 1ps
`default_nettype none
/*
 archie_fdd.v

 The floppy drives of the Archimedes (fdc1772 of archimedes_top, the sd_* ports of the MiSTer hps:
 a 16-bit buffer, sd_buff_addr = the word of a 512-byte sector) on img_sdc of karabas-go-modules
 (the file mounter of the mcu: bytes with an address, slots 0 / 1 = drives 0 / 1).

 - sd_ack while img_sdc serves a request of a drive slot (sdc_busy with sdc_slot 0 / 1): fdc1772
   drops sd_rd / sd_wr on it and takes its fall as the end of the sector;
 - read: the bytes of img_sdc (sdc_byte_in_strobe) in pairs, the even one low (the byte order of
   the fifo of fdc1772): the odd one writes the word { odd, even } a clock later;
 - write: img_sdc copies the sector out by sdc_byte_addr; the word is read a clock after the
   address (sd_buff_addr is registered) and the fifo of fdc1772 answers a clock later, the byte is
   picked from it by the delayed low address bit: valid two clocks after sdc_byte_addr
   (OUT_LATENCY 3 of img_sdc, which takes it on the third edge).
 - img_mounted / img_size / img_wp for archimedes_top: the mount pulse of a drive slot with its size,
   img_wp of that slot (fdc1772 latches it at the mount).
*/
module archie_fdd (
	input wire clk,

	// img_sdc
	input wire [7:0] sdc_img_mounted,
	input wire [63:0] sdc_img_size,
	input wire [7:0] img_wp_all,        // IMG_WP of kg_mcu
	input wire sdc_busy,
	input wire [2:0] sdc_slot,
	input wire sdc_byte_in_strobe,
	input wire [8:0] sdc_byte_addr,
	input wire [7:0] sdc_byte_in_data,
	output wire [7:0] sdc_byte_out_data,
	output wire sel,                    // the request is a drive's (for a requester of other slots)

	// archimedes_top
	output wire [1:0] img_mounted,
	output wire [31:0] img_size,
	output wire img_wp,
	output wire sd_ack,
	output reg [7:0] sd_buff_addr = 8'd0,
	output reg [15:0] sd_buff_dout = 16'd0,
	output reg sd_buff_wr = 1'b0,
	input wire [15:0] sd_buff_din
);

assign sel = sdc_slot[2:1] == 2'b00;
assign sd_ack = sdc_busy && sel;

assign img_mounted = sdc_img_mounted[1:0];
assign img_size = sdc_img_size[31:0];
assign img_wp = sdc_img_mounted[1] ? img_wp_all[1] : img_wp_all[0];

reg [7:0] lo = 8'd0;
reg s1 = 1'b0, s2 = 1'b0;

always @(posedge clk) begin
	sd_buff_addr <= sdc_byte_addr[8:1];
	s1 <= sdc_byte_addr[0];
	s2 <= s1;
	sd_buff_wr <= 1'b0;
	if (sdc_byte_in_strobe && sel) begin
		if (!sdc_byte_addr[0])
			lo <= sdc_byte_in_data;
		else begin
			sd_buff_dout <= { sdc_byte_in_data, lo };
			sd_buff_wr <= 1'b1;
		end
	end
end

assign sdc_byte_out_data = s2 ? sd_buff_din[15:8] : sd_buff_din[7:0];

endmodule
