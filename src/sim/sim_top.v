`timescale 1ns / 1ps
/*
 sim_top.v: the machine of Ф1 for Verilator (run_boot.sh).

 archimedes_top (rtl/sv2v, what XST builds) on one clock (40 MHz as the boards: CPU, VIDC, audio), with the
 karabas parts of the board tops: archie_ce (VIDC enables), archie_cmos, archie_kbd. The memory is a
 behavioural model of the wishbone side of the Archie_MiSTer sdram.v: 16 MB of 32-bit words (RAM at
 0, the RISC OS ROM at 0x400000, written by the C++ harness), a read answers four words on four
 clocks in a row starting at the asked word and wrapping in its 16-byte line (SDRAM BL8), a write one
 ack with the byte selects; the first ack comes RD_LAT / WR_LAT clocks after the request.
*/

module sim_top #(
	parameter integer RD_LAT = 5,
	parameter integer WR_LAT = 3
) (
	input wire clk,
	input wire reset,

	// video
	output wire [3:0] r,
	output wire [3:0] g,
	output wire [3:0] b,
	output wire de,
	output wire hs_n,
	output wire vs_n,
	output wire ce_pix,
	output wire [1:0] baseclk,
	output wire [1:0] selpix,

	// audio
	output wire [15:0] audio_l,
	output wire [15:0] audio_r,

	// keyboard / mouse
	input wire key_strobe,
	input wire [7:0] key_code,
	input wire key_up,
	input wire mouse_strobe,
	input wire [7:0] mouse_dx,
	input wire [7:0] mouse_dy,
	input wire [2:0] mouse_buttons,
	output wire kbd_scan,
	output wire kbd_mouse,

	// trace
	output wire [7:0] kbd_rx_data,
	output wire kbd_rx_strobe,
	output wire [7:0] kbd_tx_data,
	output wire kbd_tx_strobe,
	output wire fdd_led,
	output wire [7:0] cmos_changes,
	output wire [25:0] cpu_pc,  // the ARM r15 address (hierarchical, for the trace)
	output wire i2c_scl,
	output wire i2c_sda_m,      // driven by the IOC (open drain: 0 pulls low)
	output wire i2c_sda_s,      // driven by the CMOS
	output wire [18:0] vid_init, // MEMC video DMA pointers (hierarchical, for the trace)
	output wire [18:0] vid_start,
	output wire [18:0] vid_end,
	output wire wr_strobe,       // a memory write (the ack of the model)
	output wire [21:0] wr_addr   // its word address
);
assign wr_strobe = mem_ack & mem_we;
assign wr_addr = line;
assign vid_init = archie.MEMC.vid_init;
assign vid_start = archie.MEMC.vid_start;
assign vid_end = archie.MEMC.vid_end;
assign i2c_scl = i2c_clock;
assign i2c_sda_m = i2c_dout;
assign i2c_sda_s = i2c_din;


assign cpu_pc = {archie.ARM.u_execute.u_register_bank.r15, 2'b00};

// ---------------- memory model
reg [31:0] mem [0:4194303] /* verilator public */;

wire mem_cyc, mem_stb, mem_we;
wire [3:0] mem_sel;
wire [2:0] mem_cti;
wire [23:2] mem_addr;
wire [31:0] mem_dout;
reg [31:0] mem_din = 32'd0;
reg mem_ack = 1'b0;

reg [3:0] wait_cnt = 4'd0;
reg [2:0] words = 3'd0;    // read words still to send
reg busy = 1'b0;
reg [21:0] line;           // word address being sent
wire req = mem_cyc & mem_stb & ~mem_ack;

always @(posedge clk) begin
	mem_ack <= 1'b0;
	if (!busy) begin
		if (req && !mem_ack) begin
			busy <= 1'b1;
			wait_cnt <= mem_we ? WR_LAT[3:0] : RD_LAT[3:0];
			words <= mem_we ? 3'd1 : 3'd4;
			line <= mem_addr;
		end
	end else if (wait_cnt != 4'd0) begin
		wait_cnt <= wait_cnt - 4'd1;
	end else if (!(mem_cyc & mem_stb)) begin
		busy <= 1'b0;      // the master gave up
		words <= 3'd0;
	end else begin
		mem_ack <= 1'b1;
		if (mem_we) begin
			if (mem_sel[0]) mem[line][7:0] <= mem_dout[7:0];
			if (mem_sel[1]) mem[line][15:8] <= mem_dout[15:8];
			if (mem_sel[2]) mem[line][23:16] <= mem_dout[23:16];
			if (mem_sel[3]) mem[line][31:24] <= mem_dout[31:24];
		end else
			mem_din <= mem[line];
		line[1:0] <= line[1:0] + 2'd1;
		words <= words - 3'd1;
		if (words == 3'd1) busy <= 1'b0;
	end
end

// ---------------- the machine
wire ce_aud;
wire i2c_dout, i2c_din, i2c_clock;
wire hires_mono;
wire [7:0] kbd_out_data, kbd_in_data;
wire kbd_out_strobe, kbd_in_strobe;

archie_ce #(.CLK_HZ(40000000)) u_ce (
	.clk(clk), .reset(reset), .baseclk(baseclk), .selpix(selpix), .ce_pix(ce_pix), .ce_aud(ce_aud)
);

// the IDE podule: archie_ide (hdf_ata) as on the boards, device 0 on the image of +hdf=FILE
wire [2:0] ide_a;
wire ide_cs, ide_rd, ide_wr;
wire [15:0] ide_wdata, ide_rdata;
wire hd_mnt, hd_busy, hd_done, hd_err, hd_strobe;
wire [63:0] hd_size;
wire [1:0] hd_rd, hd_wr;
wire [31:0] hd_sector;
wire [8:0] hd_baddr;
wire [7:0] hd_bin, hd_bout;
archie_ide ide (
	.clk(clk), .reset(1'b0), .ata_reset(reset),
	.ide_a(ide_a), .ide_cs(ide_cs), .ide_rd(ide_rd), .ide_wr(ide_wr), .ide_wdata(ide_wdata), .ide_rdata(ide_rdata),
	.img_mounted({ 1'b0, hd_mnt }), .img_size(hd_size), .sdc_rd(hd_rd), .sdc_wr(hd_wr), .sdc_sector(hd_sector),
	.sdc_busy(hd_busy), .sdc_done(hd_done), .sdc_error(hd_err), .sdc_byte_in_strobe(hd_strobe),
	.sdc_byte_addr(hd_baddr), .sdc_byte_in_data(hd_bin), .sdc_byte_out_data(hd_bout), .led()
);
sdc_file_model #(.MOUNT_AT(4000)) hdf (
	.clk(clk), .img_mounted(hd_mnt), .img_size(hd_size), .sdc_rd(hd_rd[0]), .sdc_wr(hd_wr[0]), .sdc_sector(hd_sector),
	.sdc_busy(hd_busy), .sdc_done(hd_done), .sdc_error(hd_err), .sdc_byte_in_strobe(hd_strobe),
	.sdc_byte_addr(hd_baddr), .sdc_byte_in_data(hd_bin), .sdc_byte_out_data(hd_bout)
);

archimedes_top #(.CLKCPU(40000000)) archie (
	.CLKCPU_I(clk),
	.CLKPIX_I(clk),
	.CEPIX_I(ce_pix),
	.CEVID_I(ce_pix),
	.SELPIX_O(selpix),
	.HIRES_MONO_O(hires_mono),
	.CLKAUD_I(clk),
	.CEAUD_I(ce_aud),
	.RESET_I(reset),
	.RESET_VIDEO_I(reset),
	.RESET_VIDEO_CPU_I(reset),
	.RESET_COMMAND_I(reset),
	.MEM_CYC_O(mem_cyc),
	.MEM_STB_O(mem_stb),
	.MEM_WE_O(mem_we),
	.MEM_ACK_I(mem_ack),
	.MEM_ERR_I(1'b0),
	.MEM_RTY_I(1'b0),
	.MEM_SEL_O(mem_sel),
	.MEM_CTI_O(mem_cti),
	.MEM_ADDR_O(mem_addr),
	.MEM_DAT_I(mem_din),
	.MEM_DAT_O(mem_dout),
	.HSYNC(hs_n),
	.VSYNC(vs_n),
	.VIDEO_R(r),
	.VIDEO_G(g),
	.VIDEO_B(b),
	.VIDEO_EN(de),
	.VIDBASECLK_O(baseclk),
	.VIDSYNCPOL_O(),
	.I2C_DOUT(i2c_dout),
	.I2C_DIN(i2c_din),
	.I2C_CLOCK(i2c_clock),
	.fdd_led(fdd_led),
	.img_mounted(2'b00),
	.img_wp(1'b0),
	.img_size(32'd0),
	.sd_lba(),
	.sd_rd(),
	.sd_wr(),
	.sd_ack(1'b0),
	.sd_buff_addr(8'd0),
	.sd_buff_dout(16'd0),
	.sd_buff_din(),
	.sd_buff_wr(1'b0),
	.ide_a(ide_a),
	.ide_cs(ide_cs),
	.ide_rd(ide_rd),
	.ide_wr(ide_wr),
	.ide_wdata(ide_wdata),
	.ide_rdata(ide_rdata),
	.KBD_OUT_DATA(kbd_out_data),
	.KBD_OUT_STROBE(kbd_out_strobe),
	.KBD_IN_DATA(kbd_in_data),
	.KBD_IN_STROBE(kbd_in_strobe),
	.JOYSTICK0(5'h1f),
	.JOYSTICK1(5'h1f),
	.AUDIO_L(audio_l),
	.AUDIO_R(audio_r)
);

wire [7:0] rtc_a, rtc_di, rtc_do;
wire rtc_cs, rtc_wr_n;
archie_cmos u_cmos (
	.clk(clk), .reset(reset), .scl(i2c_clock), .sda_in(i2c_dout), .sda_out(i2c_din),
	.rtc_a(rtc_a), .rtc_di(rtc_di), .rtc_do(rtc_do), .rtc_cs(rtc_cs), .rtc_wr_n(rtc_wr_n),
	.changes(cmos_changes)
);
// the RTC registers of kg_mcu
rtc_model u_rtc (.clk(clk), .rtc_a(rtc_a), .rtc_di(rtc_di), .rtc_do(rtc_do), .rtc_cs(rtc_cs), .rtc_wr_n(rtc_wr_n));

archie_kbd #(.CLK_HZ(40000000)) u_kbd (
	.clk(clk),
	.reset(reset),
	.kbd_out_data(kbd_out_data),
	.kbd_out_strobe(kbd_out_strobe),
	.kbd_in_data(kbd_in_data),
	.kbd_in_strobe(kbd_in_strobe),
	.key_strobe(key_strobe),
	.key_code(key_code),
	.key_up(key_up),
	.mouse_strobe(mouse_strobe),
	.mouse_dx(mouse_dx),
	.mouse_dy(mouse_dy),
	.mouse_buttons(mouse_buttons),
	.scan_enabled(kbd_scan),
	.mouse_enabled(kbd_mouse)
);

assign kbd_rx_data = kbd_out_data;
assign kbd_rx_strobe = kbd_out_strobe;
assign kbd_tx_data = kbd_in_data;
assign kbd_tx_strobe = kbd_in_strobe;

endmodule
