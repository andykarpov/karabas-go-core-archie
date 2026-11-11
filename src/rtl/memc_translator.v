`timescale 1ns / 1ps
/* memc_translator.v

 Copyright (c) 2012-2014, Stephen J. Leary
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of the <organization> nor the
 *       names of its contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
 
module memc_translator
(
		input 			clkcpu,
		
		input			wr,		// write to the page table
		input [1:0]		page_size,
		input			spvmd,
		input			osmd,
		input			mem_write,
		
		input	[25:0]	addr_i,
		output  [25:0]	addr_o,
		output			valid
);

localparam PAGE_TABLE_SIZE = 128;

// Memory protection truth table.
//      |  00  |  01  |  10  |  11  |
// -----|------|------|------|------|
// SPVMD| R/W  | R/W  | R/W  | R/W  |
//  OSMD| R/W  | R/W  |  R   |  R   |
// USRMD| R/W  |  R   |  -   |  -   |
// 		|------|------|------|------|

// address translation table.

// TODO: other memory sizes?
// if the OS uses different memory sizes at startup i'll implement it
// otherwise i'll make it fixed at synth time.
 
// ppn swizzle for 32K page size. 
// could potentially get 16Mb here by making 512 pages.
wire [6:0] ppn =  page_size == 2'b00 ? {addr_i[6:0]} :
						page_size == 2'b01 ? {addr_i[0], addr_i[6:1]} : 
						page_size == 2'b10 ? {addr_i[1:0], addr_i[6:2]} :
										         {addr_i[1], addr_i[2], addr_i[0], addr_i[6:3]};

// karabas: the enables of all entries, for the tree decode below
wire [PAGE_TABLE_SIZE-1:0] en_v;

genvar c;
generate
	for (c = 0; c < PAGE_TABLE_SIZE; c = c + 1) begin: pgentry
		
		reg[14:0] 	r	= 	0; 				// register for this table entry.
		
		wire 		prot		= spvmd | (osmd & ~mem_write) | (osmd & mem_write & r[14]) | ~r[14] & r[13] & ~mem_write | ~r[14] & ~r[13];
		
		wire		en	= 	r[12:3] == addr_i[24:15] & prot; // lookup logic when this table is active.
		wire 		sel	= 	ppn[6:0] == c[6:0]; // select logic for this page table (for writing table)
		wire [25:0]	addr = 	{4'b0000, c[6:0], addr_i[14:0]};
		assign en_v[c] = en;
		
		always @(posedge clkcpu) begin
		
			if (wr & sel) begin 
	
				// code to program the table
				r <= {addr_i[9:8], addr_i[11:10], addr_i[22:12]};
				$display("writing to table entry %d := %x (%x)", c,  {addr_i[9:8], addr_i[11:10], addr_i[22:12]}, addr_i);
				
			end 
			
		end
		
    end

endgenerate

// 128 to 1 decode.
// karabas: the same priority (the lowest matching entry wins) as a tree: the chain of 128 ?: of the
// original became a chain of 30 muxes in XST on the Go build (41 ns at 40 MHz). 16 groups of 8: the
// lowest entry of each group, then the lowest group.
function [2:0] lowest8;
	input [7:0] v;
	integer k;
	begin
		lowest8 = 3'd0;
		for (k = 7; k >= 0; k = k - 1)
			if (v[k]) lowest8 = k[2:0];
	end
endfunction

function [3:0] lowest16;
	input [15:0] v;
	integer k;
	begin
		lowest16 = 4'd0;
		for (k = 15; k >= 0; k = k - 1)
			if (v[k]) lowest16 = k[3:0];
	end
endfunction

wire [15:0] g_any;
wire [2:0] g_idx [0:15];
genvar g;
generate
	for (g = 0; g < 16; g = g + 1) begin: grp
		assign g_any[g] = |en_v[g*8 +: 8];
		assign g_idx[g] = lowest8(en_v[g*8 +: 8]);
	end
endgenerate

wire [3:0] gi = lowest16(g_any);
assign valid = |g_any;
assign addr_o = valid ? {4'b0000, gi, g_idx[gi], addr_i[14:0]} : 26'd0;

endmodule
