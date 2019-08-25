`timescale 1ns / 1ps
module store_buffer
(
    input          clk,
    input          resetn,

    input          cpu_data_req    ,
    input          cpu_data_wr     ,
    input   [1 :0] cpu_data_size   ,
    input   [31:0] cpu_data_addr   ,
    input   [31:0] cpu_data_wdata  ,
	input   [3 :0] cpu_data_wstrb  ,
    output  [31:0] cpu_data_rdata  ,
    output         cpu_data_addr_ok,
    output         cpu_data_data_ok,

    output          dcache_data_req    ,
    output          dcache_data_wr     ,
    output   [1 :0] dcache_data_size   ,
    output   [31:0] dcache_data_addr   ,
    output   [31:0] dcache_data_wdata  ,
	output   [3 :0] dcache_data_wstrb  ,
    input    [31:0] dcache_data_rdata  ,
    input           dcache_data_addr_ok,
    input           dcache_data_data_ok
);

wire rst;
assign rst=!resetn; 

reg [4:0]   s_index   [0:31];
reg [31:0]  s_addr    [0:31];
reg [31:0]  s_data    [0:31];
reg [3:0]   s_wstrb   [0:31];
reg [1:0]   s_size   [0:31];

reg [4:0]   A;
reg [4:0]   B;

wire [4:0] symbol_A;
wire [4:0] symbol_B;
assign symbol_A = A + 5'd1;
assign symbol_B = B + 5'd1;

wire full;
wire empty;
assign full     = (symbol_B == A) ? 1'b1 : 1'b0;
assign empty    = (A == B) ? 1'b1 : 1'b0;

//schedulor
reg cpu_data_req_history;

always @(posedge clk)
	begin
		if(rst)
		begin
			cpu_data_req_history <= 1'b0;
		end
        else if(cpu_data_addr_ok)
        begin
            cpu_data_req_history <= cpu_data_req;
        end
        else if(cpu_data_data_ok)
        begin
            cpu_data_req_history <= 1'b0;
        end
	end

//workstate

wire        buffer_data_ok_r;
wire        buffer_addr_ok_r;
wire [31:0] buffer_addr_r;
wire [31:0] buffer_rdata_r;
wire [31:0] buffer_wdata_r;
wire [3:0]  buffer_wstrb_r;
wire        buffer_req_r;
wire        buffer_wr_r;

wire        buffer_data_ok_l;
wire        buffer_addr_ok_l;
wire [31:0] buffer_addr_l;
wire [31:0] buffer_rdata_l;
wire [31:0] buffer_wdata_l;
wire [3:0]  buffer_wstrb_l;
wire        buffer_req_l;
wire        buffer_wr_l;


reg [3:0] buffer_workstate;
reg [3:0] axi_workstate;
always @(posedge clk)
	begin
		if(rst)
		begin
			buffer_workstate <= 4'd0;        
		end
        else if(buffer_workstate == 4'd0)
        begin
            buffer_workstate <= 4'd1;
        end
        else if(buffer_workstate == 4'd1)
        begin
            if(buffer_addr_ok_r || catch)
            begin
                buffer_workstate <= 4'd2;
            end
        end
        else if(buffer_workstate == 4'd2)
        begin
            if(buffer_data_ok_r && !(buffer_addr_ok_r || catch))
            begin
                buffer_workstate <= 4'd1;
            end
        end
    end

wire        axi_data_ok;
wire        axi_addr_ok;
wire [31:0] axi_addr;
wire [31:0] axi_rdata;
wire [31:0] axi_wdata;
wire [3:0]  axi_wstrb;
wire [1:0]  axi_size;
wire        axi_req;
wire        axi_wr;

always @(posedge clk)
	begin
		if(rst)
		begin
			axi_workstate <= 4'd0;        
		end
        else if(axi_workstate == 4'd0)
        begin
            axi_workstate <= 4'd1;
        end
        else if(axi_workstate == 4'd1)
        begin
            if(axi_addr_ok && !catch)
            begin
                axi_workstate <= 4'd2;
            end
        end
        else if(axi_workstate == 4'd2)
        begin
            if(axi_data_ok && (!axi_addr_ok || catch))
            begin
                axi_workstate <= 4'd1;
            end
        end
    end

wire        buffer_push;
assign      buffer_push = !full && cpu_data_wr && cpu_data_req;

reg buffer_data_ok_out;
always @(posedge clk)
	begin
		if(rst)
		begin
			buffer_data_ok_out <= 1'b0;
		end
        else if(buffer_push)
        begin
            buffer_data_ok_out <= 1'b1;
        end
        else if(cpu_data_data_ok && (axi_workstate != 4'd2))
        begin
            buffer_data_ok_out <= 1'b0;
        end
	end

assign buffer_addr_ok_l = buffer_push;
assign buffer_data_ok_l = buffer_data_ok_out;

assign buffer_addr_r    = s_addr[A];
assign buffer_wr_r      = 1'b1;
assign buffer_req_r     = ((buffer_workstate == 4'd1) || buffer_data_ok_r) && !empty && !catch_reg;
assign buffer_wstrb_r   = s_wstrb[A];
assign buffer_wdata_r   = s_data[A];
wire [1:0] buffer_size_r = s_size[A];
assign buffer_addr_ok_r = buffer_req_r && dcache_data_addr_ok; 
assign buffer_data_ok_r = (buffer_workstate == 4'd2) && (axi_workstate != 4'd2) && dcache_data_data_ok;

reg catch_reg;
wire catch;
assign catch = buffer_push && empty && axi_addr_ok;
always @(posedge clk)
	begin
		if(rst)
		begin
			catch_reg <= 1'b0;
		end
        else if(catch)
        begin
            catch_reg <= 1'b1;
        end
        else
        begin
            catch_reg <= 1'b0;
        end
	end


wire axi_work;
assign axi_work     = empty;
assign axi_data_ok  = dcache_data_data_ok;   ////////////to simplify
assign axi_addr_ok  = axi_work && axi_req && dcache_data_addr_ok;
assign axi_addr     = cpu_data_addr;
assign axi_rdata    = dcache_data_rdata;
assign axi_wdata    = cpu_data_wdata;
assign axi_wstrb    = cpu_data_wstrb;
assign axi_req      = cpu_data_req;
assign axi_size     = cpu_data_size;
assign axi_wr       = cpu_data_wr;

assign dcache_data_req      = (axi_work) ? axi_req          : buffer_req_r;
assign dcache_data_wr       = (axi_work) ? axi_wr           : buffer_wr_r;
assign dcache_data_size     = (axi_work) ? axi_size         : buffer_size_r;
assign dcache_data_addr     = (axi_work) ? axi_addr         : buffer_addr_r;
assign dcache_data_wdata    = (axi_work) ? axi_wdata        : buffer_wdata_r;
assign dcache_data_wstrb    = (axi_work) ? cpu_data_wstrb   : buffer_wstrb_r;

assign cpu_data_rdata       = axi_rdata;
assign cpu_data_addr_ok     = axi_addr_ok || buffer_addr_ok_l;
assign cpu_data_data_ok     = ((axi_workstate == 4'd2)) ? axi_data_ok : buffer_data_ok_l;

always @(posedge clk)
	begin
		if(rst)
		begin
			s_index[0] <= 5'd0;
            s_index[1] <= 5'd1;
            s_index[2] <= 5'd2;
            s_index[3] <= 5'd3;
            s_index[4] <= 5'd4;
            s_index[5] <= 5'd5; 
            s_index[6] <= 5'd6;
            s_index[7] <= 5'd7;
            s_index[8] <= 5'd8;
            s_index[9] <= 5'd9;
            s_index[10] <= 5'd10;
            s_index[11] <= 5'd11;
            s_index[12] <= 5'd12;
            s_index[13] <= 5'd13; 
            s_index[14] <= 5'd14;
            s_index[15] <= 5'd15;
            s_index[16] <= 5'd16;
            s_index[17] <= 5'd17;
            s_index[18] <= 5'd18;
            s_index[19] <= 5'd19;
            s_index[20] <= 5'd20;
            s_index[21] <= 5'd21; 
            s_index[22] <= 5'd22;
            s_index[23] <= 5'd23;
            s_index[24] <= 5'd24;
            s_index[25] <= 5'd25;
            s_index[26] <= 5'd26;
            s_index[27] <= 5'd27;
            s_index[28] <= 5'd28;
            s_index[29] <= 5'd29; 
            s_index[30] <= 5'd30;
            s_index[31] <= 5'd31;
		end
	end

always @(posedge clk)
	begin
		if(rst)
		begin
			A <= 5'd0;
		end
        else if(/*(buffer_workstate == 4'd2) &&*/ (buffer_addr_ok_r && !empty) || catch)
        begin
            A <= A + 5'd1;
        end
	end

always @(posedge clk)
	begin
		if(rst)
		begin
			B <= 5'd0;
		end
        else if(buffer_push)
        begin
            B <= B + 5'd1;
        end
	end

always @(posedge clk)
	begin
        if(buffer_push)
        begin
            s_addr[B] <= cpu_data_addr;
        end
	end

always @(posedge clk)
	begin
        if(buffer_push)
        begin
            s_wstrb[B] <= cpu_data_wstrb;
        end
	end

always @(posedge clk)
	begin
        if(buffer_push)
        begin
            s_data[B] <= cpu_data_wdata;
        end
	end
	
always @(posedge clk)
	begin
        if(buffer_push)
        begin
            s_size[B] <= cpu_data_size;
        end
	end

reg push_history;
always @(posedge clk)
	begin
        if(rst)
        begin
            push_history <= 1'b0;
        end
        else if(buffer_push)
        begin
            push_history <= 1'b1;
        end
        else
        begin
            push_history <= 1'b0;
        end
	end

reg [31:0] counter_full;
always @(posedge clk)
	begin
        if(rst)
        begin
            counter_full <= 32'b0;
        end
        else if(push_history && full)
        begin
            counter_full <= counter_full + 32'd1;
        end
	end

endmodule

