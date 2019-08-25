`include "common.vh"

module decoder #(
    parameter integer bits = 4
)
(
    input [bits-1:0] in,
    output [(1<<bits)-1:0] out
);

  generate
    genvar i;
    for (i=0; i<(1<<bits); i=i+1) begin
      assign out[i] = in == i;
    end
  endgenerate

endmodule

module decode_stage(
    input                       clk,
    input                       resetn,
    
    // memory access interface
    input   [31:0]              inst_rdata,
    input                       inst_data_ok,

    // regfile interface
    output  [4 :0]              rf_raddr1,
    output  [4 :0]              rf_raddr2,
    input   [31:0]              rf_rdata1,
    input   [31:0]              rf_rdata2,

    // data forwarding
    input   [4 :0]              ex_fwd_addr,    // 0 if instruction does not write
    input   [31:0]              ex_fwd_data,
    input                       ex_fwd_ok,      // whether data is generated after ex stage
    input   [4 :0]              wb_fwd_addr,    // 0 if instruction does not write
    input   [31:0]              wb_fwd_data,
    input                       wb_fwd_ok,      // whether data is generated after wb stage
    
    // interrupt
    input                       int_sig,

    output                      done_o,
    input                       valid_i,
    input   [31:0]              pc_i,
    input                       cancelled_i,
    input                       ready_i,
    output reg                  valid_o,
    output reg [31:0]           pc_o,
    output reg [31:0]           inst_o,
    output reg [`LDECBITS]      decoded_o,
    output reg [31:0]           rdata1_o,
    output reg [31:0]           rdata2_o,
    output reg [31:0]           pc_j_o,
    output reg [31:0]           pc_b_o,
    
    // exception interface
    input                       exc_i,
    input                       exc_miss_i,
    input   [4:0]               exccode_i,
    output reg                  exc_o,
    output reg                  exc_miss_o,
    output reg                  exc_int_o,
    output reg [4:0]            exccode_o,
    input                       cancel_i,
    
    output reg [31:0]           perfcnt_fetch_waitack
);

    wire valid;
    reg done;
    
    reg [31:0] inst_save;
    reg inst_saved;
    
    always @(posedge clk) if (inst_data_ok && !inst_saved) inst_save <= inst_rdata;
    always @(posedge clk) begin
        if (!resetn) inst_saved <= 1'b0;
        else if (done_o && ready_i) inst_saved <= 1'b0;
        else if (valid_i && inst_data_ok) inst_saved <= 1'b1;
    end
    
    wire [31:0] inst = inst_saved ? inst_save : inst_rdata;
    wire inst_ok = inst_data_ok || inst_saved;
    
    reg cancel_save;
    always @(posedge clk) begin
        if (!resetn) cancel_save <= 1'b0;
        else if (done_o && ready_i) cancel_save <= 1'b0;
        else if (cancel_i && valid_i) cancel_save <= 1'b1;
    end
    
    assign valid = valid_i && !cancelled_i && inst_ok && !done && !cancel_save;

    wire [63:0] op_d, func_d;
    wire [31:0] rs_d, rt_d, rd_d, sa_d;
    
    decoder #(.bits(6))
    dec_op (.in(inst[31:26]), .out(op_d)), dec_func (.in(inst[5:0]), .out(func_d));
    
    decoder #(.bits(5))
    dec_rs (.in(inst[25:21]), .out(rs_d)), dec_rt (.in(inst[20:16]), .out(rt_d)),
    dec_rd (.in(inst[15:11]), .out(rd_d)), dec_sa (.in(inst[10:6]), .out(sa_d));
    
    wire op_sll       = op_d[0] && rs_d[0] && func_d[0];
    wire op_movft     = op_d[0] && sa_d[0] && func_d[1];
    wire op_srl       = op_d[0] && rs_d[0] && func_d[2];
    wire op_sra       = op_d[0] && rs_d[0] && func_d[3];
    wire op_sllv      = op_d[0] && sa_d[0] && func_d[4];
    wire op_srlv      = op_d[0] && sa_d[0] && func_d[6];
    wire op_srav      = op_d[0] && sa_d[0] && func_d[7];
    wire op_jr        = op_d[0] && rt_d[0] && rd_d[0] && sa_d[0] && func_d[8];
    wire op_jalr      = op_d[0] && rt_d[0] && sa_d[0] && func_d[9];
    wire op_movz      = op_d[0] && sa_d[0] && func_d[10];
    wire op_movn      = op_d[0] && sa_d[0] && func_d[11];
    wire op_syscall   = op_d[0] && func_d[12];
    wire op_break     = op_d[0] && func_d[13];
    wire op_sync      = op_d[0] && rs_d[0] && rt_d[0] && rd_d[0] && func_d[15];
    wire op_mfhi      = op_d[0] && rs_d[0] && rt_d[0] && sa_d[0] && func_d[16];
    wire op_mthi      = op_d[0] && rt_d[0] && rd_d[0] && sa_d[0] && func_d[17];
    wire op_mflo      = op_d[0] && rs_d[0] && rt_d[0] && sa_d[0] && func_d[18];
    wire op_mtlo      = op_d[0] && rt_d[0] && rd_d[0] && sa_d[0] && func_d[19];
    wire op_mult      = op_d[0] && rd_d[0] && sa_d[0] && func_d[24];
    wire op_multu     = op_d[0] && rd_d[0] && sa_d[0] && func_d[25];
    wire op_div       = op_d[0] && rd_d[0] && sa_d[0] && func_d[26];
    wire op_divu      = op_d[0] && rd_d[0] && sa_d[0] && func_d[27];
    wire op_add       = op_d[0] && sa_d[0] && func_d[32];
    wire op_addu      = op_d[0] && sa_d[0] && func_d[33];
    wire op_sub       = op_d[0] && sa_d[0] && func_d[34];
    wire op_subu      = op_d[0] && sa_d[0] && func_d[35];
    wire op_and       = op_d[0] && sa_d[0] && func_d[36];
    wire op_or        = op_d[0] && sa_d[0] && func_d[37];
    wire op_xor       = op_d[0] && sa_d[0] && func_d[38];
    wire op_nor       = op_d[0] && sa_d[0] && func_d[39];
    wire op_slt       = op_d[0] && sa_d[0] && func_d[42];
    wire op_sltu      = op_d[0] && sa_d[0] && func_d[43];
    wire op_tge       = op_d[0] && func_d[48];
    wire op_tgeu      = op_d[0] && func_d[49];
    wire op_tlt       = op_d[0] && func_d[50];
    wire op_tltu      = op_d[0] && func_d[51];
    wire op_teq       = op_d[0] && func_d[52];
    wire op_tne       = op_d[0] && func_d[54];
    wire op_bltz      = op_d[1] && rt_d[0];
    wire op_bgez      = op_d[1] && rt_d[1];
    wire op_tgei      = op_d[1] && rt_d[8];
    wire op_tgeiu     = op_d[1] && rt_d[9];
    wire op_tlti      = op_d[1] && rt_d[10];
    wire op_tltiu     = op_d[1] && rt_d[11];
    wire op_teqi      = op_d[1] && rt_d[12];
    wire op_tnei      = op_d[1] && rt_d[14];
    wire op_bltzl     = op_d[1] && rt_d[2];
    wire op_bgezl     = op_d[1] && rt_d[3];
    wire op_bltzal    = op_d[1] && rt_d[16];
    wire op_bgezal    = op_d[1] && rt_d[17];
    wire op_bltzall   = op_d[1] && rt_d[18];
    wire op_bgezall   = op_d[1] && rt_d[19];
    wire op_j         = op_d[2];
    wire op_jal       = op_d[3];
    wire op_beq       = op_d[4];
    wire op_bne       = op_d[5];
    wire op_blez      = op_d[6] && rt_d[0];
    wire op_bgtz      = op_d[7] && rt_d[0];
    wire op_addi      = op_d[8];
    wire op_addiu     = op_d[9];
    wire op_slti      = op_d[10];
    wire op_sltiu     = op_d[11];
    wire op_andi      = op_d[12];
    wire op_ori       = op_d[13];
    wire op_xori      = op_d[14];
    wire op_lui       = op_d[15];
    wire op_mfc0      = op_d[16] && rs_d[0] && sa_d[0] && inst[5:3] == 3'b000;
    wire op_mtc0      = op_d[16] && rs_d[4] && sa_d[0] && inst[5:3] == 3'b000;
    wire op_tlbr      = op_d[16] && rs_d[16] && rt_d[0] && rd_d[0] && sa_d[0] && func_d[1];
    wire op_tlbwi     = op_d[16] && rs_d[16] && rt_d[0] && rd_d[0] && sa_d[0] && func_d[2];
    wire op_tlbwr     = op_d[16] && rs_d[16] && rt_d[0] && rd_d[0] && sa_d[0] && func_d[6];
    wire op_tlbp      = op_d[16] && rs_d[16] && rt_d[0] && rd_d[0] && sa_d[0] && func_d[8];
    wire op_eret      = op_d[16] && rs_d[16] && rt_d[0] && rd_d[0] && sa_d[0] && func_d[24];
    wire op_wait      = op_d[16] && inst[25] && func_d[32];
    wire op_cop1      = op_d[17] && !rs_d[14]; // foooooooooooo
    wire op_beql      = op_d[20];
    wire op_bnel      = op_d[21];
    wire op_blezl     = op_d[22] && rt_d[0];
    wire op_bgtzl     = op_d[23] && rt_d[0];
    wire op_madd      = op_d[28] && rd_d[0] && sa_d[0] && func_d[0];
    wire op_maddu     = op_d[28] && rd_d[0] && sa_d[0] && func_d[1];
    wire op_mul       = op_d[28] && sa_d[0] && func_d[2];
    wire op_msub      = op_d[28] && rd_d[0] && sa_d[0] && func_d[4];
    wire op_msubu     = op_d[28] && rd_d[0] && sa_d[0] && func_d[5];
    wire op_clz       = op_d[28] && sa_d[0] && func_d[32];
    wire op_clo       = op_d[28] && sa_d[0] && func_d[33];
    wire op_lb        = op_d[32];
    wire op_lh        = op_d[33];
    wire op_lwl       = op_d[34];
    wire op_lw        = op_d[35];
    wire op_lbu       = op_d[36];
    wire op_lhu       = op_d[37];
    wire op_lwr       = op_d[38];
    wire op_sb        = op_d[40];
    wire op_sh        = op_d[41];
    wire op_swl       = op_d[42];
    wire op_sw        = op_d[43];
    wire op_swr       = op_d[46];
    wire op_cache     = op_d[47];
    wire op_ll        = op_d[48];
    wire op_lwc1      = op_d[49];
    wire op_pref      = op_d[51];
    wire op_ldc1      = op_d[53];
    wire op_sc        = op_d[56];
    wire op_swc1      = op_d[57];
    wire op_sdc1      = op_d[61];
    
    wire [`LDECBITS] decoded;
    assign decoded = {`DECODED_OPS};
    
    assign rf_raddr1 = `GET_RS(inst);
    assign rf_raddr2 = `GET_RT(inst);

    // data forwarding
    // `I_RS_R & `I_RT_R check is omitted for enhanced timing
    // this may introduce false data hazards but no forwarding errors
    wire fwd_ex_raddr1_hit  = ex_fwd_addr != 5'd0 && rf_raddr1 == ex_fwd_addr;
    wire fwd_ex_raddr2_hit  = ex_fwd_addr != 5'd0 && rf_raddr2 == ex_fwd_addr;
    wire fwd_wb_raddr1_hit  = wb_fwd_addr != 5'd0 && rf_raddr1 == wb_fwd_addr;
    wire fwd_wb_raddr2_hit  = wb_fwd_addr != 5'd0 && rf_raddr2 == wb_fwd_addr;
    
    wire [31:0] fwd_rdata1  = fwd_ex_raddr1_hit ? ex_fwd_data
                            : fwd_wb_raddr1_hit ? wb_fwd_data
                            : rf_rdata1;
    wire [31:0] fwd_rdata2  = fwd_ex_raddr2_hit ? ex_fwd_data
                            : fwd_wb_raddr2_hit ? wb_fwd_data
                            : rf_rdata2;
    
    wire fwd_stall  = fwd_ex_raddr1_hit && !ex_fwd_ok
                   || fwd_ex_raddr2_hit && !ex_fwd_ok
                   || fwd_wb_raddr1_hit && !wb_fwd_ok
                   || fwd_wb_raddr2_hit && !wb_fwd_ok;

    always @(posedge clk) begin
        if (!resetn) done <= 1'b0;
        else if (ready_i) done <= 1'b0;
        else if (valid && done_o) done <= 1'b1;
    end
    
    assign done_o = inst_ok && (!fwd_stall || cancelled_i) || exc_i;
    
    wire [15:0] imm = `GET_IMM(inst);
    
    wire [31:0] seq_pc = pc_i + 32'd4;
    wire [31:0] pc_branch = seq_pc + {{14{imm[15]}}, imm, 2'd0};
    wire [31:0] pc_jump = {seq_pc[31:28], `GET_INDEX(inst), 2'd0};

    always @(posedge clk) begin
        if (!resetn) begin
            valid_o     <= 1'b0;
            pc_o        <= 32'd0;
            inst_o      <= 32'd0;
            decoded_o   <= 100'd0;
            rdata1_o    <= 32'd0;
            rdata2_o    <= 32'd0;
            pc_j_o      <= 32'd0;
            pc_b_o      <= 32'd0;
            exc_o       <= 1'b0;
            exc_miss_o  <= 1'b0;
            exc_int_o   <= 1'b0;
            exccode_o   <= 5'd0;
        end
        else if (ready_i) begin
            valid_o     <= valid_i && done_o && !cancelled_i && !cancel_i && !cancel_save;
            pc_o        <= pc_i;
            inst_o      <= inst;
            decoded_o   <= decoded;
            rdata1_o    <= fwd_rdata1;
            rdata2_o    <= fwd_rdata2;
            pc_j_o      <= pc_jump;
            pc_b_o      <= pc_branch;
            exc_o       <= exc_i || int_sig;
            exc_miss_o  <= exc_miss_i;
            exc_int_o   <= !exc_i && int_sig;
            exccode_o   <= exc_i ? exccode_i : `EXC_INT;
        end
    end
    
    // performance counters
    always @(posedge clk) begin
        if (!resetn) perfcnt_fetch_waitack <= 32'd0;
        else if (valid_i && !exc_i && !inst_ok) perfcnt_fetch_waitack <= perfcnt_fetch_waitack + 32'd1;
    end

endmodule