`timescale 1ns / 1ps
module dcache_tag
(
    input          clk,
    input          rst,
    input          en,
    input          wen,
    input   [20:0] wdata,
    output  [20:0] rdata,

    input   [31:0] addr,        //input desired address to check whether hit
    output         hit,         //whether hit?
    output         valid,
    output         work,
    input          op
    // input   [6:0]  op_addr,
    // input   [20:0] op_wdata
);

reg [31:0] addr_reg;
always @(posedge clk)
	begin
		if(rst)
		begin
			addr_reg <= 32'b0;
		end
		else
		begin
			addr_reg <= addr;
		end
	end

assign valid = rdata[20];

// `ifdef THIS_IS_THE_OLD_IMPLEMENTATION

// assign hit = (rdata[19:0] == addr_reg[31:12]) ? 1'b1 : 1'b0;

// icache_tag_ram icache_tag_ram_u
// (
//     .clka  (clk            ),   
// //    .rsta   (rst        ),
//     .ena   (en        ),
//     .wea   (wen       ),   //3:0 //TBD
//     .addra (addr[11:5]),   //17:0
//     .dina  (wdata     ),   //31:0
//     .douta (rdata     )    //31:0
// );

// `else

reg [6:0] reset_counter;
wire work_state;
reg work_reg;
always @(posedge clk)
begin
    if(rst)
    begin
        reset_counter <= 7'd0;
    end
    else if(reset_counter != 7'd127)
    begin
        reset_counter <= reset_counter + 7'd1;
    end
end
assign work_state = (reset_counter == 7'd127) ? 1'b1 : 1'b0;
always @(posedge clk)
begin
    if(rst)
    begin
        work_reg <= 1'd0;
    end
    else
    begin
        work_reg <= work_state;
    end
end
assign work = work_reg;
// assign work = 1'b1;

reg [20:0] tag_ram [127:0];
reg [20:0] tag_reg;

integer i;
initial begin
for (i=0;i<128;i=i+1) tag_ram[i] <= 21'd0;
end

always @(posedge clk)
begin
    if (!work) tag_ram[reset_counter] <= 21'b0;
    // else if (op)  tag_ram[op_addr] <= op_wdata;
    else if (wen || op) tag_ram[addr[11:5]] <= wdata;
end

wire [20:0] tag_out = tag_ram[addr[11:5]];
always @(posedge clk) tag_reg <= tag_out;
assign rdata = tag_reg;

//reg hit_reg;
//always @(posedge clk) hit_reg <= tag_out[19:0] == addr[31:12];
//assign hit = hit_reg;
assign hit = (tag_reg[19:0] == addr_reg[31:12]) ? 1'b1 : 1'b0;
// `endif


endmodule