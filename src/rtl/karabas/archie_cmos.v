`timescale 1ns / 1ps
/*
 archie_cmos.v

 The clock / CMOS chip of the Archimedes (PCF8583 on the I2C bus of the IOC) on the RTC registers of
 kg_mcu (kg_mcu_rtc: 256 bytes the mcu keeps; rtc_mode 0 = MC146818A, BCD). The I2C side is
 EEPROM_24C0x of Archie_MiSTer (as a 24C02), its enable clk / 4 as in Archie.sv.

 Address map of the PCF8583 -> the registers of kg_mcu:
 - 0x10..0xFF, the CMOS RAM: the same address. The mcu keeps registers 0x0E..0xFF of MC146818A in the
   EEPROM bank of the core (eeprom_bank of core.json: /config/archie.eep), so the CMOS survives;
   its first contents is the eeprom_init of the core file (cmos.bin: the RISC OS 3.11 defaults of
   the cmos.mif of Archie_MiSTer). The year of RISC OS (CMOS 0xC0 = year % 100, 0xC1 = century, the
   YearCMOS of the kernel) is read from the clock: 0xC0 from register 9, 0xC1 20.
 - 0x02..0x06, the time: from MC146818A 0 (seconds), 2 (minutes), 4 (hours, 24 h), 7 (date),
   8 (month), 6 (day of the week 1..7 -> 0..6), 9 (year: the two bits of the PCF8583 are year % 4).
   A write goes to those registers (kg_mcu sends it to the mcu, which sets the clock chip), and a
   write of CMOS 0xC0 to register 9 as well.
 - 0x00, 0x01, 0x07..0x0F (control, hundredths, alarm, timer): a local copy, the hundredths 0.

 The registers of kg_mcu are read a clock after the address (rtc_a -> rtc_do): an address goes out
 each clock and its data come two clocks later. A request of the I2C side is served first; between
 them the time registers are read in turn into a copy here. A write is one clock of rtc_cs with
 rtc_wr_n low. ram_done holds from the answer until the I2C side drops its request (at its ce).
*/

module archie_cmos (
	input wire clk,
	input wire reset,
	input wire scl,       // I2C_CLOCK of archimedes_top
	input wire sda_in,    // I2C_DOUT
	output wire sda_out,  // I2C_DIN

	output reg [7:0] rtc_a = 8'd0,
	output reg [7:0] rtc_di = 8'd0,
	input wire [7:0] rtc_do,
	output reg rtc_cs = 1'b0,
	output reg rtc_wr_n = 1'b1,

	output reg [7:0] changes = 8'd0  // writes to bytes 16..255 (the cmos_cnt of Archie.sv)
);

reg [1:0] cnt = 2'd0;
reg ce = 1'b0;
always @(posedge clk) begin
	cnt <= cnt + 2'd1;
	ce <= cnt == 2'd0;
end

wire [7:0] ram_addr, data_to_ram;
wire ram_read, ram_write;
reg [7:0] data_from_ram = 8'd0;
reg ram_done = 1'b0;

// the copy of the time registers of MC146818A (BCD)
reg [7:0] t_sec = 8'd0, t_min = 8'd0, t_hour = 8'd0, t_wday = 8'd1, t_day = 8'd1, t_mon = 8'd1, t_year = 8'd0;
// the local registers 0x00..0x0F
reg [7:0] loc [0:15];
integer k;
initial for (k = 0; k < 16; k = k + 1) loc[k] = 8'd0;

wire [7:0] year_bin = { 4'd0, t_year[7:4] } * 8'd10 + { 4'd0, t_year[3:0] };
wire [2:0] wday0 = t_wday[2:0] - 3'd1;
wire [7:0] wr_year_bcd = { data_to_ram / 8'd10, 4'd0 } | (data_to_ram % 8'd10);

// the value of a PCF8583 register / CMOS byte that is not read from kg_mcu
reg [7:0] pcf_local;
always @(*) begin
	case (ram_addr)
	8'h01: pcf_local = 8'h00;
	8'h02: pcf_local = t_sec & 8'h7F;
	8'h03: pcf_local = t_min & 8'h7F;
	8'h04: pcf_local = t_hour & 8'h3F;
	8'h05: pcf_local = { year_bin[1:0], t_day[5:0] };
	8'h06: pcf_local = { wday0, t_mon[4:0] };
	8'hC0: pcf_local = year_bin;
	8'hC1: pcf_local = 8'd20;
	default: pcf_local = loc[ram_addr[3:0]];
	endcase
end
wire from_rtc = ram_addr >= 8'h10 && ram_addr != 8'hC0 && ram_addr != 8'hC1;

// the writes for kg_mcu of one I2C write: up to two, one per clock
reg [7:0] w_a0 = 8'd0, w_d0 = 8'd0, w_a1 = 8'd0, w_d1 = 8'd0;
reg [1:0] w_n = 2'd0;

// the read pipe: the address of two clocks ago and whether it is the request
reg [2:0] scan = 3'd0;
reg [7:0] p1_a = 8'hFF, p2_a = 8'hFF;
reg p1_req = 1'b0, p2_req = 1'b0;
reg busy_rd = 1'b0;                  // a read of the request is in the pipe

reg [7:0] scan_reg;
always @(*) begin
	case (scan)
	3'd0: scan_reg = 8'h00;
	3'd1: scan_reg = 8'h02;
	3'd2: scan_reg = 8'h04;
	3'd3: scan_reg = 8'h06;
	3'd4: scan_reg = 8'h07;
	3'd5: scan_reg = 8'h08;
	default: scan_reg = 8'h09;
	endcase
end

always @(posedge clk) begin
	rtc_cs <= 1'b0;
	rtc_wr_n <= 1'b1;
	p1_req <= 1'b0;
	p2_a <= p1_a;
	p2_req <= p1_req;

	if (!ram_read && !ram_write) ram_done <= 1'b0;

	// the data of the address of two clocks ago
	if (p2_req) begin
		data_from_ram <= rtc_do;
		ram_done <= 1'b1;
		busy_rd <= 1'b0;
	end
	case (p2_a)
	8'h00: t_sec <= rtc_do;
	8'h02: t_min <= rtc_do;
	8'h04: t_hour <= rtc_do;
	8'h06: t_wday <= rtc_do;
	8'h07: t_day <= rtc_do;
	8'h08: t_mon <= rtc_do;
	8'h09: t_year <= rtc_do;
	default: ;
	endcase

	// the address of this clock: a write, the read of the request, or the next time register
	if (w_n != 2'd0) begin
		rtc_a <= w_a0;
		rtc_di <= w_d0;
		rtc_cs <= 1'b1;
		rtc_wr_n <= 1'b0;
		w_a0 <= w_a1;
		w_d0 <= w_d1;
		w_n <= w_n - 2'd1;
		p1_a <= 8'hFF;
	end else if (ram_read && !ram_done && !busy_rd && from_rtc) begin
		rtc_a <= ram_addr;
		p1_a <= ram_addr;
		p1_req <= 1'b1;
		busy_rd <= 1'b1;
	end else begin
		rtc_a <= scan_reg;
		p1_a <= scan_reg;
		scan <= scan == 3'd6 ? 3'd0 : scan + 3'd1;
	end

	// a read answered here at once
	if (ram_read && !ram_done && !busy_rd && !from_rtc) begin
		data_from_ram <= pcf_local;
		ram_done <= 1'b1;
	end
	// a write: its kg_mcu writes queued, done at once
	if (ram_write && !ram_done && w_n == 2'd0) begin
		ram_done <= 1'b1;
		w_n <= 2'd1;
		w_a1 <= 8'h09;
		w_d1 <= wr_year_bcd;
		if (ram_addr >= 8'h10) begin
			changes <= changes + 8'd1;
			w_a0 <= ram_addr;
			w_d0 <= data_to_ram;
			if (ram_addr == 8'hC0) w_n <= 2'd2;
		end else begin
			loc[ram_addr[3:0]] <= data_to_ram;
			case (ram_addr)
			8'h02: begin w_a0 <= 8'h00; w_d0 <= data_to_ram & 8'h7F; end
			8'h03: begin w_a0 <= 8'h02; w_d0 <= data_to_ram & 8'h7F; end
			8'h04: begin w_a0 <= 8'h04; w_d0 <= data_to_ram & 8'h3F; end
			8'h05: begin w_a0 <= 8'h07; w_d0 <= { 2'b00, data_to_ram[5:0] }; end
			8'h06: begin
				w_a0 <= 8'h08; w_d0 <= { 3'b000, data_to_ram[4:0] };
				w_a1 <= 8'h06; w_d1 <= { 5'd0, data_to_ram[7:5] + 3'd1 };
				w_n <= 2'd2;
			end
			default: w_n <= 2'd0;
			endcase
		end
	end
end

EEPROM_24C0x eeprom (
	.type_24C01(1'b0),
	.clk(clk),
	.ce(ce),
	.reset(reset),
	.SCL(scl),
	.SDA_in(sda_in),
	.SDA_out(sda_out),
	.E_id(3'd0),
	.WC_n(1'b0),
	.data_from_ram(data_from_ram),
	.data_to_ram(data_to_ram),
	.ram_addr(ram_addr),
	.ram_read(ram_read),
	.ram_write(ram_write),
	.ram_done(ram_done)
);

endmodule
