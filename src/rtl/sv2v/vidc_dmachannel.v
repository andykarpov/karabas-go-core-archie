module vidc_dmachannel (
	clkcpu,
	clkdev,
	cedev,
	rst_cpu,
	rst_dev,
	ak,
	rq,
	cpu_data,
	stall,
	dev_ak,
	dev_data
);
	input clkcpu;
	input clkdev;
	input cedev;
	input rst_cpu;
	input rst_dev;
	input ak;
	output reg rq;
	input [31:0] cpu_data;
	input stall;
	input dev_ak;
	output wire [7:0] dev_data;
	parameter FIFO_SIZE = 3;
	wire can_burst;
	initial rq = 0;
	vidc_async_fifo #(.ADDR_WIDTH(FIFO_SIZE)) VIDEO_FIFO(
		.wr_clk(clkcpu),
		.wr_rst(rst_cpu),
		.wr_en(ak & rq),
		.wr_data(cpu_data),
		.wr_can_burst(can_burst),
		.rd_clk(clkdev),
		.rd_rst(rst_dev),
		.rd_en(cedev & dev_ak),
		.rd_data(dev_data)
	);
	always @(posedge clkcpu) begin : block
		reg [1:0] dma_count;
		reg rstD;
		reg rstD2;
		rstD <= rst_cpu;
		rstD2 <= rstD;
		if (rstD2) begin
			dma_count <= 0;
			rq <= 0;
		end
		else if (rq) begin
			if (ak) begin
				dma_count <= dma_count + 1'd1;
				if (&dma_count)
					rq <= 0;
			end
		end
		else if (~stall & can_burst) begin
			dma_count <= 0;
			rq <= 1;
		end
	end
endmodule
