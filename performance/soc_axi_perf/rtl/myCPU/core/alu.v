`timescale 10 ns / 1 ns

`include "common.vh"

// ALU module
module alu(
  input [31:0] A,
  input [31:0] B,
  input [10:0] ALUop,
  output Overflow,
  output CarryOut,
  output Zero,
  output [31:0] Result
);

  // ALUop decoder
  wire alu_add    = ALUop[`ALU_ADD];
  wire alu_sub    = ALUop[`ALU_SUB];
  wire alu_and    = ALUop[`ALU_AND];
  wire alu_or     = ALUop[`ALU_OR];
  wire alu_xor    = ALUop[`ALU_XOR];
  wire alu_nor    = ALUop[`ALU_NOR];
  wire alu_slt    = ALUop[`ALU_SLT];
  wire alu_sltu   = ALUop[`ALU_SLTU];
  wire alu_sll    = ALUop[`ALU_SLL];
  wire alu_srl    = ALUop[`ALU_SRL];
  wire alu_sra    = ALUop[`ALU_SRA];

  // invert B for subtractions (sub & slt)
  wire invb = alu_sub | alu_slt | alu_sltu;
  // select addend according to invb
  wire [31:0] addend = invb ? (~B) : B;

  // carryout flag for addition
  wire cf;
  // result for addition and subtraction
  wire [31:0] add_sub_res;
  // do addition (invb as carryin in subtraction)
  assign {cf, add_sub_res} = A + addend + invb;
  // calculate overflow flag
  wire of = A[31] ^ addend[31] ^ cf ^ add_sub_res[31];

  // do and operation
  wire [31:0] and_res = A & B;
  // do or operation
  wire [31:0] or_res = A | B;
  // do xor operation
  wire [31:0] xor_res = A ^ B;
  // do nor operation
  wire [31:0] nor_res = ~or_res;
  // set slt/sltu result according to subtraction result
  wire [31:0] slt_res = (add_sub_res[31] ^ of) ? 1 : 0;
  wire [31:0] sltu_res = (!cf) ? 1 : 0;
  // do sll operation
  wire [31:0] sll_res = B << A[4:0];
  // do srl&sra operation
  wire [64:0] sr_res_64 = {{32{alu_sra&B[31]}}, B} >> A[4:0];
  wire [31:0] sr_res = sr_res_64[31:0]; 

  // result muxer
  wire [31:0] res =
    {32{alu_and}} & and_res |
    {32{alu_or}} & or_res |
    {32{alu_xor}} & xor_res |
    {32{alu_nor}} & nor_res |
    {32{alu_add}} & add_sub_res |
    {32{alu_sub}} & add_sub_res |
    {32{alu_slt}} & slt_res |
    {32{alu_sltu}} & sltu_res |
    {32{alu_sll}} & sll_res |
    {32{alu_srl}} & sr_res |
    {32{alu_sra}} & sr_res;

  // set zero flag
  wire zf = (res == 0);

  // output results
  assign Overflow = of;
  assign CarryOut = cf ^ invb;
  assign Zero = zf;
  assign Result = res;
  
endmodule
