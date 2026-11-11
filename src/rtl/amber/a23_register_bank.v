//////////////////////////////////////////////////////////////////
//                                                              //
//  Register Bank for Amber Core                                //
//                                                              //
//  This file is part of the Amber project                      //
//  http://www.opencores.org/project,amber                      //
//                                                              //
//  Description                                                 //
//  Contains 37 32-bit registers, 16 of which are visible       //
//  ina any one operating mode. Registers use real flipflops,   //
//  rather than SRAM. This makes sense for an FPGA              //
//  implementation, where flipflops are plentiful.              //
//                                                              //
//  Author(s):                                                  //
//      - Conor Santifort, csantifort.amber@gmail.com           //
//                                                              //
//////////////////////////////////////////////////////////////////
//                                                              //
// Copyright (C) 2010 Authors and OPENCORES.ORG                 //
//                                                              //
// This source file may be used and distributed without         //
// restriction provided that this copyright statement is not    //
// removed from the file and that any derivative work contains  //
// the original copyright notice and the associated disclaimer. //
//                                                              //
// This source file is free software; you can redistribute it   //
// and/or modify it under the terms of the GNU Lesser General   //
// Public License as published by the Free Software Foundation; //
// either version 2.1 of the License, or (at your option) any   //
// later version.                                               //
//                                                              //
// This source is distributed in the hope that it will be       //
// useful, but WITHOUT ANY WARRANTY; without even the implied   //
// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      //
// PURPOSE.  See the GNU Lesser General Public License for more //
// details.                                                     //
//                                                              //
// You should have received a copy of the GNU Lesser General    //
// Public License along with this source; if not, download it   //
// from http://www.opencores.org/lgpl.shtml                     //
//                                                              //
//////////////////////////////////////////////////////////////////

module a23_register_bank (

input                       i_clk,
input                       i_reset,
input                       i_fetch_stall,

input       [1:0]           i_mode_idec,            // user, supervisor, irq_idec, firq_idec etc.
                                                    // Used for register writes
input       [1:0]           i_mode_exec,            // 1 periods delayed from i_mode_idec
                                                    // Used for register reads
input       [3:0]           i_mode_rds_exec,        // Use one-hot version specifically for rds, 
                                                    // includes i_user_mode_regs_store
input                       i_user_mode_regs_load,
input                       i_firq_not_user_mode,
input       [3:0]           i_rm_sel,
input       [3:0]           i_rds_sel,
input       [3:0]           i_rn_sel,

input                       i_pc_wen,
input       [14:0]          i_reg_bank_wen,

input       [23:0]          i_pc,                   // program counter [25:2]
input       [31:0]          i_reg,

input       [3:0]           i_status_bits_flags,
input                       i_status_bits_irq_mask,
input                       i_status_bits_firq_mask,

output      [31:0]          o_rm,
output reg  [31:0]          o_rs,
output reg  [31:0]          o_rd,
output      [31:0]          o_rn,
output      [31:0]          o_pc

);

`include "a23_localparams.v"
`include "a23_functions.v"

// karabas: the 27 registers of the modes in a 32 x 32 distributed RAM (one write port, three
// asynchronous read ports: rm and rn by the exec mode, rds by its one-hot mode) instead of
// flip-flops with four mux trees (1100 LUT / 856 FF in XST). Same ports, same timing: a write on the
// clock edge (!i_fetch_stall), reads combinational. The registers are not set to deadbeef at reset.
// r15 stays a flip-flop register with its outputs. Slots (the map of a23_ram_register_bank):
//   0..14 r0..r14 (user, and r0..r12 of all but FIQ), 16..22 r8..r14 FIQ, 25 / 26 r13 / r14 IRQ,
//   29 / 30 r13 / r14 SVC.

reg  [23:0] r15 = 24'hc0_ffee;
reg  [31:0] rf [0:31];

wire        usr_exec  = i_mode_exec == USR;
wire        svc_exec  = i_mode_exec == SVC;
wire        irq_exec  = i_mode_exec == IRQ;
wire        firq_exec = i_mode_exec == FIRQ;

wire        usr_idec  =  i_user_mode_regs_load || i_mode_idec == USR;
wire        svc_idec  = !i_user_mode_regs_load && i_mode_idec == SVC;
wire        irq_idec  = !i_user_mode_regs_load && i_mode_idec == IRQ;
// pre-encoded in decode stage to speed up long path
wire        firq_idec = i_firq_not_user_mode;

// the slot of register sel in a mode (u, s, i, f: user, supervisor, interrupt, fast interrupt)
function [4:0] slot;
input [3:0] sel;
input       u, s, i, f;
begin
    if (!sel[3] || sel[3:2] == 2'b10 && !f || sel == 4'd12 && !f)
        slot = {1'b0, sel};                 // r0..r12 (r8..r12 FIQ below)
    else if (sel <= 4'd12)
        slot = {2'b10, sel[2:0]};           // r8..r12 FIQ
    else if (u)
        slot = {1'b0, sel};                 // r13, r14 user
    else if (s)
        slot = {3'b111, sel[1:0]};          // r13, r14 SVC
    else if (i)
        slot = {3'b110, sel[1:0]};          // r13, r14 IRQ
    else
        slot = {2'b10, sel[2:0]};           // r13, r14 FIQ
end
endfunction

// the register written (i_reg_bank_wen is one-hot, from reg_bank_wsel of decode)
reg  [3:0]  wsel;
integer     k;
always @* begin
    wsel = 4'd0;
    for (k = 0; k < 15; k = k + 1)
        if (i_reg_bank_wen[k]) wsel = k;
end
wire        wen = |i_reg_bank_wen;
wire [4:0]  w_slot  = slot(wsel, usr_idec, svc_idec, irq_idec, firq_idec);

wire [4:0]  rm_slot = slot(i_rm_sel, usr_exec, svc_exec, irq_exec, firq_exec);
wire [4:0]  rn_slot = slot(i_rn_sel, usr_exec, svc_exec, irq_exec, firq_exec);
wire [4:0]  ds_slot = slot(i_rds_sel, i_mode_rds_exec[OH_USR], i_mode_rds_exec[OH_SVC],
                           i_mode_rds_exec[OH_IRQ], i_mode_rds_exec[OH_FIRQ]);

always @ ( posedge i_clk )
    if (i_reset)
        r15 <= 24'h00_0000;
    else if (!i_fetch_stall) begin
        if (wen) rf[w_slot] <= i_reg;
        r15 <= i_pc_wen ? i_pc : r15;
    end

wire [31:0] rm_ram = rf[rm_slot];
wire [31:0] rn_ram = rf[rn_slot];
wire [31:0] ds_ram = rf[ds_slot];

wire [31:0] r15_out_rm     = { i_status_bits_flags,
                               i_status_bits_irq_mask,
                               i_status_bits_firq_mask,
                               r15,
                               i_mode_exec};

wire [31:0] r15_out_rm_nxt = { i_status_bits_flags,
                               i_status_bits_irq_mask,
                               i_status_bits_firq_mask,
                               i_pc,
                               i_mode_exec};

wire [31:0] r15_out_rn     = {6'd0, r15, 2'd0};

assign o_pc = r15_out_rn;
assign o_rm = i_rm_sel  == 4'd15 ? r15_out_rm     : rm_ram;
assign o_rn = i_rn_sel  == 4'd15 ? r15_out_rn     : rn_ram;
always @* o_rs = i_rds_sel == 4'd15 ? r15_out_rn     : ds_ram;
always @* o_rd = i_rds_sel == 4'd15 ? r15_out_rm_nxt : ds_ram;

endmodule
