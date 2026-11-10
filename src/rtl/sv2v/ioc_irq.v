module ioc_irq (
	clkcpu,
	reset,
	i,
	c,
	irq,
	write,
	addr,
	din,
	dout,
	sel
);
	parameter ADDRESS = 2'b01;
	parameter CANCLEAR = 8'b11111111;
	parameter PERMBITS = 8'h00;
	input clkcpu;
	input reset;
	input [7:0] i;
	input [7:0] c;
	output wire irq;
	input write;
	input [6:2] addr;
	input [7:0] din;
	output wire [7:0] dout;
	output wire sel;
	reg [7:0] mask = 8'h00;
	reg [7:0] status = 8'h00;
	wire selected = ~addr[6] & (addr[5:4] == ADDRESS);
	always @(posedge clkcpu)
		if (reset) begin
			mask <= 8'h00;
			status <= 8'h00;
		end
		else begin
			status <= (((status & CANCLEAR) | ((status & ~CANCLEAR) & ~c)) | i) | PERMBITS;
			if (selected & write) begin
				if (addr[3:2] == 2'b10)
					mask <= din;
				if (addr[3:2] == 2'b01)
					status <= ((status & ~CANCLEAR) | ((status & ~din) & CANCLEAR)) | PERMBITS;
			end
		end
	assign sel = selected;
	assign irq = |(mask & status);
	assign dout = (addr[3:2] == 2'b00 ? status : (addr[3:2] == 2'b01 ? mask & status : (addr[3:2] == 2'b10 ? mask : 8'd0)));
endmodule
