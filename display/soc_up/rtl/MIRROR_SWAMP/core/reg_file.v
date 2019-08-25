`timescale 10 ns / 1 ns

// register file for MIPS 32

module reg_file(
	input clk,
	input [4:0] waddr,
	input [4:0] raddr1,
	input [4:0] raddr2,
	input wen,
	input [31:0] wdata,
	output [31:0] rdata1,
	output [31:0] rdata2
);

  // registers (r0 excluded)
	reg [31:0] regs [31:1];

  // process read (r0 wired to 0)
	assign rdata1 = (raddr1 == 0 ? 0 : regs[raddr1]);
	assign rdata2 = (raddr2 == 0 ? 0 : regs[raddr2]);

  // process write
	always @(posedge clk) if (wen) regs[waddr] <= wdata;

endmodule
