`include "common.vh"

module fetch_stage(
    input               clk,
    input               resetn,
    
    // memory access interface
    output              inst_req,
    output              inst_cache,
    output  [31:0]      inst_addr,
    input               inst_addr_ok,
    input               inst_data_ok,
    
    // tlb
    input               tlb_write,
    output  [31:0]      tlb_vaddr,
    input   [31:0]      tlb_paddr,
    input               tlb_miss,
    input               tlb_invalid,
    input   [2:0]       tlb_cattr,
    
    input   [31:0]      status,
    input   [2:0]       config_k0,
    
    output              ready_o,
    input               valid_i,
    input   [31:0]      pc_i,
    input               ready_i,
    output reg          valid_o,
    output reg [31:0]   pc_o,
    output reg          cancelled_o,
    
    // exception interface
    output reg          exc_o,
    output reg          exc_miss_o,
    output reg [4:0]    exccode_o,
    input               commit_i,
    
    output              ok_to_branch,
    
    output reg [31:0]   perfcnt_fetch_waitreq
);
    
    // tlb query fsm (0=check/bypass, 1=query, 2=request)
    reg [1:0] qstate, qstate_next;
    
    // tlb query cache
    reg tlbc_valid; // indicates query cache validity
    reg [19:0] tlbc_vaddr_hi, tlbc_paddr_hi;
    reg tlbc_miss, tlbc_invalid;
    reg [2:0] tlbc_cattr;
    
    wire kseg01 = pc_i[31:30] == 2'b10;
    wire kseg0 = pc_i[31:29] == 3'b100;
    wire kseg = pc_i[31];
    wire kernelmode = !status[`STATUS_UM] || status[`STATUS_EXL];
    wire if_adel = pc_i[1:0] != 2'd0 || kseg && !kernelmode;
    wire tlbc_hit = tlbc_valid && tlbc_vaddr_hi == pc_i[31:12];
    
    always @(posedge clk) begin
        if (!resetn) qstate <= 2'd0;
        else qstate <= qstate_next;
    end
    
    always @(*) begin
        if (commit_i)   qstate_next = 2'd0;
        else begin
            case (qstate)
            // wait for ready_i before tlb lookup because pc_i might be changed by branch/jump instructions
            2'd0:       qstate_next = (kseg01 || tlbc_hit || !valid_i || !ready_i) ? 2'd0 : 2'd1;
            2'd1:       qstate_next = 2'd2;
            2'd2:       qstate_next = inst_addr_ok ? 2'd0 : 2'd2;
            default:    qstate_next = 2'd0;
            endcase
        end
    end
    
    // pc is saved for tlb lookup
    reg [31:0] pc_save;
    always @(posedge clk) /*if (qstate_next == 2'd1)*/ pc_save <= pc_i;
    
    assign tlb_vaddr = pc_save;
    
    always @(posedge clk) begin
        if (!resetn) tlbc_valid <= 1'b0;
        else if (tlb_write || commit_i) tlbc_valid <= 1'b0;
        else if (qstate == 2'd1) tlbc_valid <= 1'b1;
    end
    
    always @(posedge clk) begin
        if (!resetn) begin
            tlbc_vaddr_hi <= 20'd0;
            tlbc_paddr_hi <= 20'd0;
            tlbc_miss <= 1'b0;
            tlbc_invalid <= 1'b0;
            tlbc_cattr <= 3'd0;
        end
        else if (qstate == 2'd1) begin
            tlbc_vaddr_hi <= pc_save[31:12];
            tlbc_paddr_hi <= tlb_paddr[31:12];
            tlbc_miss <= tlb_miss;
            tlbc_invalid <= tlb_invalid;
            tlbc_cattr <= tlb_cattr;
        end
    end
    
    // exceptions
    // for exceptions raised in IF_req, wait until IF_wait is emptied and then output
    wire if_req_exc = qstate == 2'd0 && if_adel
                   || qstate == 2'd2 && (tlbc_miss || tlbc_invalid);
    
    wire req_state = qstate == 2'd0 && (kseg01 || tlbc_hit)
                  || qstate == 2'd2;
    
    reg req_flag;
    always @(posedge clk) begin
        if (!resetn) req_flag <= 1'b0;
        else if (inst_addr_ok) req_flag <= 1'b1;
        else if (inst_data_ok) req_flag <= 1'b0;
    end
    
    wire ok_to_req = !req_flag || inst_data_ok;
    
    assign inst_req         = valid_i && ok_to_req &&  !if_req_exc && req_state;
    assign inst_addr[31:12] = (qstate == 2'd0 && kseg01) ? {3'd0, pc_i[28:12]} : tlbc_paddr_hi;
    assign inst_addr[11:0]  = qstate == 2'd0 ? pc_i[11:0] : pc_save[11:0];
    assign inst_cache       = (qstate == 2'd0 && kseg01) ? (kseg0 && config_k0[0]) : tlbc_cattr[0];
    
    assign ready_o      = ready_i && (inst_addr_ok || if_req_exc);
    
    assign ok_to_branch = qstate == 2'd0;
    
    // Note: exception in IF_req must be passwd to ID after the instruction in IF_wait has been passed to ID
    always @(posedge clk) begin
        if (!resetn) begin
            valid_o     <= 1'b0;
            pc_o        <= 32'd0;
            cancelled_o <= 1'b0;
            exc_o       <= 1'b0;
            exc_miss_o  <= 1'b0;
            exccode_o   <= 5'd0;
        end
        else if (ready_i) begin
            valid_o     <= valid_i && inst_addr_ok || if_req_exc;
            pc_o        <= qstate == 2'd0 ? pc_i : pc_save;
            cancelled_o <= commit_i;
            exc_o       <= if_req_exc;
            exc_miss_o  <= (qstate == 2'd0 && tlbc_hit || qstate == 2'd2) && tlbc_miss;
            exccode_o   <= if_adel ? `EXC_ADEL : `EXC_TLBL;
        end
    end
    
    // performance counters
    always @(posedge clk) begin
        if (!resetn) perfcnt_fetch_waitreq <= 32'd0;
        else if (valid_i && inst_req && !inst_addr_ok) perfcnt_fetch_waitreq <= perfcnt_fetch_waitreq + 32'd1;
    end

endmodule