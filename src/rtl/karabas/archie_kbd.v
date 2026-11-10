`timescale 1ns / 1ps
/*
 archie_kbd.v

 The Archimedes keyboard (the A3xx / A4xx keyboard microcontroller) on the byte link of the IOC of
 Archie_MiSTer: the protocol MiST and MiSTer run in their ARM / HPS firmware (mist-firmware archie.c),
 here in logic.

 Link: the IOC raises kbd_out_strobe (a level, high while its faked transmission runs) with a byte in
 kbd_out_data; we answer with a one-clock kbd_in_strobe and kbd_in_data.

 Protocol (the codes of archie.c):
 - reset: we send HRST and wait for RAK1 (state RAK1), send RAK1 and wait for RAK2, send RAK2: IDLE.
   No answer in 20 ms: HRST again. HRST from the machine starts it again (flags cleared).
 - RQID: KBID | 1. RQPD, PRST, RQMP, LEDS: nothing (as archie.c).
 - a key: two bytes, KDDA / KUDA | row, then | column; the machine acks the first with BACK and the
   second with NACK / SACK / MACK / SMAK, which also set the scan / mouse enable flags. 10 ms without
   an ack: IDLE.
 - mouse: when enabled and moved, two bytes x, y (7 bits, two's complement, clamped to -64..63) in the
   same way; the buttons are keys 0x70 (left), 0x71 (middle), 0x72 (right) and need scanning enabled.

 Inputs: key_strobe with key_code (row << 4 | column) and key_up; mouse_strobe with the motion of one
 report (mouse_dx right positive, mouse_dy down positive as USB, inverted here as archie.c) and the
 buttons (bit 0 left, 1 right, 2 middle as USB). Key events wait in a FIFO of 16 (older ones kept
 when it is full); the motion is summed.
*/

module archie_kbd #(
	parameter integer CLK_HZ = 42000000
) (
	input wire clk,
	input wire reset,

	// the IOC link
	input wire [7:0] kbd_out_data,
	input wire kbd_out_strobe,
	output reg [7:0] kbd_in_data = 8'd0,
	output reg kbd_in_strobe = 1'b0,

	// keys
	input wire key_strobe,
	input wire [7:0] key_code,
	input wire key_up,

	// mouse
	input wire mouse_strobe,
	input wire signed [7:0] mouse_dx,
	input wire signed [7:0] mouse_dy,
	input wire [2:0] mouse_buttons,

	output wire scan_enabled,
	output wire mouse_enabled
);

localparam [7:0] HRST = 8'hff, RAK1 = 8'hfe, RAK2 = 8'hfd, RQID = 8'h20, KBID = 8'h80,
	KDDA = 8'hc0, KUDA = 8'hd0, BACK = 8'h3f, NACK = 8'h30, SACK = 8'h31, MACK = 8'h32, SMAK = 8'h33;

localparam [2:0] S_RAK1 = 3'd0, S_RAK2 = 3'd1, S_IDLE = 3'd2, S_ACK1 = 3'd3, S_ACK2 = 3'd4;

localparam integer T20MS = CLK_HZ / 50;
localparam integer T10MS = CLK_HZ / 100;

reg [2:0] state = S_RAK1;
reg [24:0] timer = 25'd0;
reg scan_en = 1'b0, mouse_en = 1'b0;
reg [7:0] second = 8'd0;   // the second byte of the pair being sent
reg start = 1'b1;          // send HRST after reset

assign scan_enabled = scan_en;
assign mouse_enabled = mouse_en;

// ---- key FIFO: {up, code}
reg [8:0] fifo [0:15];
reg [3:0] wr = 4'd0, rd = 4'd0;
wire fifo_empty = wr == rd;
wire fifo_full = (wr + 4'd1) == rd;

// ---- mouse buttons as keys
reg [2:0] buttons = 3'd0;
// usb bit -> archie column: left 0, right 2, middle 1
function [3:0] but_col(input [1:0] b);
	but_col = (b == 2'd0) ? 4'd0 : (b == 2'd1) ? 4'd2 : 4'd1;
endfunction

// ---- mouse motion
reg signed [7:0] mx = 8'sd0, my = 8'sd0;
function signed [7:0] clamp(input signed [9:0] v);
	clamp = (v > 10'sd63) ? 8'sd63 : (v < -10'sd64) ? -8'sd64 : v[7:0];
endfunction

// ---- link receive
reg out_strobe_r = 1'b0;
wire rx = kbd_out_strobe & ~out_strobe_r;

// one event (key or button) entering the FIFO per clock: a key strobe wins over a button change, the
// button change is taken on the next clock (buttons is updated only when it goes in)
wire [2:0] but_diff = mouse_buttons ^ buttons;
wire but_ev = |but_diff & ~key_strobe & scan_en;
wire [1:0] but_n = but_diff[0] ? 2'd0 : but_diff[1] ? 2'd1 : 2'd2;

task send(input [7:0] b);
	begin
		kbd_in_data <= b;
		kbd_in_strobe <= 1'b1;
	end
endtask

always @(posedge clk) begin
	kbd_in_strobe <= 1'b0;
	out_strobe_r <= kbd_out_strobe;
	if (timer != 25'd0) timer <= timer - 25'd1;

	// key events in
	if (key_strobe && scan_en && state != S_RAK1 && state != S_RAK2 && !fifo_full) begin
		fifo[wr] <= {key_up, key_code};
		wr <= wr + 4'd1;
	end else if (but_ev && !fifo_full) begin
		fifo[wr] <= {~mouse_buttons[but_n], 4'h7, but_col(but_n)};
		wr <= wr + 4'd1;
		buttons[but_n] <= mouse_buttons[but_n];
	end
	if (!scan_en) buttons <= mouse_buttons;

	// mouse motion in (summed, clamped)
	if (mouse_strobe && mouse_en) begin
		mx <= clamp(mx + mouse_dx);
		my <= clamp(my - mouse_dy);
	end

	if (reset) begin
		state <= S_RAK1;
		start <= 1'b1;
		scan_en <= 1'b0;
		mouse_en <= 1'b0;
		rd <= wr;
		mx <= 8'sd0;
		my <= 8'sd0;
		timer <= 25'd0;
	end else if (start) begin
		start <= 1'b0;
		send(HRST);
		state <= S_RAK1;
		timer <= T20MS;
	end else if (rx) begin
		case (kbd_out_data)
		HRST: begin
			scan_en <= 1'b0;
			mouse_en <= 1'b0;
			rd <= wr;
			mx <= 8'sd0;
			my <= 8'sd0;
			send(HRST);
			state <= S_RAK1;
			timer <= T20MS;
		end
		RAK1:
			if (state == S_RAK1) begin
				send(RAK1);
				state <= S_RAK2;
				timer <= T20MS;
			end else begin
				send(HRST);
				state <= S_RAK1;
				timer <= T20MS;
			end
		RAK2:
			if (state == S_RAK2) begin
				send(RAK2);
				state <= S_IDLE;
			end else begin
				send(HRST);
				state <= S_RAK1;
				timer <= T20MS;
			end
		RQID:
			send(KBID | 8'd1);
		BACK:
			if (state == S_ACK1) begin
				send(second);
				state <= S_ACK2;
				timer <= T10MS;
			end else begin
				send(HRST);
				state <= S_RAK1;
				timer <= T20MS;
			end
		NACK, SACK, MACK, SMAK: begin
			scan_en <= kbd_out_data[0];
			mouse_en <= kbd_out_data[1];
			if (state == S_ACK1 || state == S_ACK2) state <= S_IDLE;
		end
		default: ;
		endcase
	end else begin
		case (state)
		S_RAK1, S_RAK2:
			if (timer == 25'd0) begin
				send(HRST);
				state <= S_RAK1;
				timer <= T20MS;
			end
		S_ACK1, S_ACK2:
			if (timer == 25'd0) state <= S_IDLE;
		S_IDLE:
			if (!fifo_empty) begin
				send((fifo[rd][8] ? KUDA : KDDA) | {4'd0, fifo[rd][7:4]});
				second <= (fifo[rd][8] ? KUDA : KDDA) | {4'd0, fifo[rd][3:0]};
				rd <= rd + 4'd1;
				state <= S_ACK1;
				timer <= T10MS;
			end else if (mouse_en && (mx != 8'sd0 || my != 8'sd0) && !mouse_strobe) begin
				send({1'b0, mx[6:0]});
				second <= {1'b0, my[6:0]};
				mx <= 8'sd0;
				my <= 8'sd0;
				state <= S_ACK1;
				timer <= T10MS;
			end
		default: ;
		endcase
	end
end

endmodule
