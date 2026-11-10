module EEPROM_24C0x (
	type_24C01,
	clk,
	ce,
	reset,
	SCL,
	SDA_in,
	SDA_out,
	E_id,
	WC_n,
	data_from_ram,
	data_to_ram,
	ram_addr,
	ram_read,
	ram_write,
	ram_done
);
	input type_24C01;
	input clk;
	input ce;
	input reset;
	input SCL;
	input SDA_in;
	output reg SDA_out;
	input [2:0] E_id;
	input WC_n;
	input [7:0] data_from_ram;
	output wire [7:0] data_to_ram;
	output wire [7:0] ram_addr;
	output reg ram_read;
	output reg ram_write;
	input ram_done;
	reg [2:0] state;
	reg [9:0] command;
	reg [7:0] address;
	reg [8:0] data;
	reg last_SCL;
	reg last_SDA;
	wire NoTestState = type_24C01;
	always @(posedge clk)
		if (reset) begin
			state <= 3'd0;
			command <= 0;
			last_SCL <= 0;
			last_SDA <= 0;
			SDA_out <= 1;
			ram_read <= 0;
			ram_write <= 0;
		end
		else if (ce) begin
			last_SCL <= SCL;
			last_SDA <= SDA_in;
			if (ram_write && ram_done) begin
				ram_write <= 0;
				address[3:0] <= address[3:0] + 4'b0001;
			end
			if (ram_read && ram_done) begin
				ram_read <= 0;
				data <= {data_from_ram, 1'b1};
				address <= address + 8'b00000001;
			end
			if (((SCL && last_SCL) && !SDA_in) && last_SDA) begin
				if (NoTestState)
					state <= 3'd2;
				else
					state <= 3'd1;
				command <= 10'd2;
			end
			else if (((SCL && last_SCL) && SDA_in) && !last_SDA) begin
				state <= 3'd0;
				command <= 10'd0;
			end
			else if (state == 3'd0)
				;
			else if (SCL && !last_SCL)
				command <= {command[8:0], SDA_in};
			else if (!SCL && last_SCL) begin
				SDA_out <= 1;
				if (state == 3'd4) begin
					SDA_out <= data[8];
					if (!ram_read)
						data[8:1] <= data[7:0];
				end
				if (command[9]) begin
					if (state == 3'd1) begin
						if (command[7:1] == {4'b1010, E_id}) begin
							if (command[0]) begin
								state <= 3'd4;
								ram_read <= 1;
							end
							else
								state <= 3'd2;
							SDA_out <= 0;
						end
						command <= 10'd1;
					end
					else if (state == 3'd2) begin
						if (NoTestState) begin
							address <= {1'b0, command[7:1]};
							if (command[0]) begin
								state <= 3'd4;
								ram_read <= 1;
							end
							else
								state <= 3'd3;
						end
						else begin
							address <= command[7:0];
							state <= 3'd3;
						end
						SDA_out <= 0;
						command <= 10'd1;
					end
					else if (state == 3'd3) begin
						data <= {command[7:0], 1'b0};
						if (!WC_n) begin
							ram_write <= 1;
							SDA_out <= 0;
						end
						command <= 10'd1;
					end
					else if (state == 3'd4) begin
						ram_read <= 1;
						SDA_out <= 1;
						command <= 10'd1;
					end
				end
			end
		end
	assign ram_addr = (type_24C01 == 1 ? {1'b0, address[6:0]} : address);
	assign data_to_ram = data[8:1];
endmodule
