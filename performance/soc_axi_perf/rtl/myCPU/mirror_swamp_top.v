`define USE_DATA_CACHE
//`define FORCE_INST_CACHE

module mycpu_top(
    input [5:0] int,   //high active

    input aclk,
    input aresetn,   //low active

    //axi
    //ar
    output [3:0] arid,
    output [31:0] araddr,
    output [3:0] arlen,
    output [2:0] arsize,
    output [1:0] arburst,
    output [1:0] arlock,
    output [3:0] arcache,
    output [2:0] arprot,
    output arvalid,
    input arready,
    //r              
    input [3:0] rid,
    input [31:0] rdata,
    input [1:0] rresp,
    input rlast,
    input rvalid,
    output rready,
    //aw           
    output [3:0] awid,
    output [31:0] awaddr,
    output [3:0] awlen,
    output [2:0] awsize,
    output [1:0] awburst,
    output [1:0] awlock,
    output [3:0] awcache,
    output [2:0] awprot,
    output awvalid,
    input awready,
    //w          
    output [3:0] wid,
    output [31:0] wdata,
    output [3:0] wstrb,
    output wlast,
    output wvalid,
    input wready,
    //b              
    input [3:0] bid,
    input [1:0] bresp,
    input bvalid,
    output bready,

    //debug interface
    output  [31:0]   debug_wb_pc,
    output  [3 :0]   debug_wb_rf_wen,
    output  [4 :0]   debug_wb_rf_wnum,
    output  [31:0]   debug_wb_rf_wdata
);

    // //87_dbg: load failed2
//     reg [15:0] malloc_counter;
//     reg [15:0] free_counter;
//      reg [15:0] boom_addr_counter;
//      reg [15:0] boom_addr_axi_counter;
//      reg [15:0] boom_addr_range_counter;
//      reg [15:0] boom_addr_range_axi_counter;
// //     reg [15:0] boom_data_wcounter;
//      reg [15:0] boom_addr_range_axi_rcounter;
//      reg [15:0] boom_addr_rcounter;
    
//     always@(posedge aclk)
//     begin
//         malloc_counter <= !aresetn ? 16'b0 : ((cpu_inst_addr==32'h0708a250) & cpu_inst_addr_ok & cpu_inst_req) ? malloc_counter + 16'b1 : malloc_counter;
//     end
//     always@(posedge aclk)
//     begin
//         free_counter <= !aresetn ? 16'b0 : ((cpu_inst_addr==32'h0708a180) & cpu_inst_addr_ok & cpu_inst_req) ? free_counter + 16'b1 : free_counter;
//     end
    //  always@(posedge aclk)
    //  begin
    //      boom_addr_counter <= !aresetn ? 16'b0 : ((cpu_data_addr==32'h00000200) & cpu_data_addr_ok & cpu_data_req & cpu_data_wr) ? boom_addr_counter + 16'b1 : boom_addr_counter ;
    //  end
    //  always@(posedge aclk)
    //  begin
    //      boom_addr_axi_counter <= !aresetn ? 16'b0 : ((awaddr==32'h00000200) & awvalid & awready) ? boom_addr_axi_counter + 16'b1 : boom_addr_axi_counter ;
    //  end
    //  always@(posedge aclk)
    //  begin
    //      boom_addr_range_counter <= !aresetn ? 16'b0 : (({cpu_data_addr[31:5],5'b00000}==32'h00000200) & cpu_data_addr_ok & cpu_data_req & cpu_data_wr) ? boom_addr_range_counter + 16'b1 : boom_addr_range_counter ;
    //  end
    //  always@(posedge aclk)
    //  begin
    //      boom_addr_range_axi_counter <= !aresetn ? 16'b0 : (({awaddr[31:5],5'b00000}==32'h00000200) & awvalid & awready) ? boom_addr_range_axi_counter + 16'b1 : boom_addr_range_axi_counter ;
    //  end

    //  always@(posedge aclk)
    //  begin
    //      boom_addr_range_axi_rcounter <= !aresetn ? 16'b0 : (({araddr[31:5],5'b00000}==32'h00000200) & arvalid & arready) ? boom_addr_range_axi_rcounter + 16'b1 : boom_addr_range_axi_rcounter ;
    //  end
    //  always@(posedge aclk)
    //  begin
    //      boom_addr_rcounter <= !aresetn ? 16'b0 : ((cpu_data_addr==32'h00000200) & cpu_data_addr_ok & cpu_data_req & (!cpu_data_wr)) ? boom_addr_rcounter + 16'b1 : boom_addr_rcounter ;
    //  end

//     always@(posedge aclk)
//     begin
//         boom_data_wcounter <= !aresetn ? 16'b0 : ((cpu_data_wdata==32'h805b0000) & cpu_data_addr_ok & cpu_data_req & cpu_data_wr) ? boom_data_wcounter + 16'b1 : boom_data_wcounter ;
//     end
    

    `ifdef FORCE_INST_CACHE
    wire inst_cache=1'b1;
    `else
    wire inst_cache= cpu_inst_req ? cpu_inst_cache : 1'b0; // TMPFIX: & inst_req is used to deal with those time when inst_cache = x 
    // wire inst_cache=cpu_inst_cache; 
    `endif
    `ifdef USE_DATA_CACHE
    wire data_cache;
    `else
    wire data_cache=1'b0;
    `endif
    
    reg [19:0] cache_op_counter;
    always@(posedge aclk)
    begin
        cache_op_counter <= !aresetn ? 19'b0 : (cache_req & cache_op_ok) ? (cache_op_counter+19'b1) : cache_op_counter;
    end
    
    // // for os debug
    // reg [31:0] cache_w_counter;
    // reg [31:0] cache_r_counter;
    // reg [31:0] uncache_w_counter;
    // reg [31:0] uncache_r_counter;
    // wire [31:0] total_w_counter = cache_w_counter + uncache_w_counter;
    // wire [31:0] total_r_counter = cache_r_counter + uncache_r_counter;
    
    // always@(posedge aclk)
    // begin
    //     cache_w_counter <= !aresetn ? 32'b0 : (cpu_data_req & data_cache & cpu_data_cache_addr_ok & (cpu_data_wr)) ? (cache_w_counter+32'b1) : cache_w_counter;
    //     cache_r_counter <= !aresetn ? 32'b0 : (cpu_data_req & data_cache & cpu_data_cache_addr_ok & (!cpu_data_wr)) ? (cache_r_counter+32'b1) : cache_r_counter;
    //     uncache_w_counter <= !aresetn ? 32'b0 : (cpu_data_req & (!data_cache) & cpu_data_uncache_addr_ok & (cpu_data_wr)) ? (uncache_w_counter+32'b1) : uncache_w_counter;
    //     uncache_r_counter <= !aresetn ? 32'b0 : (cpu_data_req & (!data_cache) & cpu_data_uncache_addr_ok & (!cpu_data_wr)) ? (uncache_r_counter+32'b1) : uncache_r_counter;
    // end
    
    wire cpu_inst_req;
    wire [31:0] cpu_inst_addr;
    wire [31:0] cpu_inst_rdata;
    wire [31:0] cpu_inst_cache_rdata;
    wire [31:0] cpu_inst_uncache_rdata;
    wire [31:0] cpu_inst_wdata;
    wire cpu_inst_addr_ok;
    wire cpu_inst_data_ok;
    wire cpu_data_req;
    wire cpu_data_wr;
    wire [3:0] cpu_data_wstrb;
    wire [31:0] cpu_data_addr;
    wire [2 :0] cpu_data_size;
    wire [31:0] cpu_data_wdata;
    wire [31:0] cpu_data_rdata;
    wire [31:0] cpu_data_cache_rdata;
    wire [31:0] cpu_data_cache_wdata;
    wire [31:0] cpu_data_uncache_rdata;
    wire [31:0] cpu_data_uncache_wdata;
    wire cpu_data_addr_ok;
    wire cpu_data_data_ok;

    wire cache_req;
    wire [6 :0] cache_op;
    wire [31:0] cache_tag;
    
    reg cache_op_r;
    always@(posedge aclk)
    begin
        if(cache_req & (cache_op!=7'b0))
        begin
            cache_op_r <= cache_op_r ? 1'b0 : 1'b1;
        end
    end
    
//        .cache_req(cache_req),
//        .cache_op(cache_op),
    wire dcache_op_ok;
    wire icache_op_ok;
    wire cache_op_ok = dcache_op_ok | icache_op_ok;

    wire [31:0] araddr_before, awaddr_before;
    wire [3:0] arlen_before;

    wire confreg_sideway = (cpu_data_addr[31:16]==16'hbfaf)
                          |(cpu_data_addr[31:16]==16'h1faf);

//    assign inst_cache = `USE_CACHE;
//    assign data_cache = confreg_sideway?1'b0:`USE_CACHE; 

    wire inst_req_cango ;
    wire data_req_cango ;
    
    wire cpu_inst_cache;

    reg inst_cache_reg;
    reg data_cache_reg;
    wire [31:0] inst_phys_addr = {3'd0, cpu_inst_addr[28:0]};
    wire [31:0] data_phys_addr = {3'd0, cpu_data_addr[28:0]};
    

    wire  [3 :0]dcache_arid   ;
    wire  [31:0]dcache_araddr ;
    wire  [7 :0]dcache_arlen  ;
    wire  [2 :0]dcache_arsize ;
    wire  [1 :0]dcache_arburst;
    wire  [1 :0]dcache_arlock ;
    wire  [3 :0]dcache_arcache;
    wire  [2 :0]dcache_arprot ;
    wire        dcache_arvalid;
    wire        dcache_arready;
    //r
    wire [3 :0] dcache_rid    ;
    wire [31:0] dcache_rdata  ;
    wire [1 :0] dcache_rresp  ;
    wire        dcache_rlast  ;
    wire        dcache_rvalid ;
    wire        dcache_rready ;
    //aw
    wire  [3 :0]dcache_awid   ;
    wire  [31:0]dcache_awaddr ;
    wire  [7 :0]dcache_awlen  ;
    wire  [2 :0]dcache_awsize ;
    wire  [1 :0]dcache_awburst;
    wire  [1 :0]dcache_awlock ;
    wire  [3 :0]dcache_awcache;
    wire  [2 :0]dcache_awprot ;
    wire         dcache_awvalid;
    wire         dcache_awready;
    //w
    wire  [3 :0]dcache_wid    ;
    wire  [31:0]dcache_wdata  ;
    wire  [3 :0]dcache_wstrb  ;
    wire         dcache_wlast  ;
    wire         dcache_wvalid ;
    wire         dcache_wready ;
    //b
    wire [3 :0]dcache_bid    ;
    wire [1 :0]dcache_bresp  ;
    wire        dcache_bvalid ;
    wire        dcache_bready ;

    wire idle_cpu_inst_wr = 1'b0;
    wire [2:0]idle_cpu_inst_size = 3'b0;
    wire [31:0]idle_cpu_inst_addr = 32'b0;
    wire [31:0]idle_cpu_inst_rdata = 32'b0; 
    wire [31:0]idle_cpu_inst_wdata = 32'b0;
    wire idle_cpu_inst_addr_ok;
    wire idle_cpu_inst_data_ok;


    //wire for icache inst read    
    wire  [3 :0]icache_arid   ;
    wire  [31:0]icache_araddr ;
    wire  [7 :0]icache_arlen  ;
    wire  [2 :0]icache_arsize ;
    wire  [1 :0]icache_arburst;
    wire  [1 :0]icache_arlock ;
    wire  [3 :0]icache_arcache;
    wire  [2 :0]icache_arprot ;
    wire         icache_arvalid;
    wire         icache_arready;
    //r
    wire [3 :0]icache_rid    ;
    wire [31:0]icache_rdata  ;
    wire [1 :0]icache_rresp  ;
    wire        icache_rlast  ;
    wire        icache_rvalid ;
    wire        icache_rready ;
    //aw
    wire  [3 :0]icache_awid   ;
    wire  [31:0]icache_awaddr ;
    wire  [7 :0]icache_awlen  ;
    wire  [2 :0]icache_awsize ;
    wire  [1 :0]icache_awburst;
    wire  [1 :0]icache_awlock ;
    wire  [3 :0]icache_awcache;
    wire  [2 :0]icache_awprot ;
    wire         icache_awvalid;
    wire         icache_awready;
    //w
    wire  [3 :0]icache_wid    ;
    wire  [31:0]icache_wdata  ;
    wire  [3 :0]icache_wstrb  ;
    wire         icache_wlast  ;
    wire         icache_wvalid ;
    wire         icache_wready ;
    //b
    wire [3 :0]icache_bid    ;
    wire [1 :0]icache_bresp  ;
    wire        icache_bvalid ;
    wire        icache_bready ;

    //wire for uncached inst read
    //ar
    wire  [3 :0]uncached_inst_arid   ;
    wire  [31:0]uncached_inst_araddr ;
    wire  [7 :0]uncached_inst_arlen  ;
    wire  [2 :0]uncached_inst_arsize ;
    wire  [1 :0]uncached_inst_arburst;
    wire  [1 :0]uncached_inst_arlock ;
    wire  [3 :0]uncached_inst_arcache;
    wire  [2 :0]uncached_inst_arprot ;
    wire        uncached_inst_arvalid;
    wire        uncached_inst_arready;
    //r
    wire [3 :0] uncached_inst_rid    ;
    wire [31:0] uncached_inst_rdata  ;
    wire [1 :0] uncached_inst_rresp  ;
    wire        uncached_inst_rlast  ;
    wire        uncached_inst_rvalid ;
    wire        uncached_inst_rready ;
    //aw
    wire  [3 :0]uncached_inst_awid   ;
    wire  [31:0]uncached_inst_awaddr ;
    wire  [7 :0]uncached_inst_awlen  ;
    wire  [2 :0]uncached_inst_awsize ;
    wire  [1 :0]uncached_inst_awburst;
    wire  [1 :0]uncached_inst_awlock ;
    wire  [3 :0]uncached_inst_awcache;
    wire  [2 :0]uncached_inst_awprot ;
    wire         uncached_inst_awvalid;
    wire         uncached_inst_awready;
    //w
    wire  [3 :0]uncached_inst_wid    ;
    wire  [31:0]uncached_inst_wdata  ;
    wire  [3 :0]uncached_inst_wstrb  ;
    wire         uncached_inst_wlast  ;
    wire         uncached_inst_wvalid ;
    wire         uncached_inst_wready ;
    //b
    wire [3 :0]uncached_inst_bid    ;
    wire [1 :0]uncached_inst_bresp  ;
    wire        uncached_inst_bvalid ;
    wire        uncached_inst_bready ;

    //wire for uncached data read/write
    //ar
    wire  [3 :0]uncached_data_arid   ;
    wire  [31:0]uncached_data_araddr ;
    wire  [7 :0]uncached_data_arlen  ;
    wire  [2 :0]uncached_data_arsize ;
    wire  [1 :0]uncached_data_arburst;
    wire  [1 :0]uncached_data_arlock ;
    wire  [3 :0]uncached_data_arcache;
    wire  [2 :0]uncached_data_arprot ;
    wire        uncached_data_arvalid;
    wire        uncached_data_arready;
    //r
    wire [3 :0] uncached_data_rid    ;
    wire [31:0] uncached_data_rdata  ;
    wire [1 :0] uncached_data_rresp  ;
    wire        uncached_data_rlast  ;
    wire        uncached_data_rvalid ;
    wire        uncached_data_rready ;
    //aw
    wire  [3 :0]uncached_data_awid   ;
    wire  [31:0]uncached_data_awaddr ;
    wire  [7 :0]uncached_data_awlen  ;
    wire  [2 :0]uncached_data_awsize ;
    wire  [1 :0]uncached_data_awburst;
    wire  [1 :0]uncached_data_awlock ;
    wire  [3 :0]uncached_data_awcache;
    wire  [2 :0]uncached_data_awprot ;
    wire         uncached_data_awvalid;
    wire         uncached_data_awready;
    //w
    wire  [3 :0]uncached_data_wid    ;
    wire  [31:0]uncached_data_wdata  ;
    wire  [3 :0]uncached_data_wstrb  ;
    wire         uncached_data_wlast  ;
    wire         uncached_data_wvalid ;
    wire         uncached_data_wready ;
    //b
    wire [3 :0]uncached_data_bid    ;
    wire [1 :0]uncached_data_bresp  ;
    wire        uncached_data_bvalid ;
    wire        uncached_data_bready ;

    wire cpu_inst_cache_data_ok;
    wire cpu_inst_uncache_data_ok;
    wire cpu_data_cache_data_ok;
    wire cpu_data_uncache_data_ok;
    wire cpu_inst_cache_addr_ok;
    wire cpu_inst_uncache_addr_ok;
    wire cpu_data_cache_addr_ok;
    wire cpu_data_uncache_addr_ok;

    wire        dcache_data_req;
    wire        dcache_data_wr;
    wire [1 :0] dcache_data_size;
    wire [31:0] dcache_data_addr;
    wire [31:0] dcache_data_wdata;
    wire [3 :0] dcache_data_wstrb;
    wire [31:0] dcache_data_rdata;
    wire        dcache_data_addr_ok;
    wire        dcache_data_data_ok;

    wire        duncache_data_req;
    wire        duncache_data_wr;
    wire [1 :0] duncache_data_size;
    wire [31:0] duncache_data_addr;
    wire [31:0] duncache_data_wdata;
    wire [3 :0] duncache_data_wstrb;
    wire [31:0] duncache_data_rdata;
    wire        duncache_data_addr_ok;
    wire        duncache_data_data_ok;

    wire        storebuffer_data_req;
    wire        storebuffer_data_wr;
    wire [1 :0] storebuffer_data_size;
    wire [31:0] storebuffer_data_addr;
    wire [31:0] storebuffer_data_wdata;
    wire [3 :0] storebuffer_data_wstrb;
    wire [31:0] storebuffer_data_rdata;
    wire        storebuffer_data_addr_ok;
    wire        storebuffer_data_data_ok;
    
    assign cpu_inst_rdata = inst_src_queue[idata_pointer] ? cpu_inst_cache_rdata : cpu_inst_uncache_rdata;
    // assign cpu_data_rdata = data_src_queue[data_pointer] ? (buffer_data_cango ? cpu_dcache_buffer : cpu_data_cache_rdata) : cpu_data_uncache_rdata;
    assign cpu_data_rdata = data_src_queue[data_pointer] ?  cpu_data_cache_rdata : cpu_data_uncache_rdata;
    assign cpu_inst_data_ok = cpu_inst_cache_data_ok | cpu_inst_uncache_data_ok;
    assign cpu_data_data_ok = cpu_data_cache_data_ok | cpu_data_uncache_data_ok;
    // assign cpu_data_data_ok = cpu_data_cache_data_ok | cpu_data_uncache_data_ok | buffer_data_cango; // FIXIT
    assign cpu_inst_addr_ok = inst_cache ? cpu_inst_cache_addr_ok : cpu_inst_uncache_addr_ok;
    assign cpu_data_addr_ok = data_cache ? cpu_data_cache_addr_ok : cpu_data_uncache_addr_ok;
    
    assign inst_req_cango = (inst_cache==inst_src_queue[idata_pointer])?1'b1:(iaddr_pointer==idata_pointer);
    assign data_req_cango = (data_cache==data_src_queue[data_pointer])?1'b1:(addr_pointer==data_pointer);
        
    // assign inst_req_cango = 1'b1;
    // assign data_req_cango = 1'b1;
    
//    assign cpu_inst_data_ok = inst_src_queue[idata_pointer] ? cpu_inst_cache_data_ok : cpu_inst_uncache_data_ok;
//    assign cpu_data_data_ok = data_src_queue[data_pointer] ? cpu_data_cache_data_ok : cpu_data_uncache_data_ok;
//     assign cpu_inst_addr_ok = inst_cache ? cpu_inst_cache_addr_ok : ((iaddr_pointer==idata_pointer)?cpu_inst_uncache_addr_ok:1'b0);
//    assign cpu_data_addr_ok = data_cache ? cpu_data_cache_addr_ok : ((addr_pointer==data_pointer)?cpu_data_uncache_addr_ok:1'b0);

    // reg [31:0] cpu_dcache_buffer;
    // reg have_cache_data_to_transfer;
    reg [3:0]data_src_queue;
    reg [1:0]addr_pointer;
    reg [1:0]data_pointer;
    reg [3:0]inst_src_queue;
    reg [1:0]iaddr_pointer;
    reg [1:0]idata_pointer;

    // wire buffer_data_cango = have_cache_data_to_transfer & data_src_queue[data_pointer] == 1'b1;

    // always@(posedge aclk)begin
    //     if(!aresetn)
    //     begin
    //         have_cache_data_to_transfer<=1'b0;
    //     end 
    //     else 
    //     begin
    //         if((cpu_data_cache_data_ok & cpu_data_uncache_data_ok)|(cpu_data_cache_data_ok & (data_src_queue[data_pointer]!=1'b1)))
    //         //if two data comes at the same time / cache result comes before uncache data 
    //         //save it, and wait until uncache fimished 
    //         begin
    //             have_cache_data_to_transfer<=1'b1;
    //         end
    //         else
    //         if(buffer_data_cango)
    //         begin
    //             have_cache_data_to_transfer<=1'b0;
    //         end
    //     end
    // end

    // always@(posedge aclk)begin
    //     if(!aresetn)
    //     begin
    //         cpu_dcache_buffer<=32'b0;
    //     end 
    //     else 
    //     begin
    //         if((cpu_data_cache_data_ok & cpu_data_uncache_data_ok)|(cpu_data_cache_data_ok & (data_src_queue[data_pointer]!=1)))
    //         //if two data comes at the same time / cache result comes before uncache data 
    //         //save it, and wait until uncache fimished 
    //         begin
    //             cpu_dcache_buffer<=cpu_data_cache_rdata;
    //         end
    //     end
    // end

    always@(posedge aclk)begin
        if(!aresetn)begin
            addr_pointer<=2'b0;
            data_pointer<=2'b0;
            data_src_queue<=4'b0;
        end else begin
            if(cpu_data_addr_ok & cpu_data_req & data_req_cango)begin
                addr_pointer<=addr_pointer+1;
                data_src_queue[addr_pointer]<=data_cache;
            end
            if(cpu_data_data_ok)begin
                data_pointer<=data_pointer+1;
            end
        end
    end

    always@(posedge aclk)begin
        if(!aresetn)begin
            iaddr_pointer<=2'b0;
            idata_pointer<=2'b0;
            inst_src_queue<=4'b0;
        end else begin
            if(cpu_inst_addr_ok & cpu_inst_req & inst_req_cango)begin
                iaddr_pointer<=iaddr_pointer+1;
                inst_src_queue[iaddr_pointer]<=inst_cache;
            end
            if(cpu_inst_data_ok)begin
                idata_pointer<=idata_pointer+1;
            end
        end
    end
    
    mips_cpu cpu(
        .clk(aclk),
        .resetn(aresetn),
        .int(int),

        .inst_req(cpu_inst_req),
        .inst_addr(cpu_inst_addr),
        .inst_rdata(cpu_inst_rdata),
        .inst_addr_ok(cpu_inst_addr_ok & inst_req_cango),
        .inst_data_ok(cpu_inst_data_ok),

        .data_req(cpu_data_req),
        .data_wr(cpu_data_wr),
        .data_wstrb(cpu_data_wstrb),
        .data_addr(cpu_data_addr),
        .data_size(cpu_data_size),
        .data_wdata(cpu_data_wdata),
        .data_rdata(cpu_data_rdata),
        .data_addr_ok(cpu_data_addr_ok & data_req_cango),
        .data_data_ok(cpu_data_data_ok),

        .cache_req(cache_req),
        .cache_op(cache_op),
        .cache_tag(cache_tag),//TODO: not assigned!
        .cache_op_ok(cache_op_ok),

        .debug_wb_pc(debug_wb_pc),
        .debug_wb_rf_wen(debug_wb_rf_wen),
        .debug_wb_rf_wnum(debug_wb_rf_wnum),
        .debug_wb_rf_wdata(debug_wb_rf_wdata)
        
        `ifndef FORCE_INST_CACHE
        ,.inst_cache(cpu_inst_cache)//in func test, mark it as 1
        `endif
        `ifdef USE_DATA_CACHE
        ,.data_cache(data_cache)
        `endif
    );


    // store_buffer is enabled
   assign         storebuffer_data_req    = cpu_data_req & data_cache & data_req_cango;
   assign         storebuffer_data_wr     = cpu_data_wr ;
   assign         storebuffer_data_size   = cpu_data_size;
   assign         storebuffer_data_addr   = cpu_data_addr;
   assign         storebuffer_data_wdata  = cpu_data_wdata;
   assign         storebuffer_data_wstrb  = cpu_data_wstrb;
   assign         cpu_data_cache_rdata     = storebuffer_data_rdata;
   assign         cpu_data_cache_addr_ok   = storebuffer_data_addr_ok;
   assign         cpu_data_cache_data_ok   = storebuffer_data_data_ok;

    accelerator u_accelerator
    (
        .clk(aclk),
        .resetn(aresetn),
        .cpu_data_req(storebuffer_data_req)    ,
        .cpu_data_wr(storebuffer_data_wr)     ,
        .cpu_data_size(storebuffer_data_size)   ,
        .cpu_data_addr(storebuffer_data_addr)   ,
        .cpu_data_wdata(storebuffer_data_wdata)  ,
        .cpu_data_wstrb(storebuffer_data_wstrb)  ,
        .cpu_data_rdata(storebuffer_data_rdata)  ,
        .cpu_data_addr_ok(storebuffer_data_addr_ok),
        .cpu_data_data_ok(storebuffer_data_data_ok),
        .dcache_data_req(dcache_data_req)    ,
        .dcache_data_wr(dcache_data_wr)     ,
        .dcache_data_size(dcache_data_size)   ,
        .dcache_data_addr(dcache_data_addr)   ,
        .dcache_data_wdata(dcache_data_wdata)  ,
        .dcache_data_wstrb(dcache_data_wstrb)  ,
        .dcache_data_rdata(dcache_data_rdata)  ,
        .dcache_data_addr_ok(dcache_data_addr_ok),
        .dcache_data_data_ok(dcache_data_data_ok)
    );
    // cache_store_buffer is no longer used

    // assign dcache_data_req = storebuffer_data_req;
    // assign dcache_data_wr = storebuffer_data_wr;
    // assign dcache_data_size = storebuffer_data_size;
    // assign dcache_data_addr = storebuffer_data_addr;
    // assign dcache_data_wdata = storebuffer_data_wdata;
    // assign dcache_data_wstrb = storebuffer_data_wstrb;

    // assign storebuffer_data_rdata = dcache_data_rdata;
    // assign storebuffer_data_addr_ok = dcache_data_addr_ok;
    // assign storebuffer_data_data_ok = dcache_data_data_ok;

    store_buffer u_store_buffer
    (
        .clk(aclk),
        .resetn(aresetn),
        .cpu_data_req(cpu_data_req & (~data_cache) & data_req_cango)    ,
        .cpu_data_wr(cpu_data_wr)     ,
        .cpu_data_size(cpu_data_size)   ,
        .cpu_data_addr(cpu_data_addr)   ,
        .cpu_data_wdata(cpu_data_wdata)  ,
        .cpu_data_wstrb(cpu_data_wstrb)  ,
        .cpu_data_rdata(cpu_data_uncache_rdata)  ,
        .cpu_data_addr_ok(cpu_data_uncache_addr_ok),
        .cpu_data_data_ok(cpu_data_uncache_data_ok),
        .dcache_data_req(duncache_data_req)    ,
        .dcache_data_wr(duncache_data_wr)     ,
        .dcache_data_size(duncache_data_size)   ,
        .dcache_data_addr(duncache_data_addr)   ,
        .dcache_data_wdata(duncache_data_wdata)  ,
        .dcache_data_wstrb(duncache_data_wstrb)  ,
        .dcache_data_rdata(duncache_data_rdata)  ,
        .dcache_data_addr_ok(duncache_data_addr_ok),
        .dcache_data_data_ok(duncache_data_data_ok)
    );

    //dcache
    dcache u_dcache
    (
        ////basic
        .clk(aclk), 
        .resetn(aresetn), 

        .cache_req(cache_req),
        .cache_op(cache_op),
        .cache_op_ok(dcache_op_ok),

        ////axi_control
        //ar
        
        .arid         (dcache_arid             ),
        .araddr       (dcache_araddr           ),
        .arlen        (dcache_arlen            ),
        .arsize       (dcache_arsize           ),
        .arburst      (dcache_arburst          ),
        .arlock       (dcache_arlock           ),
        .arcache      (dcache_arcache          ),
        .arprot       (dcache_arprot           ),
        .arvalid      (dcache_arvalid          ),
        .arready      (dcache_arready          ),
        //r              
        .rid          (dcache_rid              ),
        .rdata        (dcache_rdata            ),
        .rresp        (dcache_rresp            ),
        .rlast        (dcache_rlast            ),
        .rvalid       (dcache_rvalid           ),
        .rready       (dcache_rready           ),
        //aw               
        .awid         (dcache_awid             ),
        .awaddr       (dcache_awaddr           ),
        .awlen        (dcache_awlen            ),
        .awsize       (dcache_awsize           ),
        .awburst      (dcache_awburst          ),
        .awlock       (dcache_awlock           ),
        .awcache      (dcache_awcache          ),
        .awprot       (dcache_awprot           ),
        .awvalid      (dcache_awvalid          ),
        .awready      (dcache_awready          ),
        //w               
        .wid          (dcache_wid              ),
        .wdata        (dcache_wdata            ),
        .wstrb        (dcache_wstrb            ),
        .wlast        (dcache_wlast            ),
        .wvalid       (dcache_wvalid           ),
        .wready       (dcache_wready           ),
        //b              
        .bid          (dcache_bid              ),
        .bresp        (dcache_bresp            ),
        .bvalid       (dcache_bvalid           ),
        .bready       (dcache_bready           ),

        ////cpu_control
        //------data sram-like-------
        .data_req          (dcache_data_req),
        .data_wr           (dcache_data_wr),
        .data_size         (dcache_data_size),
        .data_addr         (dcache_data_addr),
        .data_wdata        (dcache_data_wdata),
        .data_wstrb        (dcache_data_wstrb),
        .data_rdata        (dcache_data_rdata),
        .data_addr_ok      (dcache_data_addr_ok),
        .data_data_ok      (dcache_data_data_ok)

    );

    icache u_icache
    (
        ////basic
        .clk(aclk),   
        .resetn(aresetn),   

        .cache_req(cache_req),
        .cache_op(cache_op),
        .cache_op_ok(icache_op_ok),

        ////axi_control
        //ar
        
        .arid         (icache_arid             ),
        .araddr       (icache_araddr           ),
        .arlen        (icache_arlen            ),
        .arsize       (icache_arsize           ),
        .arburst      (icache_arburst          ),
        .arlock       (icache_arlock           ),
        .arcache      (icache_arcache          ),
        .arprot       (icache_arprot           ),
        .arvalid      (icache_arvalid          ),
        .arready      (icache_arready          ),
        //r              
        .rid          (icache_rid              ),
        .rdata        (icache_rdata            ),
        .rresp        (icache_rresp            ),
        .rlast        (icache_rlast            ),
        .rvalid       (icache_rvalid           ),
        .rready       (icache_rready           ),
        //aw               
        .awid         (icache_awid             ),
        .awaddr       (icache_awaddr           ),
        .awlen        (icache_awlen            ),
        .awsize       (icache_awsize           ),
        .awburst      (icache_awburst          ),
        .awlock       (icache_awlock           ),
        .awcache      (icache_awcache          ),
        .awprot       (icache_awprot           ),
        .awvalid      (icache_awvalid          ),
        .awready      (icache_awready          ),
        //w               
        .wid          (icache_wid              ),
        .wdata        (icache_wdata            ),
        .wstrb        (icache_wstrb            ),
        .wlast        (icache_wlast            ),
        .wvalid       (icache_wvalid           ),
        .wready       (icache_wready           ),
        //b              
        .bid          (icache_bid              ),
        .bresp        (icache_bresp            ),
        .bvalid       (icache_bvalid           ),
        .bready       (icache_bready           ),

        ////cpu_control
        //------inst sram-like-------
        .inst_req          (cpu_inst_req & inst_cache & inst_req_cango),
        .inst_wr           (1'b0             ),
        .inst_size         (1'b0             ),
        .inst_addr         (inst_phys_addr   ),
        .inst_wdata        (cpu_inst_wdata   ),
        .inst_rdata        (cpu_inst_cache_rdata   ),
        .inst_addr_ok      (cpu_inst_cache_addr_ok ),
        .inst_data_ok      (cpu_inst_cache_data_ok )

    );

    
    cpu_inst_axi_ifc u_cpu_inst_axi_ifc
    (
        .clk(aclk),
        .resetn(aresetn), 
        .arid(uncached_inst_arid),
        .araddr(uncached_inst_araddr),
        .arlen(uncached_inst_arlen),
        .arsize(uncached_inst_arsize),
        .arburst(uncached_inst_arburst),
        .arlock(uncached_inst_arlock),
        .arcache(uncached_inst_arcache),
        .arprot(uncached_inst_arprot),
        .arvalid(uncached_inst_arvalid),
        .arready(uncached_inst_arready),         
        .rid(uncached_inst_rid),
        .rdata(uncached_inst_rdata),
        .rresp(uncached_inst_rresp),
        .rlast(uncached_inst_rlast),
        .rvalid(uncached_inst_rvalid),
        .rready(uncached_inst_rready),
        .awid(uncached_inst_awid),
        .awaddr(uncached_inst_awaddr),
        .awlen(uncached_inst_awlen),
        .awsize(uncached_inst_awsize),
        .awburst(uncached_inst_awburst),
        .awlock(uncached_inst_awlock),
        .awcache(uncached_inst_awcache),
        .awprot(uncached_inst_awprot),
        .awvalid(uncached_inst_awvalid),
        .awready(uncached_inst_awready),
        .wid(uncached_inst_wid),
        .wdata(uncached_inst_wdata),
        .wstrb(uncached_inst_wstrb),
        .wlast(uncached_inst_wlast),
        .wvalid(uncached_inst_wvalid),
        .wready(uncached_inst_wready),
        .bid(uncached_inst_bid),
        .bresp(uncached_inst_bresp),
        .bvalid(uncached_inst_bvalid),
        .bready(uncached_inst_bready),

        //inst sram-like 
        .inst_req(cpu_inst_req & (!inst_cache) & inst_req_cango),
        .inst_wr(1'b0),
        .inst_size(2'b10),
        .inst_addr(cpu_inst_addr),
        .inst_wdata(32'b0),
        .inst_rdata(cpu_inst_uncache_rdata),
        .inst_addr_ok(cpu_inst_uncache_addr_ok),
        .inst_data_ok(cpu_inst_uncache_data_ok)
    );


    cpu_data_axi_ifc u_cpu_data_axi_ifc
    (
        .clk(aclk),
        .resetn(aresetn), 
        .arid(uncached_data_arid),
        .araddr(uncached_data_araddr),
        .arlen(uncached_data_arlen),
        .arsize(uncached_data_arsize),
        .arburst(uncached_data_arburst),
        .arlock(uncached_data_arlock),
        .arcache(uncached_data_arcache),
        .arprot(uncached_data_arprot),
        .arvalid(uncached_data_arvalid),
        .arready(uncached_data_arready),         
        .rid(uncached_data_rid),
        .rdata(uncached_data_rdata),
        .rresp(uncached_data_rresp),
        .rlast(uncached_data_rlast),
        .rvalid(uncached_data_rvalid),
        .rready(uncached_data_rready),
        .awid(uncached_data_awid),
        .awaddr(uncached_data_awaddr),
        .awlen(uncached_data_awlen),
        .awsize(uncached_data_awsize),
        .awburst(uncached_data_awburst),
        .awlock(uncached_data_awlock),
        .awcache(uncached_data_awcache),
        .awprot(uncached_data_awprot),
        .awvalid(uncached_data_awvalid),
        .awready(uncached_data_awready),
        .wid(uncached_data_wid),
        .wdata(uncached_data_wdata),
        .wstrb(uncached_data_wstrb),
        .wlast(uncached_data_wlast),
        .wvalid(uncached_data_wvalid),
        .wready(uncached_data_wready),
        .bid(uncached_data_bid),
        .bresp(uncached_data_bresp),
        .bvalid(uncached_data_bvalid),
        .bready(uncached_data_bready),

        //data sram-like 
        .data_req(duncache_data_req),
        .data_wr(duncache_data_wr),
        .data_size(duncache_data_size),
        .data_addr(duncache_data_addr),
        .data_wdata(duncache_data_wdata),
        .data_wstrb(duncache_data_wstrb),
        .data_rdata(duncache_data_rdata),
        .data_addr_ok(duncache_data_addr_ok),
        .data_data_ok(duncache_data_data_ok)
    );

    axi_cache_bridge u_axi_cache_bridge(

        .aclk             ( aclk              ), // i, 1                 
        .aresetn          ( aresetn           ), // i, 1                 

        .s_axi_arid       ( {dcache_arid, icache_arid, uncached_data_arid,uncached_inst_arid}        ),
        .s_axi_araddr     ( {dcache_araddr, icache_araddr, uncached_data_araddr,uncached_inst_araddr}      ),
        .s_axi_arlen      ( {dcache_arlen[3:0], icache_arlen[3:0], uncached_data_arlen[3:0], uncached_inst_arlen[3:0]}  ),
        .s_axi_arsize     ( {dcache_arsize, icache_arsize, uncached_data_arsize,3'b010}      ),
        .s_axi_arburst    ( {dcache_arburst, icache_arburst, uncached_data_arburst,uncached_inst_arburst}     ),
        .s_axi_arlock     ( {dcache_arlock, icache_arlock, uncached_data_arlock,uncached_inst_arlock}      ),
        .s_axi_arcache    ( {dcache_arcache, icache_arcache, uncached_data_arcache,uncached_inst_arcache}     ),
        .s_axi_arprot     ( {dcache_arprot, icache_arprot, uncached_data_arprot,uncached_inst_arprot}      ),
        .s_axi_arqos      ( {4'd0,4'd0,4'd0,4'd0}          ),
        .s_axi_arvalid    ( {dcache_arvalid, icache_arvalid, uncached_data_arvalid, uncached_inst_arvalid}     ),
        .s_axi_arready    ( {dcache_arready, icache_arready, uncached_data_arready, uncached_inst_arready}     ),
        .s_axi_rid        ( {dcache_rid, icache_rid, uncached_data_rid, uncached_inst_rid}         ),
        .s_axi_rdata      ( {dcache_rdata, icache_rdata, uncached_data_rdata, uncached_inst_rdata}       ),
        .s_axi_rresp      ( {dcache_rresp, icache_rresp, uncached_data_rresp, uncached_inst_rresp}       ),
        .s_axi_rlast      ( {dcache_rlast, icache_rlast, uncached_data_rlast, uncached_inst_rlast}       ),
        .s_axi_rvalid     ( {dcache_rvalid, icache_rvalid, uncached_data_rvalid, uncached_inst_rvalid}      ),
        .s_axi_rready     ( {dcache_rready, icache_rready, uncached_data_rready, uncached_inst_rready}      ),
        .s_axi_awid       ( {dcache_awid, icache_awid, uncached_data_awid, uncached_inst_awid}        ),
        .s_axi_awaddr     ( {dcache_awaddr, icache_awaddr, uncached_data_awaddr, 32'b0}      ),
        .s_axi_awlen      ( {dcache_awlen[3:0], icache_awlen[3:0], uncached_data_awlen[3:0], uncached_inst_awlen[3:0]}  ),
        .s_axi_awsize     ( {dcache_awsize, icache_awsize, uncached_data_awsize, uncached_inst_awsize}      ),
        .s_axi_awburst    ( {dcache_awburst, icache_awburst, uncached_data_awburst, uncached_inst_awburst}     ),
        .s_axi_awlock     ( {dcache_awlock, icache_awlock, uncached_data_awlock, uncached_inst_awlock}      ),
        .s_axi_awcache    ( {dcache_awcache, icache_awcache, uncached_data_awcache, uncached_inst_awcache}     ),
        .s_axi_awprot     ( {dcache_awprot, icache_awprot, uncached_data_awprot, uncached_inst_awprot}      ),
        .s_axi_awqos      ( {4'd0,4'd0,4'd0,4'd0}          ),
        .s_axi_awvalid    ( {dcache_awvalid, icache_awvalid, uncached_data_awvalid, uncached_inst_awvalid}     ),
        .s_axi_awready    ( {dcache_awready, icache_awready, uncached_data_awready, uncached_inst_awready}     ),
        .s_axi_wid        ( {dcache_wid, icache_wid, uncached_data_wid, uncached_inst_wid}         ),
        .s_axi_wdata      ( {dcache_wdata, icache_wdata, uncached_data_wdata, uncached_inst_wdata}       ),
        .s_axi_wstrb      ( {dcache_wstrb, icache_wstrb, uncached_data_wstrb, uncached_inst_wstrb}       ),
        .s_axi_wlast      ( {dcache_wlast, icache_wlast, uncached_data_wlast, uncached_inst_wlast}       ),
        .s_axi_wvalid     ( {dcache_wvalid, icache_wvalid, uncached_data_wvalid, uncached_inst_wvalid}      ),
        .s_axi_wready     ( {dcache_wready, icache_wready, uncached_data_wready, uncached_inst_wready}      ),
        .s_axi_bid        ( {dcache_bid, icache_bid, uncached_data_bid, uncached_inst_bid}         ),
        .s_axi_bresp      ( {dcache_bresp, icache_bresp, uncached_data_bresp, uncached_inst_bresp}       ),
        .s_axi_bvalid     ( {dcache_bvalid, icache_bvalid, uncached_data_bvalid, uncached_inst_bvalid}      ),
        .s_axi_bready     ( {dcache_bready, icache_bready, uncached_data_bready, uncached_inst_bready}      ),

        .m_axi_arid       (arid      ),
        .m_axi_araddr     (araddr_before    ),
        .m_axi_arlen      (arlen_before     ),
        .m_axi_arsize     (arsize    ),
        .m_axi_arburst    (arburst   ),
        .m_axi_arlock     (arlock    ),
        .m_axi_arcache    (arcache   ),
        .m_axi_arprot     (arprot    ),
        .m_axi_arqos      (          ),
        .m_axi_arvalid    (arvalid   ),
        .m_axi_arready    (arready   ),
        .m_axi_rid        (rid       ),
        .m_axi_rdata      (rdata     ),
        .m_axi_rresp      (rresp     ),
        .m_axi_rlast      (rlast     ),
        .m_axi_rvalid     (rvalid    ),
        .m_axi_rready     (rready    ),
        .m_axi_awid       (awid      ),
        .m_axi_awaddr     (awaddr_before    ),
        .m_axi_awlen      (awlen     ),
        .m_axi_awsize     (awsize    ),
        .m_axi_awburst    (awburst   ),
        .m_axi_awlock     (awlock    ),
        .m_axi_awcache    (awcache   ),
        .m_axi_awprot     (awprot    ),
        .m_axi_awqos      (          ),
        .m_axi_awvalid    (awvalid   ),
        .m_axi_awready    (awready   ),
        .m_axi_wid        (wid       ),
        .m_axi_wdata      (wdata     ),
        .m_axi_wstrb      (wstrb     ),
        .m_axi_wlast      (wlast     ),
        .m_axi_wvalid     (wvalid    ),
        .m_axi_wready     (wready    ),
        .m_axi_bid        (bid       ),
        .m_axi_bresp      (bresp     ),
        .m_axi_bvalid     (bvalid    ),
        .m_axi_bready     (bready    )

    );

    assign araddr = {araddr_before[31:0]};
    assign awaddr = {awaddr_before[31:0]};
    // assign araddr = {3'd0, araddr_before[28:0]};
    // assign awaddr = {3'd0, awaddr_before[28:0]};
    assign arlen  = {4'd0, arlen_before};

endmodule