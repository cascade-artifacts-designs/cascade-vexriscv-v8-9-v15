// Copyright 2022 Flavien Solt, ETH Zurich.
// Licensed under the General Public License, Version 3.0, see LICENSE for details.
// SPDX-License-Identifier: GPL-3.0-only

module vexriscv_tiny_soc #(
    // The two below must be equal.
    parameter int unsigned InstrMemDepth = 1 << 20, // 32-bit words
    parameter int unsigned DataMemDepth  = 1 << 20, // 32-bit words

    localparam type data_t = logic [63:0],
    localparam type strb_t = logic [7:0], // The strobe is bytewise.
    localparam type addr_t = logic [31:0]
) (
  input logic clk_i,
  input logic rst_ni,

  ////////////////////
  // Memory signals //
  ////////////////////

  output logic  instr_mem_req_o,
  output logic  instr_mem_gnt_o,
  output addr_t instr_mem_addr_o,
  output data_t instr_mem_wdata_o,
  output strb_t instr_mem_strb_o,
  output logic  instr_mem_we_o,
  output data_t instr_mem_rdata_o,

  output logic  data_mem_req_o,
  output logic  data_mem_gnt_o,
  output addr_t data_mem_addr_o,
  output data_t data_mem_wdata_o,
  output strb_t data_mem_strb_o,
  output logic  data_mem_we_o,
  output data_t data_mem_rdata_o
);

  /////////////////
  // CPU signals //
  /////////////////

  logic        timerInterrupt;
  logic        externalInterrupt;
  logic        externalInterruptS;
  logic        softwareInterrupt;

  assign timerInterrupt                = '0;
  assign externalInterrupt             = '0;
  assign externalInterruptS            = '0;
  assign softwareInterrupt             = '0;

  /////////
  // CPU //
  /////////

  vexriscv_mem_top i_vexriscv_mem_top (
    .clk_i                         (clk_i),
    .rst_ni                        (rst_ni),
    .data_mem_req                  (data_mem_req_o),
    .data_mem_gnt                  (data_mem_gnt_o),
    .data_mem_addr                 (data_mem_addr_o),
    .data_mem_wdata                (data_mem_wdata_o),
    .data_mem_strb                 (data_mem_strb_o),
    .data_mem_we                   (data_mem_we_o),
    .data_mem_rdata                (data_mem_rdata_o),
    .instr_mem_req                 (instr_mem_req_o),
    .instr_mem_gnt                 (instr_mem_gnt_o),
    .instr_mem_addr                (instr_mem_addr_o),
    .instr_mem_wdata               (instr_mem_wdata_o),
    .instr_mem_strb                (instr_mem_strb_o),
    .instr_mem_we                  (instr_mem_we_o),
    .instr_mem_rdata               (instr_mem_rdata_o),
    .timerInterrupt                (timerInterrupt),
    .externalInterrupt             (externalInterrupt),
    .externalInterruptS            (externalInterruptS),
    .softwareInterrupt             (softwareInterrupt)
  );

  //////////////////////////////
  // Instruction ROM instance //
  //////////////////////////////

  sram_mem #(
    .Width(64),
    .Depth(InstrMemDepth),
    .RelocateRequestUp(64'h10000000) // 80000000 >> 3
  ) i_instr_rom (
    .clk_i,
    .rst_ni,

    .req_i(instr_mem_req_o),
    .write_i(instr_mem_we_o),
    .addr_i(instr_mem_addr_o >> 3), // 64-bit words
    .wdata_i(instr_mem_wdata_o),
    .wmask_i({{8{instr_mem_strb_o[7]}}, {8{instr_mem_strb_o[6]}}, {8{instr_mem_strb_o[5]}}, {8{instr_mem_strb_o[4]}}, {8{instr_mem_strb_o[3]}}, {8{instr_mem_strb_o[2]}}, {8{instr_mem_strb_o[1]}}, {8{instr_mem_strb_o[0]}}}),
    .rdata_o(instr_mem_rdata_o)
  );

  assign instr_mem_gnt_o = '1;

  ////////////////////////
  // Data SRAM instance //
  ////////////////////////

  sram_mem #(
    .Width(64),
    .Depth(DataMemDepth),
    .RelocateRequestUp(64'h10000000) // 80000000 >> 3
  ) i_data_sram (
    .clk_i,
    .rst_ni,

    .req_i(data_mem_req_o),
    .write_i(data_mem_we_o),
    .addr_i(data_mem_addr_o >> 3), // 64-bit words
    .wdata_i(data_mem_wdata_o),
    .wmask_i({{8{data_mem_strb_o[7]}}, {8{data_mem_strb_o[6]}}, {8{data_mem_strb_o[5]}}, {8{data_mem_strb_o[4]}}, {8{data_mem_strb_o[3]}}, {8{data_mem_strb_o[2]}}, {8{data_mem_strb_o[1]}}, {8{data_mem_strb_o[0]}}}),
    .rdata_o(data_mem_rdata_o)
  );

  assign data_mem_gnt_o = '1;

endmodule
