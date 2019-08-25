`timescale 1ns / 1ps
module dcache_data
(
    input          clk,
    input          rst,
    input          en,
    input   [3:0] wen,
    input   [31:0] wdata,
    input   [31:0] addr,
    output  [31:0] rdata
);

dcache_data_ram dcache_data_ram_u
(
    .clka  (clk            ),   
//    .rsta   (rst        ),
    .ena   (en        ),
    .wea   (wen       ),   //3:0 //TBD
    .addra (addr[12:5]),   //17:0
    .dina  (wdata     ),   //31:0
    .douta (rdata     )    //31:0
);


endmodule