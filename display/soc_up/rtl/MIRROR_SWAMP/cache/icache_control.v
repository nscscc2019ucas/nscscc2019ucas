`timescale 1ns / 1ps
module icache
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
    input          inst_req    ,
    input          inst_wr     ,
    input   [1 :0] inst_size   ,
    input   [31:0] inst_addr   ,
    input   [31:0] inst_wdata  ,
    output  [31:0] inst_rdata  ,
    output         inst_addr_ok,
    output         inst_data_ok

);

wire rst;
assign rst = !resetn;

////hit and valid
//hit
wire    hit_0;
wire    hit_1;
wire    hit_2;
wire    hit_3;
wire    valid_0;
wire    valid_1;
wire    valid_2;
wire    valid_3;
wire 	tag_0_en;
wire    tag_1_en;
wire 	tag_2_en;
wire    tag_3_en;

wire    [31:0] inst_addr_input;
wire    [31:0] tag_wdata_input;
assign  inst_addr_input = (work_state == 4'b0000) ? inst_addr : ((work_state == 4'b0110) ? (prefetch_tag) : inst_addr_reg);
assign  tag_wdata_input = (work_state == 4'b1111) ? 21'b0 : {1'b1,inst_addr_input[31:12]};

wire    [31:0] prefetch_addr_input;
assign  prefetch_addr_input = inst_addr_input +32'h00000020;

wire [20:0]   idle_rdata_0;
wire [20:0]   idle_rdata_1;
wire [20:0]   idle_rdata_2;
wire [20:0]   idle_rdata_3;
wire [20:0]   idle_rdata_4;
wire [20:0]   idle_rdata_5;
wire [20:0]   idle_rdata_6;
wire [20:0]   idle_rdata_7;

wire cache_work_0;
wire cache_work_1;
wire cache_work_2;
wire cache_work_3;
wire cache_work_4;
wire cache_work_5;
wire cache_work_6;
wire cache_work_7;

wire prefetch_hit_0;
wire prefetch_hit_1;
wire prefetch_hit_2;
wire prefetch_hit_3;

wire prefetch_valid_0;
wire prefetch_valid_1;
wire prefetch_valid_2;
wire prefetch_valid_3;

wire op_0;
wire op_1;
wire op_2;
wire op_3;

icache_tag tag_0(clk,rst,1'b1,tag_0_en,tag_wdata_input,idle_rdata_0,inst_addr_input,hit_0,valid_0,cache_work_0,op_0);
icache_tag tag_1(clk,rst,1'b1,tag_1_en,tag_wdata_input,idle_rdata_1,inst_addr_input,hit_1,valid_1,cache_work_1,op_1);
icache_tag tag_2(clk,rst,1'b1,tag_2_en,tag_wdata_input,idle_rdata_2,inst_addr_input,hit_2,valid_2,cache_work_2,op_2);
icache_tag tag_3(clk,rst,1'b1,tag_3_en,tag_wdata_input,idle_rdata_3,inst_addr_input,hit_3,valid_3,cache_work_3,op_3);

icache_tag_pre tag_4(clk,rst,1'b1,tag_0_en,tag_wdata_input,idle_rdata_4,inst_addr_input,prefetch_hit_0,prefetch_valid_0,cache_work_4,prefetch_addr_input,op_0);
icache_tag_pre tag_5(clk,rst,1'b1,tag_1_en,tag_wdata_input,idle_rdata_5,inst_addr_input,prefetch_hit_1,prefetch_valid_1,cache_work_5,prefetch_addr_input,op_1);
icache_tag_pre tag_6(clk,rst,1'b1,tag_2_en,tag_wdata_input,idle_rdata_6,inst_addr_input,prefetch_hit_2,prefetch_valid_2,cache_work_6,prefetch_addr_input,op_2);
icache_tag_pre tag_7(clk,rst,1'b1,tag_3_en,tag_wdata_input,idle_rdata_7,inst_addr_input,prefetch_hit_3,prefetch_valid_3,cache_work_7,prefetch_addr_input,op_3);

wire    hit;
assign  hit = hit_0 | hit_1 | hit_2 | hit_3;

//valid
wire    succeed_0;
wire    succeed_1;
wire    succeed_2;
wire    succeed_3;
wire    succeed;
reg     succeed_ack;

assign succeed_0    = hit_0 & valid_0; //if hit and  if valid
assign succeed_1    = hit_1 & valid_1;
assign succeed_2    = hit_2 & valid_2; 
assign succeed_3    = hit_3 & valid_3;
assign succeed      = succeed_0 | succeed_1 | succeed_2 | succeed_3 ;
always @(posedge clk)
	begin
		if(rst)
		begin
			succeed_ack <= 1'b0;
		end
		else if((work_state == 4'b0000) || (work_state == 4'b0010))
		begin
			succeed_ack <= succeed;
		end
	end


////data access
wire    [19:0] tag;
wire    [6:0]  index;
wire    [4:0]  offset;

assign  tag     = inst_addr_reg[31:12];
assign  index   = inst_addr_reg[11:5];
assign  offset  = inst_addr_reg[4:0];

wire 	[31:0] ram_wen;
//assign ram_wen = 32'hffff;
//assign   ram_wen = {4{}};

wire	[31:0] ram_wdata;
wire	[31:0] ram_wdata_0;
wire	[31:0] ram_wdata_1;
wire	[31:0] ram_wdata_2;
wire	[31:0] ram_wdata_3;
wire	[31:0] ram_wdata_4;
wire	[31:0] ram_wdata_5;
wire	[31:0] ram_wdata_6;
wire	[31:0] ram_wdata_7;

assign ram_wdata = rdata;
assign ram_wdata_0 = (work_state == 4'b0110) ? prefetch_buffer[0] : rdata;
assign ram_wdata_1 = (work_state == 4'b0110) ? prefetch_buffer[1] : rdata;
assign ram_wdata_2 = (work_state == 4'b0110) ? prefetch_buffer[2] : rdata;
assign ram_wdata_3 = (work_state == 4'b0110) ? prefetch_buffer[3] : rdata;
assign ram_wdata_4 = (work_state == 4'b0110) ? prefetch_buffer[4] : rdata;
assign ram_wdata_5 = (work_state == 4'b0110) ? prefetch_buffer[5] : rdata;
assign ram_wdata_6 = (work_state == 4'b0110) ? prefetch_buffer[6] : rdata;
assign ram_wdata_7 = (work_state == 4'b0110) ? prefetch_buffer[7] : rdata;

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

wire 	ram_en_way_2_bank_0;
wire 	ram_en_way_2_bank_1;
wire 	ram_en_way_2_bank_2;
wire 	ram_en_way_2_bank_3;
wire 	ram_en_way_2_bank_4;
wire 	ram_en_way_2_bank_5;
wire 	ram_en_way_2_bank_6;
wire 	ram_en_way_2_bank_7;

wire 	ram_en_way_3_bank_0;
wire 	ram_en_way_3_bank_1;
wire 	ram_en_way_3_bank_2;
wire 	ram_en_way_3_bank_3;
wire 	ram_en_way_3_bank_4;
wire 	ram_en_way_3_bank_5;
wire 	ram_en_way_3_bank_6;
wire 	ram_en_way_3_bank_7;

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

wire    [31:0] way_2_rdata_0;
wire    [31:0] way_2_rdata_1;
wire    [31:0] way_2_rdata_2;
wire    [31:0] way_2_rdata_3;
wire    [31:0] way_2_rdata_4;
wire    [31:0] way_2_rdata_5;
wire    [31:0] way_2_rdata_6;
wire    [31:0] way_2_rdata_7;

wire    [31:0] way_3_rdata_0;
wire    [31:0] way_3_rdata_1;
wire    [31:0] way_3_rdata_2;
wire    [31:0] way_3_rdata_3;
wire    [31:0] way_3_rdata_4;
wire    [31:0] way_3_rdata_5;
wire    [31:0] way_3_rdata_6;
wire    [31:0] way_3_rdata_7;

wire prefetch_ram_en_way_0_bank_0;
wire prefetch_ram_en_way_0_bank_1;
wire prefetch_ram_en_way_0_bank_2;
wire prefetch_ram_en_way_0_bank_3;
wire prefetch_ram_en_way_0_bank_4;
wire prefetch_ram_en_way_0_bank_5;
wire prefetch_ram_en_way_0_bank_6;
wire prefetch_ram_en_way_0_bank_7;

wire prefetch_ram_en_way_1_bank_0;
wire prefetch_ram_en_way_1_bank_1;
wire prefetch_ram_en_way_1_bank_2;
wire prefetch_ram_en_way_1_bank_3;
wire prefetch_ram_en_way_1_bank_4;
wire prefetch_ram_en_way_1_bank_5;
wire prefetch_ram_en_way_1_bank_6;
wire prefetch_ram_en_way_1_bank_7;

wire prefetch_ram_en_way_2_bank_0;
wire prefetch_ram_en_way_2_bank_1;
wire prefetch_ram_en_way_2_bank_2;
wire prefetch_ram_en_way_2_bank_3;
wire prefetch_ram_en_way_2_bank_4;
wire prefetch_ram_en_way_2_bank_5;
wire prefetch_ram_en_way_2_bank_6;
wire prefetch_ram_en_way_2_bank_7;

wire prefetch_ram_en_way_3_bank_0;
wire prefetch_ram_en_way_3_bank_1;
wire prefetch_ram_en_way_3_bank_2;
wire prefetch_ram_en_way_3_bank_3;
wire prefetch_ram_en_way_3_bank_4;
wire prefetch_ram_en_way_3_bank_5;
wire prefetch_ram_en_way_3_bank_6;
wire prefetch_ram_en_way_3_bank_7;

icache_data way_0_data_0(clk,rst,1'b1,(ram_en_way_0_bank_0 | prefetch_ram_en_way_0_bank_0),ram_wdata_0,inst_addr_input,way_0_rdata_0);
icache_data way_0_data_1(clk,rst,1'b1,(ram_en_way_0_bank_1 | prefetch_ram_en_way_0_bank_1),ram_wdata_1,inst_addr_input,way_0_rdata_1);
icache_data way_0_data_2(clk,rst,1'b1,(ram_en_way_0_bank_2 | prefetch_ram_en_way_0_bank_2),ram_wdata_2,inst_addr_input,way_0_rdata_2);
icache_data way_0_data_3(clk,rst,1'b1,(ram_en_way_0_bank_3 | prefetch_ram_en_way_0_bank_3),ram_wdata_3,inst_addr_input,way_0_rdata_3);
icache_data way_0_data_4(clk,rst,1'b1,(ram_en_way_0_bank_4 | prefetch_ram_en_way_0_bank_4),ram_wdata_4,inst_addr_input,way_0_rdata_4);
icache_data way_0_data_5(clk,rst,1'b1,(ram_en_way_0_bank_5 | prefetch_ram_en_way_0_bank_5),ram_wdata_5,inst_addr_input,way_0_rdata_5);
icache_data way_0_data_6(clk,rst,1'b1,(ram_en_way_0_bank_6 | prefetch_ram_en_way_0_bank_6),ram_wdata_6,inst_addr_input,way_0_rdata_6);
icache_data way_0_data_7(clk,rst,1'b1,(ram_en_way_0_bank_7 | prefetch_ram_en_way_0_bank_7),ram_wdata_7,inst_addr_input,way_0_rdata_7);

icache_data way_1_data_0(clk,rst,1'b1,(ram_en_way_1_bank_0 | prefetch_ram_en_way_1_bank_0),ram_wdata_0,inst_addr_input,way_1_rdata_0);
icache_data way_1_data_1(clk,rst,1'b1,(ram_en_way_1_bank_1 | prefetch_ram_en_way_1_bank_1),ram_wdata_1,inst_addr_input,way_1_rdata_1);
icache_data way_1_data_2(clk,rst,1'b1,(ram_en_way_1_bank_2 | prefetch_ram_en_way_1_bank_2),ram_wdata_2,inst_addr_input,way_1_rdata_2);
icache_data way_1_data_3(clk,rst,1'b1,(ram_en_way_1_bank_3 | prefetch_ram_en_way_1_bank_3),ram_wdata_3,inst_addr_input,way_1_rdata_3);
icache_data way_1_data_4(clk,rst,1'b1,(ram_en_way_1_bank_4 | prefetch_ram_en_way_1_bank_4),ram_wdata_4,inst_addr_input,way_1_rdata_4);
icache_data way_1_data_5(clk,rst,1'b1,(ram_en_way_1_bank_5 | prefetch_ram_en_way_1_bank_5),ram_wdata_5,inst_addr_input,way_1_rdata_5);
icache_data way_1_data_6(clk,rst,1'b1,(ram_en_way_1_bank_6 | prefetch_ram_en_way_1_bank_6),ram_wdata_6,inst_addr_input,way_1_rdata_6);
icache_data way_1_data_7(clk,rst,1'b1,(ram_en_way_1_bank_7 | prefetch_ram_en_way_1_bank_7),ram_wdata_7,inst_addr_input,way_1_rdata_7);

icache_data way_2_data_0(clk,rst,1'b1,(ram_en_way_2_bank_0 | prefetch_ram_en_way_2_bank_0),ram_wdata_0,inst_addr_input,way_2_rdata_0);
icache_data way_2_data_1(clk,rst,1'b1,(ram_en_way_2_bank_1 | prefetch_ram_en_way_2_bank_1),ram_wdata_1,inst_addr_input,way_2_rdata_1);
icache_data way_2_data_2(clk,rst,1'b1,(ram_en_way_2_bank_2 | prefetch_ram_en_way_2_bank_2),ram_wdata_2,inst_addr_input,way_2_rdata_2);
icache_data way_2_data_3(clk,rst,1'b1,(ram_en_way_2_bank_3 | prefetch_ram_en_way_2_bank_3),ram_wdata_3,inst_addr_input,way_2_rdata_3);
icache_data way_2_data_4(clk,rst,1'b1,(ram_en_way_2_bank_4 | prefetch_ram_en_way_2_bank_4),ram_wdata_4,inst_addr_input,way_2_rdata_4);
icache_data way_2_data_5(clk,rst,1'b1,(ram_en_way_2_bank_5 | prefetch_ram_en_way_2_bank_5),ram_wdata_5,inst_addr_input,way_2_rdata_5);
icache_data way_2_data_6(clk,rst,1'b1,(ram_en_way_2_bank_6 | prefetch_ram_en_way_2_bank_6),ram_wdata_6,inst_addr_input,way_2_rdata_6);
icache_data way_2_data_7(clk,rst,1'b1,(ram_en_way_2_bank_7 | prefetch_ram_en_way_2_bank_7),ram_wdata_7,inst_addr_input,way_2_rdata_7);

icache_data way_3_data_0(clk,rst,1'b1,(ram_en_way_3_bank_0 | prefetch_ram_en_way_3_bank_0),ram_wdata_0,inst_addr_input,way_3_rdata_0);
icache_data way_3_data_1(clk,rst,1'b1,(ram_en_way_3_bank_1 | prefetch_ram_en_way_3_bank_1),ram_wdata_1,inst_addr_input,way_3_rdata_1);
icache_data way_3_data_2(clk,rst,1'b1,(ram_en_way_3_bank_2 | prefetch_ram_en_way_3_bank_2),ram_wdata_2,inst_addr_input,way_3_rdata_2);
icache_data way_3_data_3(clk,rst,1'b1,(ram_en_way_3_bank_3 | prefetch_ram_en_way_3_bank_3),ram_wdata_3,inst_addr_input,way_3_rdata_3);
icache_data way_3_data_4(clk,rst,1'b1,(ram_en_way_3_bank_4 | prefetch_ram_en_way_3_bank_4),ram_wdata_4,inst_addr_input,way_3_rdata_4);
icache_data way_3_data_5(clk,rst,1'b1,(ram_en_way_3_bank_5 | prefetch_ram_en_way_3_bank_5),ram_wdata_5,inst_addr_input,way_3_rdata_5);
icache_data way_3_data_6(clk,rst,1'b1,(ram_en_way_3_bank_6 | prefetch_ram_en_way_3_bank_6),ram_wdata_6,inst_addr_input,way_3_rdata_6);
icache_data way_3_data_7(clk,rst,1'b1,(ram_en_way_3_bank_7 | prefetch_ram_en_way_3_bank_7),ram_wdata_7,inst_addr_input,way_3_rdata_7);


assign rdata_0 = ({32{succeed_0}} & way_0_rdata_0) | 
				 ({32{succeed_1}} & way_1_rdata_0) |
				 ({32{succeed_2}} & way_2_rdata_0) | 
				 ({32{succeed_3}} & way_3_rdata_0) ;
assign rdata_1 = ({32{succeed_0}} & way_0_rdata_1) | 
				 ({32{succeed_1}} & way_1_rdata_1) |
				 ({32{succeed_2}} & way_2_rdata_1) | 
				 ({32{succeed_3}} & way_3_rdata_1) ;
assign rdata_2 = ({32{succeed_0}} & way_0_rdata_2) | 
				 ({32{succeed_1}} & way_1_rdata_2) |
				 ({32{succeed_2}} & way_2_rdata_2) | 
				 ({32{succeed_3}} & way_3_rdata_2) ;
assign rdata_3 = ({32{succeed_0}} & way_0_rdata_3) | 
				 ({32{succeed_1}} & way_1_rdata_3) |
				 ({32{succeed_2}} & way_2_rdata_3) | 
				 ({32{succeed_3}} & way_3_rdata_3) ;
assign rdata_4 = ({32{succeed_0}} & way_0_rdata_4) | 
				 ({32{succeed_1}} & way_1_rdata_4) |
				 ({32{succeed_2}} & way_2_rdata_4) | 
				 ({32{succeed_3}} & way_3_rdata_4) ;
assign rdata_5 = ({32{succeed_0}} & way_0_rdata_5) | 
				 ({32{succeed_1}} & way_1_rdata_5) |
				 ({32{succeed_2}} & way_2_rdata_5) | 
				 ({32{succeed_3}} & way_3_rdata_5) ;
assign rdata_6 = ({32{succeed_0}} & way_0_rdata_6) | 
				 ({32{succeed_1}} & way_1_rdata_6) |
				 ({32{succeed_2}} & way_2_rdata_6) | 
				 ({32{succeed_3}} & way_3_rdata_6) ;
assign rdata_7 = ({32{succeed_0}} & way_0_rdata_7) | 
				 ({32{succeed_1}} & way_1_rdata_7) |
				 ({32{succeed_2}} & way_2_rdata_7) | 
				 ({32{succeed_3}} & way_3_rdata_7) ;

wire    [31:0] cache_rdata;
assign cache_rdata =  	(({32{offset[4:2] == 3'd0}}) & rdata_0) |
						(({32{offset[4:2] == 3'd1}}) & rdata_1) |
						(({32{offset[4:2] == 3'd2}}) & rdata_2) |
						(({32{offset[4:2] == 3'd3}}) & rdata_3) |
						(({32{offset[4:2] == 3'd4}}) & rdata_4) |
						(({32{offset[4:2] == 3'd5}}) & rdata_5) |
						(({32{offset[4:2] == 3'd6}}) & rdata_6) |
						(({32{offset[4:2] == 3'd7}}) & rdata_7);

wire [2:0] pick = offset[4:2]; //idle

////replace
//info store
reg          inst_req_reg    ;
reg          inst_wr_reg     ;
reg   [1 :0] inst_size_reg   ;
reg   [31:0] inst_addr_reg   ;
reg   [31:0] inst_rdata_reg  ;

always @(posedge clk)
	begin
		if(rst)
		begin
			inst_req_reg <= 1'b0;
		end
		else if((work_state == 4'b0000) && inst_addr_ok)
		begin
			inst_req_reg <= inst_req;
		end
//        else if((work_state == 3'b001) && axi_inst_addr_ok) // if axi ack addr, stop requiring //TBD
        else if(inst_data_ok) // if axi ack addr, stop requiring //TBD
		begin
			inst_req_reg <= 1'b0;
		end
	end

always @(posedge clk)
	begin
		if(rst)
		begin
			inst_wr_reg <= 1'b0;
		end
		else if(work_state == 4'b0000)
		begin
			inst_wr_reg <= inst_wr;
		end
	end

always @(posedge clk)
	begin
		if(rst)
		begin
			inst_size_reg <= 2'b0;
		end
		else if(work_state == 4'b0000)
		begin
			inst_size_reg <= inst_size;
		end
	end

always @(posedge clk)
	begin
		if(rst)
		begin
			inst_addr_reg <= 32'b0;
		end
		else if(((work_state == 4'b0000) & inst_addr_ok) || ((work_state == 4'b1111) && (op_workstate == 4'd0) && cache_req))
		begin
			inst_addr_reg <= inst_addr;
		end
	end

//replace
wire replace_mode;
assign replace_mode = (work_state == 4'b0011) ? 1'b1 : 1'b0;

wire [1:0] way_choose = {lru_3_1[index],lru_3_0[index]};
wire [1:0] way_choose_prefetch = {lru_3_1[prefetch_tag[11:5]],lru_3_0[prefetch_tag[11:5]]};

/*data bank*/

reg	[2:0] target_bank;
always @(posedge clk)
	begin
		if(rst)
		begin
			target_bank <= 3'd0;
		end
		// else if(((work_state == 3'b011) || (work_state == 3'b111)) && (rlast && (rid == 4'd3)))
		// begin
		// 	target_bank <= 3'd0;
		// end
		else if(((work_state == 4'b0011) || (work_state == 4'b0111)) && (rvalid && (rid == 4'd3)))
		begin
			target_bank <= target_bank + 3'd1;
		end		
	end

assign ram_en_way_0_bank_0 = replace_mode ? ((way_choose == 2'b00) ? ((target_bank == 3'd0) && rvalid) : 1'b0) : 1'b0;
assign ram_en_way_0_bank_1 = replace_mode ? ((way_choose == 2'b00) ? ((target_bank == 3'd1) && rvalid) : 1'b0) : 1'b0;
assign ram_en_way_0_bank_2 = replace_mode ? ((way_choose == 2'b00) ? ((target_bank == 3'd2) && rvalid) : 1'b0) : 1'b0;
assign ram_en_way_0_bank_3 = replace_mode ? ((way_choose == 2'b00) ? ((target_bank == 3'd3) && rvalid) : 1'b0) : 1'b0;
assign ram_en_way_0_bank_4 = replace_mode ? ((way_choose == 2'b00) ? ((target_bank == 3'd4) && rvalid) : 1'b0) : 1'b0;
assign ram_en_way_0_bank_5 = replace_mode ? ((way_choose == 2'b00) ? ((target_bank == 3'd5) && rvalid) : 1'b0) : 1'b0;
assign ram_en_way_0_bank_6 = replace_mode ? ((way_choose == 2'b00) ? ((target_bank == 3'd6) && rvalid) : 1'b0) : 1'b0;
assign ram_en_way_0_bank_7 = replace_mode ? ((way_choose == 2'b00) ? ((target_bank == 3'd7) && rvalid) : 1'b0) : 1'b0;

assign ram_en_way_1_bank_0 = replace_mode ? ((way_choose == 2'b01) ? ((target_bank == 3'd0) && rvalid) : 1'b0) : 1'b0;
assign ram_en_way_1_bank_1 = replace_mode ? ((way_choose == 2'b01) ? ((target_bank == 3'd1) && rvalid) : 1'b0) : 1'b0;
assign ram_en_way_1_bank_2 = replace_mode ? ((way_choose == 2'b01) ? ((target_bank == 3'd2) && rvalid) : 1'b0) : 1'b0;
assign ram_en_way_1_bank_3 = replace_mode ? ((way_choose == 2'b01) ? ((target_bank == 3'd3) && rvalid) : 1'b0) : 1'b0;
assign ram_en_way_1_bank_4 = replace_mode ? ((way_choose == 2'b01) ? ((target_bank == 3'd4) && rvalid) : 1'b0) : 1'b0;
assign ram_en_way_1_bank_5 = replace_mode ? ((way_choose == 2'b01) ? ((target_bank == 3'd5) && rvalid) : 1'b0) : 1'b0;
assign ram_en_way_1_bank_6 = replace_mode ? ((way_choose == 2'b01) ? ((target_bank == 3'd6) && rvalid) : 1'b0) : 1'b0;
assign ram_en_way_1_bank_7 = replace_mode ? ((way_choose == 2'b01) ? ((target_bank == 3'd7) && rvalid) : 1'b0) : 1'b0;

assign ram_en_way_2_bank_0 = replace_mode ? ((way_choose == 2'b10) ? ((target_bank == 3'd0) && rvalid) : 1'b0) : 1'b0;
assign ram_en_way_2_bank_1 = replace_mode ? ((way_choose == 2'b10) ? ((target_bank == 3'd1) && rvalid) : 1'b0) : 1'b0;
assign ram_en_way_2_bank_2 = replace_mode ? ((way_choose == 2'b10) ? ((target_bank == 3'd2) && rvalid) : 1'b0) : 1'b0;
assign ram_en_way_2_bank_3 = replace_mode ? ((way_choose == 2'b10) ? ((target_bank == 3'd3) && rvalid) : 1'b0) : 1'b0;
assign ram_en_way_2_bank_4 = replace_mode ? ((way_choose == 2'b10) ? ((target_bank == 3'd4) && rvalid) : 1'b0) : 1'b0;
assign ram_en_way_2_bank_5 = replace_mode ? ((way_choose == 2'b10) ? ((target_bank == 3'd5) && rvalid) : 1'b0) : 1'b0;
assign ram_en_way_2_bank_6 = replace_mode ? ((way_choose == 2'b10) ? ((target_bank == 3'd6) && rvalid) : 1'b0) : 1'b0;
assign ram_en_way_2_bank_7 = replace_mode ? ((way_choose == 2'b10) ? ((target_bank == 3'd7) && rvalid) : 1'b0) : 1'b0;

assign ram_en_way_3_bank_0 = replace_mode ? ((way_choose == 2'b11) ? ((target_bank == 3'd0) && rvalid) : 1'b0) : 1'b0;
assign ram_en_way_3_bank_1 = replace_mode ? ((way_choose == 2'b11) ? ((target_bank == 3'd1) && rvalid) : 1'b0) : 1'b0;
assign ram_en_way_3_bank_2 = replace_mode ? ((way_choose == 2'b11) ? ((target_bank == 3'd2) && rvalid) : 1'b0) : 1'b0;
assign ram_en_way_3_bank_3 = replace_mode ? ((way_choose == 2'b11) ? ((target_bank == 3'd3) && rvalid) : 1'b0) : 1'b0;
assign ram_en_way_3_bank_4 = replace_mode ? ((way_choose == 2'b11) ? ((target_bank == 3'd4) && rvalid) : 1'b0) : 1'b0;
assign ram_en_way_3_bank_5 = replace_mode ? ((way_choose == 2'b11) ? ((target_bank == 3'd5) && rvalid) : 1'b0) : 1'b0;
assign ram_en_way_3_bank_6 = replace_mode ? ((way_choose == 2'b11) ? ((target_bank == 3'd6) && rvalid) : 1'b0) : 1'b0;
assign ram_en_way_3_bank_7 = replace_mode ? ((way_choose == 2'b11) ? ((target_bank == 3'd7) && rvalid) : 1'b0) : 1'b0;

assign prefetch_ram_en_way_0_bank_0 = (work_state == 4'b0110) && (way_choose_prefetch == 2'b00);
assign prefetch_ram_en_way_0_bank_1 = (work_state == 4'b0110) && (way_choose_prefetch == 2'b00);
assign prefetch_ram_en_way_0_bank_2 = (work_state == 4'b0110) && (way_choose_prefetch == 2'b00);
assign prefetch_ram_en_way_0_bank_3 = (work_state == 4'b0110) && (way_choose_prefetch == 2'b00);
assign prefetch_ram_en_way_0_bank_4 = (work_state == 4'b0110) && (way_choose_prefetch == 2'b00);
assign prefetch_ram_en_way_0_bank_5 = (work_state == 4'b0110) && (way_choose_prefetch == 2'b00);
assign prefetch_ram_en_way_0_bank_6 = (work_state == 4'b0110) && (way_choose_prefetch == 2'b00);
assign prefetch_ram_en_way_0_bank_7 = (work_state == 4'b0110) && (way_choose_prefetch == 2'b00);

assign prefetch_ram_en_way_1_bank_0 = (work_state == 4'b0110) && (way_choose_prefetch == 2'b01);
assign prefetch_ram_en_way_1_bank_1 = (work_state == 4'b0110) && (way_choose_prefetch == 2'b01);
assign prefetch_ram_en_way_1_bank_2 = (work_state == 4'b0110) && (way_choose_prefetch == 2'b01);
assign prefetch_ram_en_way_1_bank_3 = (work_state == 4'b0110) && (way_choose_prefetch == 2'b01);
assign prefetch_ram_en_way_1_bank_4 = (work_state == 4'b0110) && (way_choose_prefetch == 2'b01);
assign prefetch_ram_en_way_1_bank_5 = (work_state == 4'b0110) && (way_choose_prefetch == 2'b01);
assign prefetch_ram_en_way_1_bank_6 = (work_state == 4'b0110) && (way_choose_prefetch == 2'b01);
assign prefetch_ram_en_way_1_bank_7 = (work_state == 4'b0110) && (way_choose_prefetch == 2'b01);

assign prefetch_ram_en_way_2_bank_0 = (work_state == 4'b0110) && (way_choose_prefetch == 2'b10);
assign prefetch_ram_en_way_2_bank_1 = (work_state == 4'b0110) && (way_choose_prefetch == 2'b10);
assign prefetch_ram_en_way_2_bank_2 = (work_state == 4'b0110) && (way_choose_prefetch == 2'b10);
assign prefetch_ram_en_way_2_bank_3 = (work_state == 4'b0110) && (way_choose_prefetch == 2'b10);
assign prefetch_ram_en_way_2_bank_4 = (work_state == 4'b0110) && (way_choose_prefetch == 2'b10);
assign prefetch_ram_en_way_2_bank_5 = (work_state == 4'b0110) && (way_choose_prefetch == 2'b10);
assign prefetch_ram_en_way_2_bank_6 = (work_state == 4'b0110) && (way_choose_prefetch == 2'b10);
assign prefetch_ram_en_way_2_bank_7 = (work_state == 4'b0110) && (way_choose_prefetch == 2'b10);

assign prefetch_ram_en_way_3_bank_0 = (work_state == 4'b0110) && (way_choose_prefetch == 2'b11);
assign prefetch_ram_en_way_3_bank_1 = (work_state == 4'b0110) && (way_choose_prefetch == 2'b11);
assign prefetch_ram_en_way_3_bank_2 = (work_state == 4'b0110) && (way_choose_prefetch == 2'b11);
assign prefetch_ram_en_way_3_bank_3 = (work_state == 4'b0110) && (way_choose_prefetch == 2'b11);
assign prefetch_ram_en_way_3_bank_4 = (work_state == 4'b0110) && (way_choose_prefetch == 2'b11);
assign prefetch_ram_en_way_3_bank_5 = (work_state == 4'b0110) && (way_choose_prefetch == 2'b11);
assign prefetch_ram_en_way_3_bank_6 = (work_state == 4'b0110) && (way_choose_prefetch == 2'b11);
assign prefetch_ram_en_way_3_bank_7 = (work_state == 4'b0110) && (way_choose_prefetch == 2'b11);

/*tag*/
assign tag_0_en = (replace_mode || (work_state == 4'b0110)) ? ((way_choose == 2'b00) ? 1'b1 : 1'b0) : 1'b0;
assign tag_1_en = (replace_mode || (work_state == 4'b0110)) ? ((way_choose == 2'b01) ? 1'b1 : 1'b0) : 1'b0;
assign tag_2_en = (replace_mode || (work_state == 4'b0110)) ? ((way_choose == 2'b10) ? 1'b1 : 1'b0) : 1'b0;
assign tag_3_en = (replace_mode || (work_state == 4'b0110)) ? ((way_choose == 2'b11) ? 1'b1 : 1'b0) : 1'b0;

////workstate
//state
reg [3:0] work_state;   //00: hit  /01: seek to replace and require  /11: wait for axi
wire req_but_miss;
assign req_but_miss = inst_req_reg && (!succeed);

reg prefetch;
always @(posedge clk)
	begin
		if(rst)
		begin
			prefetch <= 1'b0;
		end
		else if(work_state == 4'b0110)
		begin
			prefetch <= 1'd1;
		end
		else if((work_state == 4'b0011) && rvalid && (target_bank == 3'd7) && (rid == 4'd3))
        begin
            prefetch <= 1'd0;
        end
	end

always @(posedge clk)
	begin
		if(rst)
		begin
			work_state <= 4'b0100;
		end
		else if((work_state == 4'b0100) && cache_work_0)
		begin
			work_state <= 4'b0000;
		end
		else if((work_state == 4'b0000) && (cache_req && (cache_op[2:0] != 3'd0)))
		begin
			work_state <= 4'b1111;
		end
		else if((work_state == 4'b1111) && (op_workstate == 4'd1))
		begin
			work_state <= 4'b0000;
		end
		else if((work_state == 4'b0101) ||(work_state == 4'b1010) )
		begin
			work_state <= 4'b0000;
		end
		else if((work_state == 4'b0110))
		begin
			work_state <= 4'b1010;
		end
		// else if(work_state == 4'b0010)
		// begin
		// 	work_state <= 4'b0111;
		// end
		// else if((work_state == 4'b0000) && req_but_miss && (offset[4] == 1'b1)) // miss or invalid, prefetch
		// begin
		// 	work_state <= 4'b0110;
		// end
        else if(work_state == 4'b0010)
        begin
            if(prefetch_state == 4'd3)
            begin
                work_state <=4'b0110;
            end
        end
		else if((work_state == 4'b0000) && req_but_miss) // miss or invalid, enter state 001
		begin
			work_state <= 4'b0001;
		end
		// else if((work_state == 4'b0000) && index_change) 
		// begin
		// 	work_state <= 4'b0101;
		// end
        else if(work_state == 4'b0001) 
        begin
            if(wait_prefetch && (prefetch_state == 4'd3))
            begin
                work_state <= 4'b0110;
            end
            else if(wait_prefetch)
            begin
                work_state <= 4'b0010;
            end
            else if(arready && (arid == 4'd3)) // after axi ack addr, enter state 011
            begin
                work_state <= 4'b0011;
            end
        end
		// else if((work_state == 4'b0110) && arready && (arid == 4'd3)) // 
        // begin
        //     work_state <= 4'b0011;
        // end
		else if((work_state == 4'b0011) && rlast && rvalid && (rid == 4'd3)) // after axi rlast(trans end), enter state 010
        begin
            work_state <= 4'b0000;
        end
		// else if((work_state == 4'b0011) && rvalid && (target_bank == 3'd7) && (rid == 4'd3) && prefetch) // after axi rlast(trans end), enter state 010
        // begin
        //     work_state <= 4'b0010;
        // end
		else if((work_state == 4'b0111) && rlast && rvalid && (rid == 4'd3)) // after axi rlast(trans end), enter state 010
        begin
            work_state <= 4'b0101;
        end
        else
        begin
            work_state <= work_state; 
        end
	end

reg inst_addr_ok_history;
always @(posedge clk)
	begin
		if(rst)
		begin
			inst_addr_ok_history <= 1'b0;
		end
        else 
        begin
           	inst_addr_ok_history <= inst_addr_ok;
        end
	end


reg addr_data_equal;
always @(posedge clk)
	begin
		if(rst)
		begin
			addr_data_equal <= 1'b0;
		end
        else if(inst_addr_ok && !inst_data_ok)
        begin
            addr_data_equal <= 1'b1; 
        end
		else if(inst_data_ok && !inst_addr_ok)
		begin
            addr_data_equal <= 1'b0; 
        end
	end

//index change
wire index_change;
assign index_change = 1'b0;

//sram control
assign inst_addr_ok = !cache_req && inst_req && (work_state == 4'b0000) && (addr_data_equal ? inst_data_ok : 1'b1);   ////////////////
assign inst_data_ok = inst_req_reg && succeed /*&& succeed_ack*/ && (work_state == 4'b0000);// || ((work_state == 3'b010) ? 1'b1 : 1'b0);   // state 10 after rlast, 
assign inst_rdata   = cache_rdata;  // state 10 ensure that right state is ready

//axi control
assign arid		= (prefetch_state == 4'd1) ? 4'd2 : 4'd3;
assign araddr   = (prefetch_state == 4'd1) ? {prefetch_tag[31:5],5'b0} : {inst_addr_reg[31:5],5'b0};
assign arlen    = 8'd7;
assign arsize   = 3'd2; 
assign arburst  = 2'b01;
assign arlock   = 2'b0;
assign arcache  = 4'b0;
assign arprot   = 3'b0;
assign arvalid  = (((work_state == 4'b0001) && !wait_prefetch) || (prefetch_state == 4'd1));

assign rready 	= ((work_state == 4'b0011) || (prefetch_state == 4'd2)) ? 1'b1 : 1'b0;

//do not care
assign awid     = 4'd2;
assign awlen    = 8'b0;
assign awburst  = 2'b0;
assign awlock   = 2'b0;
assign awcache  = 4'b0;
assign awprot   = 3'b0;
assign awaddr   = 32'b0;
assign awvalid  = 1'b0;
assign awsize   = 3'd2;

assign wdata    = 32'b0;
assign wvalid   = 1'b0;
assign wid      = 4'd2;
assign wlast    = 1'b0;

assign bresp    = 2'b0;
assign bready   = 1'b0;


// prefetch
reg [31:0] prefetch_buffer[7:0];
reg [31:0] prefetch_tag;

wire wait_prefetch; 
assign wait_prefetch = (prefetch_tag[31:5] == inst_addr_reg[31:5]) && (prefetch_state != 4'd0);

reg [2:0]  prefetch_target;
reg [3:0]  prefetch_state;
wire prefetch_succeed_0;
wire prefetch_succeed_1;
wire prefetch_succeed_2;
wire prefetch_succeed_3;

assign prefetch_succeed_0 = prefetch_hit_0 & prefetch_valid_0;
assign prefetch_succeed_1 = prefetch_hit_1 & prefetch_valid_1;
assign prefetch_succeed_2 = prefetch_hit_2 & prefetch_valid_2;
assign prefetch_succeed_3 = prefetch_hit_3 & prefetch_valid_3;

wire prefetch_succeed;
assign prefetch_succeed = prefetch_succeed_0 | prefetch_succeed_1 | prefetch_succeed_2 | prefetch_succeed_3;

wire prefetch_hit;
assign prefetch_hit = prefetch_hit_0 || prefetch_hit_1 || prefetch_hit_2 || prefetch_hit_3;

wire prefetch_work;
assign prefetch_work = inst_req_reg && succeed && !prefetch_succeed && (work_state == 4'b0000);

always @(posedge clk)
	begin
		if(rst)
		begin
			prefetch_state <= 4'd15;
		end
		else if(prefetch_state == 4'd15)
		begin
			prefetch_state <= 4'd0;
		end
        else if(prefetch_state == 4'd0)
		begin
			if(prefetch_work)
            begin
                prefetch_state <= 4'd1;
            end
		end
        else if(prefetch_state == 4'd1) 
		begin
			if(arready && (arid == 4'd2))
            begin
                prefetch_state <= 4'd2;
            end
		end
        else if(prefetch_state == 4'd2) 
		begin
			if(rlast && rvalid && (rid == 4'd2))
            begin
                prefetch_state <= 4'd3;
            end
		end
        else if(prefetch_state == 4'd3) 
		begin
			if(work_state == 4'b0110)
            begin
                prefetch_state <= 4'd0;
            end
            else if((work_state ==4'b0001) && !wait_prefetch)
            begin
                prefetch_state <= 4'd0;
            end
		end
	end

always @(posedge clk)
	begin
		if(rst)
		begin
			prefetch_tag <= 32'd0;
		end
        else if(prefetch_state == 4'd0) 
		begin
			if(prefetch_work)
            begin
                prefetch_tag <= inst_addr_reg + 32'h00000020;
            end
		end
	end

always @(posedge clk)
	begin
		if(rst)
		begin
			prefetch_target <= 3'd0;
		end
        else if(prefetch_state == 4'd2) 
		begin
			if(rvalid && (rid == 4'd2))
            begin
                prefetch_target <= prefetch_target + 3'd1;
            end	
		end
	end

always @(posedge clk)
	begin
		if(rst)
		begin
			prefetch_buffer[0] <= 32'd0;
            prefetch_buffer[1] <= 32'd0;
            prefetch_buffer[2] <= 32'd0;
            prefetch_buffer[3] <= 32'd0;
            prefetch_buffer[4] <= 32'd0;
            prefetch_buffer[5] <= 32'd0;
            prefetch_buffer[6] <= 32'd0;
            prefetch_buffer[7] <= 32'd0;
		end
        else if(prefetch_state == 4'd2) 
		begin
			if(rvalid && (rid == 4'd2))
            begin
                prefetch_buffer[prefetch_target] <= rdata;
            end
		end
	end


////LRU
reg [127:0] lru;
reg [127:0] lru_0_0;
reg [127:0] lru_0_1;
reg [127:0] lru_1_0;
reg [127:0] lru_1_1;
reg [127:0] lru_2_0;
reg [127:0] lru_2_1;
reg [127:0] lru_3_0;
reg [127:0] lru_3_1;
wire lru_0_0_input;
wire lru_0_1_input;
wire lru_1_0_input;
wire lru_1_1_input;
wire lru_2_0_input;
wire lru_2_1_input;
wire lru_3_0_input;
wire lru_3_1_input;
assign lru_0_0_input = hit_1 || hit_3;
assign lru_0_1_input = hit_2 || hit_3;
assign lru_1_0_input = hit_1 || hit_3;
assign lru_1_1_input = hit_2 || hit_3;


always @(posedge clk)
	begin
		if(rst)
		begin
			lru_0_0 <= 128'h0;
			lru_0_1 <= 128'h0;
			lru_1_0 <= 128'hffffffffffffffffffffffffffffffff;
			lru_1_1 <= 128'h0;
			lru_2_0 <= 128'h0;
			lru_2_1 <= 128'hffffffffffffffffffffffffffffffff;
			lru_3_0 <= 128'hffffffffffffffffffffffffffffffff;
			lru_3_1 <= 128'hffffffffffffffffffffffffffffffff;
		end
		else if((work_state == 3'b000) && inst_req_reg && succeed ) // require and hit, so update lru
		begin
			if((lru_3_0[index] == lru_0_0_input) && (lru_3_1[index] == lru_0_1_input))
			begin
				lru_0_0[index] <= lru_0_0_input;
				lru_0_1[index] <= lru_0_1_input;
				lru_1_0[index] <= lru_0_0[index];
				lru_1_1[index] <= lru_0_1[index];
				lru_2_0[index] <= lru_1_0[index];
				lru_2_1[index] <= lru_1_1[index];
				lru_3_0[index] <= lru_2_0[index];
				lru_3_1[index] <= lru_2_1[index];
			end
			else if((lru_2_0[index] == lru_0_0_input) && (lru_2_1[index] == lru_0_1_input))
			begin
				lru_0_0[index] <= lru_0_0_input;
				lru_0_1[index] <= lru_0_1_input;
				lru_1_0[index] <= lru_0_0[index];
				lru_1_1[index] <= lru_0_1[index];
				lru_2_0[index] <= lru_1_0[index];
				lru_2_1[index] <= lru_1_1[index];
			end
			else if((lru_1_0[index] == lru_0_0_input) && (lru_1_1[index] == lru_0_1_input))
			begin
				lru_0_0[index] <= lru_0_0_input;
				lru_0_1[index] <= lru_0_1_input;
				lru_1_0[index] <= lru_0_0[index];
				lru_1_1[index] <= lru_0_1[index];
			end
			else 
			begin
				lru_0_0[index] <= lru_0_0_input;
				lru_0_1[index] <= lru_0_1_input;
			end
		end
	end


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
		else if(inst_addr_ok) // 
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
		else if(inst_addr_ok && (req_counter_0 == 32'hffffffff)) 
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
		else if(inst_addr_ok && (req_counter_1 == 32'hffffffff)) 
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

//reg  [3:0] 	op_workstate;
reg  [3:0]  op_workstate;
reg  [31:0] op_addr_reg;
wire [6:0] 	op_index;
wire [1:0]  op_way;
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
				if(cache_op[0])       //icache index invalidate
				begin
					op_workstate <= 4'd2;
				end
				else if(cache_op[1])       //icache index store tag
				begin
					op_workstate <= 4'd6;
				end
				else if(cache_op[2])       //icache hit invalidate
				begin
					op_workstate <= 4'd3;
				end
			end
		end
		else if(op_workstate == 4'd2)   //   icache index invalidate start & end
		begin
			op_workstate <= 4'd1;
		end
		else if(op_workstate == 4'd3)   //   icache hit invalidate start:
		begin
			op_workstate <= 4'd4;
		end
		else if(op_workstate == 4'd4)   
		begin
			if(succeed)
			begin
				op_workstate <= 4'd5;
			end
			else 
			begin
				op_workstate <= 4'd1;
			end
		end
		else if(op_workstate == 4'd5)   //   icache hit invalidate end
		begin
			op_workstate <= 4'd1;
		end
		else if(op_workstate == 4'd6)   //   icache index store tag start end
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
			op_addr_reg <= inst_addr;
		end
	end

assign op_way 	= op_addr_reg[13:12];
assign op_index = op_addr_reg[11:5];
assign op_offset= op_addr_reg[4:0];

assign cache_op_ok = (op_workstate == 4'd1) ? 1'b1 : 1'b0;

assign op_0 = ((op_way == 2'd0) && ((op_workstate == 4'd2) || (op_workstate == 4'd6))) || (succeed_0 && (op_workstate == 4'd5));
assign op_1 = ((op_way == 2'd1) && ((op_workstate == 4'd2) || (op_workstate == 4'd6))) || (succeed_1 && (op_workstate == 4'd5));
assign op_2 = ((op_way == 2'd2) && ((op_workstate == 4'd2) || (op_workstate == 4'd6))) || (succeed_2 && (op_workstate == 4'd5));
assign op_3 = ((op_way == 2'd3) && ((op_workstate == 4'd2) || (op_workstate == 4'd6))) || (succeed_3 && (op_workstate == 4'd5));

endmodule