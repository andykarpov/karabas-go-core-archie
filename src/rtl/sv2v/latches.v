module latches (
	clkcpu,
	wb_cyc,
	wb_stb,
	wb_we,
	wb_adr,
	wb_dat_i,
	wb_dat_o,
	floppy_drive,
	floppy_side,
	floppy_motor,
	floppy_inuse,
	floppy_density,
	floppy_reset,
	joy0,
	joy1,
	baseclk,
	syncpol
);
	input clkcpu;
	input wb_cyc;
	input wb_stb;
	input wb_we;
	input [15:2] wb_adr;
	input [7:0] wb_dat_i;
	output wire [7:0] wb_dat_o;
	output wire [3:0] floppy_drive;
	output wire floppy_side;
	output wire floppy_motor;
	output wire floppy_inuse;
	output wire floppy_density;
	output wire floppy_reset;
	input [4:0] joy0;
	input [4:0] joy1;
	output wire [1:0] baseclk;
	output wire [1:0] syncpol;
	reg [7:0] ext_latch_a;
	reg [7:0] ext_latch_b;
	reg [7:0] ext_latch_c;
	wire write_request = (wb_stb & wb_cyc) & wb_we;
	initial begin
		ext_latch_a = 8'hff;
		ext_latch_b = 8'hff;
		ext_latch_c = 8'd0;
	end
	always @(posedge clkcpu)
		if (write_request)
			case (wb_adr)
				14'h0010: ext_latch_a <= wb_dat_i;
				14'h0006: ext_latch_b <= wb_dat_i;
				14'h0012: ext_latch_c <= wb_dat_i;
			endcase
	assign floppy_drive = ext_latch_a[3:0];
	assign floppy_side = ext_latch_a[4];
	assign floppy_motor = ext_latch_a[5];
	assign floppy_inuse = ext_latch_a[6];
	assign floppy_density = ext_latch_b[1];
	assign floppy_reset = ext_latch_b[3];
	assign wb_dat_o = (wb_adr == 14'h001e ? {3'b011, joy0} : (wb_adr == 14'h001f ? {3'b011, joy1} : 8'hff));
	assign baseclk = ext_latch_c[1:0];
	assign syncpol = ext_latch_c[3:2];
endmodule
