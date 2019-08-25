`timescale 1ns / 1ps
module icache_data
(
    input          clk,
    input          rst,
    input          en,
    input          wen,
    input   [31:0] wdata,
    input   [31:0] addr,
    output  [31:0] rdata
);

icache_data_ram icache_data_ram_u
(
    .clka  (clk            ),   
//    .rsta   (rst        ),
    .ena   (en        ),
    .wea   (wen       ),   //3:0 //TBD
    .addra (addr[11:5]),   //17:0
    .dina  (wdata     ),   //31:0
    .douta (rdata     )    //31:0
);

//wire [31:0]data_out;

//icache_data_ram2 icache_data_ram_u
//(
//    .clk  (clk            ),   
////    .rsta   (rst        ),
//    .we   (wen       ),   //3:0 //TBD
//    .a (addr[11:5]),   //17:0
//    .d  (wdata     ),   //31:0
//    .spo (data_out     )    //31:0
//);
 
//reg [31:0]rdata_data;
//always@(posedge clk)
//begin
//    if(rst)
//    begin
//        rdata_data <= 32'b0;
//    end
//    else if(wen)
//    begin
//        rdata_data <= wdata;
//    end
//    else
//    begin
//        rdata_data <=data_out;
//    end
//end
//assign rdata = rdata_data;

endmodule
