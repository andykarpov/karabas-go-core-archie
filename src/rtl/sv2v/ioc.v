module ioc (
	clkcpu,
	clk2m_en,
	clk7m_en,
	por,
	c_in,
	c_out,
	select,
	sext,
	fh,
	il,
	ir,
	wb_we,
	wb_stb,
	wb_cyc,
	wb_adr,
	wb_dat_i,
	wb_dat_o,
	wb_bank,
	irq,
	firq,
	kbd_out_data,
	kbd_out_strobe,
	kbd_in_data,
	kbd_in_strobe
);
	input clkcpu;
	output reg clk2m_en;
	output reg clk7m_en;
	input por;
	input [5:0] c_in;
	output wire [5:0] c_out;
	output wire [7:1] select;
	output wire sext;
	input [1:0] fh;
	input [7:0] il;
	input ir;
	input wb_we;
	input wb_stb;
	input wb_cyc;
	input [6:2] wb_adr;
	input [7:0] wb_dat_i;
	output wire [7:0] wb_dat_o;
	input [2:0] wb_bank;
	output wire irq;
	output wire firq;
	output reg [7:0] kbd_out_data;
	output reg kbd_out_strobe;
	input [7:0] kbd_in_data;
	input kbd_in_strobe;
	reg [4:0] clk2en_counter = 0;
	reg [2:0] clk7en_counter = 0;
	wire [7:0] irqa_dout;
	wire [7:0] irqb_dout;
	wire [7:0] firq_dout;
	wire irqa_req;
	wire irqb_req;
	wire firq_req;
	wire irqa_selected;
	wire irqb_selected;
	wire firq_selected;
	wire ctrl_selected = wb_adr[6:2] == 5'd0;
	wire [7:0] ctrl_dout;
	reg [5:0] ctrl_state;
	wire serial_selected = wb_adr[6:2] == 5'd1;
	wire write_request = (((wb_bank == 3'b000) & wb_stb) & wb_cyc) & wb_we;
	wire read_request = (((wb_bank == 3'b000) & wb_stb) & wb_cyc) & !wb_we;
	reg [7:0] kbd_in_data_latch;
	reg kbd_in_irq_ack;
	reg kbd_in_irq;
	always @(posedge clkcpu or posedge kbd_in_irq_ack)
		if (kbd_in_irq_ack)
			kbd_in_irq <= 0;
		else if (kbd_in_strobe) begin
			kbd_in_data_latch <= kbd_in_data;
			kbd_in_irq <= 1;
		end
	reg [4:0] txcount = 5'd0;
	wire txdone = txcount == 5'd0;
	reg ir_r;
	wire ir_edge;
	ioc_irq #(
		.ADDRESS(2'b01),
		.PERMBITS(8'h80),
		.CANCLEAR(8'b01111111)
	) IRQA(
		.clkcpu(clkcpu),
		.reset(por),
		.i({timer[2].reload, timer[1].reload, timer[0].reload, por, ir_edge, 3'b000}),
		.irq(irqa_req),
		.c(8'h00),
		.addr(wb_adr[6:2]),
		.din(wb_dat_i),
		.dout(irqa_dout),
		.sel(irqa_selected),
		.write(write_request)
	);
	ioc_irq #(
		.ADDRESS(2'b10),
		.CANCLEAR(8'b00000000)
	) IRQB(
		.clkcpu(clkcpu),
		.reset(por),
		.i({kbd_in_irq, txdone, ~il[5:0]}),
		.c({!kbd_in_irq, ~txdone, il[5:0]}),
		.irq(irqb_req),
		.addr(wb_adr[6:2]),
		.din(wb_dat_i),
		.dout(irqb_dout),
		.sel(irqb_selected),
		.write(write_request)
	);
	ioc_irq #(
		.ADDRESS(2'b11),
		.CANCLEAR(8'd0)
	) FIRQ(
		.clkcpu(clkcpu),
		.reset(por),
		.i({6'h00, fh[1:0]}),
		.c({6'h00, ~fh[1:0]}),
		.irq(firq_req),
		.addr(wb_adr[6:2]),
		.din(wb_dat_i),
		.dout(firq_dout),
		.sel(firq_selected),
		.write(write_request)
	);
	genvar _gv_c_2;
	generate
		for (_gv_c_2 = 0; _gv_c_2 < 4; _gv_c_2 = _gv_c_2 + 1) begin : timer
			localparam c = _gv_c_2;
			reg [15:0] latch_i;
			reg [15:0] counter;
			reg [15:0] latch_o;
			reg reload;
			wire selected = wb_adr[6] & (c[1:0] == wb_adr[5:4]);
			wire [7:0] out = (wb_adr[2] ? latch_o[15:8] : latch_o[7:0]);
			initial begin
				latch_i = 16'd0;
				counter = 16'd0;
				latch_o = 16'd0;
				reload = 1'b0;
			end
			always @(posedge clkcpu) begin
				reload <= 1'b0;
				if (write_request & selected)
					case (wb_adr[3:2])
						2'b00: latch_i[7:0] <= wb_dat_i;
						2'b01: latch_i[15:8] <= wb_dat_i;
						2'b10: counter <= {latch_i[15:4], 4'd0};
						2'b11: latch_o <= counter;
					endcase
				else if (clk2m_en) begin
					counter <= counter - 15'd1;
					if (~|counter) begin
						reload <= 1'b1;
						counter <= {latch_i[15:4], 4'd0};
					end
				end
			end
		end
	endgenerate
	always @(posedge clkcpu)
		if (por) begin
			ctrl_state <= 6'h3f;
			ir_r <= 1'b1;
			clk2en_counter <= 0;
			clk7en_counter <= 0;
			clk2m_en <= 0;
			clk7m_en <= 0;
		end
		else begin
			kbd_out_strobe <= !txdone;
			kbd_in_irq_ack <= serial_selected && read_request;
			ir_r <= ir;
			if (!txdone && timer[3].reload)
				txcount <= txcount - 4'd1;
			clk2en_counter <= clk2en_counter + 1'd1;
			if (clk2en_counter == 20)
				clk2en_counter <= 0;
			clk2m_en <= !clk2en_counter;
			clk7en_counter <= clk7en_counter + 1'd1;
			if (clk7en_counter == 5)
				clk7en_counter <= 0;
			clk7m_en <= !clk7en_counter;
			if (write_request & ctrl_selected)
				ctrl_state <= wb_dat_i[5:0];
			if (write_request & serial_selected) begin
				kbd_out_strobe <= 1'b0;
				kbd_out_data <= wb_dat_i[7:0];
				txcount <= 5'd20;
			end
		end
	assign {select, sext} = (wb_bank ? (8'd1 << wb_bank) | 8'd1 : 8'd0);
	assign c_out = ctrl_state;
	assign ctrl_dout = {ir, 1'b1, c_in & c_out};
	assign ir_edge = ~ir_r & ir;
	assign wb_dat_o = (~read_request ? 8'hff : (ctrl_selected ? ctrl_dout : (serial_selected ? kbd_in_data_latch : (irqa_selected ? irqa_dout : (irqb_selected ? irqb_dout : (firq_selected ? firq_dout : (timer[0].selected ? timer[0].out : (timer[1].selected ? timer[1].out : (timer[2].selected ? timer[2].out : (timer[3].selected ? timer[3].out : 8'hff))))))))));
	assign irq = irqa_req | irqb_req;
	assign firq = firq_req;
endmodule
