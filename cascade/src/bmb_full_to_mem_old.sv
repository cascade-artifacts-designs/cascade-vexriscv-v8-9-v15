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
  // Burst management
  logic [PayloadBits-1:0] burst_counter_d, burst_counter_q;
  logic was_cmd_d, was_cmd_q;
  logic is_new_cmd;
  data_t curr_addr_d, curr_addr_q;
  assign was_cmd_d = bmb_cmd_valid;
  assign is_new_cmd = was_cmd_d & !was_cmd_q;
  always_comb begin
    burst_counter_d = burst_counter_q;
    curr_addr_d = curr_addr_q;
    if (is_new_cmd) begin
      // burst_counter_d = bmb_cmd_payload_size-1;
      burst_counter_d = 0;
      curr_addr_d = bmb_cmd_payload_address + (DataSize >> 3);
    end else begin
      // We expect no backpressure therefore the logic is simple
      burst_counter_d = burst_counter_q ? burst_counter_q - 1'b1 : '0;
      curr_addr_d = curr_addr_d + (DataSize >> 3);
    end
  end

  // Update the address


  // // For commands, the FIFO contains data, address, mask and write enable

  // localparam CmdFifoWidth = DataSize + AddrSize + DataSize/8 + 1;
  // prim_fifo_sync #(
  //   .Width(DataSize),
  //   .Depth(8),
  //   .Pass(1),
  //   .OutputZeroIfEmpty(1)
  // ) i_prim_fifo_sync_cmd (
  //   .clk_i(clk_i),
  //   .rst_ni(rst_ni),
  //   .wvalid_i(bmb_cmd_valid),
  //   .wready_o(bmb_cmd_ready), // TODO bmb_cmd_ready must be related to bursts as well
  //   .wdata_i({bmb_cmd_payload_data, bmb_cmd_payload_address, bmb_cmd_payload_mask}),
  //   .rvalid_o(mem_req),
  //   .rready_i(mem_gnt),
  //   .rdata_o({mem_wdata, mem_addr, mem_strb, mem_we})
  // );

  assign mem_req = is_new_cmd | |burst_counter_q;
  // Maybe this is wrong and we would need to store the values, maybe in a FIFO
  assign mem_addr = is_new_cmd ? bmb_cmd_payload_address : curr_addr_q;
  assign mem_wdata = bmb_cmd_payload_data;
  assign mem_strb = bmb_cmd_payload_mask;
  assign mem_we = bmb_cmd_payload_wr;

  // The response is ready one cycle after the command is sent to the memory

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      bmb_rsp_valid <= 1'b0;
    end else begin
      bmb_rsp_valid <= mem_req;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      burst_counter_q <= '0;
      curr_addr_q <= '0;
      was_cmd_q <= '0;
    end else begin
      burst_counter_q <= burst_counter_d;
      curr_addr_q <= curr_addr_d;
      was_cmd_q <= was_cmd_d;
    end
  end

  assign bmb_cmd_ready = 1'b1;

  assign bmb_rsp_payload_data = mem_rdata;
  assign bmb_rsp_payload_last = (burst_counter_q == {PayloadBits{1'b1}}) | (bmb_cmd_payload_size == {PayloadBits{1'b1}} && is_new_cmd);
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
