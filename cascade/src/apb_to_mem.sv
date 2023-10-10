// Copyright 2022 Flavien Solt, ETH Zurich.
// Licensed under the General Public License, Version 3.0, see LICENSE for details.
// SPDX-License-Identifier: GPL-3.0-only

module apb_to_mem #(
  parameter ADDR_SIZE = 32,
  parameter DATA_SIZE = 32,

  localparam type data_t = logic[DATA_SIZE-1:0],
  localparam type strb_t = logic[(DATA_SIZE>>3)-1:0], // The strobe is bytewise
  localparam type addr_t = logic[ADDR_SIZE-1:0]
) (
    input  logic  clk_i,
    input  logic  rst_ni,

    // APB
    input  addr_t PADDR,
    input  data_t PWDATA,
    input  logic  PWRITE,
    input  logic  PSEL,
    input  logic  PENABLE,
    input  strb_t PSTRB,
    output data_t PRDATA,
    output logic  PREADY,
    output logic  PSLVERR,

    // MEM
    output logic  mem_req,
    input  logic  mem_gnt,
    output addr_t mem_addr,
    output data_t mem_wdata,
    output strb_t mem_strb,
    output logic  mem_we,
    input  data_t mem_rdata
);

  // Requests
  assign mem_addr  = PADDR;
  assign mem_wdata = PWDATA;
  assign mem_req   = PSEL && ~PENABLE; // This assumes that the timing is always all 0 -> only PSEL -> PSEL & PENABLE -> 0
  assign mem_we    = PWRITE;
  assign mem_strb  = PSTRB;

  // Responses
  // Memory never stalls but we need to deliver the data with 1 cycle latency.
  logic  pready_d, pready_q;
  // data_t rdata_d, rdata_q;
  assign pready_d = PSEL && ~PENABLE;
  assign rdata_d = mem_rdata;
  always_ff @(posedge clk_i) begin
    if (~rst_ni) begin
      // rdata_q <= '0;
      pready_q <= '0;
    end else begin
      // rdata_q <= rdata_d;
      pready_q <= pready_d;
    end
  end
  assign PREADY = pready_q;
  assign PRDATA = mem_rdata;
  assign PSLVERR = '0;

endmodule
