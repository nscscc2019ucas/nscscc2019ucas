`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2018/10/04 16:34:38
// Design Name: 
// Module Name: div
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


module div(
    input div_clk,
    input resetn,
    input div,
    input div_signed,
    input [31:0] x,
    input [31:0] y,
    output [31:0] s,
    output [31:0] r,
    output complete,
    input cancel
);

  reg [5:0] cnt;
  wire [5:0] cnt_next;
  reg [63:0] x_, y1, y2, y3;
  reg [31:0] quot; // quotient
  reg sign_s, sign_r;
  wire [63:0] y1_wire = {2'd0, (y[31]&&div_signed) ? ~y+1'b1 : y, 30'd0};
  wire [64:0] sub1_res = x_ - y1;
  wire [64:0] sub2_res = x_ - y2;
  wire [64:0] sub3_res = x_ - y3;
  wire working = cnt != 6'd0;

  assign cnt_next = cnt == 6'd17 || cancel ? 6'd0
                  : div ? 6'd1
                  : working ? cnt + 6'd1
                  : 6'd0;
  always @(posedge div_clk or negedge resetn) begin
    if (!resetn) cnt <= 6'd0;
    else cnt <= cnt_next;
  end

  always @(posedge div_clk or negedge resetn) begin
    if (!resetn) begin
      x_ <= 64'd0;
      y1 <= 64'd0;
      y2 <= 64'd0;
      y3 <= 64'd0;
      quot <= 32'd0;
      sign_s <= 1'b0;
      sign_r <= 1'b0;
    end
    else if (cnt_next == 6'd1) begin
      x_ <= {32'd0, (x[31]&&div_signed) ? ~x+1'b1 : x};
      y1 <= y1_wire;
      y2 <= y1_wire << 1;
      y3 <= y1_wire + (y1_wire << 1);
      sign_s <= (x[31]^y[31]) && div_signed;
      sign_r <= x[31] && div_signed;
    end
    else if (cnt != 6'd17) begin
      x_ <= !sub3_res[64] ? sub3_res[63:0]
          : !sub2_res[64] ? sub2_res[63:0]
          : !sub1_res[64] ? sub1_res[63:0]
          : x_;
      y1 <= y1 >> 2;
      y2 <= y2 >> 2;
      y3 <= y3 >> 2;
      quot <= (quot << 2) | {30'd0, !sub3_res[64] ? 2'd3 : !sub2_res[64] ? 2'd2 : !sub1_res[64] ? 2'd1 : 2'd0};
    end
  end

  assign s = sign_s ? ~quot+1'b1 : quot;
  assign r = sign_r ? ~x_[31:0]+1'b1 : x_[31:0];
  assign complete = cnt == 6'd17;

endmodule
