`include "common.vh"

module cp0regs(
    input               clk,
    input               resetn,
    
    input   [5 :0]      int,
    output              int_sig, // indicates unmasked interrupts
    
    // mtc0/mfc0
    input               mtc0,
    input   [31:0]      mtc0_data,
    output  [31:0]      mfc0_data,
    input   [7 :0]      addr, // rd, sel
    
    // tlb read/write
    input               tlbr,
    input   [31:0]      tlbr_lo0,
    input   [31:0]      tlbr_lo1,
    input   [31:0]      tlbr_hi,
    input   [11:0]      tlbr_mask,
    input               tlbwr,
    input               tlbp,
    input   [31:0]      tlbp_index,
    
    // exception commit
    input               commit_exc, // also valid when commit_eret is valid
    input   [4 :0]      commit_code,
    input               commit_bd,
    input   [1 :0]      commit_ce,
    input   [31:0]      commit_epc,
    input   [31:0]      commit_bvaddr,
    input               commit_eret,
    
    output  [31:0]      index,
    output  [31:0]      random,
    output  [31:0]      entrylo0,
    output  [31:0]      entrylo1,
    output reg [11:0]   mask, // mask field in PageMask
    output  [31:0]      entryhi,
    output  [31:0]      status,
    output  [31:0]      cause,
    output reg [31:0]   epc,
    output reg [2:0]    config_k0,
    output reg [31:0]   taglo
);

    wire [5:0] hw_int;
    reg timer_int;
    
    assign hw_int[5] = int[5] || timer_int;
    assign hw_int[4:0] = int[4:0];

    // this indicates an exception is to commit, distinguished from an ERET instruction
    wire exception_commit = commit_exc && !commit_eret;
    wire exception_mem = commit_code == `EXC_MOD
                      || commit_code == `EXC_TLBL
                      || commit_code == `EXC_TLBS
                      || commit_code == `EXC_ADEL
                      || commit_code == `EXC_ADES;
    
    // Index (0, 0)
    reg index_p;
    reg [`TLB_IDXBITS-1:0] index_index;
    assign index = (index_p << 31) | index_index;
    
    wire index_write = mtc0 && addr == `CP0_INDEX;
    always @(posedge clk) begin
        // P
        if (!resetn) index_p <= 1'b0;
        if (tlbp) index_p <= tlbp_index[`INDEX_P];
        // Index
        if (tlbp) index_index <= tlbp_index[`INDEX_INDEX];
        else if (index_write) index_index <= mtc0_data[`INDEX_INDEX];
    end
    
    // Wired (6, 0)
    reg [`TLB_IDXBITS-1:0] wired_wired;
    wire [31:0] wired = wired_wired;
    
    wire wired_write = mtc0 && addr == `CP0_WIRED;
    always @(posedge clk) begin
        // Wired
        if (!resetn) wired_wired <= 0;
        else if (wired_write) wired_wired <= mtc0_data[`WIRED_WIRED];
    end
    
    // Random (1, 0)
    reg [`TLB_IDXBITS-1:0] random_random;
    assign random = random_random;
    
    wire [`TLB_IDXBITS-1:0] next_random = random_random + 1'b1;
    always @(posedge clk) begin
        // Random
        if (!resetn || wired_write) random_random <= `TLB_ENTRIES - 1;
        else if (tlbwr) random_random <= next_random < wired_wired ? wired_wired : next_random;
    end
    
    // EntryLo0, EntryLo1 (2 and 3, 0)
    
    reg [19:0] entrylo0_pfn, entrylo1_pfn;
    reg [2:0] entrylo0_c, entrylo1_c;
    reg entrylo0_d, entrylo1_d;
    reg entrylo0_v, entrylo1_v;
    reg entrylo0_g, entrylo1_g;
    assign entrylo0 = {
        6'd0,
        entrylo0_pfn, // 25:6
        entrylo0_c, // 5:3
        entrylo0_d, // 2
        entrylo0_v, // 1
        entrylo0_g // 0
    };
    assign entrylo1 = {
        6'd0,
        entrylo1_pfn, // 25:6
        entrylo1_c, // 5:3
        entrylo1_d, // 2
        entrylo1_v, // 1
        entrylo1_g // 0
    };
    
    wire entrylo0_write = mtc0 && addr == `CP0_ENTRYLO0;
    wire entrylo1_write = mtc0 && addr == `CP0_ENTRYLO1;
    
    always @(posedge clk) begin
        // EntryLo0
        if (tlbr) begin
            entrylo0_pfn <= tlbr_lo0[`ENTRYLO_PFN];
            entrylo0_c <= tlbr_lo0[`ENTRYLO_C];
            entrylo0_d <= tlbr_lo0[`ENTRYLO_D];
            entrylo0_v <= tlbr_lo0[`ENTRYLO_V];
            entrylo0_g <= tlbr_lo0[`ENTRYLO_G];
        end
        else if (entrylo0_write) begin
            entrylo0_pfn <= mtc0_data[`ENTRYLO_PFN];
            entrylo0_c <= mtc0_data[`ENTRYLO_C];
            entrylo0_d <= mtc0_data[`ENTRYLO_D];
            entrylo0_v <= mtc0_data[`ENTRYLO_V];
            entrylo0_g <= mtc0_data[`ENTRYLO_G];
        end
        // EntryLo1
        if (tlbr) begin
            entrylo1_pfn <= tlbr_lo1[`ENTRYLO_PFN];
            entrylo1_c <= tlbr_lo1[`ENTRYLO_C];
            entrylo1_d <= tlbr_lo1[`ENTRYLO_D];
            entrylo1_v <= tlbr_lo1[`ENTRYLO_V];
            entrylo1_g <= tlbr_lo1[`ENTRYLO_G];
        end
        else if (entrylo1_write) begin
            entrylo1_pfn <= mtc0_data[`ENTRYLO_PFN];
            entrylo1_c <= mtc0_data[`ENTRYLO_C];
            entrylo1_d <= mtc0_data[`ENTRYLO_D];
            entrylo1_v <= mtc0_data[`ENTRYLO_V];
            entrylo1_g <= mtc0_data[`ENTRYLO_G];
        end
    end
    
    // Context (4, 0)
    
    reg [8:0] context_ptebase;
    reg [18:0] context_badvpn2;
    
    wire [31:0] context = {
        context_ptebase, // 31:23
        context_badvpn2, // 22:4
        4'd0
    };
    
    wire context_write = mtc0 && addr == `CP0_CONTEXT;
    
    always @(posedge clk) begin
        // PTEBase
        if (context_write) context_ptebase <= mtc0_data[`CONTEXT_PTEBASE];
        // BadVPN2
        if (exception_commit && exception_mem) context_badvpn2 <= commit_bvaddr[31:13];
    end
    
    // PageMask (5, 0)
    wire [31:0] pagemask = {
        8'd0,
        mask, // 24:13
        13'd0
    };
    
    wire pagemask_write = mtc0 && addr == `CP0_PAGEMASK;
    always @(posedge clk) begin
        if (tlbr) mask <= tlbr_mask;
        else if (pagemask_write) mask <= mtc0_data[`PAGEMASK_MASK];
    end
    
    // BadVAddr (8, 0)
    reg [31:0] badvaddr;
    always @(posedge clk) begin
        if (exception_commit && exception_mem) badvaddr <= commit_bvaddr;
    end
    
    // Count (9, 0)
    reg [31:0] count;
    reg tick;
    
    wire count_write = mtc0 && addr == `CP0_COUNT;
    always @(posedge clk) begin
        if (!resetn) tick <= 1'b0;
        else tick <= ~tick;
        // Count
        if (count_write) count <= mtc0_data;
        else if (tick) count <= count + 32'd1;
    end
    
    // EntryHi (10, 0)
    reg [18:0] entryhi_vpn2;
    reg [7:0] entryhi_asid;
    assign entryhi = {
        entryhi_vpn2, // 31:13
        5'd0,
        entryhi_asid // 7:0
    };
    
    wire entryhi_write = mtc0 && addr == `CP0_ENTRYHI;
    always @(posedge clk) begin
        // VPN2
        if (exception_commit && exception_mem) entryhi_vpn2 <= commit_bvaddr[`ENTRYHI_VPN2];
        else if (tlbr) entryhi_vpn2 <= tlbr_hi[`ENTRYHI_VPN2];
        else if (entryhi_write) entryhi_vpn2 <= mtc0_data[`ENTRYHI_VPN2];
        // ASID
        if (!resetn) entryhi_asid <= 0;
        if (tlbr) entryhi_asid <= tlbr_hi[`ENTRYHI_ASID];
        else if (entryhi_write) entryhi_asid <= mtc0_data[`ENTRYHI_ASID];
    end
    
    // Compare (11, 0)
    reg [31:0] compare;
    
    wire compare_write = mtc0 && addr == `CP0_COMPARE;
    always @(posedge clk) begin
        if (compare_write) compare <= mtc0_data;
    end
    
    // Status (12, 0)
    reg status_cu0;
    reg status_bev;
    reg [7:0] status_im;
    reg status_um;
    reg status_exl;
    reg status_ie;
    assign status = {
        3'd0,
        status_cu0, // 28
        5'd0,
        status_bev, // 22
        6'd0,
        status_im,  // 15:8
        3'd0,
        status_um,  // 4
        1'b0,
        1'b0, // 2
        status_exl, // 1
        status_ie   // 0
    };
    
    wire status_write = mtc0 && addr == `CP0_STATUS;
    always @(posedge clk) begin
        // CU0
        if (!resetn) status_cu0 <= 1'b0;
        else if (status_write) status_cu0 <= mtc0_data[`STATUS_CU0];
        // BEV
        if (!resetn) status_bev <= 1'b1;
        else if (status_write) status_bev <= mtc0_data[`STATUS_BEV];
        // IM
        if (!resetn) status_im <= 8'd0;
        else if (status_write) status_im <= mtc0_data[`STATUS_IM];
        // UM
        if (!resetn) status_um <= 1'b0;
        else if (status_write) status_um <= mtc0_data[`STATUS_UM];
        // EXL
        if (!resetn) status_exl <= 1'b0;
        else if (commit_exc) status_exl <= !commit_eret;
        else if (status_write) status_exl <= mtc0_data[`STATUS_EXL];
        // IE
        if (!resetn) status_ie <= 1'b0;
        else if (status_write) status_ie <= mtc0_data[`STATUS_IE];
    end
    
    // Cause (13, 0)
    reg cause_bd;
    reg cause_ti;
    reg [1:0] cause_ce;
    reg cause_iv;
    reg [5:0] cause_ip7_2;
    reg [1:0] cause_ip1_0;
    reg [4:0] cause_exccode;
    assign cause = {
        cause_bd,       // 31
        cause_ti,       // 30
        cause_ce,       // 29:28
        4'd0,
        cause_iv,       // 23
        7'd0,
        cause_ip7_2,    // 15:10
        cause_ip1_0,    // 9:8
        1'd0,
        cause_exccode,  // 6:2
        2'd0
    };
    
    wire cause_write = mtc0 && addr == `CP0_CAUSE;
    always @(posedge clk) begin
        // BD
        if (!resetn) cause_bd <= 1'b0;
        else if (exception_commit && !status_exl) cause_bd <= commit_bd;
        // TI
        if (!resetn) cause_ti <= 1'b0;
        else cause_ti <= timer_int;
        // CE
        if (!resetn) cause_ce <= 2'd0;
        else if (exception_commit) cause_ce <= commit_ce;
        // IV
        if (!resetn) cause_iv <= 1'b0;
        else if (cause_write) cause_iv <= mtc0_data[`CAUSE_IV];
        // IP
        cause_ip7_2 <= hw_int;
        if (!resetn) cause_ip1_0 <= 2'd0;
        else if (cause_write) cause_ip1_0 <= mtc0_data[`CAUSE_IP1_0];
        // ExcCode
        if (!resetn) cause_exccode <= 5'd0;
        else if (exception_commit) cause_exccode <= commit_code;
    end
    
    // EPC (14, 0)
    wire epc_write = mtc0 && addr == `CP0_EPC;
    always @(posedge clk) begin
        if (epc_write) epc <= mtc0_data;
        else if (exception_commit && !status_exl) epc <= commit_epc;
    end
    
    // PRId (15, 0)
    wire [31:0] prid = 32'h00004220;
    
    // Config (16, 0)
    wire [31:0] config0 = {
        1'b1, // M
        3'd0,
        3'd0,
        9'd0,
        1'b0, // BE
        2'd0,
        3'd0,
        3'd1, // MT
        3'd0,
        1'b0, // VI
        config_k0
    };
    
    wire config_write = mtc0 && addr == `CP0_CONFIG;
    always @(posedge clk) begin
        if (!resetn) config_k0 <= 3'd3;
        else if (config_write) config_k0 <= mtc0_data[`CONFIG_K0];
    end
    
    // Config1 (16, 1)
    wire [31:0] config1 = {
        1'b0,
        6'd31,  // TLB entries = 32
        3'd1,   // Icache sets = 128
        3'd4,   // Icache line size = 32
        3'd3,   // Icache associativity = 4
        3'd1,   // Dcache sets = 128
        3'd4,   // Dcache line size = 32
        3'd1,   // Dcache associativity = 2
        1'b0,   // C2
        1'b0,
        1'b0,   // PC
        1'b0,   // WR
        1'b0,
        1'b0,   // EP
        1'b0    // FP
    };
    
    // TagLo (28, 0)
    wire taglo_write = mtc0 && addr == `CP0_TAGLO;
    always @(posedge clk) begin
        if (taglo_write) taglo <= mtc0_data;
    end
    
    // timer interrupt
    always @(posedge clk) begin
        if (!resetn) timer_int <= 1'b0;
        else if (compare_write) timer_int <= 1'b0;
        else if (count == compare) timer_int <= 1'b1;
    end
    
    assign int_sig = {cause_ip7_2, cause_ip1_0} & status_im && !status_exl && status_ie;
    
    assign mfc0_data =
        {32{addr == `CP0_INDEX      }} & index      |
        {32{addr == `CP0_RANDOM     }} & random     |
        {32{addr == `CP0_ENTRYLO0   }} & entrylo0   |
        {32{addr == `CP0_ENTRYLO1   }} & entrylo1   |
        {32{addr == `CP0_CONTEXT    }} & context    |
        {32{addr == `CP0_PAGEMASK   }} & pagemask   |
        {32{addr == `CP0_WIRED      }} & wired      |
        {32{addr == `CP0_BADVADDR   }} & badvaddr   |
        {32{addr == `CP0_COUNT      }} & count      |
        {32{addr == `CP0_ENTRYHI    }} & entryhi    |
        {32{addr == `CP0_COMPARE    }} & compare    |
        {32{addr == `CP0_STATUS     }} & status     |
        {32{addr == `CP0_CAUSE      }} & cause      |
        {32{addr == `CP0_EPC        }} & epc        |
        {32{addr == `CP0_PRID       }} & prid       |
        {32{addr == `CP0_CONFIG     }} & config0    |
        {32{addr == `CP0_CONFIG1    }} & config1    |
        {32{addr == `CP0_TAGLO      }} & taglo      ;
    
endmodule