`timescale 10ns / 1ns

`include "common.vh"

module mips_cpu(
    input               clk,
    input               resetn,            //low active

    input   [5 :0]      int,

    output              inst_req,
    output              inst_cache,
    output  [31:0]      inst_addr,
    input   [31:0]      inst_rdata,
    input               inst_addr_ok,
    input               inst_data_ok,
    output              data_req,
    output              data_cache,
    output              data_wr,
    output  [3 :0]      data_wstrb,
    output  [31:0]      data_addr,
    output  [2 :0]      data_size,
    output  [31:0]      data_wdata,
    input   [31:0]      data_rdata,
    input               data_addr_ok,
    input               data_data_ok,
    
    output              cache_req,
    output  [6 :0]      cache_op,
    output  [31:0]      cache_tag,
    input               cache_op_ok,

    //debug interface
    output  [31:0]      debug_wb_pc,
    output  [3 :0]      debug_wb_rf_wen,
    output  [4 :0]      debug_wb_rf_wnum,
    output  [31:0]      debug_wb_rf_wdata
);
    
    wire int_sig;
    
    wire commit, commit_miss, commit_int, commit_bd, commit_eret;
    wire [4:0] commit_code;
    wire [1:0] commit_ce;
    wire [31:0] commit_epc, commit_bvaddr;
    
    wire cp0_w;
    wire [31:0] cp0_wdata, cp0_rdata;
    wire [7:0] cp0_addr;
    
    wire [31:0] cp0_index, cp0_random, cp0_entrylo0, cp0_entrylo1, cp0_entryhi;
    wire [11:0] cp0_mask;
    wire [31:0] cp0_status, cp0_cause, cp0_epc;
    wire [2:0] config_k0;
    
    wire tlbr, tlbwi, tlbwr, tlbp;
    wire [31:0] tlbr_lo0, tlbr_lo1, tlbr_hi, tlbp_index;
    wire [11:0] tlbr_mask;
    
    cp0regs u_cp0regs(
        .clk            (clk),
        .resetn         (resetn),
        .int            (int),
        .int_sig        (int_sig),
        .mtc0           (cp0_w),
        .mtc0_data      (cp0_wdata),
        .mfc0_data      (cp0_rdata),
        .addr           (cp0_addr),
        .tlbr           (tlbr),
        .tlbr_lo0       (tlbr_lo0),
        .tlbr_lo1       (tlbr_lo1),
        .tlbr_hi        (tlbr_hi),
        .tlbr_mask      (tlbr_mask),
        .tlbwr          (tlbwr),
        .tlbp           (tlbp),
        .tlbp_index     (tlbp_index),
        .commit_exc     (commit),
        .commit_code    (commit_code),
        .commit_bd      (commit_bd),
        .commit_ce      (commit_ce),
        .commit_epc     (commit_epc),
        .commit_bvaddr  (commit_bvaddr),
        .commit_eret    (commit_eret),
        .index          (cp0_index),
        .random         (cp0_random),
        .entrylo0       (cp0_entrylo0),
        .entrylo1       (cp0_entrylo1),
        .mask           (cp0_mask),
        .entryhi        (cp0_entryhi),
        .status         (cp0_status),
        .cause          (cp0_cause),
        .epc            (cp0_epc),
        .config_k0      (config_k0),
        .taglo          (cache_tag)
    );
    
    // Address Translation
    wire [31:0] inst_vaddr, data_vaddr;
    wire [31:0] inst_paddr, data_paddr;
    wire [2:0] inst_cattr, data_cattr;
    wire inst_miss, data_miss;
    wire inst_invalid, data_invalid;
    wire data_dirty;
    
    wire [`TLB_IDXBITS-1:0] tlbw_idx = tlbwr ? cp0_random[`TLB_IDXBITS-1:0] : cp0_index[`TLB_IDXBITS-1:0];
    
    tlb u_tlb(
        .clk            (clk),
        .resetn         (resetn),
        .write          (tlbwi||tlbwr),
        .idx            (tlbw_idx), // TODO: Random
        .mask           (cp0_mask),
        .entryhi        (cp0_entryhi),
        .entrylo0       (cp0_entrylo0),
        .entrylo1       (cp0_entrylo1),
        .read_lo0       (tlbr_lo0),
        .read_lo1       (tlbr_lo1),
        .read_hi        (tlbr_hi),
        .read_mask      (tlbr_mask),
        .probe_index    (tlbp_index),
        .inst_vaddr     (inst_vaddr),
        .inst_paddr     (inst_paddr),
        .inst_cache     (inst_cattr),
        .inst_miss      (inst_miss),
        .inst_invalid   (inst_invalid),
        .data_vaddr     (data_vaddr),
        .data_paddr     (data_paddr),
        .data_cache     (data_cattr),
        .data_miss      (data_miss),
        .data_invalid   (data_invalid),
        .data_dirty     (data_dirty)
    );
    
    //////////////////// IF ////////////////////
    
    wire if_valid;
    wire if_ready;
    wire [31:0] if_pc;
    wire if_id_valid, id_if_ready;
    wire [31:0] if_id_pc;
    wire if_id_cancelled, if_id_exc, if_id_exc_miss;
    wire [4:0] if_id_exccode;
    
    wire ok_to_branch;
    wire branch, blikely_clear;
    wire [31:0] branch_pc;
    
    wire bev = cp0_status[`STATUS_BEV];
    wire exl = cp0_status[`STATUS_EXL];
    wire iv  = cp0_cause [`CAUSE_IV];
    wire [31:0] vector_miss     = {32{!bev&&!exl}} & `VEC_REFILL
                                | {32{!bev&& exl}} & `VEC_REFILL_EXL
                                | {32{ bev&&!exl}} & `VEC_REFILL_BEV
                                | {32{ bev&& exl}} & `VEC_REFILL_BEV_EXL;
    wire [31:0] vector_intr     = {32{!bev&&!iv }} & `VEC_INTR
                                | {32{!bev&& iv }} & `VEC_INTR_IV
                                | {32{ bev&&!iv }} & `VEC_INTR_BEV
                                | {32{ bev&& iv }} & `VEC_INTR_BEV_IV;
    wire [31:0] vector_other    = {32{!bev      }} & `VEC_OTHER
                                | {32{ bev      }} & `VEC_OTHER_BEV;
    wire [31:0] vector          = commit_eret ? cp0_epc
                                : commit_miss ? vector_miss
                                : commit_int  ? vector_intr
                                : vector_other;
    
    reg [31:0] pc;
    (*keep = "true"*)wire [31:0] next_pc = if_pc + 32'd4;
    always @(posedge clk) begin
        if (!resetn) pc <= `VEC_RESET;
        else if (commit) pc <= vector;
        else if (if_ready) pc <= next_pc;
        else pc <= if_pc;
    end
    
    assign if_valid = 1'b1;
    
    assign if_pc = branch ? branch_pc : pc;
    
    fetch_stage fetch(
        .clk            (clk),
        .resetn         (resetn),
        .inst_req       (inst_req),
        .inst_cache     (inst_cache),
        .inst_addr      (inst_addr),
        .inst_addr_ok   (inst_addr_ok),
        .inst_data_ok   (inst_data_ok),
        .tlb_write      (tlbwi||tlbwr),
        .tlb_vaddr      (inst_vaddr),
        .tlb_paddr      (inst_paddr),
        .tlb_miss       (inst_miss),
        .tlb_invalid    (inst_invalid),
        .tlb_cattr      (inst_cattr),
        .status         (cp0_status),
        .config_k0      (config_k0),
        .ready_o        (if_ready),
        .valid_i        (if_valid),
        .pc_i           (if_pc),
        .ready_i        (id_if_ready),
        .valid_o        (if_id_valid),
        .pc_o           (if_id_pc),
        .cancelled_o    (if_id_cancelled),
        .exc_o          (if_id_exc),
        .exc_miss_o     (if_id_exc_miss),
        .exccode_o      (if_id_exccode),
        .commit_i       (commit),
        .ok_to_branch   (ok_to_branch)
    );
    
    //////////////////// ID ////////////////////
    
    // reg file
    wire [4:0] rf_raddr1, rf_raddr2, rf_waddr;
    wire [31:0] rf_rdata1, rf_rdata2, rf_wdata;
    wire rf_wen;
    reg_file rf(
       .clk         (clk),
	   .waddr      (rf_waddr),
	   .raddr1     (rf_raddr1),
	   .raddr2     (rf_raddr2),
	   .wen        (rf_wen),
	   .wdata      (rf_wdata),
	   .rdata1     (rf_rdata1),
	   .rdata2     (rf_rdata2)
    );
    
    wire [4:0] ex_fwd_addr, wb_fwd_addr;
    wire [31:0] ex_fwd_data, wb_fwd_data;
    wire ex_fwd_ok, wb_fwd_ok;
    
    wire id_ex_valid, ex_id_ready, id_done;
    wire [31:0] id_ex_pc, id_ex_inst;
    wire [`LDECBITS] id_ex_decoded;
    wire [31:0] id_ex_rdata1, id_ex_rdata2, id_ex_pc_j, id_ex_pc_b;
    wire id_ex_exc, id_ex_exc_miss, id_ex_exc_int;
    wire [4:0] id_ex_exccode;
    
    decode_stage decode(
        .clk            (clk),
        .resetn         (resetn),
        .inst_rdata     (inst_rdata),
        .inst_data_ok   (inst_data_ok),
        .rf_raddr1      (rf_raddr1),
        .rf_raddr2      (rf_raddr2),
        .rf_rdata1      (rf_rdata1),
        .rf_rdata2      (rf_rdata2),
        .ex_fwd_addr    (ex_fwd_addr),
        .ex_fwd_data    (ex_fwd_data),
        .ex_fwd_ok      (ex_fwd_ok),
        .wb_fwd_addr    (wb_fwd_addr),
        .wb_fwd_data    (wb_fwd_data),
        .wb_fwd_ok      (wb_fwd_ok),
        .int_sig        (int_sig),
        .done_o         (id_done),
        .valid_i        (if_id_valid),
        .pc_i           (if_id_pc),
        .cancelled_i    (if_id_cancelled),
        .ready_i        (ex_id_ready),
        .valid_o        (id_ex_valid),
        .pc_o           (id_ex_pc),
        .inst_o         (id_ex_inst),
        .decoded_o      (id_ex_decoded),
        .rdata1_o       (id_ex_rdata1),
        .rdata2_o       (id_ex_rdata2),
        .pc_j_o         (id_ex_pc_j),
        .pc_b_o         (id_ex_pc_b),
        .exc_i          (if_id_exc),
        .exc_miss_i     (if_id_exc_miss),
        .exccode_i      (if_id_exccode),
        .exc_o          (id_ex_exc),
        .exc_miss_o     (id_ex_exc_miss),
        .exc_int_o      (id_ex_exc_int),
        .exccode_o      (id_ex_exccode),
        .cancel_i       (commit||blikely_clear)
    );
    
    //////////////////// EX ////////////////////
    
    wire ex_wb_valid, wb_ex_ready, ex_done;
    wire [31:0] ex_wb_pc, ex_wb_inst;
    wire [`I_MAX-1:0] ex_wb_ctrl;
    wire [31:0] ex_wb_result, ex_wb_eaddr, ex_wb_rdata2;
    wire [4:0] ex_wb_waddr;
    
    execute_stage execute(
        .clk            (clk),
        .resetn         (resetn),
        .data_req       (data_req),
        .data_cache     (data_cache),
        .data_wr        (data_wr),
        .data_wstrb     (data_wstrb),
        .data_addr      (data_addr),
        .data_size      (data_size),
        .data_wdata     (data_wdata),
        .data_addr_ok   (data_addr_ok),
        .data_data_ok   (data_data_ok),
        .branch         (branch),
        .branch_ready   (if_id_valid && ok_to_branch),
        .blikely_clear  (blikely_clear),
        .target_pc      (branch_pc),
        .tlb_vaddr      (data_vaddr),
        .tlb_paddr      (data_paddr),
        .tlb_miss       (data_miss),
        .tlb_invalid    (data_invalid),
        .tlb_dirty      (data_dirty),
        .tlb_cattr      (data_cattr),
        .cache_req      (cache_req),
        .cache_op       (cache_op),
        .cache_op_ok    (cache_op_ok),
        .status         (cp0_status),
        .config_k0      (config_k0),
        .fwd_addr       (ex_fwd_addr),
        .fwd_data       (ex_fwd_data),
        .fwd_ok         (ex_fwd_ok),
        .cp0_w          (cp0_w),
        .cp0_wdata      (cp0_wdata),
        .cp0_rdata      (cp0_rdata),
        .cp0_addr       (cp0_addr),
        .tlbr           (tlbr),
        .tlbwi          (tlbwi),
        .tlbwr          (tlbwr),
        .tlbp           (tlbp),
        .done_o         (ex_done),
        .valid_i        (id_ex_valid),
        .pc_i           (id_ex_pc),
        .inst_i         (id_ex_inst),
        .decoded_i      (id_ex_decoded),
        .rdata1_i       (id_ex_rdata1),
        .rdata2_i       (id_ex_rdata2),
        .pc_j_i         (id_ex_pc_j),
        .pc_b_i         (id_ex_pc_b),
        .ready_i        (wb_ex_ready),
        .valid_o        (ex_wb_valid),
        .pc_o           (ex_wb_pc),
        .inst_o         (ex_wb_inst),
        .ctrl_o         (ex_wb_ctrl),
        .result_o       (ex_wb_result),
        .eaddr_o        (ex_wb_eaddr),            
        .rdata2_o       (ex_wb_rdata2),
        .waddr_o        (ex_wb_waddr),
        .exc_i          (id_ex_exc),
        .exc_miss_i     (id_ex_exc_miss),
        .exc_int_i      (id_ex_exc_int),
        .exccode_i      (id_ex_exccode),
        .commit         (commit),
        .commit_miss    (commit_miss),
        .commit_int     (commit_int),
        .commit_code    (commit_code),
        .commit_bd      (commit_bd),
        .commit_ce      (commit_ce),
        .commit_epc     (commit_epc),
        .commit_bvaddr  (commit_bvaddr),
        .commit_eret    (commit_eret)
    );
    
    //////////////////// WB ////////////////////
    
    wire wb_done;
    
    writeback_stage writeback(
        .clk            (clk),
        .resetn         (resetn),
        .data_rdata     (data_rdata),
        .data_data_ok   (data_data_ok),
        .rf_wen         (rf_wen),
        .rf_waddr       (rf_waddr),
        .rf_wdata       (rf_wdata),
        .done_o         (wb_done),
        .valid_i        (ex_wb_valid),
        .pc_i           (ex_wb_pc),
        .inst_i         (ex_wb_inst),
        .ctrl_i         (ex_wb_ctrl),
        .result_i       (ex_wb_result),
        .eaddr_i        (ex_wb_eaddr), 
        .rdata2_i       (ex_wb_rdata2),
        .waddr_i        (ex_wb_waddr)
    );
    
    assign wb_fwd_addr  = {5{ex_wb_valid}} & rf_waddr;
    assign wb_fwd_data  = rf_wdata;
    assign wb_fwd_ok    = rf_wen;
    
    ///// stall control /////
    /*
    assign wb_ex_ready = wb_done || !ex_wb_valid;
    assign ex_id_ready = ex_done && wb_ex_ready || !id_ex_valid;
    assign id_if_ready = id_done && ex_id_ready || !if_id_valid;
    */
    assign wb_ex_ready = wb_done || !ex_wb_valid;
    assign ex_id_ready = ex_done && wb_done || ex_done && !ex_wb_valid || !id_ex_valid;
    assign id_if_ready = id_done && ex_done && wb_done || id_done && ex_done && !ex_wb_valid || id_done && !id_ex_valid || !if_id_valid;
    
    assign debug_wb_pc          = ex_wb_pc;
    assign debug_wb_rf_wen      = {4{rf_wen}};
    assign debug_wb_rf_wnum     = rf_waddr;
    assign debug_wb_rf_wdata    = rf_wdata;

endmodule

