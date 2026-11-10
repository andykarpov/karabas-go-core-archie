module vidc_timing (
	clkcpu,
	wr,
	cpu_dat,
	clkvid,
	cevid,
	rst,
	pixel_depth,
	o_vsync,
	o_hsync,
	o_cursor,
	o_enabled,
	o_border,
	o_flyback,
	o_hires_geometry,
	o_cursor_phase,
	o_cursor_fetch
);
	input clkcpu;
	input wr;
	input [31:0] cpu_dat;
	input clkvid;
	input cevid;
	input rst;
	input [1:0] pixel_depth;
	output wire o_vsync;
	output wire o_hsync;
	output wire o_cursor;
	output wire o_enabled;
	output wire o_border;
	output wire o_flyback;
	output wire o_hires_geometry;
	output wire [1:0] o_cursor_phase;
	output wire o_cursor_fetch;
	reg [10:0] hcount;
	reg [9:0] vcount;
	localparam VIDEO_HCR = 6'b100000;
	localparam VIDEO_HSWR = 6'b100001;
	localparam VIDEO_HBSR = 6'b100010;
	localparam VIDEO_HDSR = 6'b100011;
	localparam VIDEO_HDER = 6'b100100;
	localparam VIDEO_HBER = 6'b100101;
	localparam VIDEO_VCR = 6'b101000;
	localparam VIDEO_VSWR = 6'b101001;
	localparam VIDEO_VBSR = 6'b101010;
	localparam VIDEO_VDSR = 6'b101011;
	localparam VIDEO_VDER = 6'b101100;
	localparam VIDEO_VBER = 6'b101101;
	localparam VIDEO_VCSR = 6'b101110;
	localparam VIDEO_VCER = 6'b101111;
	localparam VIDEO_HCSR = 6'b100110;
	reg [9:0] vidc_vcr;
	reg [9:0] vidc_vswr;
	reg [9:0] vidc_vbsr;
	reg [9:0] vidc_vdsr;
	reg [9:0] vidc_vder;
	reg [9:0] vidc_vber;
	reg [10:0] vidc_hcr;
	reg [10:0] vidc_hswr;
	reg [10:0] vidc_hbsr;
	reg [10:0] vidc_hdsr;
	reg [10:0] vidc_hder;
	reg [10:0] vidc_hber;
	reg [12:0] vidc_hcsr;
	reg [9:0] vidc_vcsr;
	reg [9:0] vidc_vcer;
	initial begin
		vidc_vcr = 10'd0;
		vidc_vswr = 10'd0;
		vidc_vbsr = 10'd0;
		vidc_vdsr = 10'd0;
		vidc_vder = 10'd0;
		vidc_vber = 10'd0;
		vidc_hcr = 11'd0;
		vidc_hswr = 11'd0;
		vidc_hbsr = 11'd0;
		vidc_hdsr = 11'd0;
		vidc_hder = 11'd0;
		vidc_hber = 11'd0;
		vidc_hcsr = 13'd0;
		vidc_vcsr = 10'd0;
		vidc_vcer = 10'd0;
	end
	always @(posedge clkcpu)
		if (wr) begin
			$display("Writing the timing registers: 0x%08x", cpu_dat);
			case (cpu_dat[31:26])
				VIDEO_VCR: vidc_vcr <= cpu_dat[23:14];
				VIDEO_VSWR: vidc_vswr <= cpu_dat[23:14];
				VIDEO_VBSR: vidc_vbsr <= cpu_dat[23:14];
				VIDEO_VBER: vidc_vber <= cpu_dat[23:14];
				VIDEO_VDSR: vidc_vdsr <= cpu_dat[23:14];
				VIDEO_VDER: vidc_vder <= cpu_dat[23:14];
				VIDEO_HCR: vidc_hcr <= {cpu_dat[23:14], 1'b0};
				VIDEO_HSWR: vidc_hswr <= {cpu_dat[23:14], 1'b0};
				VIDEO_HBSR: vidc_hbsr <= {cpu_dat[23:14], 1'b0};
				VIDEO_HBER: vidc_hber <= {cpu_dat[23:14], 1'b0};
				VIDEO_HDSR: vidc_hdsr <= {cpu_dat[23:14], 1'b0};
				VIDEO_HDER: vidc_hder <= {cpu_dat[23:14], 1'b0};
				VIDEO_HCSR: vidc_hcsr <= cpu_dat[23:11];
				VIDEO_VCSR: vidc_vcsr <= cpu_dat[23:14];
				VIDEO_VCER: vidc_vcer <= cpu_dat[23:14];
				default: vidc_vcr <= vidc_vcr;
			endcase
		end
	reg vborder;
	reg hborder;
	reg vdisplay;
	reg hdisplay;
	reg vflyback;
	reg vcursor;
	reg hcursor;
	reg hcursor_fetch;
	reg hsync;
	reg vsync;
	assign o_cursor = hcursor & vcursor;
	assign o_cursor_fetch = hcursor_fetch & vcursor;
	assign o_flyback = vflyback;
	assign o_enabled = hdisplay & vdisplay;
	assign o_border = hborder & vborder;
	assign o_vsync = ~vsync;
	assign o_hsync = ~hsync;
	wire [10:0] hcr_end = vidc_hcr + 11'd1;
	wire [10:0] hswr_end = vidc_hswr + 11'd1;
	wire [10:0] hbsr_end = vidc_hbsr;
	wire [10:0] hber_end = vidc_hber;
	wire [10:0] display_pipeline = (pixel_depth == 2'b11 ? 11'd4 : (pixel_depth == 2'b10 ? 11'd6 : (pixel_depth == 2'b01 ? 11'd10 : 11'd18)));
	wire [10:0] mode23_display_offset = ((pixel_depth == 2'b10) && o_hires_geometry ? 11'd2 : 11'd0);
	wire [10:0] hdsr_end = (vidc_hdsr + display_pipeline) - mode23_display_offset;
	wire [10:0] hder_end = (vidc_hder + display_pipeline) - mode23_display_offset;
	wire mode23_hcsr = (pixel_depth == 2'b10) && o_hires_geometry;
	wire [10:0] hcsr_base = vidc_hcsr[12:2];
	assign o_cursor_phase = (mode23_hcsr ? vidc_hcsr[1:0] : 2'd0);
	wire [10:0] hcsr_end = hcsr_base + 11'd5;
	wire [10:0] hcsr_fetch_end = (mode23_hcsr ? hcsr_end - 11'd12 : hcsr_end);
	assign o_hires_geometry = (((vidc_hcr >= 11'd384) && (vidc_hcr <= 11'd400)) && (vidc_vcr >= 10'd940)) && (vidc_vcr <= 10'd960);
	always @(posedge clkvid)
		if (rst) begin
			hcount <= 0;
			vcount <= 0;
			hborder <= 0;
			vborder <= 0;
			hsync <= 0;
			vsync <= 0;
			vflyback <= 0;
			hdisplay <= 0;
			vdisplay <= 0;
			hcursor <= 0;
			hcursor_fetch <= 0;
			vcursor <= 0;
		end
		else if (cevid) begin
			hcount <= hcount + 1'd1;
			if (hcount == hbsr_end)
				hborder <= 1;
			if (hcount == hber_end)
				hborder <= 0;
			if (hcount == hdsr_end)
				hdisplay <= 1;
			if (hcount == hder_end)
				hdisplay <= 0;
			if (hcount == hcsr_end)
				hcursor <= 1;
			if (hcount == hcsr_fetch_end)
				hcursor_fetch <= 1;
			if (hcount == hswr_end)
				hsync <= 0;
			if (hcount == hcr_end) begin
				hcount <= 0;
				hcursor <= 0;
				hcursor_fetch <= 0;
				hsync <= 1;
				vcount <= vcount + 1'd1;
				if (vcount == vidc_vbsr)
					vborder <= 1;
				if (vcount == vidc_vber)
					vborder <= 0;
				if (vcount == vidc_vdsr)
					vdisplay <= 1;
				if (vcount == vidc_vder) begin
					vdisplay <= 0;
					vflyback <= 1;
				end
				if (vcount == vidc_vcsr)
					vcursor <= 1;
				if (vcount == vidc_vcer)
					vcursor <= 0;
				if (vcount == vidc_vswr) begin
					vsync <= 0;
					vflyback <= 0;
				end
				if (vcount == vidc_vcr) begin
					vcount <= 0;
					vflyback <= 1;
					vsync <= 1;
				end
			end
		end
endmodule
