`timescale 1ns / 1ps
module dcache
(
    ////basic
    input         clk,
    input         resetn,

	input		  cache_req,
	input	[6:0] cache_op,
	input   [31:0]cache_tag,
	output		  cache_op_ok,

    ////axi_control
    //ar
    output  [3 :0] arid   ,
    output  [31:0] araddr,
    output  [7 :0] arlen  ,
    output  [2 :0] arsize ,
    output  [1 :0] arburst,
    output  [1 :0] arlock ,
    output  [3 :0] arcache,
    output  [2 :0] arprot ,
    output         arvalid,
    input          arready,
    //r
    input [3 :0] rid    ,
    input [31:0] rdata  ,
    input [1 :0] rresp ,
    input        rlast ,
    input        rvalid ,
    output       rready ,
    //aw
    output  [3 :0] awid   ,
    output  [31:0] awaddr ,
    output  [7 :0] awlen  ,
    output  [2 :0] awsize ,
    output  [1 :0] awburst,
    output  [1 :0] awlock ,
    output  [3 :0] awcache,
    output  [2 :0] awprot ,
    output         awvalid,
    input          awready,
    //w
    output  [3 :0] wid    ,
    output  [31:0] wdata  ,
    output  [3 :0] wstrb  ,
    output         wlast  ,
    output         wvalid ,
    input          wready ,
    //b
    input [3 :0] bid    ,
    input [1 :0] bresp  ,
    input        bvalid ,
    output       bready ,

    ////cpu_control
    //------inst sram-like-------
    input          data_req    ,
    input          data_wr     ,
    input   [3: 0] req_id      ,
    input   [1 :0] data_size   ,
    input   [31:0] data_addr   ,
    input   [31:0] data_wdata  ,
	input   [3 :0] data_wstrb  ,
    output  [31:0] data_rdata  ,
    output         data_addr_ok,
    output         data_data_ok,
    output  [3: 0] data_id

);

wire rst;
assign rst = !resetn;

////hit and valid
//hit
wire   	continue_sw = (work_state == 4'b0111) && data_wr && data_req;
wire    hit_0;
wire    hit_1;
wire    valid_0;
wire    valid_1;
wire 	tag_0_en;
wire    tag_1_en;
wire    [31:0] ram_wdata;

wire    [31:0] data_addr_input;
wire    [31:0] tag_addr_input;
wire    [20:0] tag_wdata_input;
wire 	tag_0_en_input;
wire    tag_1_en_input;
assign  tag_addr_input 	= (((work_state == 4'b0000) || continue_sw) ? data_addr : data_addr_reg);
assign  data_addr_input = ((work_state == 4'b0000) ? data_addr : data_addr_reg);
assign  tag_wdata_input = (work_state == 4'b1111) ? 21'b0 : {1'b1,tag_addr_input[31:12]};
// assign  tag_0_en_input  = (work_state = 4'b1111) ? ((op_workstate == 4'd3) && !op_way) : tag_0_en;
// assign  tag_1_en_input  = (work_state = 4'b1111) ? ((op_workstate == 4'd3) && op_way) : tag_1_en;

wire [20:0]   tag_rdata_0;
wire [20:0]   tag_rdata_1;
wire [20:0]   tag_rdata;
wire cache_work_0;
wire cache_work_1;
wire op_0;
wire op_1;

dcache_tag tag_0(clk,rst,1'b1,tag_0_en,tag_wdata_input,tag_rdata_0,tag_addr_input,hit_0,valid_0,cache_work_0,op_0);
dcache_tag tag_1(clk,rst,1'b1,tag_1_en,tag_wdata_input,tag_rdata_1,tag_addr_input,hit_1,valid_1,cache_work_1,op_1);

wire    hit;
assign  hit = hit_0 | hit_1;

//valid
wire    succeed_0;
wire    succeed_1;
wire    succeed;

assign succeed_0    = hit_0 & valid_0; //if hit and  if valid
assign succeed_1    = hit_1 & valid_1;
assign succeed      = succeed_0 | succeed_1;


////data access
wire    [19:0] tag;
wire    [6:0]  index;
wire    [4:0]  offset;

reg   [3 :0] data_wstrb_reg; 
wire  [3 :0] data_wstrb_input;

assign  data_wstrb_input = ((work_state == 4'b0011) || (work_state == 4'b1001) || (work_state == 4'b1000)) ? 4'b1111 : data_wstrb_reg;

assign  tag     = data_addr_reg[31:12];
assign  index   = data_addr_reg[11:5];
assign  offset  = data_addr_reg[4:0];

wire 	[31:0] ram_wen;

wire	[31:0] ram_wdata_way_0_data_0;
wire	[31:0] ram_wdata_way_0_data_1;
wire	[31:0] ram_wdata_way_0_data_2;
wire	[31:0] ram_wdata_way_0_data_3;
wire	[31:0] ram_wdata_way_0_data_4;
wire	[31:0] ram_wdata_way_0_data_5;
wire	[31:0] ram_wdata_way_0_data_6;
wire	[31:0] ram_wdata_way_0_data_7;

wire	[31:0] ram_wdata_way_1_data_0;
wire	[31:0] ram_wdata_way_1_data_1;
wire	[31:0] ram_wdata_way_1_data_2;
wire	[31:0] ram_wdata_way_1_data_3;
wire	[31:0] ram_wdata_way_1_data_4;
wire	[31:0] ram_wdata_way_1_data_5;
wire	[31:0] ram_wdata_way_1_data_6;
wire	[31:0] ram_wdata_way_1_data_7;


wire 	ram_en_way_0_bank_0;
wire 	ram_en_way_0_bank_1;
wire 	ram_en_way_0_bank_2;
wire 	ram_en_way_0_bank_3;
wire 	ram_en_way_0_bank_4;
wire 	ram_en_way_0_bank_5;
wire 	ram_en_way_0_bank_6;
wire 	ram_en_way_0_bank_7;

wire 	ram_en_way_1_bank_0;
wire 	ram_en_way_1_bank_1;
wire 	ram_en_way_1_bank_2;
wire 	ram_en_way_1_bank_3;
wire 	ram_en_way_1_bank_4;
wire 	ram_en_way_1_bank_5;
wire 	ram_en_way_1_bank_6;
wire 	ram_en_way_1_bank_7;

wire 	ram_wen_way_0_bank_0;
wire 	ram_wen_way_0_bank_1;
wire 	ram_wen_way_0_bank_2;
wire 	ram_wen_way_0_bank_3;
wire 	ram_wen_way_0_bank_4;
wire 	ram_wen_way_0_bank_5;
wire 	ram_wen_way_0_bank_6;
wire 	ram_wen_way_0_bank_7;

wire 	ram_wen_way_1_bank_0;
wire 	ram_wen_way_1_bank_1;
wire 	ram_wen_way_1_bank_2;
wire 	ram_wen_way_1_bank_3;
wire 	ram_wen_way_1_bank_4;
wire 	ram_wen_way_1_bank_5;
wire 	ram_wen_way_1_bank_6;
wire 	ram_wen_way_1_bank_7;

wire 	ram_wen_way_0_bank_0_normal;
wire 	ram_wen_way_0_bank_1_normal;
wire 	ram_wen_way_0_bank_2_normal;
wire 	ram_wen_way_0_bank_3_normal;
wire 	ram_wen_way_0_bank_4_normal;
wire 	ram_wen_way_0_bank_5_normal;
wire 	ram_wen_way_0_bank_6_normal;
wire 	ram_wen_way_0_bank_7_normal;

wire 	ram_wen_way_1_bank_0_normal;
wire 	ram_wen_way_1_bank_1_normal;
wire 	ram_wen_way_1_bank_2_normal;
wire 	ram_wen_way_1_bank_3_normal;
wire 	ram_wen_way_1_bank_4_normal;
wire 	ram_wen_way_1_bank_5_normal;
wire 	ram_wen_way_1_bank_6_normal;
wire 	ram_wen_way_1_bank_7_normal;

wire 	ram_wen_way_0_bank_0_input;
wire 	ram_wen_way_0_bank_1_input;
wire 	ram_wen_way_0_bank_2_input;
wire 	ram_wen_way_0_bank_3_input;
wire 	ram_wen_way_0_bank_4_input;
wire 	ram_wen_way_0_bank_5_input;
wire 	ram_wen_way_0_bank_6_input;
wire 	ram_wen_way_0_bank_7_input;

wire 	ram_wen_way_1_bank_0_input;
wire 	ram_wen_way_1_bank_1_input;
wire 	ram_wen_way_1_bank_2_input;
wire 	ram_wen_way_1_bank_3_input;
wire 	ram_wen_way_1_bank_4_input;
wire 	ram_wen_way_1_bank_5_input;
wire 	ram_wen_way_1_bank_6_input;
wire 	ram_wen_way_1_bank_7_input;

wire 	ram_wstrb_way_0_bank_0;
wire 	ram_wstrb_way_0_bank_1;
wire 	ram_wstrb_way_0_bank_2;
wire 	ram_wstrb_way_0_bank_3;
wire 	ram_wstrb_way_0_bank_4;
wire 	ram_wstrb_way_0_bank_5;
wire 	ram_wstrb_way_0_bank_6;
wire 	ram_wstrb_way_0_bank_7;

wire 	ram_wstrb_way_1_bank_0;
wire 	ram_wstrb_way_1_bank_1;
wire 	ram_wstrb_way_1_bank_2;
wire 	ram_wstrb_way_1_bank_3;
wire 	ram_wstrb_way_1_bank_4;
wire 	ram_wstrb_way_1_bank_5;
wire 	ram_wstrb_way_1_bank_6;
wire 	ram_wstrb_way_1_bank_7;

wire    [31:0] rdata_0;
wire    [31:0] rdata_1;
wire    [31:0] rdata_2;
wire    [31:0] rdata_3;
wire    [31:0] rdata_4;
wire    [31:0] rdata_5;
wire    [31:0] rdata_6;
wire    [31:0] rdata_7;

wire    [31:0] way_0_rdata_0;
wire    [31:0] way_0_rdata_1;
wire    [31:0] way_0_rdata_2;
wire    [31:0] way_0_rdata_3;
wire    [31:0] way_0_rdata_4;
wire    [31:0] way_0_rdata_5;
wire    [31:0] way_0_rdata_6;
wire    [31:0] way_0_rdata_7;

wire    [31:0] way_1_rdata_0;
wire    [31:0] way_1_rdata_1;
wire    [31:0] way_1_rdata_2;
wire    [31:0] way_1_rdata_3;
wire    [31:0] way_1_rdata_4;
wire    [31:0] way_1_rdata_5;
wire    [31:0] way_1_rdata_6;
wire    [31:0] way_1_rdata_7;

dcache_data way_0_data_0(clk,rst,1'b1,({4{ram_wen_way_0_bank_0_input}} & data_wstrb_input),ram_wdata,data_addr_input,way_0_rdata_0);
dcache_data way_0_data_1(clk,rst,1'b1,({4{ram_wen_way_0_bank_1_input}} & data_wstrb_input),ram_wdata,data_addr_input,way_0_rdata_1);
dcache_data way_0_data_2(clk,rst,1'b1,({4{ram_wen_way_0_bank_2_input}} & data_wstrb_input),ram_wdata,data_addr_input,way_0_rdata_2);
dcache_data way_0_data_3(clk,rst,1'b1,({4{ram_wen_way_0_bank_3_input}} & data_wstrb_input),ram_wdata,data_addr_input,way_0_rdata_3);
dcache_data way_0_data_4(clk,rst,1'b1,({4{ram_wen_way_0_bank_4_input}} & data_wstrb_input),ram_wdata,data_addr_input,way_0_rdata_4);
dcache_data way_0_data_5(clk,rst,1'b1,({4{ram_wen_way_0_bank_5_input}} & data_wstrb_input),ram_wdata,data_addr_input,way_0_rdata_5);
dcache_data way_0_data_6(clk,rst,1'b1,({4{ram_wen_way_0_bank_6_input}} & data_wstrb_input),ram_wdata,data_addr_input,way_0_rdata_6);
dcache_data way_0_data_7(clk,rst,1'b1,({4{ram_wen_way_0_bank_7_input}} & data_wstrb_input),ram_wdata,data_addr_input,way_0_rdata_7);

dcache_data way_1_data_0(clk,rst,1'b1,({4{ram_wen_way_1_bank_0_input}} & data_wstrb_input),ram_wdata,data_addr_input,way_1_rdata_0);
dcache_data way_1_data_1(clk,rst,1'b1,({4{ram_wen_way_1_bank_1_input}} & data_wstrb_input),ram_wdata,data_addr_input,way_1_rdata_1);
dcache_data way_1_data_2(clk,rst,1'b1,({4{ram_wen_way_1_bank_2_input}} & data_wstrb_input),ram_wdata,data_addr_input,way_1_rdata_2);
dcache_data way_1_data_3(clk,rst,1'b1,({4{ram_wen_way_1_bank_3_input}} & data_wstrb_input),ram_wdata,data_addr_input,way_1_rdata_3);
dcache_data way_1_data_4(clk,rst,1'b1,({4{ram_wen_way_1_bank_4_input}} & data_wstrb_input),ram_wdata,data_addr_input,way_1_rdata_4);
dcache_data way_1_data_5(clk,rst,1'b1,({4{ram_wen_way_1_bank_5_input}} & data_wstrb_input),ram_wdata,data_addr_input,way_1_rdata_5);
dcache_data way_1_data_6(clk,rst,1'b1,({4{ram_wen_way_1_bank_6_input}} & data_wstrb_input),ram_wdata,data_addr_input,way_1_rdata_6);
dcache_data way_1_data_7(clk,rst,1'b1,({4{ram_wen_way_1_bank_7_input}} & data_wstrb_input),ram_wdata,data_addr_input,way_1_rdata_7);

assign rdata_0 = succeed_0 ? way_0_rdata_0 : way_1_rdata_0;
assign rdata_1 = succeed_0 ? way_0_rdata_1 : way_1_rdata_1;
assign rdata_2 = succeed_0 ? way_0_rdata_2 : way_1_rdata_2;
assign rdata_3 = succeed_0 ? way_0_rdata_3 : way_1_rdata_3;
assign rdata_4 = succeed_0 ? way_0_rdata_4 : way_1_rdata_4;
assign rdata_5 = succeed_0 ? way_0_rdata_5 : way_1_rdata_5;
assign rdata_6 = succeed_0 ? way_0_rdata_6 : way_1_rdata_6;
assign rdata_7 = succeed_0 ? way_0_rdata_7 : way_1_rdata_7;

wire    [31:0] cache_rdata;
assign cache_rdata =  	(({32{offset[4:2] == 3'd0}}) & rdata_0) |
						(({32{offset[4:2] == 3'd1}}) & rdata_1) |
						(({32{offset[4:2] == 3'd2}}) & rdata_2) |
						(({32{offset[4:2] == 3'd3}}) & rdata_3) |
						(({32{offset[4:2] == 3'd4}}) & rdata_4) |
						(({32{offset[4:2] == 3'd5}}) & rdata_5) |
						(({32{offset[4:2] == 3'd6}}) & rdata_6) |
						(({32{offset[4:2] == 3'd7}}) & rdata_7);

wire [31:0] rdata_0_write_back;
wire [31:0] rdata_1_write_back;
wire [31:0] rdata_2_write_back;
wire [31:0] rdata_3_write_back;
wire [31:0] rdata_4_write_back;
wire [31:0] rdata_5_write_back;
wire [31:0] rdata_6_write_back;
wire [31:0] rdata_7_write_back;

assign rdata_0_write_back = way_choose ? way_1_rdata_0 : way_0_rdata_0;
assign rdata_1_write_back = way_choose ? way_1_rdata_1 : way_0_rdata_1;
assign rdata_2_write_back = way_choose ? way_1_rdata_2 : way_0_rdata_2;
assign rdata_3_write_back = way_choose ? way_1_rdata_3 : way_0_rdata_3;
assign rdata_4_write_back = way_choose ? way_1_rdata_4 : way_0_rdata_4;
assign rdata_5_write_back = way_choose ? way_1_rdata_5 : way_0_rdata_5;
assign rdata_6_write_back = way_choose ? way_1_rdata_6 : way_0_rdata_6;
assign rdata_7_write_back = way_choose ? way_1_rdata_7 : way_0_rdata_7;

wire [2:0] pick = offset[4:2]; //idle

////replace
//info store
reg          data_req_reg    ;
reg          data_wr_reg     ;
reg   [1 :0] data_size_reg   ;
reg   [31:0] data_addr_reg   ;
reg   [31:0] data_wdata_reg  ;
reg   [3: 0] data_id_reg     ;

always @(posedge clk)
	begin
		if(rst)
		begin
			data_req_reg <= 1'b0;
		end
		else if(((work_state == 4'b0000) || continue_sw) && data_addr_ok)
		begin
			data_req_reg <= data_req;
		end
        else if(data_data_ok) // if axi ack addr, stop requiring //TBD
		begin
			data_req_reg <= 1'b0;
		end
	end

always @(posedge clk)
	begin
		if(rst)
		begin
			data_wr_reg <= 1'b0;
		end
		else if(((work_state == 4'b0000) || continue_sw) & data_addr_ok)
		begin
			data_wr_reg <= data_wr;
		end
		else if((work_state == 4'd6) || ((work_state == 4'd7) && data_data_ok))
		begin
			data_wr_reg <= 1'b0;
		end
	end

always @(posedge clk)
	begin
		if(rst)
		begin
			data_size_reg <= 2'b0;
		end
		else if(((work_state == 4'b0000) || continue_sw) & data_addr_ok)
		begin
			data_size_reg <= data_size;
		end
	end

always @(posedge clk)
	begin
		if(rst)
		begin
			data_wstrb_reg <= 4'b0;
		end
		else if(((work_state == 4'b0000) || continue_sw) & data_addr_ok)
		begin
			data_wstrb_reg <= data_wstrb;
		end
	end

always @(posedge clk)
	begin
		if(rst)
		begin
			data_addr_reg <= 32'b0;
		end
		else if((((work_state == 4'b0000) || continue_sw) & data_addr_ok) || ((work_state == 4'b1111) && (op_workstate == 4'd0) && cache_req))
		begin
			data_addr_reg <= data_addr;
		end
	end

always @(posedge clk)
	begin
		if(rst)
		begin
			data_wdata_reg <= 32'b0;
		end
		else if(((work_state == 4'b0000) || continue_sw) & data_addr_ok)
		begin
			data_wdata_reg <= data_wdata;
		end
	end


//replace
wire replace_mode_tag;
wire replace_mode_data;

assign replace_mode_tag  = (work_state == 4'b0011) || (work_state == 4'b1001) || (work_state == 4'b1000);
assign replace_mode_data = replace_mode_tag;

wire way_choose = !lru[index];

/*data bank*/
assign ram_wdata =  ((work_state == 4'b0011) || (work_state == 4'b1001) || (work_state == 4'b1000)) ? rdata : data_wdata_reg;

// assign ram_wdata_way_0_data_0 = ((data_wr_reg && (offset == 3'd0)) || data_wr) ? wdata : rdata;
// assign ram_wdata_way_0_data_1 = ((data_wr_reg && (offset == 3'd1)) || data_wr) ? wdata : rdata;
// assign ram_wdata_way_0_data_2 = ((data_wr_reg && (offset == 3'd2)) || data_wr) ? wdata : rdata;
// assign ram_wdata_way_0_data_3 = ((data_wr_reg && (offset == 3'd3)) || data_wr) ? wdata : rdata;
// assign ram_wdata_way_0_data_4 = ((data_wr_reg && (offset == 3'd4)) || data_wr) ? wdata : rdata;
// assign ram_wdata_way_0_data_5 = ((data_wr_reg && (offset == 3'd5)) || data_wr) ? wdata : rdata;
// assign ram_wdata_way_0_data_6 = ((data_wr_reg && (offset == 3'd6)) || data_wr) ? wdata : rdata;
// assign ram_wdata_way_0_data_7 = ((data_wr_reg && (offset == 3'd7)) || data_wr) ? wdata : rdata;

// assign ram_wdata_way_1_data_0 = ((data_wr_reg && (offset == 3'd0)) || data_wr) ? wdata : rdata;
// assign ram_wdata_way_1_data_1 = ((data_wr_reg && (offset == 3'd1)) || data_wr) ? wdata : rdata;
// assign ram_wdata_way_1_data_2 = ((data_wr_reg && (offset == 3'd2)) || data_wr) ? wdata : rdata;
// assign ram_wdata_way_1_data_3 = ((data_wr_reg && (offset == 3'd3)) || data_wr) ? wdata : rdata;
// assign ram_wdata_way_1_data_4 = ((data_wr_reg && (offset == 3'd4)) || data_wr) ? wdata : rdata;
// assign ram_wdata_way_1_data_5 = ((data_wr_reg && (offset == 3'd5)) || data_wr) ? wdata : rdata;
// assign ram_wdata_way_1_data_6 = ((data_wr_reg && (offset == 3'd6)) || data_wr) ? wdata : rdata;
// assign ram_wdata_way_1_data_7 = ((data_wr_reg && (offset == 3'd7)) || data_wr) ? wdata : rdata;

reg	[2:0] target_bank_read;
always @(posedge clk)
	begin
		if(rst)
		begin
			target_bank_read <= 3'd0;
		end
		else if(work_state == 4'b0001)
		begin
			target_bank_read <= offset[4:2];
		end
		else if(((work_state == 4'b0011) || (work_state == 4'b1001) || (work_state == 4'b1000)) && rvalid && (rid == 4'd1))
		begin
			target_bank_read <= target_bank_read + 3'd1;
		end		
	end

assign ram_en_way_0_bank_0 = replace_mode_data ? (way_choose ? 1'b0 : ((target_bank_read == 3'd0) && rvalid)) : 1'b0;
assign ram_en_way_0_bank_1 = replace_mode_data ? (way_choose ? 1'b0 : ((target_bank_read == 3'd1) && rvalid)) : 1'b0;
assign ram_en_way_0_bank_2 = replace_mode_data ? (way_choose ? 1'b0 : ((target_bank_read == 3'd2) && rvalid)) : 1'b0;
assign ram_en_way_0_bank_3 = replace_mode_data ? (way_choose ? 1'b0 : ((target_bank_read == 3'd3) && rvalid)) : 1'b0;
assign ram_en_way_0_bank_4 = replace_mode_data ? (way_choose ? 1'b0 : ((target_bank_read == 3'd4) && rvalid)) : 1'b0;
assign ram_en_way_0_bank_5 = replace_mode_data ? (way_choose ? 1'b0 : ((target_bank_read == 3'd5) && rvalid)) : 1'b0;
assign ram_en_way_0_bank_6 = replace_mode_data ? (way_choose ? 1'b0 : ((target_bank_read == 3'd6) && rvalid)) : 1'b0;
assign ram_en_way_0_bank_7 = replace_mode_data ? (way_choose ? 1'b0 : ((target_bank_read == 3'd7) && rvalid)) : 1'b0;

assign ram_en_way_1_bank_0 = replace_mode_data ? (way_choose ? ((target_bank_read == 3'd0) && rvalid) : 1'b0) : 1'b0;
assign ram_en_way_1_bank_1 = replace_mode_data ? (way_choose ? ((target_bank_read == 3'd1) && rvalid) : 1'b0) : 1'b0;
assign ram_en_way_1_bank_2 = replace_mode_data ? (way_choose ? ((target_bank_read == 3'd2) && rvalid) : 1'b0) : 1'b0;
assign ram_en_way_1_bank_3 = replace_mode_data ? (way_choose ? ((target_bank_read == 3'd3) && rvalid) : 1'b0) : 1'b0;
assign ram_en_way_1_bank_4 = replace_mode_data ? (way_choose ? ((target_bank_read == 3'd4) && rvalid) : 1'b0) : 1'b0;
assign ram_en_way_1_bank_5 = replace_mode_data ? (way_choose ? ((target_bank_read == 3'd5) && rvalid) : 1'b0) : 1'b0;
assign ram_en_way_1_bank_6 = replace_mode_data ? (way_choose ? ((target_bank_read == 3'd6) && rvalid) : 1'b0) : 1'b0;
assign ram_en_way_1_bank_7 = replace_mode_data ? (way_choose ? ((target_bank_read == 3'd7) && rvalid) : 1'b0) : 1'b0;

assign	ram_wen_way_0_bank_0 = ((work_state == 4'b0110)) ? (way_choose ? 1'b0 : ((offset[4:2] == 3'd0) ? 1'b1 : 1'b0)) : 1'b0;
assign	ram_wen_way_0_bank_1 = ((work_state == 4'b0110)) ? (way_choose ? 1'b0 : ((offset[4:2] == 3'd1) ? 1'b1 : 1'b0)) : 1'b0;
assign	ram_wen_way_0_bank_2 = ((work_state == 4'b0110)) ? (way_choose ? 1'b0 : ((offset[4:2] == 3'd2) ? 1'b1 : 1'b0)) : 1'b0;
assign	ram_wen_way_0_bank_3 = ((work_state == 4'b0110)) ? (way_choose ? 1'b0 : ((offset[4:2] == 3'd3) ? 1'b1 : 1'b0)) : 1'b0;
assign	ram_wen_way_0_bank_4 = ((work_state == 4'b0110)) ? (way_choose ? 1'b0 : ((offset[4:2] == 3'd4) ? 1'b1 : 1'b0)) : 1'b0;
assign	ram_wen_way_0_bank_5 = ((work_state == 4'b0110)) ? (way_choose ? 1'b0 : ((offset[4:2] == 3'd5) ? 1'b1 : 1'b0)) : 1'b0;
assign	ram_wen_way_0_bank_6 = ((work_state == 4'b0110)) ? (way_choose ? 1'b0 : ((offset[4:2] == 3'd6) ? 1'b1 : 1'b0)) : 1'b0;
assign	ram_wen_way_0_bank_7 = ((work_state == 4'b0110)) ? (way_choose ? 1'b0 : ((offset[4:2] == 3'd7) ? 1'b1 : 1'b0)) : 1'b0;

assign	ram_wen_way_1_bank_0 = ((work_state == 4'b0110)) ? (way_choose ? ((offset[4:2] == 3'd0) ? 1'b1 : 1'b0) : 1'b0) : 1'b0;
assign	ram_wen_way_1_bank_1 = ((work_state == 4'b0110)) ? (way_choose ? ((offset[4:2] == 3'd1) ? 1'b1 : 1'b0) : 1'b0) : 1'b0;
assign	ram_wen_way_1_bank_2 = ((work_state == 4'b0110)) ? (way_choose ? ((offset[4:2] == 3'd2) ? 1'b1 : 1'b0) : 1'b0) : 1'b0;
assign	ram_wen_way_1_bank_3 = ((work_state == 4'b0110)) ? (way_choose ? ((offset[4:2] == 3'd3) ? 1'b1 : 1'b0) : 1'b0) : 1'b0;
assign	ram_wen_way_1_bank_4 = ((work_state == 4'b0110)) ? (way_choose ? ((offset[4:2] == 3'd4) ? 1'b1 : 1'b0) : 1'b0) : 1'b0;
assign	ram_wen_way_1_bank_5 = ((work_state == 4'b0110)) ? (way_choose ? ((offset[4:2] == 3'd5) ? 1'b1 : 1'b0) : 1'b0) : 1'b0;
assign	ram_wen_way_1_bank_6 = ((work_state == 4'b0110)) ? (way_choose ? ((offset[4:2] == 3'd6) ? 1'b1 : 1'b0) : 1'b0) : 1'b0;
assign	ram_wen_way_1_bank_7 = ((work_state == 4'b0110)) ? (way_choose ? ((offset[4:2] == 3'd7) ? 1'b1 : 1'b0) : 1'b0) : 1'b0;

assign	ram_wen_way_0_bank_0_normal = (work_state == 4'b0111) ? (succeed_0 ? ((offset[4:2] == 3'd0) ? 1'b1 : 1'b0) : 1'b0) : 1'b0;
assign	ram_wen_way_0_bank_1_normal = (work_state == 4'b0111) ? (succeed_0 ? ((offset[4:2] == 3'd1) ? 1'b1 : 1'b0) : 1'b0) : 1'b0;
assign	ram_wen_way_0_bank_2_normal = (work_state == 4'b0111) ? (succeed_0 ? ((offset[4:2] == 3'd2) ? 1'b1 : 1'b0) : 1'b0) : 1'b0;
assign	ram_wen_way_0_bank_3_normal = (work_state == 4'b0111) ? (succeed_0 ? ((offset[4:2] == 3'd3) ? 1'b1 : 1'b0) : 1'b0) : 1'b0;
assign	ram_wen_way_0_bank_4_normal = (work_state == 4'b0111) ? (succeed_0 ? ((offset[4:2] == 3'd4) ? 1'b1 : 1'b0) : 1'b0) : 1'b0;
assign	ram_wen_way_0_bank_5_normal = (work_state == 4'b0111) ? (succeed_0 ? ((offset[4:2] == 3'd5) ? 1'b1 : 1'b0) : 1'b0) : 1'b0;
assign	ram_wen_way_0_bank_6_normal = (work_state == 4'b0111) ? (succeed_0 ? ((offset[4:2] == 3'd6) ? 1'b1 : 1'b0) : 1'b0) : 1'b0;
assign	ram_wen_way_0_bank_7_normal = (work_state == 4'b0111) ? (succeed_0 ? ((offset[4:2] == 3'd7) ? 1'b1 : 1'b0) : 1'b0) : 1'b0;

assign	ram_wen_way_1_bank_0_normal = (work_state == 4'b0111) ? (succeed_1 ? ((offset[4:2] == 3'd0) ? 1'b1 : 1'b0) : 1'b0) : 1'b0;
assign	ram_wen_way_1_bank_1_normal = (work_state == 4'b0111) ? (succeed_1 ? ((offset[4:2] == 3'd1) ? 1'b1 : 1'b0) : 1'b0) : 1'b0;
assign	ram_wen_way_1_bank_2_normal = (work_state == 4'b0111) ? (succeed_1 ? ((offset[4:2] == 3'd2) ? 1'b1 : 1'b0) : 1'b0) : 1'b0;
assign	ram_wen_way_1_bank_3_normal = (work_state == 4'b0111) ? (succeed_1 ? ((offset[4:2] == 3'd3) ? 1'b1 : 1'b0) : 1'b0) : 1'b0;
assign	ram_wen_way_1_bank_4_normal = (work_state == 4'b0111) ? (succeed_1 ? ((offset[4:2] == 3'd4) ? 1'b1 : 1'b0) : 1'b0) : 1'b0;
assign	ram_wen_way_1_bank_5_normal = (work_state == 4'b0111) ? (succeed_1 ? ((offset[4:2] == 3'd5) ? 1'b1 : 1'b0) : 1'b0) : 1'b0;
assign	ram_wen_way_1_bank_6_normal = (work_state == 4'b0111) ? (succeed_1 ? ((offset[4:2] == 3'd6) ? 1'b1 : 1'b0) : 1'b0) : 1'b0;
assign	ram_wen_way_1_bank_7_normal = (work_state == 4'b0111) ? (succeed_1 ? ((offset[4:2] == 3'd7) ? 1'b1 : 1'b0) : 1'b0) : 1'b0;

assign	ram_wen_way_0_bank_0_input = ram_en_way_0_bank_0 | ram_wen_way_0_bank_0 | ram_wen_way_0_bank_0_normal;
assign	ram_wen_way_0_bank_1_input = ram_en_way_0_bank_1 | ram_wen_way_0_bank_1 | ram_wen_way_0_bank_1_normal;
assign	ram_wen_way_0_bank_2_input = ram_en_way_0_bank_2 | ram_wen_way_0_bank_2 | ram_wen_way_0_bank_2_normal;
assign	ram_wen_way_0_bank_3_input = ram_en_way_0_bank_3 | ram_wen_way_0_bank_3 | ram_wen_way_0_bank_3_normal;
assign	ram_wen_way_0_bank_4_input = ram_en_way_0_bank_4 | ram_wen_way_0_bank_4 | ram_wen_way_0_bank_4_normal;
assign	ram_wen_way_0_bank_5_input = ram_en_way_0_bank_5 | ram_wen_way_0_bank_5 | ram_wen_way_0_bank_5_normal;
assign	ram_wen_way_0_bank_6_input = ram_en_way_0_bank_6 | ram_wen_way_0_bank_6 | ram_wen_way_0_bank_6_normal;
assign	ram_wen_way_0_bank_7_input = ram_en_way_0_bank_7 | ram_wen_way_0_bank_7 | ram_wen_way_0_bank_7_normal;

assign	ram_wen_way_1_bank_0_input = ram_en_way_1_bank_0 | ram_wen_way_1_bank_0 | ram_wen_way_1_bank_0_normal;
assign	ram_wen_way_1_bank_1_input = ram_en_way_1_bank_1 | ram_wen_way_1_bank_1 | ram_wen_way_1_bank_1_normal;
assign	ram_wen_way_1_bank_2_input = ram_en_way_1_bank_2 | ram_wen_way_1_bank_2 | ram_wen_way_1_bank_2_normal;
assign	ram_wen_way_1_bank_3_input = ram_en_way_1_bank_3 | ram_wen_way_1_bank_3 | ram_wen_way_1_bank_3_normal;
assign	ram_wen_way_1_bank_4_input = ram_en_way_1_bank_4 | ram_wen_way_1_bank_4 | ram_wen_way_1_bank_4_normal;
assign	ram_wen_way_1_bank_5_input = ram_en_way_1_bank_5 | ram_wen_way_1_bank_5 | ram_wen_way_1_bank_5_normal;
assign	ram_wen_way_1_bank_6_input = ram_en_way_1_bank_6 | ram_wen_way_1_bank_6 | ram_wen_way_1_bank_6_normal;
assign	ram_wen_way_1_bank_7_input = ram_en_way_1_bank_7 | ram_wen_way_1_bank_7 | ram_wen_way_1_bank_7_normal;

/*tag*/
assign tag_0_en = replace_mode_tag ? (way_choose ? 1'b0 : 1'b1) : 1'b0;
assign tag_1_en = replace_mode_tag ? (way_choose ? 1'b1 : 1'b0) : 1'b0;

////workstate
//state
reg [3:0] work_state;   //00: hit  /01: seek to replace and require  /11: wait for axi
reg [3: 0] victim_workstate;
reg [26:0] victim_addr;
wire req_but_miss;
wire write_back;

assign req_but_miss = data_req_reg && (!succeed);
assign write_back 	=((way_choose == 1'b0) && valid_0) || ((way_choose == 1'b1) && valid_1);
					  

always @(posedge clk)
	begin
		if(rst)
		begin
			work_state <= 4'b0100;
		end
		else if((work_state == 4'b0100) && cache_work_1) 
		begin
			work_state <= 4'b0000;
		end
		else if((work_state == 4'b0000) && (cache_req && (cache_op[6:3] != 4'd0)))
		begin
			work_state <= 4'b1111;
		end
		else if((work_state == 4'b1111) && (op_workstate == 4'd1))
		begin
			work_state <= 4'b0000;
		end
		else if((work_state == 4'b0101) || (work_state == 4'b0110))
		begin
			work_state <= 4'b0000;
		end
		else if((work_state == 4'b0010) && (victim_workstate == 4'd1)) // write back                                  ///////////////////////////2
		begin
			work_state <= 4'b0001; 
		end
		else if((work_state == 4'b0000) && data_addr_ok && data_wr) // write into cache          
		begin
			work_state <= 4'b0111; 
		end
		else if((work_state == 4'b0111) && req_but_miss && write_back) // write back prepare     ////////////////////////////1
		begin
			work_state <= 4'b1110; 
		end
		else if(work_state == 4'b1110) // write back prepare     ////////////////////////////1
		begin
			work_state <= 4'b0010; 
		end
		else if((work_state == 4'b0111) && req_but_miss && !write_back) // write into cache
		begin
			work_state <= 4'b0001; 
		end
		else if((work_state == 4'b0000) && req_but_miss && write_back) // write back prepare     /////////////////////////////1
		begin
			work_state <= 4'b0010;
		end
		else if((work_state == 4'b0111) && succeed && !continue_sw) // write into cache
		begin
			work_state <= 4'b0000; 
		end
		else if((work_state == 4'b0000) && req_but_miss && !write_back) // miss or invalid, enter state 001
		begin
			work_state <= 4'b0001;
		end
        else if((work_state == 4'b0001) && arready && !wait_victim_buffer) // after axi ack addr, enter state 011
        begin
            work_state <= 4'b0011;
        end
        else if((work_state == 4'b0011) && rvalid && (rid == 4'd1)) //???????
        begin
            work_state <= 4'b1000;
        end
         else if(work_state == 4'b1000) //???????
        begin
            work_state <= 4'b1001;
        end
		else if((work_state == 4'b1001) && rvalid && rlast && (rid == 4'd1) && data_wr_reg) // after axi rlast(trans end), enter state 010
        begin
            work_state <= 4'b0110;
        end
		else if((work_state == 4'b1001) && rvalid && rlast && (rid == 4'd1)) // after axi rlast(trans end), enter state 010
        begin
            work_state <= 4'b0000;
        end
	end

reg addr_data_equal;
always @(posedge clk)
	begin
		if(rst)
		begin
			addr_data_equal <= 1'b0;
		end
        else if(data_addr_ok && !data_data_ok)
        begin
            addr_data_equal <= 1'b1; 
        end
		else if(data_data_ok && !data_addr_ok)
		begin
            addr_data_equal <= 1'b0; 
        end
	end

//sram control
assign data_addr_ok = data_req & ((work_state == 4'b0000) || (continue_sw)) & (addr_data_equal ? data_data_ok : 1'b1);   ////////////////
assign data_data_ok = (data_req_reg && succeed && ((work_state == 4'b0000) || (work_state == 4'b0111))) || (work_state == 4'b1000);// || ((work_state == 3'b010) ? 1'b1 : 1'b0);   // state 10 after rlast, 
assign data_rdata   = cache_rdata;  // state 10 ensure that right state is ready
assign data_id      = data_id_reg;

//axi control
wire   wait_victim_buffer;
assign wait_victim_buffer = (data_addr_reg[31:5] == victim_addr) && (victim_workstate != 4'd0);

assign arid		= 4'd1;
assign araddr   = {data_addr_reg[31:2],2'b0};
assign arlen    = 8'd7;
assign arsize   = 3'd2;
assign arburst  = 2'b10;
assign arlock   = 2'b0;
assign arcache  = 4'b0;
assign arprot   = 3'b0;
assign arvalid  = (work_state == 4'b0001) && !wait_victim_buffer;

assign rready 	= ((work_state == 4'b0011) || (work_state == 4'b1001) || (work_state == 4'b1000)) ? 1'b1 : 1'b0;

////LRU
reg lru_history;
always @(posedge clk)
	begin
		if(rst)
		begin
			lru_history <= 1'b0;
		end
		else if(work_state == 4'b1000) // require and hit, so update lru
		begin
			lru_history <= 1'b1;
		end
        else if(work_state == 4'b0000) // require and hit, so update lru
		begin
			lru_history <= 1'b0;
		end
	end

reg [127:0] lru;
always @(posedge clk)
	begin
		if(rst)
		begin
			lru <= 128'b0;
		end
		else if(((work_state == 4'b0000)||(work_state == 4'b0111)) && data_req_reg && succeed) // require and hit, so update lru
		begin
			lru[index] <= hit_1;
		end
        else if((work_state == 4'b0000) && lru_history && succeed) // require and hit, so update lru
		begin
			lru[index] <= hit_1;
		end
	end


///dirty
reg victim_waychoose;

reg [127:0] dirty_way_0;
reg [127:0] dirty_way_1;
wire dirty_way_0_input;
wire dirty_way_1_input;

assign dirty_way_0_input = (work_state == 4'b0111) ? succeed_0 : !way_choose;
assign dirty_way_1_input = (work_state == 4'b0111) ? succeed_1 :  way_choose;

always @(posedge clk)
	begin
		if(rst)
		begin
			dirty_way_0 <= 128'b0;
		end
		else if(((work_state == 4'b0111) && data_req_reg) || (work_state == 4'b0110)) // 
		begin
			dirty_way_0[index] <= dirty_way_0_input;
		end
		else if((work_state == 4'b0010) && (way_choose == 1'b0))
		begin
			dirty_way_0[index] <= 1'b0;
		end
	end

always @(posedge clk)
	begin
		if(rst)
		begin
			dirty_way_1 <= 128'b0;
		end
		else if(((work_state == 4'b0111) && data_req_reg) || (work_state == 4'b0110)) // 
		begin
			dirty_way_1[index] <= dirty_way_1_input;
		end
		else if((work_state == 4'b0010) && (way_choose == 1'b1))
		begin
			dirty_way_1[index] <= 1'b0;
		end
	end

// victim_buffer
reg [31:0] victim_buffer [7:0];
reg [31:0] victim_buffer_reg [7:0];

always @(posedge clk)
	begin
		if(rst)
		begin
			victim_workstate <= 4'd15;
		end
        else if(victim_workstate == 4'd15)
        begin
            victim_workstate <= 4'd0;
        end
        else if(victim_workstate == 4'd0)
        begin
            if(((work_state == 4'b0000) && req_but_miss && write_back) || (work_state == 4'b1110))
            begin
                victim_workstate <= 4'd1;
            end
            else if(work_state == 4'b0010)
            begin
                victim_workstate <= 4'd1;
            end
        end
        else if(victim_workstate == 4'd1)
        begin
            victim_workstate <= 4'd2;
        end
        else if(victim_workstate == 4'd2)
        begin
            if(awready)
            begin
                victim_workstate <= 4'd3;
            end
        end
        else if(victim_workstate == 4'd3)
        begin
            if((target_bank_write == 3'd7) && wready)
            begin
                victim_workstate <= 4'd4;
            end
        end
        else if(victim_workstate == 4'd4)
        begin
            if(bvalid && (bid == 4'd0))
            begin
                victim_workstate <= 4'd0;
            end
        end
	end

reg[20:0] tag_rdata_reg;
always @(posedge clk)
	begin
		if(rst)
		begin
			tag_rdata_reg <= 21'd0;
		end
        else if((work_state == 4'b0000) || (work_state == 4'b0111))
        begin
            tag_rdata_reg <= tag_rdata;
        end
	end

always @(posedge clk)
	begin
		if(rst)
		begin
			victim_addr <= 27'd0;
		end
        else if(victim_workstate == 4'd1)
        begin
            victim_addr <= {tag_rdata_reg[19:0],index};
        end
	end

always @(posedge clk)
	begin
		if(rst)
		begin
			victim_buffer_reg[0] <= 32'd0;
            victim_buffer_reg[1] <= 32'd0;
            victim_buffer_reg[2] <= 32'd0;
            victim_buffer_reg[3] <= 32'd0;
            victim_buffer_reg[4] <= 32'd0;
            victim_buffer_reg[5] <= 32'd0;
            victim_buffer_reg[6] <= 32'd0;
            victim_buffer_reg[7] <= 32'd0;
		end
        else if((work_state == 4'b0000) || (work_state == 4'b1110))
        begin
            victim_buffer_reg[0] <= rdata_0_write_back;
            victim_buffer_reg[1] <= rdata_1_write_back;
            victim_buffer_reg[2] <= rdata_2_write_back;
            victim_buffer_reg[3] <= rdata_3_write_back;
            victim_buffer_reg[4] <= rdata_4_write_back;
            victim_buffer_reg[5] <= rdata_5_write_back;
            victim_buffer_reg[6] <= rdata_6_write_back;
            victim_buffer_reg[7] <= rdata_7_write_back;
        end
	end

always @(posedge clk)
	begin
		if(rst)
		begin
			victim_buffer[0] <= 32'd0;
            victim_buffer[1] <= 32'd0;
            victim_buffer[2] <= 32'd0;
            victim_buffer[3] <= 32'd0;
            victim_buffer[4] <= 32'd0;
            victim_buffer[5] <= 32'd0;
            victim_buffer[6] <= 32'd0;
            victim_buffer[7] <= 32'd0;
		end
        else if(victim_workstate == 4'd1)
        begin
            victim_buffer[0] <= victim_buffer_reg[0];
            victim_buffer[1] <= victim_buffer_reg[1];
            victim_buffer[2] <= victim_buffer_reg[2];
            victim_buffer[3] <= victim_buffer_reg[3];
            victim_buffer[4] <= victim_buffer_reg[4];
            victim_buffer[5] <= victim_buffer_reg[5];
            victim_buffer[6] <= victim_buffer_reg[6];
            victim_buffer[7] <= victim_buffer_reg[7];
        end
	end



reg	[2:0] target_bank_write;
always @(posedge clk)
	begin
		if(rst)
		begin
			target_bank_write <= 3'd0;
		end
		else if((victim_workstate == 4'd3) && wready)
		begin
			target_bank_write <= target_bank_write + 3'd1;
		end		
	end

wire    [31:0] cache_write_back;
assign cache_write_back =  	(({32{target_bank_write == 3'd0}}) & victim_buffer[0]) |
							(({32{target_bank_write == 3'd1}}) & victim_buffer[1]) |
							(({32{target_bank_write == 3'd2}}) & victim_buffer[2]) |
							(({32{target_bank_write == 3'd3}}) & victim_buffer[3]) |
							(({32{target_bank_write == 3'd4}}) & victim_buffer[4]) |
							(({32{target_bank_write == 3'd5}}) & victim_buffer[5]) |
							(({32{target_bank_write == 3'd6}}) & victim_buffer[6]) |
							(({32{target_bank_write == 3'd7}}) & victim_buffer[7]);

assign tag_rdata = way_choose ? tag_rdata_1 : tag_rdata_0;

// performance counter
reg [31:0] req_counter_0;
reg [31:0] req_counter_1;
reg [31:0] req_counter_2;
reg [31:0] miss_counter_0;
reg [31:0] miss_counter_1;

always @(posedge clk)
	begin
		if(rst)
		begin
			req_counter_0 <= 32'd0;
		end
		else if(data_addr_ok) // 
		begin
			req_counter_0 <= req_counter_0 + 32'd1;
		end
	end

always @(posedge clk)
	begin
		if(rst)
		begin
			req_counter_1 <= 32'd0;
		end
		else if(data_addr_ok && (req_counter_0 == 32'hffffffff)) 
		begin
			req_counter_1 <= req_counter_1 + 32'd1;
		end
	end

always @(posedge clk)
	begin
		if(rst)
		begin
			req_counter_2 <= 32'd0;
		end
		else if(data_addr_ok && (req_counter_1 == 32'hffffffff)) 
		begin
			req_counter_2 <= req_counter_2 + 32'd1;
		end
	end

always @(posedge clk)
	begin
		if(rst)
		begin
			miss_counter_0 <= 32'd0;
		end
		else if(((work_state == 4'b0000) || (work_state == 4'b0111)) && req_but_miss) 
		begin
			miss_counter_0 <= miss_counter_0 + 32'd1;
		end
	end

always @(posedge clk)
	begin
		if(rst)
		begin
			miss_counter_1 <= 32'd0;
		end
		else if(((work_state == 4'b0000) || (work_state == 4'b0111)) && req_but_miss && (miss_counter_0 == 32'hffffffff)) 
		begin
			miss_counter_1 <= miss_counter_1 + 32'd1;
		end
	end
	
//cache operation
reg  [3:0] 	op_workstate;
reg  [31:0] op_addr_reg;
wire [6:0] 	op_index;
wire 		op_way;
wire [4:0]  op_offset;	 

always @(posedge clk)
	begin
		if(rst)
		begin
			op_workstate <= 4'd15;
		end
		else if(op_workstate == 4'd15) 
		begin
			op_workstate <= 4'd0;
		end
		else if(op_workstate == 4'd1) 
		begin
			op_workstate <= 4'd0;
		end
		else if(op_workstate == 4'd0) 
		begin
			if(work_state == 4'b1111)
			begin
				if(cache_op[3])       //dcache index writeback invalidate
				begin
					op_workstate <= 4'd13;
				end
				else if(cache_op[4])       //dcache index store tag
				begin
					op_workstate <= 4'd12;
				end
				else if(cache_op[5])       //dcache hit invalidate
				begin
					op_workstate <= 4'd7;
				end
				else if(cache_op[6])       //dcache hit writeback invalidate
				begin
					op_workstate <= 4'd10;
				end
			end
		end
		else if(op_workstate == 4'd13) //    dcache index writeback invalidate start:
		begin
			op_workstate <= 4'd2;
		end
		else if(op_workstate == 4'd2)   
		begin
			if((victim_workstate == 4'd0) && ((valid_0 && !op_way) || (valid_1 && op_way)))
			begin
				op_workstate <= 4'd3;
			end
			else if((!valid_0 && !op_way) || (!valid_1 && op_way))
			begin
				op_workstate <= 4'd1;
			end
		end
		else if(op_workstate == 4'd3)
		begin
			if(awready)
			begin
				op_workstate <= 4'd4;
			end
		end
		else if(op_workstate == 4'd4)
		begin
			if((op_bank_write == 3'd7) && wready)
			begin
				op_workstate <= 4'd5;
			end
		end
		else if(op_workstate == 4'd5)
		begin
			if(bvalid && (bid == 4'd2))
			begin
				op_workstate <= 4'd6;
			end
		end
		else if(op_workstate == 4'd6)  //    dcache index writeback invalidate end
		begin
			op_workstate <= 4'd1;
		end
		else if(op_workstate == 4'd7)   //   dcache hit invalidate start:
		begin
			op_workstate <= 4'd8;
		end
		else if(op_workstate == 4'd8)   //   dcache hit invalidate end
		begin
			if(succeed)
			begin
				op_workstate <= 4'd6;
			end
			else 
			begin
				op_workstate <= 4'd1;
			end
		end
		else if(op_workstate == 4'd10)   //   dcache hit writeback invalidate start:
		begin
			op_workstate <= 4'd11;
		end
		else if(op_workstate == 4'd11)   
		begin
			if(succeed && (victim_workstate == 4'd0)) //   dcache hit writeback invalidate end
			begin
				op_workstate <= 4'd3;
			end
			else if(!succeed)
			begin
				op_workstate <= 4'd1;
			end
		end
		else if(op_workstate == 4'd12)   
		begin
			op_workstate <= 4'd1;
		end
	end

always @(posedge clk)
	begin
		if(rst)
		begin
			op_addr_reg <= 32'd0;
		end
		else if((work_state == 4'b1111) && (op_workstate == 4'd0) && cache_req) 
		begin
			op_addr_reg <= data_addr;
		end
	end

reg	[2:0] op_bank_write;
always @(posedge clk)
	begin
		if(rst)
		begin
			op_bank_write <= 3'd0;
		end
		else if((op_workstate == 4'd4) && wready)
		begin
			op_bank_write <= op_bank_write + 3'd1;
		end		
	end

reg op_depend_on_hit;
always @(posedge clk)
	begin
		if(rst)
		begin
			op_depend_on_hit <= 1'd0;
		end
		else if((op_workstate == 4'd10) || (op_workstate == 4'd8))
		begin
			op_depend_on_hit <= 1'd1;
		end		
		else if(op_workstate == 4'd1)
		begin
			op_depend_on_hit <= 1'd0;
		end
	end

wire  op_way_choose = op_depend_on_hit ? succeed_1 : op_way;

wire    [31:0] op_write_back;
wire    [31:0] op_rdata_0 = op_way_choose ? way_1_rdata_0 : way_0_rdata_0;
wire    [31:0] op_rdata_1 = op_way_choose ? way_1_rdata_1 : way_0_rdata_1;
wire    [31:0] op_rdata_2 = op_way_choose ? way_1_rdata_2 : way_0_rdata_2;
wire    [31:0] op_rdata_3 = op_way_choose ? way_1_rdata_3 : way_0_rdata_3;
wire    [31:0] op_rdata_4 = op_way_choose ? way_1_rdata_4 : way_0_rdata_4;
wire    [31:0] op_rdata_5 = op_way_choose ? way_1_rdata_5 : way_0_rdata_5;
wire    [31:0] op_rdata_6 = op_way_choose ? way_1_rdata_6 : way_0_rdata_6;
wire    [31:0] op_rdata_7 = op_way_choose ? way_1_rdata_7 : way_0_rdata_7;

assign op_write_back =  	(({32{op_bank_write == 3'd0}}) & op_rdata_0) |
							(({32{op_bank_write == 3'd1}}) & op_rdata_1) |
							(({32{op_bank_write == 3'd2}}) & op_rdata_2) |
							(({32{op_bank_write == 3'd3}}) & op_rdata_3) |
							(({32{op_bank_write == 3'd4}}) & op_rdata_4) |
							(({32{op_bank_write == 3'd5}}) & op_rdata_5) |
							(({32{op_bank_write == 3'd6}}) & op_rdata_6) |
							(({32{op_bank_write == 3'd7}}) & op_rdata_7) ;

assign op_way 	= op_addr_reg[12];
assign op_index = op_addr_reg[11:5];
assign op_offset= op_addr_reg[4:0];

assign cache_op_ok = (op_workstate == 4'd1) ? 1'b1 : 1'b0;

wire  [19:0] op_read_tag = op_way_choose ? tag_rdata_1[19:0] : tag_rdata_0[19:0];

assign op_0 = !op_way_choose && ((op_workstate == 4'd6) || (op_workstate == 4'd12));
assign op_1 =  op_way_choose && ((op_workstate == 4'd6) || (op_workstate == 4'd12));




assign awid     = (work_state == 4'b1111) ? 4'd2 : 4'd0;
assign awlen    = 8'd7;
assign awburst  = 2'b01;
assign awsize   = 3'd2;
assign awlock   = 2'b0;
assign awcache  = 4'b0;
assign awprot   = 3'b0;
assign awaddr   = (work_state == 4'b1111) ? {op_read_tag,op_index,5'b0} : {victim_addr,5'b0};
assign awvalid  = (victim_workstate == 4'd2) || (op_workstate == 4'd3);


assign wdata    = (work_state == 4'b1111) ? op_write_back : cache_write_back;
assign wvalid   = (victim_workstate == 4'd3) || (op_workstate == 4'd4);
assign wid      = (work_state == 4'b1111) ? 4'd2 : 4'd0;
assign wlast    = (target_bank_write == 3'd7) || (op_bank_write == 3'd7);
assign wstrb    = 4'b1111;

assign bresp    = 2'b0;
assign bready   = (victim_workstate == 4'd3) || (victim_workstate == 4'd4) || (op_workstate == 4'd4) || (op_workstate == 4'd5);

endmodule