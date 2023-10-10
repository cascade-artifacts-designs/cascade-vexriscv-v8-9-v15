// Copyright 2021 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Author: Flavien Solt, ETH Zurich

module vexriscv_mem_top #(
  parameter int unsigned AddrSize = 32,
  parameter int unsigned DataSize = 64,

  localparam type data_t = logic[DataSize-1:0],
  localparam type strb_t = logic[(DataSize >> 3)-1:0],
  localparam type addr_t = logic[AddrSize-1:0]
) (
	input logic clk_i,
  input logic rst_ni,

  // Memory interface
  output logic  data_mem_req,
  input  logic  data_mem_gnt,
  output addr_t data_mem_addr,
  output data_t data_mem_wdata,
  output strb_t data_mem_strb,
  output logic  data_mem_we,
  input  data_t data_mem_rdata,

  output logic  instr_mem_req,
  input  logic  instr_mem_gnt,
  output addr_t instr_mem_addr,
  output data_t instr_mem_wdata,
  output strb_t instr_mem_strb,
  output logic  instr_mem_we,
  input  data_t instr_mem_rdata,

	// VexRiscv core interface
  input  logic          debug_bus_cmd_valid,
  output logic          debug_bus_cmd_ready,
  input  logic          debug_bus_cmd_payload_wr,
  input  logic [7:0]    debug_bus_cmd_payload_address,
  input  logic [31:0]   debug_bus_cmd_payload_data,
  output logic [31:0]   debug_bus_rsp_data,
  output logic          debug_resetOut,
  input  logic          timerInterrupt,
  input  logic          externalInterrupt,
  input  logic          externalInterruptS,
  input  logic          softwareInterrupt
);

  logic  data_mem_req_misaligned;
  logic  data_mem_gnt_misaligned;
  addr_t data_mem_addr_misaligned;
  data_t data_mem_wdata_misaligned;
  strb_t data_mem_strb_misaligned;
  logic  data_mem_we_misaligned;
  data_t data_mem_rdata_misaligned;

  logic  instr_mem_req_misaligned;
  logic  instr_mem_gnt_misaligned;
  addr_t instr_mem_addr_misaligned;
  data_t instr_mem_wdata_misaligned;
  strb_t instr_mem_strb_misaligned;
  logic  instr_mem_we_misaligned;
  data_t instr_mem_rdata_misaligned;

  /////////////////////////////
  // BMB signals
  /////////////////////////////

  logic         dBus_cmd_valid;
  logic         dBus_cmd_ready;
  logic         dBus_cmd_payload_wr;
  logic         dBus_cmd_payload_uncached;
  logic [31:0]  dBus_cmd_payload_address;
  logic [63:0]  dBus_cmd_payload_data;
  logic [7:0]   dBus_cmd_payload_mask;
  logic [2:0]   dBus_cmd_payload_size;
  logic         dBus_cmd_payload_last;
  logic         dBus_rsp_valid;
  // logic [3:0]   dBus_rsp_payload_aggregated;
  logic         dBus_rsp_payload_last;
  logic [63:0]  dBus_rsp_payload_data;
  logic         dBus_rsp_payload_error;

  logic         iBus_cmd_valid;
  logic         iBus_cmd_ready;
  logic [31:0]  iBus_cmd_payload_address;
  logic [2:0]   iBus_cmd_payload_size;
  logic         iBus_rsp_valid;
  logic [63:0]  iBus_rsp_payload_data;
  logic         iBus_rsp_payload_error;

  /////////////////////
  // Core instance
  /////////////////////

  VexRiscv i_vexriscv (
    .clk(clk_i),
    .reset(~rst_ni),
    .dBus_cmd_valid,
    .dBus_cmd_ready,
    .dBus_cmd_payload_wr,
    .dBus_cmd_payload_uncached,
    .dBus_cmd_payload_address,
    .dBus_cmd_payload_data,
    .dBus_cmd_payload_mask,
    .dBus_cmd_payload_size,
    .dBus_cmd_payload_last,
    .dBus_rsp_valid,
    // .dBus_rsp_payload_aggregated,
    .dBus_rsp_payload_last,
    .dBus_rsp_payload_data,
    .dBus_rsp_payload_error,
    .iBus_cmd_valid,
    .iBus_cmd_ready,
    .iBus_cmd_payload_address,
    .iBus_cmd_payload_size,
    .iBus_rsp_valid,
    .iBus_rsp_payload_data,
    .iBus_rsp_payload_error,
    .timerInterrupt,
    .externalInterrupt,
    .externalInterruptS,
    .softwareInterrupt
  );

  /////////////////////////
  // APB to mem adapters
  /////////////////////////

  bmb_full_to_mem #(
    .AddrSize(AddrSize),
    .DataSize(DataSize)
  ) i_instr_bmb_full_to_mem (
    .clk_i,
    .rst_ni,
    .bmb_cmd_valid(iBus_cmd_valid),
    .bmb_cmd_ready(iBus_cmd_ready),
    .bmb_cmd_payload_address(iBus_cmd_payload_address),
    .bmb_cmd_payload_size(iBus_cmd_payload_size),
    .bmb_cmd_payload_wr(1'b0),
    .bmb_cmd_payload_uncached(1'b0),
    .bmb_cmd_payload_data('0),
    .bmb_cmd_payload_mask('0),
    .bmb_cmd_payload_last(1'b1),
    .bmb_rsp_valid(iBus_rsp_valid),
    .bmb_rsp_payload_data(iBus_rsp_payload_data),
    // .bmb_rsp_payload_aggregated(),
    .bmb_rsp_payload_last(),
    .bmb_rsp_payload_error(iBus_rsp_payload_error),
    .mem_req(instr_mem_req_misaligned),
    .mem_gnt(instr_mem_gnt_misaligned),
    .mem_addr(instr_mem_addr_misaligned),
    .mem_wdata(instr_mem_wdata_misaligned),
    .mem_strb(instr_mem_strb_misaligned),
    .mem_we(instr_mem_we_misaligned),
    .mem_rdata(instr_mem_rdata_misaligned)
  );

  bmb_full_to_mem #(
    .AddrSize(AddrSize),
    .DataSize(DataSize)
  ) i_data_bmb_full_to_mem (
    .clk_i,
    .rst_ni,
    .bmb_cmd_valid(dBus_cmd_valid),
    .bmb_cmd_ready(dBus_cmd_ready),
    .bmb_cmd_payload_address(dBus_cmd_payload_address),
    .bmb_cmd_payload_size(dBus_cmd_payload_size),
    .bmb_cmd_payload_wr(dBus_cmd_payload_wr),
    .bmb_cmd_payload_uncached(dBus_cmd_payload_uncached),
    .bmb_cmd_payload_data(dBus_cmd_payload_data),
    .bmb_cmd_payload_mask(dBus_cmd_payload_mask),
    .bmb_cmd_payload_last(dBus_cmd_payload_last),
    .bmb_rsp_valid(dBus_rsp_valid),
    .bmb_rsp_payload_data(dBus_rsp_payload_data),
    // // .bmb_rsp_payload_aggregated(dBus_rsp_payload_aggregated),
    .bmb_rsp_payload_last(dBus_rsp_payload_last),
    .bmb_rsp_payload_error(dBus_rsp_payload_error),
    .mem_req(data_mem_req_misaligned),
    .mem_gnt(data_mem_gnt_misaligned),
    .mem_addr(data_mem_addr_misaligned),
    .mem_wdata(data_mem_wdata_misaligned),
    .mem_strb(data_mem_strb_misaligned),
    .mem_we(data_mem_we_misaligned),
    .mem_rdata(data_mem_rdata_misaligned)
  );

  /////////////////////////
  // Align mem request to word width (4 bytes)
  /////////////////////////

  memreq_aligner #(
    .AlignmentBytes(8),
    .AddrSize(AddrSize),
    .DataSize(DataSize)
  ) i_instr_memreq_aligner (
    .mem_req_misaligned  (instr_mem_req_misaligned),
    .mem_gnt_misaligned  (instr_mem_gnt_misaligned),
    .mem_addr_misaligned (instr_mem_addr_misaligned),
    .mem_wdata_misaligned(instr_mem_wdata_misaligned),
    .mem_strb_misaligned (instr_mem_strb_misaligned),
    .mem_we_misaligned   (instr_mem_we_misaligned),
    .mem_rdata_misaligned(instr_mem_rdata_misaligned),
    .mem_req_aligned     (instr_mem_req),
    .mem_gnt_aligned     (instr_mem_gnt),
    .mem_addr_aligned    (instr_mem_addr),
    .mem_wdata_aligned   (instr_mem_wdata),
    .mem_strb_aligned    (instr_mem_strb),
    .mem_we_aligned      (instr_mem_we),
    .mem_rdata_aligned   (instr_mem_rdata)
  );

  memreq_aligner #(
    .AlignmentBytes(8),
    .AddrSize(AddrSize),
    .DataSize(DataSize)
  ) i_data_memreq_aligner (
    .mem_req_misaligned  (data_mem_req_misaligned),
    .mem_gnt_misaligned  (data_mem_gnt_misaligned),
    .mem_addr_misaligned (data_mem_addr_misaligned),
    .mem_wdata_misaligned(data_mem_wdata_misaligned),
    .mem_strb_misaligned (data_mem_strb_misaligned),
    .mem_we_misaligned   (data_mem_we_misaligned),
    .mem_rdata_misaligned(data_mem_rdata_misaligned),
    .mem_req_aligned     (data_mem_req),
    .mem_gnt_aligned     (data_mem_gnt),
    .mem_addr_aligned    (data_mem_addr),
    .mem_wdata_aligned   (data_mem_wdata),
    .mem_strb_aligned    (data_mem_strb),
    .mem_we_aligned      (data_mem_we),
    .mem_rdata_aligned   (data_mem_rdata)
  );

endmodule
