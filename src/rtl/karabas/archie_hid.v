`timescale 1ns / 1ps
`default_nettype wire
/*
 archie_hid.v

 The USB devices of the mcu link (kg_mcu: the keyboard report, mouse deltas, two joysticks) for the
 Archimedes: key and mouse events for archie_kbd (the keyboard protocol), the joysticks for the
 joystick interface of archimedes_top.

 Keyboard: the report (kb_status = the modifier bits, kb_dat0..5 = USB HID usage codes, bit 7 =
 none) is scanned one item per clock: items 0..111 the usage codes, 112..119 the modifiers. An item
 whose state (in the report or not) differs from the last scan gives an event: its Archimedes key
 number (usb2archie of mist-firmware keycodes.h: Print Screen = Print 0D, App = the middle mouse
 button 72; the modifiers as MiSTer, Left Ctrl 3B: mist-firmware has 36, the key number of Page Down)
 with up / down, one clock of key_strobe. A report with ErrorRollOver (01) is not scanned. A scan takes
 120 clocks, under 3 us at 42 MHz; archie_kbd queues the events.

 Mouse: a change of ms_upd (a toggle per report) is one mouse_strobe with the deltas and buttons.

 Joysticks: kg_mcu JOY: [1] up, [2] down, [3] left, [4] right, [6] A, [7] B. archimedes_top
 JOYSTICK0 / 1 (as Archie.sv): active low { fire, right, left, down, up }; fire = A or B.
*/
module archie_hid (
	input wire clk,
	input wire reset,

	input wire [7:0] kb_status,
	input wire [7:0] kb_dat0,
	input wire [7:0] kb_dat1,
	input wire [7:0] kb_dat2,
	input wire [7:0] kb_dat3,
	input wire [7:0] kb_dat4,
	input wire [7:0] kb_dat5,
	input wire [7:0] ms_x,
	input wire [7:0] ms_y,
	input wire [2:0] ms_b,
	input wire ms_upd,
	input wire [12:0] joy_l,
	input wire [12:0] joy_r,

	output reg key_strobe = 1'b0,
	output reg [7:0] key_code = 8'd0,
	output reg key_up = 1'b0,
	output reg mouse_strobe = 1'b0,
	output reg [7:0] mouse_dx = 8'd0,
	output reg [7:0] mouse_dy = 8'd0,
	output reg [2:0] mouse_buttons = 3'd0,
	output wire [4:0] joy0,
	output wire [4:0] joy1
);

// ------------------------------------------------------------------ keyboard

reg [6:0] item = 7'd0;
reg [119:0] state = 120'd0;

function in_report(input [6:0] c);
	in_report = (!kb_dat0[7] && kb_dat0[6:0] == c) || (!kb_dat1[7] && kb_dat1[6:0] == c) ||
	            (!kb_dat2[7] && kb_dat2[6:0] == c) || (!kb_dat3[7] && kb_dat3[6:0] == c) ||
	            (!kb_dat4[7] && kb_dat4[6:0] == c) || (!kb_dat5[7] && kb_dat5[6:0] == c);
endfunction

wire rollover = kb_dat0 == 8'h01 || kb_dat1 == 8'h01 || kb_dat2 == 8'h01;
wire now = item[6:3] == 4'hE ? kb_status[item[2:0]] : in_report(item);

reg [7:0] arc;
always @(*) begin
	arc = 8'hFF;
	case (item)
	7'h04: arc = 8'h3c;  // a
	7'h05: arc = 8'h52;  // b
	7'h06: arc = 8'h50;  // c
	7'h07: arc = 8'h3e;  // d
	7'h08: arc = 8'h29;  // e
	7'h09: arc = 8'h3f;  // f
	7'h0a: arc = 8'h40;  // g
	7'h0b: arc = 8'h41;  // h
	7'h0c: arc = 8'h2e;  // i
	7'h0d: arc = 8'h42;  // j
	7'h0e: arc = 8'h43;  // k
	7'h0f: arc = 8'h44;  // l
	7'h10: arc = 8'h54;  // m
	7'h11: arc = 8'h53;  // n
	7'h12: arc = 8'h2f;  // o
	7'h13: arc = 8'h30;  // p
	7'h14: arc = 8'h27;  // q
	7'h15: arc = 8'h2a;  // r
	7'h16: arc = 8'h3d;  // s
	7'h17: arc = 8'h2b;  // t
	7'h18: arc = 8'h2d;  // u
	7'h19: arc = 8'h51;  // v
	7'h1a: arc = 8'h28;  // w
	7'h1b: arc = 8'h4f;  // x
	7'h1c: arc = 8'h2c;  // y
	7'h1d: arc = 8'h4e;  // z
	7'h1e: arc = 8'h11;  // 1
	7'h1f: arc = 8'h12;  // 2
	7'h20: arc = 8'h13;  // 3
	7'h21: arc = 8'h14;  // 4
	7'h22: arc = 8'h15;  // 5
	7'h23: arc = 8'h16;  // 6
	7'h24: arc = 8'h17;  // 7
	7'h25: arc = 8'h18;  // 8
	7'h26: arc = 8'h19;  // 9
	7'h27: arc = 8'h1a;  // 0
	7'h28: arc = 8'h47;  // Return
	7'h29: arc = 8'h00;  // Escape
	7'h2a: arc = 8'h1e;  // Backspace
	7'h2b: arc = 8'h26;  // Tab
	7'h2c: arc = 8'h5f;  // Space
	7'h2d: arc = 8'h1b;  // -
	7'h2e: arc = 8'h1c;  // =
	7'h2f: arc = 8'h31;  // [
	7'h30: arc = 8'h32;  // ]
	7'h31: arc = 8'h33;  // backslash (only on us keyboards)
	7'h32: arc = 8'h33;  // Europe 1 (only on international kbds)
	7'h33: arc = 8'h45;  // ;
	7'h34: arc = 8'h46;  // '
	7'h35: arc = 8'h10;  // `
	7'h36: arc = 8'h55;  // ,
	7'h37: arc = 8'h56;  // .
	7'h38: arc = 8'h57;  // /
	7'h39: arc = 8'h5d;  // Caps Lock
	7'h3a: arc = 8'h01;  // F1
	7'h3b: arc = 8'h02;  // F2
	7'h3c: arc = 8'h03;  // F3
	7'h3d: arc = 8'h04;  // F4
	7'h3e: arc = 8'h05;  // F5
	7'h3f: arc = 8'h06;  // F6
	7'h40: arc = 8'h07;  // F7
	7'h41: arc = 8'h08;  // F8
	7'h42: arc = 8'h09;  // F9
	7'h43: arc = 8'h0a;  // F10
	7'h44: arc = 8'h0b;  // F11
	7'h45: arc = 8'h0c;  // F12 - Used heavily by the archie... OSD moved to printscreen.
	7'h46: arc = 8'h0d;  // Print Screen
	7'h47: arc = 8'h0e;  // Scroll Lock
	7'h48: arc = 8'h0f;  // Pause
	7'h49: arc = 8'h1f;  // Insert
	7'h4a: arc = 8'h20;  // Home
	7'h4b: arc = 8'h21;  // Page Up
	7'h4c: arc = 8'h34;  // Delete
	7'h4d: arc = 8'h35;  // End
	7'h4e: arc = 8'h36;  // Page Down
	7'h4f: arc = 8'h64;  // Right Arrow
	7'h50: arc = 8'h62;  // Left Arrow
	7'h51: arc = 8'h63;  // Down Arrow
	7'h52: arc = 8'h59;  // Up Arrow
	7'h53: arc = 8'h22;  // Num Lock
	7'h54: arc = 8'h23;  // KP /
	7'h55: arc = 8'h24;  // KP *
	7'h56: arc = 8'h3a;  // KP -
	7'h57: arc = 8'h4b;  // KP +
	7'h58: arc = 8'h67;  // KP Enter
	7'h59: arc = 8'h5a;  // KP 1
	7'h5a: arc = 8'h5b;  // KP 2
	7'h5b: arc = 8'h5c;  // KP 3
	7'h5c: arc = 8'h48;  // KP 4
	7'h5d: arc = 8'h49;  // KP 5
	7'h5e: arc = 8'h4a;  // KP 6
	7'h5f: arc = 8'h37;  // KP 7
	7'h60: arc = 8'h38;  // KP 8
	7'h61: arc = 8'h39;  // KP 9
	7'h62: arc = 8'h65;  // KP 0
	7'h63: arc = 8'h66;  // KP decimal
	7'h65: arc = 8'h72;  // App (maps to middle mouse button)
	7'h6b: arc = 8'h1f;  // insert (for keyrah)
	// the modifiers (items 112..119: USB modifier bits 0..7)
	7'h70: arc = 8'h3b;  // Left Ctrl (MiSTer; mist-firmware 36)
	7'h71: arc = 8'h4c;  // Left Shift
	7'h72: arc = 8'h5e;  // Left Alt
	7'h74: arc = 8'h61;  // Right Ctrl
	7'h75: arc = 8'h58;  // Right Shift
	7'h76: arc = 8'h60;  // Right Alt
	default: ;
	endcase
end

always @(posedge clk) begin
	key_strobe <= 1'b0;
	if (reset) begin
		state <= 120'd0;
		item <= 7'd0;
	end else if (!(item == 7'd0 && rollover)) begin
		if (now != state[item]) begin
			state[item] <= now;
			if (arc != 8'hFF) begin
				key_strobe <= 1'b1;
				key_code <= arc;
				key_up <= !now;
			end
		end
		item <= (item == 7'd119) ? 7'd0 : item + 7'd1;
	end
end

// ------------------------------------------------------------------ mouse

reg ms_upd_d = 1'b0;
always @(posedge clk) begin
	ms_upd_d <= ms_upd;
	mouse_strobe <= 1'b0;
	if (ms_upd != ms_upd_d) begin
		mouse_strobe <= 1'b1;
		mouse_dx <= ms_x;
		mouse_dy <= ms_y;
		mouse_buttons <= ms_b;
	end
end

// ------------------------------------------------------------------ joysticks

assign joy0 = ~{ joy_l[6] | joy_l[7], joy_l[4], joy_l[3], joy_l[2], joy_l[1] };
assign joy1 = ~{ joy_r[6] | joy_r[7], joy_r[4], joy_r[3], joy_r[2], joy_r[1] };

endmodule
