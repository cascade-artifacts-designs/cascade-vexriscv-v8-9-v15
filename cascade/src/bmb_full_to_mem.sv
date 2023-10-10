// Copyright 2022 Flavien Solt, ETH Zurich.
// Licensed under the General Public License, Version 3.0, see LICENSE for details.
// SPDX-License-Identifier: GPL-3.0-only

module bmb_full_to_mem #(
  parameter AddrSize = 32,
  parameter DataSize = 64,
  parameter PayloadBits = 2,

  localparam type data_t = logic[DataSize-1:0],
  localparam type strb_t = logic[(DataSize>>3)-1:0], // The strobe is bytewise
  localparam type addr_t = logic[AddrSize-1:0]
) (
    input  logic        clk_i,
    input  logic        rst_ni,

    input  logic        bmb_cmd_valid,
    output logic        bmb_cmd_ready,
    input  addr_t       bmb_cmd_payload_address,
    input  logic [PayloadBits-1:0] bmb_cmd_payload_size, // Burst length: log2up(log2up(bytesperline)+1)

    input  logic        bmb_cmd_payload_wr,
    input  logic        bmb_cmd_payload_uncached,
    input  data_t       bmb_cmd_payload_data,
    input  strb_t       bmb_cmd_payload_mask,
    input  logic        bmb_cmd_payload_last,

    output logic        bmb_rsp_valid,
    output data_t       bmb_rsp_payload_data,

    // output logic [3:0]  bmb_rsp_payload_aggregated,
    output logic        bmb_rsp_payload_last,
    output logic        bmb_rsp_payload_error,

    // MEM
    output logic  mem_req,
    input  logic  mem_gnt,
    output addr_t mem_addr,
    output data_t mem_wdata,
    output strb_t mem_strb,
    output logic  mem_we,
    input  data_t mem_rdata
);

  assign mem_req = bmb_cmd_valid;
  // Maybe this is wrong and we would need to store the values, maybe in a FIFO
  assign mem_addr = bmb_cmd_payload_address;
  assign mem_wdata = bmb_cmd_payload_data;
  assign mem_strb = bmb_cmd_payload_mask;
  assign mem_we = bmb_cmd_payload_wr;

  // The response is ready one cycle after the command is sent to the memory

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      bmb_rsp_valid <= 1'b0;
    end else begin
      bmb_rsp_valid <= bmb_cmd_valid & ~bmb_cmd_payload_wr;
    end
  end

  assign bmb_cmd_ready = 1'b1; // TODO Maybe randomize this for better fuzzing

  assign bmb_rsp_payload_data = mem_rdata;
  assign bmb_rsp_payload_last = 1'b1;
  assign bmb_rsp_payload_error = 1'b0;

  // // Aggregated

  // logic [3:0] bmb_payload_aggregated_d, bmb_payload_aggregated_q;
  // assign bmb_rsp_payload_aggregated = bmb_payload_aggregated_q;
  // always_ff @(posedge clk_i or negedge rst_ni) begin
  //   if (!rst_ni) begin
  //     bmb_payload_aggregated_q <= '0;
  //   end else begin
  //     bmb_payload_aggregated_q <= bmb_payload_aggregated_d;
  //   end
  // end

  // No burst currently supported. Bad assertion because data writes or reads may be smaller.
  // assert property (@(posedge clk_i) (bmb_cmd_payload_size == 0) | (bmb_cmd_payload_size == 2'h3) ) else $error("Bursts are not supported in the converter");

endmodule
