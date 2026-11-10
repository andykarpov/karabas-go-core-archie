module floppy (
	clk,
	clk8m_en,
	select,
	motor_on,
	step_in,
	step_out,
	sector_len,
	sector_base,
	spt,
	sector_gap_len,
	hd,
	fm,
	dclk_en,
	track,
	sector,
	sector_hdr,
	sector_data,
	ready,
	index
);
	input clk;
	input clk8m_en;
	input select;
	input motor_on;
	input step_in;
	input step_out;
	input [10:0] sector_len;
	input sector_base;
	input [4:0] spt;
	input [9:0] sector_gap_len;
	input hd;
	input fm;
	output wire dclk_en;
	output wire [6:0] track;
	output wire [4:0] sector;
	output wire sector_hdr;
	output wire sector_data;
	output wire ready;
	output reg index;
	parameter CLK_EN = 8000;
	localparam SECTOR_STATE_HDR = 2'd1;
	reg [1:0] sec_state;
	assign sector_hdr = sec_state == SECTOR_STATE_HDR;
	localparam SECTOR_STATE_DATA = 2'd2;
	assign sector_data = sec_state == SECTOR_STATE_DATA;
	localparam RATESD = 125000;
	localparam RATEDD = 250000;
	localparam RATEHD = 500000;
	localparam RPM = 300;
	localparam STEPBUSY = 18;
	localparam SPINUP = 500;
	localparam SPINDOWN = 300;
	localparam INDEX_PULSE_LEN = 5;
	localparam SECTOR_HDR_LEN = 6;
	localparam TRACKS = 85;
	localparam BPTSD = 3125;
	localparam BPTDD = 6250;
	localparam BPTHD = 12500;
	reg [31:0] rate = 0;
	assign ready = select && (rate == (fm ? RATESD : (hd ? RATEHD : RATEDD)));
	localparam INDEX_PULSE_CYCLES = INDEX_PULSE_LEN * CLK_EN;
	reg [18:0] index_pulse_cnt;
	reg index_pulse_start;
	always @(posedge clk)
		if (clk8m_en) begin
			if (index_pulse_start && (index_pulse_cnt == (INDEX_PULSE_CYCLES - 1))) begin
				index <= 1'b0;
				index_pulse_cnt <= 19'd0;
			end
			else if (index_pulse_cnt == (INDEX_PULSE_CYCLES - 1))
				index <= 1'b1;
			else
				index_pulse_cnt <= index_pulse_cnt + 1'd1;
		end
	localparam STEP_BUSY_CLKS = CLK_EN * STEPBUSY;
	reg [6:0] current_track = 7'd0;
	assign track = current_track;
	reg step_inD;
	reg step_outD;
	reg [19:0] step_busy;
	always @(posedge clk) begin
		step_inD <= step_in;
		step_outD <= step_out;
		if (clk8m_en && (step_busy != 0))
			step_busy <= step_busy - 18'd1;
		if (select) begin
			if (step_in && !step_inD) begin
				if (current_track != 0)
					current_track <= current_track - 7'd1;
				step_busy <= STEP_BUSY_CLKS[19:0];
			end
			if (step_out && !step_outD) begin
				if (current_track != 84)
					current_track <= current_track + 7'd1;
				step_busy <= STEP_BUSY_CLKS[19:0];
			end
		end
	end
	reg [4:0] current_sector = 4'd1;
	assign sector = current_sector;
	localparam SECTOR_STATE_GAP = 2'd0;
	reg [4:0] start_sector = 4'd1;
	reg [9:0] sec_byte_cnt;
	reg byte_clk_en;
	always @(posedge clk)
		if (byte_clk_en) begin
			if (index_pulse_start) begin
				sec_byte_cnt <= sector_gap_len - 1'd1;
				sec_state <= SECTOR_STATE_GAP;
				current_sector <= start_sector;
			end
			else if (sec_byte_cnt == 0)
				case (sec_state)
					SECTOR_STATE_GAP: begin
						sec_state <= SECTOR_STATE_HDR;
						sec_byte_cnt <= SECTOR_HDR_LEN[9:0] - 1'd1;
					end
					SECTOR_STATE_HDR: begin
						sec_state <= SECTOR_STATE_DATA;
						sec_byte_cnt <= sector_len[9:0] - 1'd1;
					end
					SECTOR_STATE_DATA: begin
						sec_state <= SECTOR_STATE_GAP;
						sec_byte_cnt <= sector_gap_len - 1'd1;
						if (current_sector == ((sector_base + spt) - 1))
							current_sector <= sector_base;
						else
							current_sector <= sector + 1'd1;
					end
					default: sec_state <= SECTOR_STATE_GAP;
				endcase
			else
				sec_byte_cnt <= sec_byte_cnt - 10'd1;
		end
	reg [14:0] byte_cnt;
	always @(posedge clk)
		if (byte_clk_en) begin
			index_pulse_start <= 1'b0;
			if (byte_cnt == ((fm ? BPTSD : (hd ? BPTHD : BPTDD)) - 1'd1)) begin
				byte_cnt <= 0;
				index_pulse_start <= 1'b1;
			end
			else
				byte_cnt <= byte_cnt + 1'd1;
		end
	assign dclk_en = byte_clk_en;
	reg [2:0] clk_cnt2;
	reg data_clk_en;
	always @(posedge clk) begin
		byte_clk_en <= 0;
		if (data_clk_en) begin
			clk_cnt2 <= clk_cnt2 + 1'd1;
			if (clk_cnt2 == 3'b011)
				byte_clk_en <= 1;
		end
	end
	localparam SPIN_UP_CLKS = CLK_EN * SPINUP;
	localparam SPIN_DOWN_CLKS = CLK_EN * SPINDOWN;
	reg [31:0] spin_up_counter;
	wire motor_on_sel = motor_on && select;
	reg motor_onD;
	always @(posedge clk) begin
		motor_onD <= motor_on_sel;
		if (motor_onD != motor_on_sel)
			spin_up_counter <= 32'd0;
		else if (clk8m_en) begin
			spin_up_counter <= spin_up_counter + (fm ? RATESD : (hd ? RATEHD : RATEDD));
			if (motor_on_sel) begin
				if (spin_up_counter > SPIN_UP_CLKS) begin
					if (rate < (fm ? RATESD : (hd ? RATEHD : RATEDD)))
						rate <= rate + 32'd1;
					spin_up_counter <= spin_up_counter - (SPIN_UP_CLKS - (fm ? RATESD : (hd ? RATEHD : RATEDD)));
				end
			end
			else if (spin_up_counter > SPIN_DOWN_CLKS) begin
				if (rate > 0)
					rate <= rate - 32'd1;
				spin_up_counter <= spin_up_counter - (SPIN_DOWN_CLKS - (fm ? RATESD : (hd ? RATEHD : RATEDD)));
			end
		end
	end
	reg data_clk;
	reg [31:0] clk_cnt;
	always @(posedge clk) begin
		data_clk_en <= 0;
		if (clk8m_en) begin
			if ((clk_cnt + rate) > ((CLK_EN * 1000) / 2)) begin
				clk_cnt <= clk_cnt - (((CLK_EN * 1000) / 2) - rate);
				data_clk <= !data_clk;
				if (~data_clk)
					data_clk_en <= 1;
			end
			else
				clk_cnt <= clk_cnt + rate;
		end
	end
endmodule
