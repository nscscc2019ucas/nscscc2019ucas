`include "common.vh"

module execute_stage(
    input                       clk,
    input                       resetn,

    // memory access interface
    output                      data_req,
    output                      data_cache,
    output                      data_wr,
    output  [3 :0]              data_wstrb,
    output  [31:0]              data_addr,
    output  [2 :0]              data_size,
    output  [31:0]              data_wdata,
    input                       data_addr_ok,
    input                       data_data_ok,
    
    // branch/jump signals
    output                      branch,
    input                       branch_ready,
    output                      blikely_clear,
    output  [31:0]              target_pc,
    
    // tlb
    output  [31:0]              tlb_vaddr,
    input   [31:0]              tlb_paddr,
    input                       tlb_miss,
    input                       tlb_invalid,
    input                       tlb_dirty,
    input   [2 :0]              tlb_cattr,
    
    input   [31:0]              status,
    input   [2: 0]              config_k0,
    
    // data forwarding
    output  [4 :0]              fwd_addr,
    output  [31:0]              fwd_data,
    output                      fwd_ok,      // whether data is generated after ex stage
    
    // mtc0/mfc0
    output                      cp0_w,
    output  [31:0]              cp0_wdata,
    input   [31:0]              cp0_rdata,
    output  [7 :0]              cp0_addr,
    
    // tlb read/write
    output                      tlbr,
    output                      tlbwi,
    output                      tlbwr,
    output                      tlbp,
    
    // cache op
    output                      cache_req,
    output  [6 :0]              cache_op,
    input                       cache_op_ok,

    output                      done_o,
    input                       valid_i,
    input   [31:0]              pc_i,
    input   [31:0]              inst_i,
    input   [`LDECBITS]         decoded_i,
    input   [31:0]              rdata1_i,
    input   [31:0]              rdata2_i,
    input   [31:0]              pc_j_i,
    input   [31:0]              pc_b_i,
    input                       ready_i,
    output reg                  valid_o,
    output reg [31:0]           pc_o,
    output reg [31:0]           inst_o,
    output reg [`I_MAX-1:0]     ctrl_o,
    output reg [31:0]           result_o,
    output reg [31:0]           eaddr_o,
    output reg [31:0]           rdata2_o,
    output reg [4 :0]           waddr_o,
    
    // exception interface
    input                       exc_i,
    input                       exc_miss_i,
    input                       exc_int_i,
    input   [4 :0]              exccode_i,
    output                      commit,
    output                      commit_miss,
    output                      commit_int,
    output  [4 :0]              commit_code,
    output                      commit_bd,
    output  [1 :0]              commit_ce,
    output  [31:0]              commit_epc,
    output  [31:0]              commit_bvaddr,
    output                      commit_eret,
    
    output reg [31:0]           perfcnt_load_waitreq,
    output reg [31:0]           perfcnt_store_waitreq
);

    wire valid;
    reg done;

    assign valid = valid_i && !done && !exc_i;
    
    ////////// post-decode //////////
    
    wire `DECODED_OPS;
    
    assign {`DECODED_OPS} = decoded_i;
    
    wire [`I_MAX-1:0] ctrl_sig;
    
    wire reserved = ~|decoded_i;
    
    // Coprocessor 0 unavailable
    
    wire cp0_inst = op_mfc0||op_mtc0||op_tlbr||op_tlbwi||op_tlbwr||op_tlbp||op_eret||op_wait||op_cache;
    wire cp0_avail = status[`STATUS_CU0] || !status[`STATUS_UM] || status[`STATUS_EXL];
    wire cp0u = cp0_inst && !cp0_avail;
    wire cp1u = op_movft||op_cop1||op_lwc1||op_ldc1||op_swc1||op_sdc1;
    wire cpxu = cp0u || cp1u;
    
    // LLbit
    reg llbit;
    always @(posedge clk) begin
        if (!resetn) llbit <= 1'b0;
        else if (commit && commit_eret) llbit <= 1'b0;
        else if (valid && op_ll) llbit <= 1'b1;
    end
    
    // conditional move
    wire cond_move                = op_movz && rdata2_i == 32'd0 || op_movn && rdata2_i != 32'd0;
    // write data to [rt] generated in ex stage
    wire inst_rt_wex              = op_addi||op_addiu||op_slti||op_sltiu||op_andi||op_ori||op_xori||op_lui||op_mfc0||op_clz||op_clo||op_sc;
    // write data to [rt] generated in wb stage
    wire inst_rt_wwb              = ctrl_sig[`I_MEM_R];
    // write data to [rd] generated in ex stage
    wire inst_rd_wex              = op_sll||op_srl||op_sra||op_sllv||op_srlv||op_srav||op_jr||op_jalr||op_mfhi||op_mflo||
                                    op_add||op_addu||op_sub||op_subu||op_and||op_or||op_xor||op_nor||op_slt||op_sltu||op_mul||cond_move;
    // write data to [31] generated in ex stage
    wire inst_r31_wex             = op_bltzal||op_bgezal||op_bltzall||op_bgezall||op_jal;
    
    assign ctrl_sig[`I_LB]        = op_lb;
    assign ctrl_sig[`I_LH]        = op_lh;
    assign ctrl_sig[`I_LWL]       = op_lwl;
    assign ctrl_sig[`I_LW]        = op_lw||op_ll;
    assign ctrl_sig[`I_LBU]       = op_lbu;
    assign ctrl_sig[`I_LHU]       = op_lhu;
    assign ctrl_sig[`I_LWR]       = op_lwr;
    assign ctrl_sig[`I_SB]        = op_sb;
    assign ctrl_sig[`I_SH]        = op_sh;
    assign ctrl_sig[`I_SWL]       = op_swl;
    assign ctrl_sig[`I_SW]        = op_sw;
    assign ctrl_sig[`I_SWR]       = op_swr;
    
    // load instruction
    assign ctrl_sig[`I_MEM_R]     = op_lb||op_lh||op_lwl||op_lw||op_lbu||op_lhu||op_lwr||op_ll;
    // store instruction
    assign ctrl_sig[`I_MEM_W]     = op_sb||op_sh||op_swl||op_sw||op_swr||op_sc&&llbit;
    // write data generated in ex stage
    assign ctrl_sig[`I_WEX]       = inst_rt_wex||inst_rd_wex||inst_r31_wex;
    // write data generated in wb stage
    assign ctrl_sig[`I_WWB]       = inst_rt_wwb;
    // imm is sign-extended
    wire imm_is_sx  = !(op_andi||op_ori||op_xori);
    // alu operand a is sa
    wire alu_a_sa   = op_sll||op_srl||op_sra;
    // alu operand b is imm
    wire alu_b_imm  = op_addi||op_addiu||op_slti||op_sltiu||op_andi||op_ori||op_xori||ctrl_sig[`I_MEM_R]||ctrl_sig[`I_MEM_W];
    wire do_link    = op_jal||op_jalr||op_bgezal||op_bltzal||op_bgezall||op_bltzall;
    wire exc_on_of  = op_add || op_sub || op_addi;
    
    wire do_bne     = op_bne||op_bnel;
    wire do_beq     = op_beq||op_beql;
    wire do_bgez    = op_bgez||op_bgezl||op_bgezal||op_bgezall;
    wire do_blez    = op_blez||op_blezl;
    wire do_bgtz    = op_bgtz||op_bgtzl;
    wire do_bltz    = op_bltz||op_bltzl||op_bltzal||op_bltzall;
    wire do_j       = op_j||op_jal;
    wire do_jr      = op_jr||op_jalr;
    wire likely     = op_bltzl||op_bgezl||op_bltzall||op_bgezall||op_beql||op_bnel||op_blezl||op_bgtzl;
    
    wire [4:0] waddr = {5{inst_rt_wex||inst_rt_wwb}}    & `GET_RT(inst_i)
                     | {5{inst_rd_wex}}                 & `GET_RD(inst_i)
                     | {5{inst_r31_wex}}                & 5'd31;

    // imm extension
    wire [15:0] imm = `GET_IMM(inst_i);
    wire [31:0] imm_sx = {{16{imm[15]}}, imm};
    wire [31:0] imm_zx = {16'd0, imm};
    wire [31:0] imm_32 = imm_is_sx ? imm_sx : imm_zx;
    
    // ALU operation
    wire [10:0] alu_op;
    assign alu_op[`ALU_ADD]   = op_add||op_addu||op_addi||op_addiu;
    assign alu_op[`ALU_SUB]   = op_sub||op_subu;
    assign alu_op[`ALU_AND]   = op_and||op_andi;
    assign alu_op[`ALU_OR]    = op_or||op_ori;
    assign alu_op[`ALU_XOR]   = op_xor||op_xori;
    assign alu_op[`ALU_NOR]   = op_nor;
    assign alu_op[`ALU_SLT]   = op_slt||op_slti;
    assign alu_op[`ALU_SLTU]  = op_sltu||op_sltiu;
    assign alu_op[`ALU_SLL]   = op_sll||op_sllv;
    assign alu_op[`ALU_SRL]   = op_srl||op_srlv;
    assign alu_op[`ALU_SRA]   = op_sra||op_srav;
    
    // ALU module
    wire [31:0] alu_a, alu_b, alu_res_wire;
    wire alu_of;
    alu alu_instance(
        .A          (alu_a),
        .B          (alu_b),
        .ALUop      (alu_op),
        .CarryOut   (),
        .Overflow   (alu_of),
        .Zero       (),
        .Result     (alu_res_wire)
    );

    // select operand sources
    assign alu_a = alu_a_sa ? {27'd0, `GET_SA(inst_i)} : rdata1_i;
    assign alu_b = alu_b_imm ? imm_32 : rdata2_i;
    
    wire alu_of_exc = exc_on_of && alu_of;
    
    // trap test
    wire trap_b_imm = op_tgei||op_tgeiu||op_tlti||op_tltiu||op_teqi||op_tnei;
    wire [31:0] trap_a = rdata1_i;
    wire [31:0] trap_b = trap_b_imm ? imm_sx : rdata2_i;
    wire [32:0] trap_res = trap_a - trap_b;
    wire trap_ge    = ~(trap_a[31] ^ trap_b[31] ^ trap_res[32]);
    wire trap_geu   = ~trap_res[32];
    wire trap_lt    = trap_a[31] ^ trap_b[31] ^ trap_res[32];
    wire trap_ltu   = trap_res[32];
    wire trap_eq    = ~|(trap_a ^ trap_b);
    wire trap_ne    = |(trap_a ^ trap_b);
    wire trap       = op_tge && trap_ge
                   || op_tgei && trap_ge
                   || op_tgeu && trap_geu
                   || op_tgeiu && trap_geu
                   || op_tlt && trap_lt
                   || op_tlti && trap_lt
                   || op_tltu && trap_ltu
                   || op_tltiu && trap_ltu
                   || op_teq && trap_eq
                   || op_teqi && trap_eq
                   || op_tne && trap_ne
                   || op_tnei && trap_ne;

    reg muldiv; // async mul or div in progreses
    
    // multiplication
    // the multiplier is divided into 3 stages
    wire [63:0] mul_res;
    reg [1:0] mul_flag;
    reg [1:0] maddsub_flag;
    reg maddsub;
    reg mul_start;
    always @(posedge clk) begin
        if (!resetn) mul_flag <= 2'b00;
        else if ((op_div||op_divu) && valid) mul_flag <= 2'b00;
        else mul_flag <= {mul_flag[0], (op_mult||op_multu||op_mul) && valid && !mul_start};
        
        if (!resetn) maddsub_flag <= 2'b00;
        else if ((op_div||op_divu||op_mult||op_multu) && valid) maddsub_flag <= 2'b00;
        else maddsub_flag <= {maddsub_flag[0:0], (op_madd||op_maddu||op_msub||op_msubu) && valid && !mul_start && !muldiv};
        
        if (op_madd||op_maddu||op_msub||op_msubu) maddsub <= op_madd||op_maddu;
        
        if (!resetn) mul_start <= 1'b0;
        else if (done_o && ready_i) mul_start <= 1'b0;
        else if ((op_mult||op_multu||op_mul||!muldiv&&(op_madd||op_maddu||op_msub||op_msubu)) && valid) mul_start <= 1'b1;
    end
    
    mul u_mul(
        .mul_clk(clk),
        .resetn(resetn),
        .mul_signed(op_mult||op_mul||op_madd||op_msub),
        .x(rdata1_i),
        .y(rdata2_i),
        .result(mul_res)
    );
    
    // division
    wire [31:0] div_s, div_r;
    wire div_complete;
    div u_div(
        .div_clk(clk),
        .resetn(resetn),
        .div((op_div||op_divu) && valid),
        .div_signed(op_div),
        .x(rdata1_i),
        .y(rdata2_i),
        .s(div_s),
        .r(div_r),
        .complete(div_complete),
        .cancel((op_mult||op_multu) && valid)
    );
    
    always @(posedge clk) begin
        if (!resetn) muldiv <= 1'b0;
        else if (mul_flag[0] || maddsub_flag[1] || div_complete) muldiv <= 1'b0;
        else if ((op_mult||op_multu||op_div||op_divu||op_madd||op_maddu||op_msub||op_msubu) && valid) muldiv <= 1'b1;
    end
    
    reg [63:0] maddsub_temp;
    always @(posedge clk) if (maddsub_flag[0]) maddsub_temp <= mul_res;
    
    // HI/LO registers
    reg [31:0] hi, lo;
    always @(posedge clk) begin
        if (mul_flag[0]) begin
            hi <= mul_res[63:32];
            lo <= mul_res[31:0];
        end
        else if (maddsub_flag[1]) begin
            {hi, lo} <= maddsub ? {hi, lo} + maddsub_temp : {hi, lo} - maddsub_temp;
        end
        else if (div_complete) begin
            hi <= div_r;
            lo <= div_s;
        end
        else begin
            if (valid && op_mthi) hi <= rdata1_i;
            if (valid && op_mtlo) lo <= rdata1_i;
        end
    end
    
    // clz/clo
    reg clo_start;
    reg [31:0] clo_data, clo_result;
    reg [4 :0] clo_cnt;
    wire do_cloz = op_clo||op_clz;
    
    always @(posedge clk) begin
        if (!resetn) clo_start <= 1'b0;
        else if (done_o && ready_i) clo_start <= 1'b0;
        else if (valid && do_cloz) clo_start <= 1'b1;
        
        if (!resetn) clo_cnt <= 5'd0;
        else if (valid && do_cloz && !clo_start) clo_cnt <= 5'd0;
        else if (clo_start) clo_cnt <= clo_cnt + 5'd1;
        
        if (!resetn) clo_data <= 32'd0;
        else if (valid && do_cloz && !clo_start) clo_data <= op_clo ? rdata1_i : ~rdata1_i;
        else if (clo_start) clo_data <= clo_data << 1;
        
        if (!resetn) clo_result <= 32'd0;
        else if (valid && do_cloz && !clo_start) clo_result <= 32'd0;
        else if (clo_start && clo_data[31]) clo_result <= clo_result + 32'd1;
    end
    
    wire cloz_ok = clo_start && ~clo_data[31];
    
    // branch test
    wire branch_taken   = (do_bne && (rdata1_i != rdata2_i))
                       || (do_beq && (rdata1_i == rdata2_i))
                       || (do_bgez && !rdata1_i[31])
                       || (do_blez && (rdata1_i[31] || rdata1_i == 32'd0))
                       || (do_bgtz && !(rdata1_i[31] || rdata1_i == 32'd0))
                       || (do_bltz && rdata1_i[31]);

    assign branch           = valid && branch_ready && (do_j||do_jr||branch_taken);
    assign blikely_clear    = valid && branch_ready && likely && !branch_taken;
    
    assign target_pc    = {32{!(do_j||do_jr)}} & pc_b_i
                        | {32{do_jr}} & rdata1_i
                        | {32{do_j}} & pc_j_i;
    
    // mtc0/mfc0
    assign cp0_w = valid && !cp0u && op_mtc0;
    assign cp0_wdata = rdata2_i;
    assign cp0_addr = {`GET_RD(inst_i), inst_i[2:0]};
    
    // tlb instructions
    assign tlbr = valid && !cp0u && op_tlbr;
    assign tlbwi = valid && !cp0u && op_tlbwi;
    assign tlbwr = valid && !cp0u && op_tlbwr;
    assign tlbp = valid && !cp0u && op_tlbp;
    
    ///// memory access request /////
    
    // tlb query fsm (0=check/bypass, 1=query, 2=request)
    reg [1:0] qstate, qstate_next;
    
    // tlb query cache
    reg tlbc_valid; // indicates query cache validity
    reg [19:0] tlbc_vaddr_hi, tlbc_paddr_hi;
    reg tlbc_miss, tlbc_invalid, tlbc_dirty;
    reg [2:0] tlbc_cattr;
    
    //wire [31:0] eff_addr = rdata1_i + imm_sx;
    wire [31:0] eaddr = rdata1_i + imm_sx;
    wire [1:0] mem_byte_offset = eaddr[1:0];
    wire [1:0] mem_byte_offsetn = ~mem_byte_offset;
    
    wire kseg01 = eaddr[31:30] == 2'b10;
    wire kseg0 = eaddr[31:29] == 3'b100;
    wire kseg = eaddr[31];
    wire kernelmode = !status[`STATUS_UM] || status[`STATUS_EXL];
    wire mem_adel   = (op_lw||op_ll) && eaddr[1:0] != 2'd0
                   || (op_lh||op_lhu) && eaddr[0] != 1'd0
                   || (ctrl_sig[`I_MEM_R] || op_cache) && kseg && !kernelmode;
    wire mem_ades   = (op_sw||op_sc) && eaddr[1:0] != 2'd0
                   || op_sh && eaddr[0] != 1'd0
                   || ctrl_sig[`I_MEM_W] && kseg && !kernelmode;
    wire mem_read = ctrl_sig[`I_MEM_R] && !mem_adel;
    wire mem_write = ctrl_sig[`I_MEM_W] && !mem_ades;
    
    wire tlbc_hit = tlbc_valid && tlbc_vaddr_hi == eaddr[31:12];
    
    wire tlbc_ok = qstate == 2'd0 && tlbc_hit
                || qstate == 2'd2;
    
    wire tlbl = (ctrl_sig[`I_MEM_R] || op_cache) && tlbc_ok && (tlbc_miss || tlbc_invalid);
    wire tlbs = ctrl_sig[`I_MEM_W] && tlbc_ok && (tlbc_miss || tlbc_invalid);
    wire tlbm = ctrl_sig[`I_MEM_W] && tlbc_ok && !tlbc_miss && !tlbc_invalid && !tlbc_dirty;
    
    wire mem_exc = qstate == 2'd0 && (mem_adel || mem_ades) || tlbl || tlbs || tlbm;
    
    always @(posedge clk) begin
        if (!resetn) qstate <= 2'd0;
        else qstate <= qstate_next;
    end
    
    always @(*) begin
        case (qstate)
        2'd0:       qstate_next = (valid && (mem_read || mem_write || op_cache && !cp0u && !mem_adel) && !kseg01 && !tlbc_hit) ? 2'd1 : 2'd0;
        2'd1:       qstate_next = 2'd2;
        2'd2:       qstate_next = mem_exc || data_addr_ok || cache_op_ok ? 2'd0 : 2'd2;
        default:    qstate_next = 2'd0;
        endcase
    end
    
    // ea is saved for tlb lookup
    reg [31:0] eaddr_save;
    always @(posedge clk) if (qstate_next == 2'd1) eaddr_save <= eaddr;
    
    assign tlb_vaddr = eaddr_save;
    
    always @(posedge clk) begin
        if (!resetn) tlbc_valid <= 1'b0;
        else if (tlbwi || tlbwr) tlbc_valid <= 1'b0;
        else if (qstate == 2'd1) tlbc_valid <= 1'b1;
    end
    
    always @(posedge clk) begin
        if (!resetn) begin
            tlbc_vaddr_hi <= 20'd0;
            tlbc_paddr_hi <= 20'd0;
            tlbc_miss <= 1'b0;
            tlbc_invalid <= 1'b0;
            tlbc_dirty <= 1'b0;
            tlbc_cattr <= 3'd0;
        end
        else if (qstate == 2'd1) begin
            tlbc_vaddr_hi <= eaddr_save[31:12];
            tlbc_paddr_hi <= tlb_paddr[31:12];
            tlbc_miss <= tlb_miss;
            tlbc_invalid <= tlb_invalid;
            tlbc_dirty <= tlb_dirty;
            tlbc_cattr <= tlb_cattr;
        end
    end
    
    wire req_state = qstate == 2'd0 && (kseg01 || tlbc_hit)
                  || qstate == 2'd2;
    
    assign data_req = valid && (mem_read || mem_write) && !mem_exc && req_state;
    assign data_cache = (qstate == 2'd0 && kseg01) ? (kseg0 && config_k0[0]) : tlbc_cattr[0];
    assign data_wr = mem_write;
    
    // mem write mask
    assign data_wstrb =
        {4{op_sw||op_sc}} & 4'b1111 |
        {4{op_sh}} & (4'b0011 << mem_byte_offset) |
        {4{op_sb}} & (4'b0001 << mem_byte_offset) |
        {4{op_swl}} & (4'b1111 >> mem_byte_offsetn) |
        {4{op_swr}} & (4'b1111 << mem_byte_offset);
    
    // mem write data
    assign data_wdata =
        {32{op_sw||op_sc}} & rdata2_i |
        {32{op_sh}} & {rdata2_i[15:0], rdata2_i[15:0]} |
        {32{op_sb}} & {rdata2_i[7:0], rdata2_i[7:0], rdata2_i[7:0], rdata2_i[7:0]} |
        {32{op_swl}} & (rdata2_i >> (8 * mem_byte_offsetn)) |
        {32{op_swr}} & (rdata2_i << (8 * mem_byte_offset));
    
    assign data_addr[31:12] = (qstate == 2'd0 && kseg01) ? {3'd0, eaddr[28:12]} : tlbc_paddr_hi;
    assign data_addr[11:0]  = qstate == 2'd0 ? eaddr[11:0] : eaddr_save[11:0];
    
    assign data_size =
        {3{op_sw||op_sc||op_swl||op_swr||op_lw||op_ll||op_lwl||op_lwr}} & 3'd2 |
        {3{op_sh||op_lh||op_lhu}} & 3'd1 |
        {3{op_sb||op_lb||op_lbu}} & 3'd0;
    
    // cache op
    assign cache_req = valid && op_cache && !cp0u && !mem_exc && req_state;
    assign cache_op[0] = `GET_RT(inst_i) == 5'b00000; // icache index invalidate
    assign cache_op[1] = `GET_RT(inst_i) == 5'b01000; // icache index store tag
    assign cache_op[2] = `GET_RT(inst_i) == 5'b10000; // icache hit invalidate
    assign cache_op[3] = `GET_RT(inst_i) == 5'b00001; // dcache index writeback invalidate
    assign cache_op[4] = `GET_RT(inst_i) == 5'b01001; // dcache index store tag
    assign cache_op[5] = `GET_RT(inst_i) == 5'b10001; // dcache hit invalidate
    assign cache_op[6] = `GET_RT(inst_i) == 5'b10101; // dcache hit writeback invalidate

    always @(posedge clk) begin
        if (!resetn) done <= 1'b0;
        else if (ready_i) done <= 1'b0;
        else if (valid_i && done_o) done <= 1'b1;
    end

    wire br_inst = op_jr||op_jalr||op_bltz||op_bgez||op_bltzl||op_bgezl||op_bltzal||op_bgezal||op_bltzall||op_bgezall
                ||op_j||op_jal||op_beq||op_bne||op_blez||op_bgtz||op_beql||op_bnel||op_blezl||op_bgtzl;

    // branch delay slot
    reg prev_branch; // if previous instruction is branch/jump
    always @(posedge clk) begin
        if (!resetn) prev_branch <= 1'b0;
        else if (valid_i && done_o && ready_i) prev_branch <= br_inst && !(valid_i && exc_i);
    end

    // exceptions
    wire exc = reserved || cpxu
            || op_syscall || op_break || op_eret || trap
            || alu_of_exc || mem_adel || mem_ades
            || valid_i && (tlbl || tlbs || tlbm);

    wire [4:0] exccode = {5{reserved}} & `EXC_RI
                       | {5{cpxu}} & `EXC_CPU
                       | {5{op_syscall}} & `EXC_SYS
                       | {5{op_break}} & `EXC_BP
                       | {5{trap}} & `EXC_TR
                       | {5{alu_of_exc}} & `EXC_OV
                       | {5{mem_adel}} & `EXC_ADEL
                       | {5{mem_ades}} & `EXC_ADES
                       | {5{tlbl}} & `EXC_TLBL
                       | {5{tlbs}} & `EXC_TLBS
                       | {5{tlbm}} & `EXC_MOD;
    assign commit = valid && exc || valid_i && exc_i;
    assign commit_miss = !cpxu && valid && (mem_read || mem_write || op_cache) && (qstate == 2'd0 && tlbc_hit || qstate == 2'd2) && tlbc_miss
                      || valid_i && exc_i && exc_miss_i;
    assign commit_int = valid_i && exc_i && exc_int_i;
    assign commit_code = valid_i && exc_i ? exccode_i : exccode;
    assign commit_bd = prev_branch;
    assign commit_ce = {2{cp1u}} & 2'd1;
    assign commit_epc = prev_branch ? pc_i - 32'd4 : pc_i;
    assign commit_bvaddr = exc_i ? pc_i : eaddr;
    assign commit_eret = !cpxu && op_eret;
    
    wire done_nonmem = ((op_mfhi||op_mflo||op_mthi||op_mtlo||op_madd||op_maddu||op_msub||op_msubu) && !muldiv
                    ||  (do_j||do_jr||branch_taken||likely) && branch_ready
                    ||  (op_mul) && mul_flag[1]
                    ||  (do_cloz) && cloz_ok
                    || !(op_mfhi||op_mflo||op_mthi||op_mtlo||op_madd||op_maddu||op_msub||op_msubu||
                         do_j||do_jr||branch_taken||likely||op_mul||do_cloz||ctrl_sig[`I_MEM_R]||ctrl_sig[`I_MEM_W]||op_cache));
    assign done_o   = done || done_nonmem
                   || (ctrl_sig[`I_MEM_R]||ctrl_sig[`I_MEM_W]) && (data_addr_ok)
                   || op_cache && cache_op_ok
                   || exc_i || exc;
    
    assign fwd_addr = {5{valid_i}} & waddr;
    assign fwd_data = {32{op_mfhi}} & hi
                    | {32{op_mflo||op_mul}} & lo
                    | {32{op_lui}} & {imm, 16'd0}
                    | {32{do_link}} & (pc_i + 32'd8)
                    | {32{op_mfc0}} & cp0_rdata
                    | {32{op_movz||op_movn}} & rdata1_i
                    | {32{do_cloz}} & clo_result
                    | {32{op_sc}} & {32'd0, llbit}
                    | {32{!(op_mfhi||op_mflo||op_lui||do_link||op_mfc0||op_movz||op_movn||op_mul||do_cloz||op_sc)}} & alu_res_wire;

    assign fwd_ok   = valid && done_nonmem && ctrl_sig[`I_WEX];

    always @(posedge clk) begin
        if (!resetn) begin
            valid_o     <= 1'b0;
            pc_o        <= 32'd0;
            inst_o      <= 32'd0;
            ctrl_o      <= `I_MAX'd0;
            waddr_o     <= 5'd0;
            result_o    <= 32'd0;
            eaddr_o     <= 32'd0;
            rdata2_o    <= 32'd0;
        end
        else if (ready_i) begin
            valid_o     <= valid_i && done_o && !exc_i && !exc;
            pc_o        <= pc_i;
            inst_o      <= inst_i;
            ctrl_o      <= ctrl_sig;
            waddr_o     <= waddr;
            result_o    <= fwd_data;
            eaddr_o     <= eaddr;
            rdata2_o    <= rdata2_i;
        end
    end
    
    // performance counters
    always @(posedge clk) begin
        // stalled cycles for load req
        if (!resetn) perfcnt_load_waitreq <= 32'd0;
        else if (valid && data_req && !done_o && ctrl_sig[`I_MEM_R]) perfcnt_load_waitreq <= perfcnt_load_waitreq + 32'd1;
        // stalled cycles for store req
        if (!resetn) perfcnt_store_waitreq <= 32'd0;
        else if (valid && data_req && !done_o && ctrl_sig[`I_MEM_W]) perfcnt_store_waitreq <= perfcnt_store_waitreq + 32'd1;
    end

endmodule