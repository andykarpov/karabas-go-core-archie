`timescale 1ns / 1ps
/*
 sim_top_sdram.v: sim_top.v with the memory of the boards: the RAM in archie_sram on sram_model (bank 0
 of the wishbone bus), the ROM and the frame buffer in archie_sdram on sdram_model (clk_mem 80 MHz,
 clk = clk_sys 40 MHz, rising together), the frame buffer archie_fb (800 x 600 at 60 Hz on clk);
 the ROM is put into bank 1 of the model by the harness. run_boot.sh SDRAM=1.

 Below: the text of sim_top.v.

 archimedes_top (rtl/sv2v, what XST builds) on one clock (40 MHz as the boards: CPU, VIDC, audio), with the
 karabas parts of the board tops: archie_ce (VIDC enables), archie_cmos, archie_kbd. The memory is a
 behavioural model of the wishbone side of the Archie_MiSTer sdram.v: 16 MB of 32-bit words (RAM at
 0, the RISC OS ROM at 0x400000, written by the C++ harness), a read answers four words on four
 clocks in a row starting at the asked word and wrapping in its 16-byte line (SDRAM BL8), a write one
 ack with the byte selects; the first ack comes RD_LAT / WR_LAT clocks after the request.
*/

module sim_top_sdram #(
	parameter integer RD_LAT = 5,
	parameter integer WR_LAT = 3
) (
	input wire clk,
	input wire clk_mem,
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
	output wire [21:0] wr_addr,  // its word address
	output wire [23:0] fb_rgb,
	output wire fb_hs,
	output wire fb_vs,
	output wire fb_de,
	output wire [31:0] sdr_errors,
	output wire [31:0] sram_errors,
	output wire sdr_ready,
	output wire [7:0] fb_dropped
);

assign vid_init = archie.MEMC.vid_init;
assign vid_start = archie.MEMC.vid_start;
assign vid_end = archie.MEMC.vid_end;
assign i2c_scl = i2c_clock;
assign i2c_sda_m = i2c_dout;
assign i2c_sda_s = i2c_din;


assign cpu_pc = {archie.ARM.u_execute.u_register_bank.r15, 2'b00};

// ---------------- memory: the RAM in the SRAM, the ROM and the frame buffer in the SDRAM
wire mem_cyc, mem_stb, mem_we;
wire [3:0] mem_sel;
wire [2:0] mem_cti;
wire [23:2] mem_addr;
wire [31:0] mem_dout;
wire [31:0] mem_din;
wire mem_ack;
wire ram_sel = mem_addr[23:22] == 2'b00;
wire [31:0] sram_din, sdram_din;
wire sram_ack, sdram_ack;
assign mem_din = ram_sel ? sram_din : sdram_din;
assign mem_ack = ram_sel ? sram_ack : sdram_ack;
wire [20:0] sram_ma;
wire [15:0] sram_md;
wire [1:0] sram_mwr_n, sram_mrd_n;
archie_sram sram (
	.clk(clk), .wb_cyc(mem_cyc & ram_sel), .wb_stb(mem_stb & ram_sel), .wb_we(mem_we), .wb_sel(mem_sel),
	.wb_adr(mem_addr[21:2]), .wb_dat_i(mem_dout), .wb_dat_o(sram_din), .wb_ack(sram_ack),
	.MA(sram_ma), .MD(sram_md), .MWR_N(sram_mwr_n), .MRD_N(sram_mrd_n)
);
sram_model sram_m (.clk(clk), .ma(sram_ma), .md(sram_md), .mwr_n(sram_mwr_n), .mrd_n(sram_mrd_n),
	.md_driven(sram.md_oe_n != 16'hFFFF));
assign sram_errors = sram_m.errors;
wire fbw_req, fbr_req, fbw_buf, fbr_buf, fbw_busy, fbr_busy, fbr_we;
wire [11:0] fbw_row, fbr_row;
wire [10:0] fbw_len, fbr_len, fbw_addr, fbr_addr;
wire [15:0] fbw_data, fbr_data;
wire [12:0] sdr_a;
wire [1:0] sdr_ba, sdr_dqm;
wire sdr_ras_n, sdr_cas_n, sdr_we_n;
wire [15:0] sdr_dq;
archie_sdram #(.INIT_CLOCKS(15'd200)) sdram (
	.clk(clk_mem), .wb_clk(clk), .reset(1'b0), .ready(sdr_ready),
	.wb_cyc(mem_cyc & ~ram_sel), .wb_stb(mem_stb & ~ram_sel), .wb_we(mem_we), .wb_sel(mem_sel), .wb_adr(mem_addr),
	.wb_dat_i(mem_dout), .wb_dat_o(sdram_din), .wb_ack(sdram_ack),
	.fbw_req(fbw_req), .fbw_row(fbw_row), .fbw_len(fbw_len), .fbw_buf(fbw_buf), .fbw_addr(fbw_addr),
	.fbw_data(fbw_data), .fbw_busy(fbw_busy),
	.fbr_req(fbr_req), .fbr_row(fbr_row), .fbr_len(fbr_len), .fbr_buf(fbr_buf), .fbr_we(fbr_we),
	.fbr_addr(fbr_addr), .fbr_data(fbr_data), .fbr_busy(fbr_busy),
	.sdr_a(sdr_a), .sdr_ba(sdr_ba), .sdr_dq(sdr_dq), .sdr_dqm(sdr_dqm), .sdr_ras_n(sdr_ras_n),
	.sdr_cas_n(sdr_cas_n), .sdr_we_n(sdr_we_n)
);
sdram_model model (.clk(clk_mem), .ba(sdr_ba), .a(sdr_a), .dqm(sdr_dqm), .ras_n(sdr_ras_n), .cas_n(sdr_cas_n),
	.we_n(sdr_we_n), .dq(sdr_dq));
assign sdr_errors = model.errors;
assign wr_strobe = mem_ack & mem_we;
assign wr_addr = mem_addr;

archie_fb fb (
	.clk_sys(clk), .clk_mem(clk_mem), .clk_pix(clk),
	.ce(ce_pix), .r_i(r), .g_i(g), .b_i(b), .de_i(de), .vs_n_i(vs_n),
	.fbw_req(fbw_req), .fbw_row(fbw_row), .fbw_len(fbw_len), .fbw_buf(fbw_buf), .fbw_addr(fbw_addr),
	.fbw_data(fbw_data), .fbw_busy(fbw_busy),
	.fbr_req(fbr_req), .fbr_row(fbr_row), .fbr_len(fbr_len), .fbr_buf(fbr_buf), .fbr_we(fbr_we),
	.fbr_addr(fbr_addr), .fbr_data(fbr_data), .fbr_busy(fbr_busy),
	.rgb(fb_rgb), .hs(fb_hs), .vs(fb_vs), .de(fb_de), .cap_w(), .cap_h(), .dropped(fb_dropped)
);

// ---------------- the machine
wire ce_aud;
wire i2c_dout, i2c_din, i2c_clock;
wire hires_mono;
wire [7:0] kbd_out_data, kbd_in_data;
wire kbd_out_strobe, kbd_in_strobe;

archie_ce #(.CLK_HZ(40000000)) u_ce (
	.clk(clk), .reset(reset), .baseclk(baseclk), .selpix(selpix), .ce_pix(ce_pix), .ce_aud(ce_aud)
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
	.RESET_I(reset | ~sdr_ready),
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
	.hdd_led(),
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
	.ide_req(),
	.ide_address(5'd0),
	.ide_write(1'b0),
	.ide_writedata(16'd0),
	.ide_read(1'b0),
	.ide_readdata(),
	.KBD_OUT_DATA(kbd_out_data),
	.KBD_OUT_STROBE(kbd_out_strobe),
	.KBD_IN_DATA(kbd_in_data),
	.KBD_IN_STROBE(kbd_in_strobe),
	.JOYSTICK0(5'h1f),
	.JOYSTICK1(5'h1f),
	.AUDIO_L(audio_l),
	.AUDIO_R(audio_r)
);

archie_cmos u_cmos (
	.clk(clk), .reset(reset), .scl(i2c_clock), .sda_in(i2c_dout), .sda_out(i2c_din), .changes(cmos_changes)
);

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
