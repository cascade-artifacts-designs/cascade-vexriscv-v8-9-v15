module memreq_aligner #(
  parameter int unsigned AddrSize = 32,
  parameter int unsigned DataSize = 64,
  parameter int unsigned AlignmentBytes = 8,

  localparam type data_t = logic[DataSize-1:0],
  localparam type strb_t = logic[(DataSize >> 3)-1:0],
  localparam type addr_t = logic[AddrSize-1:0],

  localparam int unsigned LOG2_AlignmentBytes = $clog2(AlignmentBytes)
) (
  input logic clk_i,

  input   logic  mem_req_misaligned,
  output  logic  mem_gnt_misaligned,
  input   addr_t mem_addr_misaligned,
  input   data_t mem_wdata_misaligned,
  input   strb_t mem_strb_misaligned,
  input   logic  mem_we_misaligned,
  output  data_t mem_rdata_misaligned,

  output  logic  mem_req_aligned,
  input   logic  mem_gnt_aligned,
  output  addr_t mem_addr_aligned,
  output  data_t mem_wdata_aligned,
  output  strb_t mem_strb_aligned,
  output  logic  mem_we_aligned,
  input   data_t mem_rdata_aligned
);
  // function automatic data_t gen_align_mask(input logic [LOG2_AlignmentBytes-1:0] shift_offset);
  //   data_t ret = '1;
  //   for (int i = 0; i < LOG2_AlignmentBytes; i++) begin
  //     ret[i] = 0;
  //   end
  // endfunction

  // Determine by how bits the address should be shifted
  logic [LOG2_AlignmentBytes-1:0] shift_offset;
  assign shift_offset = mem_addr_misaligned[LOG2_AlignmentBytes-1:0];
  // Align the mask
  data_t alignment_mask;
  assign alignment_mask = {{(32-LOG2_AlignmentBytes){1'b1}}, {LOG2_AlignmentBytes{1'b0}}};

  assign mem_addr_aligned = mem_addr_misaligned & alignment_mask;
  assign mem_strb_aligned = mem_strb_misaligned; //  << shift_offset;

  assign mem_req_aligned = mem_req_misaligned;
  assign mem_wdata_aligned = mem_wdata_misaligned << (shift_offset << 3);
  assign mem_we_aligned = mem_we_misaligned;

  assign mem_gnt_misaligned = mem_gnt_aligned;
  assign mem_rdata_misaligned = mem_rdata_aligned >> (shift_offset << 3);

  ///////
  // Assertions
  ///////

  // The request is expected to never be misaligned
  assert property (@(posedge clk_i) shift_offset);
  // Check that we do not shift too much
  assert property (@(posedge clk_i) shift_offset < LOG2_AlignmentBytes);
  // Check that the alignment mask is roughly correct
  assert property (@(posedge clk_i) alignment_mask[LOG2_AlignmentBytes] == 1'b1);
  assert property (@(posedge clk_i) alignment_mask[LOG2_AlignmentBytes-1] == 1'b0);
  // Check that the number of bits in the strobe never gets reduced
  assert property (@(posedge clk_i) $countones(mem_strb_aligned) == $countones(mem_strb_misaligned));

endmodule
