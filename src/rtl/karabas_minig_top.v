`timescale 1ns / 1ps
`default_nettype wire

/*
 Acorn Archimedes core for Karabas Mini rev.G (HDMI, PCM5102): archimedes_top of Archie_MiSTer
 (rtl/sv2v) with the karabas parts (rtl/karabas) and the board glue of karabas-go-modules.

 Clocks: one PLL, VCO 800 MHz (50 * 16): clk_mem 80 MHz (/10: the SDRAM controller), clk_sys 40 MHz
 (/20: the machine, the VIDC with its pixel enables, the frame buffer output = VESA 800 x 600 at 60 Hz,
 the OSD, the MCU link, audio), clk_8 8.0 MHz (/100, FT_CLK_OUT), clk_sdr 80 MHz at 225 degrees
 (/10: SDR_CLK through an ODDR2, 7.8 ns after clk_mem: setup for the commands, the read data inside
 the window the falling edge of clk_mem takes). A DCM makes the 200 MHz of the HDMI serialiser
 from clk_sys. MiSTer runs the machine at 42 MHz; 40 MHz is the MiST clock: the IOC 2 MHz and the
 FDC 8 MHz enables come from CLKCPU (archimedes_top).

 Memory: the RAM 4 MB in the SRAM (archie_sram, bank 0 of the wishbone bus, on clk_sys); the RISC OS
 ROM (bank 1, the FL item RISC OS: archie_loader writes it while the machine is held in reset) and the
 frame buffer (bank 2) in the SDRAM (archie_sdram): the frame buffer shares the SDRAM with the reads
 of the ROM only.

 Video: the VIDC (whatever mode RISC OS sets) into the frame buffer (archie_fb), out as 800 x 600 at
 60 Hz with the OSD.

 Keyboard and mouse: archie_hid (USB report -> key events, usb2archie) and archie_kbd (the protocol
 of the Archimedes keyboard on the IOC link). CMOS: archie_cmos (defaults of the MiSTer cmos.mif).

 Soft switches (the index of the item in the osd of core.json, file items included):
   0 RISC OS (FL 7)   1 Reset
*/

module karabas_minig_top (
	input wire CLK_50MHZ,

	inout wire UART_RX,
	inout wire UART_TX,
	inout wire UART_CTS,

	output wire [20:0] MA,
	inout wire [15:0] MD,
	output wire [1:0] MWR_N,
	output wire [1:0] MRD_N,

	output wire [1:0] SDR_BA,
	output wire [12:0] SDR_A,
	output wire SDR_CLK,
	output wire [1:0] SDR_DQM,
	output wire SDR_WE_N,
	output wire SDR_CAS_N,
	output wire SDR_RAS_N,
	inout wire [15:0] SDR_DQ,

	output wire SD_CS_N,
	output wire SD_CLK,
	output wire SD_DI,
	input wire SD_DO,
	input wire SD_DET_N,

	input wire [7:0] VGA_R,
	input wire [7:0] VGA_G,
	input wire [7:0] VGA_B,
	input wire VGA_HS,
	input wire VGA_VS,

	output wire [3:0] TMDS_P,
	output wire [3:0] TMDS_N,

	output wire FT_SPI_CS_N,
	output wire FT_SPI_SCK,
	input wire FT_SPI_MISO,
	output wire FT_SPI_MOSI,
	input wire FT_INT_N,
	input wire FT_CLK,
	input wire FT_DE,
	output wire FT_CLK_OUT,

	output wire [2:0] WA,
	output wire [1:0] WCS_N,
	output wire WRD_N,
	output wire WWR_N,
	output wire WRESET_N,
	inout wire [15:0] WD,

	output wire TAPE_OUT,
	input wire TAPE_IN,

	output wire DAC_BCK,
	output wire DAC_WS,
	output wire DAC_DAT,

	output wire ADC_CLK,
	inout wire ADC_BCK,
	inout wire ADC_LRCK,
	input wire ADC_DOUT,

	input wire MCU_CS_N,
	input wire MCU_SCK,
	inout wire MCU_MOSI,
	output wire MCU_MISO,
	inout wire [5:0] MCU_IO, // [0] burst cs_n, [1] burst ready, [2] sd2 cs_n, [3] ft cs_n

	output wire MIDI_TX,

	output wire ESP32_SPI_CS_N,
	input wire ESP32_PCM_BCK,
	input wire ESP32_PCM_RLCK,
	input wire ESP32_PCM_DAT,

	output wire FLASH_CS_N,
	input wire FLASH_DO,
	output wire FLASH_DI,
	output wire FLASH_SCK,
	output wire FLASH_WP_N,
	output wire FLASH_HOLD_N
);

// ------------------------------------------------------------------ unused

assign WA = 3'b000;
assign WCS_N = 2'b11;
assign WRD_N = 1'b1;
assign WWR_N = 1'b1;
assign WRESET_N = 1'b1;
assign WD = 16'bz;

assign TAPE_OUT = 1'b0;
assign ESP32_SPI_CS_N = 1'b1;
assign UART_RX = 1'bz;
assign UART_TX = 1'bz;
assign UART_CTS = 1'bz;


assign ADC_CLK = 1'b0;
assign ADC_BCK = 1'bz;
assign ADC_LRCK = 1'bz;
assign MIDI_TX = 1'b1;

// FLASH_CS_N (T3) is the SDRAM /CS of Mini G2 (rev G: tied low on the board): always selected
assign FLASH_CS_N = 1'b0;
assign FLASH_DI = 1'b1;
assign FLASH_SCK = 1'b0;
assign FLASH_WP_N = 1'b1;
assign FLASH_HOLD_N = 1'b1;

// ------------------------------------------------------------------ clocks

wire clk_mem, clk_sys, clk_8, clk_sdr;
wire locked, lockedx5, areset;
wire clk_hdmi, clk_hdmi_n;

wire [5:0] pll_clk;
kg_pll #(
	.CLKIN_PERIOD(20.0),
	.DIVCLK_DIVIDE(1),
	.CLKFBOUT_MULT(16),
	.CLKOUT0_DIVIDE(20),     // clk_sys 40 MHz
	.CLKOUT1_DIVIDE(10),     // clk_mem 80 MHz
	.CLKOUT2_DIVIDE(100),    // clk_8
	.CLKOUT3_DIVIDE(10),     // clk_sdr 80 MHz, 225 degrees
	.CLKOUT3_PHASE(225.0),
	.BUFG_MASK(6'b001111)
) pll (
	.clk_in(CLK_50MHZ),
	.rst(1'b0),
	.clk_out(pll_clk),
	.locked(locked)
);
assign clk_sys = pll_clk[0];
assign clk_mem = pll_clk[1];
assign clk_8 = pll_clk[2];
assign clk_sdr = pll_clk[3];
assign areset = ~locked;

kg_dcm #(
	.CLKIN_PERIOD(25.0),
	.CLKFX_MULTIPLY(5),
	.CLKFX_DIVIDE(1)
) pllx5 (
	.clk_in(clk_sys),
	.rst(areset),
	.clk_fx(clk_hdmi),
	.clk_fx180(clk_hdmi_n),
	.clk_0(),
	.locked(lockedx5)
);

// the clock of the FT812
ODDR2 oddr_ft_clk (.Q(FT_CLK_OUT), .C0(clk_8), .C1(~clk_8), .CE(1'b1), .D0(1'b1), .D1(1'b0), .R(1'b0), .S(1'b0));

// ------------------------------------------------------------------ MCU

wire mcu_sck_ibufg, mcu_sck;
IBUFG ibufg_mcu_sck (.I(MCU_SCK), .O(mcu_sck_ibufg));
BUFG bufg_mcu_sck (.I(mcu_sck_ibufg), .O(mcu_sck));

wire mcu_burst_ready;
assign MCU_IO[1] = mcu_burst_ready;
assign MCU_IO[0] = 1'bz;
assign MCU_IO[5:2] = 4'bzzzz;

wire [7:0] kb_status, kb_dat0, kb_dat1, kb_dat2, kb_dat3, kb_dat4, kb_dat5;
wire [7:0] uart_rx_data, uart_rx_idx, uart_tx_data;
wire uart_tx_wr;
wire [12:0] joy_l, joy_r;
wire [7:0] ms_x, ms_y;
wire [3:0] ms_z;
wire [2:0] ms_b;
wire ms_upd;
wire rom_active, rom_wr;
wire [31:0] rom_addr;
wire [7:0] rom_data;
wire file_active, file_wr;
wire [7:0] file_slot, file_data;
wire [31:0] file_addr;
wire [15:0] softsw_command, osd_command;
wire mcu_busy;
wire dvi_only;
wire ft_cs_n, ft_mosi, ft_spi_on, sd2_cs_n, sd2_mosi;
wire [7:0] img_mounted, img_data, img_result, img_wp;
wire [63:0] img_size;
wire img_data_wr, img_result_wr, img_q_wr, img_q_ack;
wire [8:0] img_data_addr;
wire [15:0] img_sum;
wire [23:0] img_q_di;
wire [7:0] rtc_a, rtc_do;
wire [15:0] dbg_addr;          // see debug below
wire key_strobe, key_up, mouse_strobe;
wire [7:0] key_code, mouse_dx, mouse_dy;
wire [2:0] mouse_buttons;
wire [7:0] kbd_out_data, kbd_in_data;
wire kbd_out_strobe, kbd_in_strobe;
reg rom_ok = 1'b0;
reg [15:0] dbg_data = 16'd0;
wire ld_overflow, kbd_scan, kbd_mouse;
wire [9:0] fb_cap_h;
wire m_cyc, m_stb;
wire [23:2] m_adr;

kg_mcu #(
	.BURST_MAX_MHZ(32),
	.CS_FILTER(3),
	.ENABLE_RTC(0),
	.ENABLE_UART(0),
	.ENABLE_MATRIX(0),
	.ENABLE_DEBUG(1),    // the state of the machine (AT+KARABAS=debug:1, kg_board.py log)
	.ENABLE_IMG(0),
	.ENABLE_IMG_WP(0),
	.ENABLE_MIDI(0),
	.ENABLE_FILE(1),
	.FILE_CMDS(0),       // the ioctl commands of the FL items
	.FILE_WR_EACH(1),
	.FILE_TO_ROM(0),
	.ENABLE_FT(1),
	.ENABLE_SD2(1)
) mcu (
	.CLK(clk_sys),
	.N_RESET(~areset),

	.MCU_MOSI(MCU_MOSI),
	.MCU_MISO(MCU_MISO),
	.MCU_SCK(mcu_sck),
	.MCU_SS(MCU_CS_N),
	.MCU_SPI_FT_SS(MCU_IO[3]),
	.MCU_SPI_SD2_SS(MCU_IO[2]),
	.MCU_BURST_CS_N(MCU_IO[0]),
	.MCU_BURST_READY(mcu_burst_ready),

	.KB_STATUS(kb_status),
	.KB_DAT0(kb_dat0),
	.KB_DAT1(kb_dat1),
	.KB_DAT2(kb_dat2),
	.KB_DAT3(kb_dat3),
	.KB_DAT4(kb_dat4),
	.KB_DAT5(kb_dat5),
	.KB_SCANCODE(),
	.KB_SCANCODE_UPD(),
	.JOY_L(joy_l),
	.JOY_R(joy_r),
	.MS_X(ms_x),
	.MS_Y(ms_y),
	.MS_Z(ms_z),
	.MS_B(ms_b),
	.MS_UPD(ms_upd),

	.ROMLOADER_ACTIVE(rom_active),
	.ROMLOAD_ADDR(rom_addr),
	.ROMLOAD_DATA(rom_data),
	.ROMLOAD_WR(rom_wr),

	.FILELOAD_ACTIVE(file_active),
	.FILELOAD_ADDR(file_addr),
	.FILELOAD_DATA(file_data),
	.FILELOAD_WR(file_wr),
	.FILELOAD_SLOT(file_slot),

	.SOFTSW_COMMAND(softsw_command),
	.OSD_COMMAND(osd_command),
	.BUSY(mcu_busy),

	.FT_SPI_ON(ft_spi_on),
	.FT_CS_N(ft_cs_n),
	.FT_MOSI(ft_mosi),
	.FT_MISO(FT_SPI_MISO),
	.FT_SCK(),
	.SD2_CS_N(sd2_cs_n),
	.SD2_MOSI(sd2_mosi),
	.SD2_MISO(SD_DO),
	.SD2_SCK(),

	.DVI_ONLY(dvi_only),

	.MIDI_DATA(),
	.MIDI_WR(),
	.MIDI_LOST(),

	.PS2_COMMAND(16'h0000),
	.PS2_COMMAND_WR(1'b0),
	.RTC_A(rtc_a),
	.RTC_DI(8'd0),
	.RTC_DO(rtc_do),
	.RTC_CS(1'b0),
	.RTC_WR_N(1'b1),
	.UART_RX_DATA(uart_rx_data),
	.UART_RX_IDX(uart_rx_idx),
	.UART_TX_DATA(uart_tx_data),
	.UART_TX_WR(uart_tx_wr),
	.UART_TX_MODE(1'b0),
	.UART_DLM(8'h00),
	.UART_DLL(8'h00),
	.UART_DLM_WR(1'b0),
	.UART_DLL_WR(1'b0),
	.MATRIX_CMD(24'h000000),
	.MATRIX_CMD_WR(1'b0),
	.DEBUG_ADDR(dbg_addr),
	.DEBUG_DATA(dbg_data),
	.IMG_MOUNTED(img_mounted),
	.IMG_SIZE(img_size),
	.IMG_WP(img_wp),
	.IMG_DATA_WR(img_data_wr),
	.IMG_DATA_ADDR(img_data_addr),
	.IMG_DATA(img_data),
	.IMG_RESULT_WR(img_result_wr),
	.IMG_RESULT(img_result),
	.IMG_SUM(img_sum),
	.IMG_Q_WR(img_q_wr),
	.IMG_Q_DI(img_q_di),
	.IMG_Q_ACK(img_q_ack),
	.ESP_UART_RX_DATA(8'h00),
	.ESP_UART_RX_WR(1'b0),
	.FLASHBOOT_START(1'b0),
	.FLASHBOOT_COREID(5'd0)
);

assign FT_SPI_CS_N = ft_spi_on ? ft_cs_n : 1'b1;
assign FT_SPI_SCK = ft_spi_on ? mcu_sck_ibufg : 1'b1;
assign FT_SPI_MOSI = ft_spi_on ? ft_mosi : 1'b1;
assign SD_CS_N = sd2_cs_n;
assign SD_DI = sd2_mosi;
assign SD_CLK = mcu_sck_ibufg;

// ------------------------------------------------------------------ debug

// DEBUG_ADDR: { rom_ok, sdr_ready, machine_reset, ld_done, file_active, ld_overflow, kbd scan, kbd mouse,
//               baseclk[1:0], selpix[1:0], a frame captured, 0, 0, 0 }
// DEBUG_DATA, sampled every 2^24 clocks (0.42 s), two kinds by turns (bit 15):
//   0: { 0, kbd scan, kbd mouse, key events of archie_hid (5 bits, wrapping), the last byte from the IOC }
//   1: { 1, rom_ok, 0, mouse button changes (5 bits), the last byte to the IOC }
reg [23:0] dbg_cnt = 24'd0;
reg dbg_kind = 1'b0;
reg [4:0] dbg_keys = 5'd0, dbg_buts = 5'd0;
reg [7:0] dbg_rx = 8'd0, dbg_tx = 8'd0;
reg dbg_rx_d = 1'b0;
reg [2:0] dbg_btn_d = 3'd0;
always @(posedge clk_sys) begin
	dbg_cnt <= dbg_cnt + 24'd1;
	if (key_strobe) dbg_keys <= dbg_keys + 5'd1;
	dbg_btn_d <= mouse_buttons;
	if (mouse_buttons != dbg_btn_d) dbg_buts <= dbg_buts + 5'd1;
	dbg_rx_d <= kbd_out_strobe;
	if (kbd_out_strobe && !dbg_rx_d) dbg_rx <= kbd_out_data;
	if (kbd_in_strobe) dbg_tx <= kbd_in_data;
	if (dbg_cnt == 24'd0) begin
		dbg_kind <= ~dbg_kind;
		dbg_data <= dbg_kind ? { 1'b1, rom_ok, 1'b0, dbg_buts, dbg_tx } : { 1'b0, kbd_scan, kbd_mouse, dbg_keys, dbg_rx };
	end
end

// ------------------------------------------------------------------ soft switches

wire [2*8-1:0] sw;
kg_soft_switches #(.N(2)) soft_switches (
	.clk(clk_sys),
	.command(softsw_command),
	.regs(sw),
	.upd()
);
wire sw_reset = sw[1*8];

// ------------------------------------------------------------------ the RISC OS ROM (FL slot 7)

wire rom_loading = file_active && file_slot == 8'd7;
wire ld_cyc, ld_stb, ld_we, ld_ack, ld_busy, ld_done;
wire [3:0] ld_sel;
wire [23:2] ld_adr;
wire [31:0] ld_dat;

archie_loader loader (
	.clk(clk_sys),
	.reset(areset),
	.active(rom_loading),
	.wr(file_wr && file_slot == 8'd7),
	.addr(file_addr),
	.data(file_data),
	.wb_cyc(ld_cyc),
	.wb_stb(ld_stb),
	.wb_we(ld_we),
	.wb_sel(ld_sel),
	.wb_adr(ld_adr),
	.wb_dat(ld_dat),
	.wb_ack(ld_ack),
	.busy(ld_busy),
	.done(ld_done),
	.overflow(ld_overflow)
);

// the machine runs once a ROM went in (until then: black, the OSD works)
always @(posedge clk_sys)
	if (ld_done) rom_ok <= 1'b1;

// ------------------------------------------------------------------ reset

wire sdr_ready;
reg sdr_ready_s1 = 1'b0, sdr_ready_s = 1'b0;
always @(posedge clk_sys) begin
	sdr_ready_s1 <= sdr_ready;
	sdr_ready_s <= sdr_ready_s1;
end

// the machine in reset: the PLL, the SDRAM init, a ROM load (and until the first), the Reset item
reg [7:0] rst_cnt = 8'hFF;
wire rst_req = areset || !sdr_ready_s || rom_loading || ld_busy || !rom_ok || sw_reset;
always @(posedge clk_sys)
	if (rst_req)
		rst_cnt <= 8'hFF;
	else if (rst_cnt != 8'd0)
		rst_cnt <= rst_cnt - 8'd1;
wire machine_reset = rst_cnt != 8'd0;

reg mem_reset_m1 = 1'b1, mem_reset_m = 1'b1;
always @(posedge clk_mem) begin
	mem_reset_m1 <= areset;
	mem_reset_m <= mem_reset_m1;
end

// ------------------------------------------------------------------ the machine


wire ce_pix, ce_aud;
wire [1:0] selpix, baseclk;
wire [3:0] vid_r, vid_g, vid_b;
wire vid_hs_n, vid_vs_n, vid_en;
wire [15:0] audio_l, audio_r;
wire i2c_dout, i2c_din, i2c_clock;
wire [4:0] joy0, joy1;

wire m_we;
wire [3:0] m_sel;
wire [2:0] m_cti;
wire [31:0] m_dout;
wire [31:0] wb_din;
wire wb_ack;

archie_ce #(.CLK_HZ(40000000)) u_ce (
	.clk(clk_sys), .reset(machine_reset), .baseclk(baseclk), .selpix(selpix), .ce_pix(ce_pix), .ce_aud(ce_aud)
);

archimedes_top #(.CLKCPU(40000000)) archie (
	.CLKCPU_I(clk_sys),
	.CLKPIX_I(clk_sys),
	.CEPIX_I(ce_pix),
	.CEVID_I(ce_pix),
	.SELPIX_O(selpix),
	.HIRES_MONO_O(),
	.CLKAUD_I(clk_sys),
	.CEAUD_I(ce_aud),
	.RESET_I(machine_reset),
	.RESET_VIDEO_I(machine_reset),
	.RESET_VIDEO_CPU_I(machine_reset),
	.RESET_COMMAND_I(machine_reset),
	.MEM_CYC_O(m_cyc),
	.MEM_STB_O(m_stb),
	.MEM_WE_O(m_we),
	.MEM_ACK_I(wb_ack & ~machine_reset),
	.MEM_ERR_I(1'b0),
	.MEM_RTY_I(1'b0),
	.MEM_SEL_O(m_sel),
	.MEM_CTI_O(m_cti),
	.MEM_ADDR_O(m_adr),
	.MEM_DAT_I(wb_din),
	.MEM_DAT_O(m_dout),
	.HSYNC(vid_hs_n),
	.VSYNC(vid_vs_n),
	.VIDEO_R(vid_r),
	.VIDEO_G(vid_g),
	.VIDEO_B(vid_b),
	.VIDEO_EN(vid_en),
	.VIDBASECLK_O(baseclk),
	.VIDSYNCPOL_O(),
	.I2C_DOUT(i2c_dout),
	.I2C_DIN(i2c_din),
	.I2C_CLOCK(i2c_clock),
	.fdd_led(),
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
	.JOYSTICK0(joy0),
	.JOYSTICK1(joy1),
	.AUDIO_L(audio_l),
	.AUDIO_R(audio_r)
);

archie_cmos u_cmos (
	.clk(clk_sys), .reset(machine_reset), .scl(i2c_clock), .sda_in(i2c_dout), .sda_out(i2c_din), .changes()
);

archie_hid hid (
	.clk(clk_sys),
	.reset(areset),
	.kb_status(kb_status),
	.kb_dat0(kb_dat0),
	.kb_dat1(kb_dat1),
	.kb_dat2(kb_dat2),
	.kb_dat3(kb_dat3),
	.kb_dat4(kb_dat4),
	.kb_dat5(kb_dat5),
	.ms_x(ms_x),
	.ms_y(ms_y),
	.ms_b(ms_b),
	.ms_upd(ms_upd),
	.joy_l(joy_l),
	.joy_r(joy_r),
	.key_strobe(key_strobe),
	.key_code(key_code),
	.key_up(key_up),
	.mouse_strobe(mouse_strobe),
	.mouse_dx(mouse_dx),
	.mouse_dy(mouse_dy),
	.mouse_buttons(mouse_buttons),
	.joy0(joy0),
	.joy1(joy1)
);

archie_kbd #(.CLK_HZ(40000000)) u_kbd (
	.clk(clk_sys),
	.reset(machine_reset),
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

// ------------------------------------------------------------------ memory

// the wishbone bus: the ROM loader while the machine is in reset, else MEMC
wire wb_cyc = machine_reset ? ld_cyc : m_cyc;
wire wb_stb = machine_reset ? ld_stb : m_stb;
wire wb_we = machine_reset ? ld_we : m_we;
wire [3:0] wb_sel = machine_reset ? ld_sel : m_sel;
wire [23:2] wb_adr = machine_reset ? ld_adr : m_adr;
wire [31:0] wb_dout = machine_reset ? ld_dat : m_dout;
assign ld_ack = wb_ack & machine_reset;

// bank 0 (the RAM) in the SRAM, the ROM in the SDRAM
wire ram_sel = wb_adr[23:22] == 2'b00;
wire [31:0] sram_din, sdram_din;
wire sram_ack, sdram_ack;
assign wb_din = ram_sel ? sram_din : sdram_din;
assign wb_ack = ram_sel ? sram_ack : sdram_ack;

archie_sram sram (
	.clk(clk_sys),
	.wb_cyc(wb_cyc & ram_sel),
	.wb_stb(wb_stb & ram_sel),
	.wb_we(wb_we),
	.wb_sel(wb_sel),
	.wb_adr(wb_adr[21:2]),
	.wb_dat_i(wb_dout),
	.wb_dat_o(sram_din),
	.wb_ack(sram_ack),
	.MA(MA),
	.MD(MD),
	.MWR_N(MWR_N),
	.MRD_N(MRD_N)
);

wire fbw_req, fbr_req, fbw_buf, fbr_buf, fbw_busy, fbr_busy, fbr_we;
wire [11:0] fbw_row, fbr_row;
wire [10:0] fbw_len, fbr_len, fbw_addr, fbr_addr;
wire [15:0] fbw_data, fbr_data;

archie_sdram sdram (
	.clk(clk_mem),
	.wb_clk(clk_sys),
	.reset(mem_reset_m),
	.ready(sdr_ready),
	.wb_cyc(wb_cyc & ~ram_sel),
	.wb_stb(wb_stb & ~ram_sel),
	.wb_we(wb_we),
	.wb_sel(wb_sel),
	.wb_adr(wb_adr),
	.wb_dat_i(wb_dout),
	.wb_dat_o(sdram_din),
	.wb_ack(sdram_ack),
	.fbw_req(fbw_req),
	.fbw_row(fbw_row),
	.fbw_len(fbw_len),
	.fbw_buf(fbw_buf),
	.fbw_addr(fbw_addr),
	.fbw_data(fbw_data),
	.fbw_busy(fbw_busy),
	.fbr_req(fbr_req),
	.fbr_row(fbr_row),
	.fbr_len(fbr_len),
	.fbr_buf(fbr_buf),
	.fbr_we(fbr_we),
	.fbr_addr(fbr_addr),
	.fbr_data(fbr_data),
	.fbr_busy(fbr_busy),
	.sdr_a(SDR_A),
	.sdr_ba(SDR_BA),
	.sdr_dq(SDR_DQ),
	.sdr_dqm(SDR_DQM),
	.sdr_ras_n(SDR_RAS_N),
	.sdr_cas_n(SDR_CAS_N),
	.sdr_we_n(SDR_WE_N)
);
ODDR2 oddr_sdr_clk (.Q(SDR_CLK), .C0(clk_sdr), .C1(~clk_sdr), .CE(1'b1), .D0(1'b1), .D1(1'b0), .R(1'b0), .S(1'b0));

// ------------------------------------------------------------------ video

wire [23:0] fb_rgb;
wire fb_hs, fb_vs, fb_de;

archie_fb fb (
	.clk_sys(clk_sys),
	.clk_mem(clk_mem),
	.clk_pix(clk_sys),
	.ce(ce_pix),
	.r_i(vid_r),
	.g_i(vid_g),
	.b_i(vid_b),
	.de_i(vid_en),
	.vs_n_i(vid_vs_n),
	.fbw_req(fbw_req),
	.fbw_row(fbw_row),
	.fbw_len(fbw_len),
	.fbw_buf(fbw_buf),
	.fbw_addr(fbw_addr),
	.fbw_data(fbw_data),
	.fbw_busy(fbw_busy),
	.fbr_req(fbr_req),
	.fbr_row(fbr_row),
	.fbr_len(fbr_len),
	.fbr_buf(fbr_buf),
	.fbr_we(fbr_we),
	.fbr_addr(fbr_addr),
	.fbr_data(fbr_data),
	.fbr_busy(fbr_busy),
	.rgb(fb_rgb),
	.hs(fb_hs),
	.vs(fb_vs),
	.de(fb_de),
	.cap_w(),
	.cap_h(fb_cap_h),
	.dropped()
);

// the OSD of the mcu on the 800 x 600 output (the offsets of core-rk, same timing)
reg [15:0] osd_cmd = 16'd0;
always @(posedge clk_sys)
	osd_cmd <= osd_command;
wire [23:0] osd_rgb;
kg_osd_overlay #(.H_DIV4_WIDTH(1100), .V_OFFSET_IN(1), .H_OFFSET_IN(1)) osd (
	.clk(clk_sys),
	.rgb_i(fb_rgb),
	.rgb_o(osd_rgb),
	.hsync_i(fb_hs),
	.vsync_i(fb_vs),
	.v_offset(11'd59),
	.h_offset(11'd180),
	.osd_command(osd_cmd)
);

// ------------------------------------------------------------------ audio

// VIDC: 16-bit signed stereo
kg_pcm5102 #(.DIV_BITS(2)) dac (  // bck 5 MHz, 156 kHz
	.clk(clk_sys),
	.reset(areset),
	.left(audio_l),
	.right(audio_r),
	.din(DAC_DAT),
	.bck(DAC_BCK),
	.lrck(DAC_WS)
);

// 48 kHz for hdmi_tx: + 3 per clock of 40 MHz, modulo 2500
reg [11:0] aud_acc = 12'd0;
reg aud_stb = 1'b0;
reg [23:0] hdmi_l = 24'd0, hdmi_r = 24'd0;
always @(posedge clk_sys) begin
	aud_stb <= 1'b0;
	if (aud_acc >= 12'd2500 - 12'd3) begin
		aud_acc <= aud_acc + 12'd3 - 12'd2500;
		aud_stb <= 1'b1;
		hdmi_l <= { audio_l, 8'd0 };
		hdmi_r <= { audio_r, 8'd0 };
	end
	else
		aud_acc <= aud_acc + 12'd3;
end

// ------------------------------------------------------------------ HDMI

// 800 x 600 at 60 Hz: positive syncs
hdmi_tx #(.SAMPLE_FREQ(48000)) hdmi (
	.clk(clk_sys),
	.sclk(clk_hdmi),
	.sclk_n(clk_hdmi_n),
	.reset(~lockedx5),
	.rgb(osd_rgb),
	.vsync(fb_vs),
	.hsync(fb_hs),
	.de(fb_de),
	.audio_en(~dvi_only),
	.audio_l(hdmi_l),
	.audio_r(hdmi_r),
	.audio_clk(aud_stb),
	.tx_clk_n(TMDS_N[3]),
	.tx_clk_p(TMDS_P[3]),
	.tx_d_n(TMDS_N[2:0]),
	.tx_d_p(TMDS_P[2:0])
);

// the debug state (see debug above)
assign dbg_addr = { rom_ok, sdr_ready_s, machine_reset, ld_done, file_active, ld_overflow, kbd_scan, kbd_mouse,
	baseclk, selpix, fb_cap_h != 10'd0, 3'b000 };

endmodule
