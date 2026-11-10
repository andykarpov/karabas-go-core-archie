module memc (
	clkcpu,
	rst_i,
	cpu_we,
	cpu_stb,
	cpu_cyc,
	cpu_err,
	cpu_ack,
	cpu_dout,
	cpu_address,
	cpu_sel,
	mem_addr_o,
	mem_stb_o,
	mem_cyc_o,
	mem_we_o,
	mem_sel_o,
	mem_dat_i,
	mem_ack_i,
	mem_cti_o,
	spvmd,
	flybk,
	sndrq,
	sndak,
	vidrq,
	vidak,
	currq,
	curak,
	vidw,
	ioc_cs,
	rom_low_cs,
	ram_cs,
	sirq_n
);
	input clkcpu;
	input rst_i;
	input cpu_we;
	input cpu_stb;
	input cpu_cyc;
	output wire cpu_err;
	output wire cpu_ack;
	output wire [31:0] cpu_dout;
	input [25:0] cpu_address;
	input [3:0] cpu_sel;
	output wire [23:2] mem_addr_o;
	output wire mem_stb_o;
	output wire mem_cyc_o;
	output wire mem_we_o;
	output wire [3:0] mem_sel_o;
	input [31:0] mem_dat_i;
	input mem_ack_i;
	output wire [2:0] mem_cti_o;
	input spvmd;
	input flybk;
	input sndrq;
	output wire sndak;
	input vidrq;
	output wire vidak;
	input currq;
	output wire curak;
	output wire vidw;
	output wire ioc_cs;
	output wire rom_low_cs;
	output wire ram_cs;
	output wire sirq_n;
	parameter INITIAL_CURSOR_BASE = 19'h00000;
	parameter INITIAL_SCREEN_BASE = 19'h00000;
	parameter INITIAL_SCREEN_SIZE = 19'h4b000;
	reg rom_overlay;
	reg [18:0] cur_address;
	reg [18:0] cur_init;
	reg [18:0] vid_address;
	reg [18:0] vid_init;
	reg [18:0] vid_start;
	reg [18:0] vid_end;
	reg [18:0] snd_sptr;
	reg [18:0] snd_endc;
	reg snd_next_valid;
	reg [18:0] snd_start;
	reg [18:0] snd_endn;
	reg [13:0] memc_control = 14'd0;
	reg cur_load;
	reg vid_load;
	reg snd_load;
	reg cpu_load;
	reg [3:0] dma_ack_r;
	wire dma_in_progress = (cur_load | vid_load) | snd_load;
	wire dma_request = (~flybk & (vidrq | currq)) | (memc_control[11] & sndrq);
	reg dma_request_r;
	wire video_dma_ip = cur_load | vid_load;
	wire sound_dma_ip = snd_load;
	wire phycs;
	wire tablew;
	wire romcs;
	wire memcw;
	reg flybk_d;
	reg video_frame_reset_pending;
	localparam REG_Vinit = 3'b000;
	localparam REG_Vstart = 3'b001;
	localparam REG_Vend = 3'b010;
	localparam REG_Cinit = 3'b011;
	localparam REG_Sstart = 3'b100;
	localparam REG_SendN = 3'b101;
	localparam REG_Sptr = 3'b110;
	localparam REG_Ctrl = 3'b111;
	wire [25:0] phys_address;
	wire table_valid;
	memc_translator PAGETABLES(
		.clkcpu(clkcpu),
		.wr(tablew),
		.spvmd(spvmd),
		.page_size(memc_control[3:2]),
		.osmd(memc_control[12]),
		.mem_write(cpu_we),
		.addr_i(cpu_address),
		.addr_o(phys_address),
		.valid(table_valid)
	);
	reg [31:0] cache_data [0:3];
	reg cache_valid;
	reg [23:4] cache_addr;
	reg cache_ack;
	wire logcs = cpu_address[25] == 1'b0;
	wire [21:2] ram_page = (memc_control[3:2] == 2'b00 ? {3'd0, cpu_address[18:2]} : (memc_control[3:2] == 2'b01 ? {2'd0, cpu_address[19:2]} : (memc_control[3:2] == 2'b10 ? {1'd0, cpu_address[20:2]} : cpu_address[21:2])));
	wire [23:2] caddr = (phycs ? {2'd0, ram_page} : (romcs ? {3'b010, cpu_address[20:2]} : (table_valid & logcs ? phys_address[23:2] : 22'd0)));
	wire cpu_mem_we = (cpu_we & ((phycs & spvmd) | (table_valid & logcs))) & ~romcs;
	wire memw = ((cpu_cyc & cpu_we) & spvmd) & (cpu_address[25:21] == 5'b11011);
	always @(posedge clkcpu) begin : block
		reg cache_rcv;
		reg cache_test;
		reg [1:0] cache_cnt;
		reg [1:0] cache_wraddr;
		cache_ack <= 0;
		if (rst_i) begin
			vid_init <= INITIAL_SCREEN_BASE;
			cur_init <= INITIAL_CURSOR_BASE;
			vid_start <= INITIAL_SCREEN_BASE;
			vid_end <= INITIAL_SCREEN_BASE + INITIAL_SCREEN_SIZE;
			vid_address <= INITIAL_SCREEN_BASE;
			cur_address <= INITIAL_CURSOR_BASE;
			vid_load <= 1'b0;
			snd_load <= 1'b0;
			cur_load <= 1'b0;
			cpu_load <= 1'b0;
			rom_overlay <= 1'b1;
			memc_control[11] <= 1'b0;
			dma_request_r <= 1'b0;
			flybk_d <= 1'b1;
			video_frame_reset_pending <= 1'b0;
			cache_rcv <= 0;
			cache_valid <= 0;
			cache_test <= 0;
			snd_next_valid <= 1'b0;
			dma_ack_r <= 4'd0;
		end
		else begin
			flybk_d <= flybk;
			if (flybk_d & ~flybk)
				video_frame_reset_pending <= 1'b1;
			if (video_frame_reset_pending & ~video_dma_ip) begin
				vid_address <= vid_init;
				cur_address <= cur_init;
				video_frame_reset_pending <= 1'b0;
			end
			if (cache_rcv & mem_ack_i) begin
				cache_data[cache_wraddr] <= mem_dat_i;
				cache_wraddr <= cache_wraddr + 1'd1;
				cache_cnt <= cache_cnt + 1'd1;
				if (cache_cnt == 2)
					cache_ack <= 1;
				if (&cache_cnt) begin
					cache_rcv <= 0;
					cache_valid <= 1;
				end
			end
			dma_request_r <= dma_request;
			if (cpu_cyc & cpu_stb) begin
				cache_test <= 1;
				if ((cache_valid & (cache_addr == caddr[23:4])) & ~cpu_mem_we) begin
					if (~cache_test)
						cache_ack <= 1;
				end
				else begin
					if (cpu_address[25:24] == 2'b11)
						rom_overlay <= 1'b0;
					if (~dma_request_r & ~dma_in_progress) begin
						cpu_load <= 1'b1;
						if (~cpu_load) begin
							if (cpu_mem_we) begin
								if (cache_addr == caddr[23:4])
									cache_valid <= 0;
							end
							else begin
								{cache_addr, cache_wraddr} <= caddr[23:2];
								cache_valid <= 0;
								cache_rcv <= 1;
								cache_cnt <= 0;
							end
						end
					end
					if (memw)
						case (cpu_address[19:17])
							REG_Vinit: vid_init <= {cpu_address[16:2], 4'b0000};
							REG_Vstart: vid_start <= {cpu_address[16:2], 4'b0000};
							REG_Vend: vid_end <= {cpu_address[16:2], 4'b0000};
							REG_Cinit: cur_init <= {cpu_address[16:2], 4'b0000};
							REG_Sstart: begin
								$display("Sstart: %x", {cpu_address[16:2], 4'b0000});
								snd_next_valid <= 1'b1;
								snd_start <= {cpu_address[16:2], 4'b0000};
							end
							REG_SendN: begin
								$display("SendN: %x", {cpu_address[16:2], 4'b0000});
								snd_endn <= {cpu_address[16:2], 4'b0000};
							end
							REG_Sptr: begin
								$display("Sound buffer swap");
								snd_sptr <= snd_start;
								if (snd_next_valid == 1'b1) begin
									snd_endc <= snd_endn;
									snd_next_valid <= 1'b0;
								end
							end
							REG_Ctrl: begin
								$display("MEMC Control Register: %x", cpu_address[13:0]);
								memc_control <= cpu_address[13:0];
							end
						endcase
				end
			end
			else begin
				cpu_load <= 0;
				cache_rcv <= 0;
				cache_test <= 0;
			end
			if (dma_in_progress & mem_ack_i) begin
				dma_ack_r <= dma_ack_r + 3'd1;
				if (dma_ack_r == 4'd3) begin
					vid_load <= 1'b0;
					snd_load <= 1'b0;
					cur_load <= 1'b0;
					dma_ack_r <= 4'd0;
				end
			end
			if (dma_request_r === 1'b1) begin
				if (((vidrq & ~flybk) & ~dma_in_progress) & ~cpu_load)
					vid_load <= 1'b1;
				else if (((currq & ~flybk) & ~dma_in_progress) & ~cpu_load)
					cur_load <= 1'b1;
				else if ((sndrq & ~dma_in_progress) & ~cpu_load)
					snd_load <= 1'b1;
			end
			if (video_dma_ip) begin
				if ((vidak & vid_load) == 1'b1)
					vid_address <= vid_address + 19'd4;
				else if ((curak & cur_load) == 1'b1)
					cur_address <= cur_address + 19'd4;
			end
			else if (vid_address > vid_end)
				vid_address <= vid_start;
			if (sound_dma_ip) begin
				if ((sndak & snd_load) == 1'b1)
					snd_sptr <= snd_sptr + 19'd4;
			end
			else if (snd_sptr > snd_endc) begin
				snd_sptr <= snd_start;
				if (snd_next_valid == 1'b1) begin
					snd_endc <= snd_endn;
					snd_next_valid <= 1'b0;
				end
			end
		end
	end
	assign mem_addr_o = (vid_load ? {5'd0, vid_address[18:2]} : (cur_load ? {5'd0, cur_address[18:2]} : (snd_load ? {5'd0, snd_sptr[18:2]} : caddr)));
	wire vidc_cs = spvmd & (cpu_address[25:21] == 5'b11010);
	wire address_valid = ((((((((logcs & table_valid) | rom_low_cs) | ioc_cs) | memw) | tablew) | vidc_cs) | (phycs & ~cpu_we)) | ((phycs & spvmd) & cpu_we)) | romcs;
	wire err = ~address_valid;
	assign mem_cyc_o = (cpu_load ? cpu_cyc & ~err : dma_in_progress);
	assign mem_stb_o = (cpu_load ? cpu_stb : dma_in_progress);
	assign mem_sel_o = (cpu_load ? cpu_sel : 4'b1111);
	assign mem_we_o = (cpu_load ? cpu_mem_we : 1'b0);
	assign mem_cti_o = 3'b010;
	assign cpu_ack = (mem_we_o ? mem_ack_i : cache_ack) & ~err;
	assign cpu_err = (cpu_load ? mem_ack_i & err : 1'b0);
	assign cpu_dout = cache_data[caddr[3:2]];
	assign tablew = ((((cpu_cyc & cpu_we) & spvmd) & (cpu_address[25:23] == 3'b111)) & (cpu_address[12] == 0)) & (cpu_address[7] == 0);
	assign vidw = (cpu_cyc & cpu_we) & vidc_cs;
	assign phycs = cpu_address[25:24] == 2'b10;
	assign ioc_cs = spvmd & (cpu_address[25:22] == 4'b1100);
	assign rom_low_cs = cpu_address[25:22] == 4'b1101;
	assign romcs = (cpu_address[25:23] == 3'b111) | ((cpu_address[25:19] == 7'h00) & rom_overlay);
	assign vidak = (cpu_load ? 1'b0 : vid_load & mem_ack_i);
	assign curak = (cpu_load ? 1'b0 : cur_load & mem_ack_i);
	assign sndak = (cpu_load ? 1'b0 : sound_dma_ip & mem_ack_i);
	assign sirq_n = snd_next_valid;
	assign ram_cs = (table_valid | phycs) | romcs;
endmodule
