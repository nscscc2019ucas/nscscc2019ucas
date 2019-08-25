`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2018/10/03 13:12:32
// Design Name: 
// Module Name: mul
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

// partial product generator for booth algorithm
module booth_gen #(
    parameter integer width = 32
)
(
    input [width-1:0] x,
    input [2:0] y,  // {y[i+1], y[i], y[i-1]}
    output [width-1:0] p,
    output c
);

  wire [width:0] x_ = {x, 1'b0};
  generate
    genvar i;
    for (i=0; i<width; i=i+1) begin
      assign p[i] = (y == 3'b001 || y == 3'b010) & x_[i+1]
                  | (y == 3'b101 || y == 3'b110) & ~x_[i+1]
                  | (y == 3'b011) & x_[i]
                  | (y == 3'b100) & ~x_[i];
    end
  endgenerate
  assign c = y == 3'b100 || y == 3'b101 || y == 3'b110;

endmodule

// 17-bit wallace tree unit
module wallace_unit_17(
    input [16:0] in,
    input [14:0] cin,
    output c,
    output out,
    output [14:0] cout
);

  wire [14:0] s;
  assign {cout[0], s[0]} = in[16] + in[15] + in[14];
  assign {cout[1], s[1]} = in[13] + in[12] + in[11];
  assign {cout[2], s[2]} = in[10] + in[9] + in[8];
  assign {cout[3], s[3]} = in[7] + in[6] + in[5];
  assign {cout[4], s[4]} = in[4] + in[3] + in[2];
  assign {cout[5], s[5]} = in[1] + in[0];
  assign {cout[6], s[6]} = s[0] + s[1] + s[2];
  assign {cout[7], s[7]} = s[3] + s[4] + s[5];
  assign {cout[8], s[8]} = cin[0] + cin[1] + cin[2];
  assign {cout[9], s[9]} = cin[3] + cin[4] + cin[5];
  assign {cout[10], s[10]} = s[6] + s[7] + s[8];
  assign {cout[11], s[11]} = s[9] + cin[6] + cin[7];
  assign {cout[12], s[12]} = s[10] + s[11] + cin[8];
  assign {cout[13], s[13]} = cin[9] + cin[10] + cin[11];
  assign {cout[14], s[14]} = s[12] + s[13] + cin[12];
  assign {c, out} = s[14] + cin[13] + cin[14];

endmodule

module mul(
    input mul_clk,
    input resetn,
    input mul_signed,
    input [31:0] x,
    input [31:0] y,
    output [63:0] result
);

  wire [63:0] x_ext = {{32{x[31] & mul_signed}}, x};
  wire [34:0] y_ext = {{2{y[31] & mul_signed}}, y, 1'b0};
  wire [63:0] part_prod [16:0];     // partial product
  wire [16:0] part_switch [63:0];   // switched partial product
  wire [16:0] part_carry;

  genvar i, j;
  generate
    for (i=0; i<17; i=i+1) begin
      booth_gen #(.width(64))
      part_mul(
        .x(x_ext << 2*i),
        .y(y_ext[(i+1)*2:i*2]),
        .p(part_prod[i]),
        .c(part_carry[i])
      );
      for (j=0; j<64; j=j+1) begin
        assign part_switch[j][i] = part_prod[i][j];
      end
    end
  endgenerate

  reg [16:0] part_switch_reg [63:0];
  reg [16:0] part_carry_reg;
  integer k;
  always @(posedge mul_clk) begin
    for (k=0; k<64; k=k+1) begin
      part_switch_reg[k] <= part_switch[k];
    end
    part_carry_reg <= part_carry;
  end

  wire [14:0] wallace_carry [64:0];
  assign wallace_carry[0] = part_carry_reg[14:0];
  wire [63:0] out_carry, out_sum;
  generate
    for (i=0; i<64; i=i+1) begin
      wallace_unit_17 u_wallace(
        .in(part_switch_reg[i]),
        .cin(wallace_carry[i]),
        .c(out_carry[i]),
        .out(out_sum[i]),
        .cout(wallace_carry[i+1])
      );
    end
  endgenerate
  
`ifdef MUL_BARRIER_2
  reg [63:0] add_a_reg, add_b_reg;
  reg add_cin_reg;
  
  always @(posedge mul_clk) begin
    add_a_reg <= {out_carry[62:0], part_carry_reg[15]};
    add_b_reg <= out_sum;
    add_cin_reg <= part_carry_reg[16];
  end
  
  assign result = add_a_reg + add_b_reg + add_cin_reg;
`else
  assign result = {out_carry[62:0], part_carry_reg[15]} + out_sum + part_carry_reg[16];
`endif

endmodule
