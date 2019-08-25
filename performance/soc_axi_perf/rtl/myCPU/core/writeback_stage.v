`include "common.vh"

module writeback_stage(
    input                       clk,
    input                       resetn,

    // memory access interface
    input   [31:0]              data_rdata,
    input                       data_data_ok,

    // regfile interface
    output                      rf_wen,
    output  [4 :0]              rf_waddr,
    output  [31:0]              rf_wdata,

    output                      done_o,
    input                       valid_i,
    input   [31:0]              pc_i,
    input   [31:0]              inst_i,
    input   [`I_MAX-1:0]        ctrl_i,
    input   [31:0]              result_i,
    input   [31:0]              eaddr_i,
    input   [31:0]              rdata2_i,
    input   [4 :0]              waddr_i,
    
    output reg [31:0]           perfcnt_inst,
    output reg [31:0]           perfcnt_load,
    output reg [31:0]           perfcnt_store,
    output reg [31:0]           perfcnt_load_waitack,
    output reg [31:0]           perfcnt_store_waitack
);
    
    // process length & extension for read
    wire [1:0] mem_byte_offset = eaddr_i[1:0];
    wire [1:0] mem_byte_offsetn = ~mem_byte_offset;
    wire [7:0] mem_rdata_b = data_rdata >> (8 * mem_byte_offset);
    wire [15:0] mem_rdata_h = data_rdata >> (8 * mem_byte_offset);
    wire [31:0] mem_rdata_b_sx, mem_rdata_b_zx, mem_rdata_h_sx, mem_rdata_h_zx;
    assign mem_rdata_b_sx = {{24{mem_rdata_b[7]}}, mem_rdata_b};
    assign mem_rdata_b_zx = {24'd0, mem_rdata_b};
    assign mem_rdata_h_sx = {{16{mem_rdata_h[15]}}, mem_rdata_h};
    assign mem_rdata_h_zx = {16'd0, mem_rdata_h};
    
    wire [31:0] mem_rdata_b_res =
    {32{ctrl_i[`I_LB]}} & mem_rdata_b_sx |
    {32{ctrl_i[`I_LBU]}} & mem_rdata_b_zx;
    
    wire [31:0] mem_rdata_h_res =
    {32{ctrl_i[`I_LH]}} & mem_rdata_h_sx |
    {32{ctrl_i[`I_LHU]}} & mem_rdata_h_zx;
    
    // mem read mask
    wire [31:0] mem_rmask =
    {32{ctrl_i[`I_LW]||ctrl_i[`I_LH]||ctrl_i[`I_LHU]||ctrl_i[`I_LB]||ctrl_i[`I_LBU]}} & 32'hffffffff |
    {32{ctrl_i[`I_LWL]}} & (32'hffffffff << (8 * mem_byte_offsetn)) |
    {32{ctrl_i[`I_LWR]}} & (32'hffffffff >> (8 * mem_byte_offset));
    // mem read data
    wire [31:0] memdata = rdata2_i & ~mem_rmask |
    {32{ctrl_i[`I_LW]}} & data_rdata |
    {32{ctrl_i[`I_LH]||ctrl_i[`I_LHU]}} & mem_rdata_h_res |
    {32{ctrl_i[`I_LB]||ctrl_i[`I_LBU]}} & mem_rdata_b_res |
    {32{ctrl_i[`I_LWL]}} & (data_rdata << (8 * mem_byte_offsetn)) |
    {32{ctrl_i[`I_LWR]}} & (data_rdata >> (8 * mem_byte_offset));
    
    // TODO: reconsider the processing of data_data_ok
    //       are we sure that the load/store instruction is in WB when data_data_ok==1? (currently yes)
    assign done_o     = (ctrl_i[`I_MEM_R] || ctrl_i[`I_MEM_W]) && data_data_ok
                   || !(ctrl_i[`I_MEM_R] || ctrl_i[`I_MEM_W]);

    assign rf_wen   = valid_i && done_o && (ctrl_i[`I_WEX]||ctrl_i[`I_WWB]);
    assign rf_waddr = waddr_i;
    assign rf_wdata = ctrl_i[`I_MEM_R] ? memdata : result_i;
    
    // performance counters
    always @(posedge clk) begin
        // instruction count
        if (!resetn) perfcnt_inst <= 32'd0;
        else if (valid_i && done_o) perfcnt_inst <= perfcnt_inst + 32'd1;
        // load count
        if (!resetn) perfcnt_load <= 32'd0;
        else if (valid_i && done_o && ctrl_i[`I_MEM_R]) perfcnt_load <= perfcnt_load + 32'd1;
        // store count
        if (!resetn) perfcnt_store <= 32'd0;
        else if (valid_i && done_o && ctrl_i[`I_MEM_W]) perfcnt_store <= perfcnt_store + 32'd1;
        // stalled cycles for load ack
        if (!resetn) perfcnt_load_waitack <= 32'd0;
        else if (valid_i && !done_o && ctrl_i[`I_MEM_R]) perfcnt_load_waitack <= perfcnt_load_waitack + 32'd1;
        // stalled cycles for store ack
        if (!resetn) perfcnt_store_waitack <= 32'd0;
        else if (valid_i && !done_o && ctrl_i[`I_MEM_W]) perfcnt_store_waitack <= perfcnt_store_waitack + 32'd1;
    end

endmodule