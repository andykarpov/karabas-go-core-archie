`timescale 1ns / 1ps
// tb_hid.v (iverilog): archie_hid on reports as kg_mcu gives them: F12 down, up; Left Ctrl; a and b
// together; the events must be the Archimedes key numbers with up / down.
module tb_hid;
reg clk = 0;
always #12.5 clk = ~clk;
reg [7:0] st = 0, d0 = 0, d1 = 0, d2 = 0, d3 = 0, d4 = 0, d5 = 0;
wire ks, ku; wire [7:0] kc;
archie_hid hid (.clk(clk), .reset(1'b0), .kb_status(st), .kb_dat0(d0), .kb_dat1(d1), .kb_dat2(d2),
	.kb_dat3(d3), .kb_dat4(d4), .kb_dat5(d5), .ms_x(8'd0), .ms_y(8'd0), .ms_b(3'd0), .ms_upd(1'b0),
	.joy_l(13'd0), .joy_r(13'd0), .key_strobe(ks), .key_code(kc), .key_up(ku),
	.mouse_strobe(), .mouse_dx(), .mouse_dy(), .mouse_buttons(), .joy0(), .joy1());
always @(posedge clk) if (ks) $display("%0t ns: key %02x %s", $time, kc, ku ? "up" : "down");
initial begin
	#5000;
	$display("-- F12 (45)"); d0 = 8'h45; #10000; d0 = 8'h00; #10000;
	$display("-- Left Ctrl (status bit 0)"); st = 8'h01; #10000; st = 8'h00; #10000;
	$display("-- a (04) + b (05)"); d0 = 8'h04; d1 = 8'h05; #10000; d0 = 8'h00; d1 = 8'h00; #10000;
	$finish;
end
endmodule
