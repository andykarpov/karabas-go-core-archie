module archimedes_top (
	CLKCPU_I,
	CLKPIX_I,
	CEPIX_I,
	CEVID_I,
	SELPIX_O,
	HIRES_MONO_O,
	CLKAUD_I,
	CEAUD_I,
	RESET_I,
	RESET_VIDEO_I,
	RESET_VIDEO_CPU_I,
	RESET_COMMAND_I,
	MEM_CYC_O,
	MEM_STB_O,
	MEM_WE_O,
	MEM_ACK_I,
	MEM_ERR_I,
	MEM_RTY_I,
	MEM_SEL_O,
	MEM_CTI_O,
	MEM_ADDR_O,
	MEM_DAT_I,
	MEM_DAT_O,
	HSYNC,
	VSYNC,
	VIDEO_R,
	VIDEO_G,
	VIDEO_B,
	VIDEO_EN,
	VIDBASECLK_O,
	VIDSYNCPOL_O,
	I2C_DOUT,
	I2C_DIN,
	I2C_CLOCK,
	fdd_led,
	img_mounted,
	img_wp,
	img_size,
	sd_lba,
	sd_rd,
	sd_wr,
	sd_ack,
	sd_buff_addr,
	sd_buff_dout,
	sd_buff_din,
	sd_buff_wr,
	ide_a,
	ide_cs,
	ide_rd,
	ide_wr,
	ide_wdata,
	ide_rdata,
	KBD_OUT_DATA,
	KBD_OUT_STROBE,
	KBD_IN_DATA,
	KBD_IN_STROBE,
	JOYSTICK0,
	JOYSTICK1,
	AUDIO_L,
	AUDIO_R
);
	parameter CLKCPU = 42000000;
	input CLKCPU_I;
	input CLKPIX_I;
	input CEPIX_I;
	input CEVID_I;
	output wire [1:0] SELPIX_O;
	output wire HIRES_MONO_O;
	input CLKAUD_I;
	input CEAUD_I;
	input RESET_I;
	input RESET_VIDEO_I;
	input RESET_VIDEO_CPU_I;
	input RESET_COMMAND_I;
	output wire MEM_CYC_O;
	output wire MEM_STB_O;
	output wire MEM_WE_O;
	input MEM_ACK_I;
	input MEM_ERR_I;
	input MEM_RTY_I;
	output wire [3:0] MEM_SEL_O;
	output wire [2:0] MEM_CTI_O;
	output wire [23:2] MEM_ADDR_O;
	input [31:0] MEM_DAT_I;
	output wire [31:0] MEM_DAT_O;
	output wire HSYNC;
	output wire VSYNC;
	output wire [3:0] VIDEO_R;
	output wire [3:0] VIDEO_G;
	output wire [3:0] VIDEO_B;
	output wire VIDEO_EN;
	output wire [1:0] VIDBASECLK_O;
	output wire [1:0] VIDSYNCPOL_O;
	output wire I2C_DOUT;
	input I2C_DIN;
	output wire I2C_CLOCK;
	output wire fdd_led;
	input [1:0] img_mounted;
	input img_wp;
	input [31:0] img_size;
	output wire [31:0] sd_lba;
	output wire [1:0] sd_rd;
	output wire [1:0] sd_wr;
	input sd_ack;
	input [7:0] sd_buff_addr;
	input [15:0] sd_buff_dout;
	output wire [15:0] sd_buff_din;
	input sd_buff_wr;
	output wire [2:0] ide_a;
	output wire ide_cs;
	output wire ide_rd;
	output wire ide_wr;
	output wire [15:0] ide_wdata;
	input [15:0] ide_rdata;
	output wire [7:0] KBD_OUT_DATA;
	output wire KBD_OUT_STROBE;
	input [7:0] KBD_IN_DATA;
	input KBD_IN_STROBE;
	input [4:0] JOYSTICK0;
	input [4:0] JOYSTICK1;
	output wire [15:0] AUDIO_L;
	output wire [15:0] AUDIO_R;
	wire [31:0] cpu_address;
	wire [3:0] cpu_sel;
	wire cpu_spvmd;
	wire [31:0] cpu_dat_o;
	wire [31:0] cpu_dat_i;
	wire cpu_cyc;
	wire cpu_stb;
	wire cpu_we;
	wire cpu_ack;
	wire cpu_err;
	wire cpu_irq;
	wire cpu_firq;
	wire [31:0] vid_address;
	wire vid_flybk;
	(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED" *) reg [1:0] vid_flybk_cpu_sync = 2'b11;
	wire vid_flybk_cpu = vid_flybk_cpu_sync[1];
	wire vid_req;
	wire vid_ack;
	wire cur_req;
	wire cur_ack;
	always @(posedge CLKCPU_I)
		if (RESET_I)
			vid_flybk_cpu_sync <= 2'b11;
		else
			vid_flybk_cpu_sync <= {vid_flybk_cpu_sync[0], vid_flybk};
	wire ioc_cs;
	wire ioc_ack;
	wire [7:0] ioc_dat_o;
	wire rom_low_cs;
	wire [5:0] ioc_cin;
	wire [5:0] ioc_cout;
	a23_core ARM(
		.i_clk(CLKCPU_I),
		.i_reset(RESET_I),
		.o_wb_cyc(cpu_cyc),
		.o_wb_stb(cpu_stb),
		.o_wb_we(cpu_we),
		.o_wb_adr(cpu_address),
		.o_wb_sel(cpu_sel),
		.i_wb_dat(cpu_dat_i),
		.o_wb_dat(cpu_dat_o),
		.i_wb_ack(cpu_ack),
		.i_wb_err(cpu_err),
		.o_wb_tga(cpu_spvmd),
		.i_irq(cpu_irq),
		.i_firq(cpu_firq),
		.i_system_rdy(~RESET_I)
	);
	wire sirq_n;
	wire ram_cs;
	wire vid_we;
	wire snd_ack;
	wire snd_req;
	wire [31:0] cpu_dout;
	memc MEMC(
		.clkcpu(CLKCPU_I),
		.rst_i(RESET_I),
		.spvmd(cpu_spvmd),
		.cpu_address(cpu_address[25:0]),
		.cpu_cyc(cpu_cyc),
		.cpu_stb(cpu_stb),
		.cpu_we(cpu_we),
		.cpu_sel(cpu_sel),
		.cpu_ack(cpu_ack),
		.cpu_err(cpu_err),
		.cpu_dout(cpu_dout),
		.mem_addr_o(MEM_ADDR_O),
		.mem_stb_o(MEM_STB_O),
		.mem_cyc_o(MEM_CYC_O),
		.mem_ack_i(MEM_ACK_I),
		.mem_sel_o(MEM_SEL_O),
		.mem_we_o(MEM_WE_O),
		.mem_cti_o(MEM_CTI_O),
		.mem_dat_i(MEM_DAT_I),
		.flybk(vid_flybk_cpu),
		.vidrq(vid_req),
		.vidak(vid_ack),
		.currq(cur_req),
		.curak(cur_ack),
		.sndak(snd_ack),
		.sndrq(snd_req),
		.vidw(vid_we),
		.ioc_cs(ioc_cs),
		.rom_low_cs(rom_low_cs),
		.ram_cs(ram_cs),
		.sirq_n(sirq_n)
	);
	vidc #(.CLKCPU(CLKCPU)) VIDC(
		.clkpix(CLKPIX_I),
		.cepix(CEPIX_I),
		.cevid(CEVID_I),
		.selpix(SELPIX_O),
		.hires_mono(HIRES_MONO_O),
		.baseclk(VIDBASECLK_O),
		.clkaud(CLKAUD_I),
		.ceaud(CEAUD_I),
		.clkcpu(CLKCPU_I),
		.rst_i(RESET_I),
		.rst_vid_i(RESET_VIDEO_I),
		.rst_vid_cpu_i(RESET_VIDEO_CPU_I),
		.rst_cmd_i(RESET_COMMAND_I),
		.cpu_dat(cpu_dat_o),
		.flybk(vid_flybk),
		.flybk_sys(vid_flybk_cpu),
		.vidak(vid_ack),
		.vidrq(vid_req),
		.curak(cur_ack),
		.currq(cur_req),
		.sndak(snd_ack),
		.sndrq(snd_req),
		.viddat(MEM_DAT_I),
		.vidw(vid_we),
		.hsync(HSYNC),
		.vsync(VSYNC),
		.video_r(VIDEO_R),
		.video_g(VIDEO_G),
		.video_b(VIDEO_B),
		.video_en(VIDEO_EN),
		.audio_l(AUDIO_L),
		.audio_r(AUDIO_R)
	);
	wire [1:0] ioc_speed = cpu_address[20:19];
	wire [7:1] ioc_select;
	wire ioc_sext;
	wire [15:0] pod_dat_o;
	wire [15:0] pod_dat_i;
	wire floppy_firq;
	wire floppy_drq;
	wire ioc_clk7m_en;
	localparam IOC_CLK2_DIV = CLKCPU / 2000000;
	localparam IOC_CLK7_DIV = (CLKCPU == 40000000 ? 5 : 6);
	localparam [15:0] FDC_CLK_KHZ = (CLKCPU / IOC_CLK7_DIV) / 1000;
	ioc #(
		.CLK2_DIV(IOC_CLK2_DIV),
		.CLK7_DIV(IOC_CLK7_DIV)
	) IOC(
		.clkcpu(CLKCPU_I),
		.clk7m_en(ioc_clk7m_en),
		.por(RESET_I),
		.ir(vid_flybk_cpu),
		.fh({floppy_firq, floppy_drq}),
		.il({6'b001111, sirq_n, 1'b1}),
		.c_in(ioc_cin),
		.c_out(ioc_cout),
		.select(ioc_select),
		.sext(ioc_sext),
		.wb_adr(cpu_address[6:2]),
		.wb_stb((cpu_stb & cpu_address[21]) & ioc_cs),
		.wb_cyc((cpu_cyc & cpu_address[21]) & ioc_cs),
		.wb_we(cpu_we),
		.wb_dat_i(cpu_dat_o[23:16]),
		.wb_dat_o(ioc_dat_o),
		.wb_bank(cpu_address[18:16]),
		.irq(cpu_irq),
		.firq(cpu_firq),
		.kbd_out_data(KBD_OUT_DATA),
		.kbd_out_strobe(KBD_OUT_STROBE),
		.kbd_in_data(KBD_IN_DATA),
		.kbd_in_strobe(KBD_IN_STROBE)
	);
	localparam PODULE0 = 2'b00;
	localparam PODULE1 = 2'b01;
	localparam PODULE2 = 2'b10;
	localparam PODULE3 = 2'b11;
	wire podules_en = ioc_cs & ioc_select[4];
	wire [1:0] podule_num = cpu_address[15:14];
	wire [15:0] podule_wdata = cpu_dat_o[31:16];
	wire [13:2] podule_adr = cpu_address[13:2];
	wire [15:0] podule0_rdata;
	wire [15:0] podule1_rdata;
	wire [15:0] podule2_rdata;
	wire [15:0] podule3_rdata;
	reg [15:0] podule_rdata;
	always @(*) begin
		podule_rdata = 16'hffff;
		if (podule_num == PODULE0)
			podule_rdata = podule0_rdata;
	end
	wire podule0_sel = ((podules_en && cpu_stb) && cpu_cyc) && (podule_num == PODULE0);
	wire [7:0] floppy_dat_o;
	wire floppy_en = ioc_cs & ioc_select[1];
	wire [3:0] floppy_drive;
	wire floppy_side;
	wire floppy_motor;
	wire floppy_inuse;
	wire floppy_density;
	wire floppy_reset;
	wire fdc_sel = (cpu_stb & cpu_cyc) & floppy_en;
	fdc1772 #(
		.EXT_MOTOR(1'b1),
		.CLK_EN(FDC_CLK_KHZ)
	) FDC1772(
		.clkcpu(CLKCPU_I),
		.clk8m_en(ioc_clk7m_en),
		.cpu_sel(fdc_sel),
		.cpu_rw(!cpu_we),
		.cpu_addr(cpu_address[3:2]),
		.cpu_dout(floppy_dat_o),
		.cpu_din(cpu_dat_o[23:16]),
		.irq(floppy_firq),
		.drq(floppy_drq),
		.img_mounted(img_mounted),
		.img_size(img_size),
		.img_wp(img_wp),
		.sd_lba(sd_lba),
		.sd_rd(sd_rd),
		.sd_wr(sd_wr),
		.sd_ack(sd_ack),
		.sd_buff_addr(sd_buff_addr),
		.sd_dout(sd_buff_dout),
		.sd_din(sd_buff_din),
		.sd_dout_strobe(sd_buff_wr),
		.floppy_drive(floppy_drive),
		.floppy_motor(!floppy_motor),
		.floppy_side(floppy_side),
		.floppy_reset(floppy_reset)
	);
	podule_ide IDE(
		.clk(CLKCPU_I),
		.reset(RESET_I),
		.cpu_sel(podule0_sel),
		.cpu_we(cpu_we),
		.cpu_adr(podule_adr),
		.cpu_dat_o(podule0_rdata),
		.cpu_dat_i(podule_wdata),
		.ide_a(ide_a),
		.ide_cs(ide_cs),
		.ide_rd(ide_rd),
		.ide_wr(ide_wr),
		.ide_wdata(ide_wdata),
		.ide_rdata(ide_rdata)
	);
	wire [7:0] latches_dat_o;
	wire latches_en = (ioc_cs & ioc_select[5]) & (ioc_speed == 2'd2);
	latches LATCHES(
		.clkcpu(CLKCPU_I),
		.wb_cyc(cpu_cyc & latches_en),
		.wb_stb(cpu_stb & latches_en),
		.wb_we(cpu_we & latches_en),
		.wb_dat_i(cpu_dat_o[23:16]),
		.wb_dat_o(latches_dat_o),
		.wb_adr(cpu_address[15:2]),
		.floppy_drive(floppy_drive),
		.floppy_motor(floppy_motor),
		.floppy_inuse(floppy_inuse),
		.floppy_side(floppy_side),
		.floppy_density(floppy_density),
		.floppy_reset(floppy_reset),
		.joy0(JOYSTICK0),
		.joy1(JOYSTICK1),
		.baseclk(VIDBASECLK_O),
		.syncpol(VIDSYNCPOL_O)
	);
	assign MEM_DAT_O = cpu_dat_o;
	assign cpu_dat_i = (floppy_en ? {24'd0, floppy_dat_o} : (latches_en ? {24'd0, latches_dat_o} : (podules_en ? {16'd0, podule_rdata} : (ioc_cs & ~ioc_sext ? {24'd0, ioc_dat_o} : (ram_cs ? cpu_dout : 32'hffffffff)))));
	assign I2C_CLOCK = ioc_cout[1];
	assign I2C_DOUT = ioc_cout[0];
	assign ioc_cin[5:0] = {ioc_cout[5:2], I2C_CLOCK, I2C_DIN};
	assign fdd_led = ~floppy_inuse;
endmodule
