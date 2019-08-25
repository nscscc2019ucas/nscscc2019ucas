`include "common.vh"

module tlb
#(
    parameter       ENTRIES = `TLB_ENTRIES,
    parameter       IDXBITS = `TLB_IDXBITS
)
(
    input               clk,
    input               resetn,

    // TLB entry write
    input               write,
    input [IDXBITS-1:0] idx,
    input [11:0]        mask,
    input [31:0]        entryhi,    // bound to EntryHi
    input [31:0]        entrylo0,   // bound to EntryLo0
    input [31:0]        entrylo1,   // bound to EntryLo1
    
    // TLB read/probe
    output [31:0]       read_lo0,
    output [31:0]       read_lo1,
    output [31:0]       read_hi,
    output [11:0]       read_mask,
    output [31:0]       probe_index,

    // TLB lookup
    input [31:0]        inst_vaddr,
    output [31:0]       inst_paddr,
    output [2:0]        inst_cache,
    output              inst_miss,
    output              inst_invalid,
    input [31:0]        data_vaddr,
    output [31:0]       data_paddr,
    output [2:0]        data_cache,
    output              data_miss,
    output              data_invalid,
    output              data_dirty
);

    reg [11:0]  tlb_mask    [ENTRIES-1:0];
    reg [18:0]  tlb_vpn2    [ENTRIES-1:0];
    reg         tlb_g       [ENTRIES-1:0];
    reg [7:0]   tlb_asid    [ENTRIES-1:0];
    reg [19:0]  tlb_pfn0    [ENTRIES-1:0];
    reg [19:0]  tlb_pfn1    [ENTRIES-1:0];
    reg [2:0]   tlb_c0      [ENTRIES-1:0];
    reg [2:0]   tlb_c1      [ENTRIES-1:0];
    reg         tlb_d0      [ENTRIES-1:0];
    reg         tlb_d1      [ENTRIES-1:0];
    reg         tlb_v0      [ENTRIES-1:0];
    reg         tlb_v1      [ENTRIES-1:0];

    integer kk;

    always @(posedge clk) begin
        if (!resetn) begin
            for (kk=0; kk<ENTRIES; kk=kk+1) begin
                tlb_mask[kk]    = 0;
                tlb_vpn2[kk]    = 0;
                tlb_g[kk]       = 0;
                tlb_asid[kk]    = 0;
                tlb_pfn0[kk]    = 0;
                tlb_c0[kk]      = 0;
                tlb_d0[kk]      = 0;
                tlb_v0[kk]      = 0;
                tlb_pfn1[kk]    = 0;
                tlb_c1[kk]      = 0;
                tlb_d1[kk]      = 0;
                tlb_v1[kk]      = 0;
            end
        end
        else if (write) begin
            tlb_mask[idx]   <= mask;
            tlb_vpn2[idx]   <= entryhi[`ENTRYHI_VPN2] & ~mask;
            tlb_g[idx]      <= entrylo0[`ENTRYLO_G] & entrylo1[`ENTRYLO_G];
            tlb_asid[idx]   <= entryhi[`ENTRYHI_ASID];
            tlb_pfn0[idx]   <= entrylo0[`ENTRYLO_PFN] & ~mask;
            tlb_c0[idx]     <= entrylo0[`ENTRYLO_C];
            tlb_d0[idx]     <= entrylo0[`ENTRYLO_D];
            tlb_v0[idx]     <= entrylo0[`ENTRYLO_V];
            tlb_pfn1[idx]   <= entrylo1[`ENTRYLO_PFN] & ~mask;
            tlb_c1[idx]     <= entrylo1[`ENTRYLO_C];
            tlb_d1[idx]     <= entrylo1[`ENTRYLO_D];
            tlb_v1[idx]     <= entrylo1[`ENTRYLO_V];
        end
    end
    
    genvar i;
    
    // NOTE: assume each lookup hits at most 1 TLB entry otherwise the result is undefined

    // inst-side translation
    
    wire [ENTRIES-1:0] inst_match;
    wire [ENTRIES-1:0] inst_sel;
    wire [19:0] inst_pfn [ENTRIES-1:0];
    wire [31:0] inst_lookup_paddr    [ENTRIES:0];
    wire [2:0]  inst_lookup_c        [ENTRIES:0];
    wire        inst_lookup_v        [ENTRIES:0];
    
    assign inst_lookup_paddr[0]  = 32'd0;
    assign inst_lookup_c[0]      = 3'd0;
    assign inst_lookup_v[0]      = 1'd0; 
    
    generate
        for (i=0; i<ENTRIES; i=i+1) begin
            assign inst_match[i] = (inst_vaddr[31:13] & ~tlb_mask[i]) == (tlb_vpn2[i] & ~tlb_mask[i])&& (tlb_g[i] || tlb_asid[i] == entryhi[`ENTRYHI_ASID]);
            assign inst_sel[i]   = (inst_vaddr[24:12] & {tlb_mask[i], 1'b1}) != (inst_vaddr[24:12] & {1'b0, tlb_mask[i]});
            assign inst_pfn[i]   = inst_sel[i] ? tlb_pfn1[i] : tlb_pfn0[i];
            // all lookup results are OR'd together assuming match is at-most-one-hot
            assign inst_lookup_paddr[i+1]    = inst_lookup_paddr[i]   | {32{inst_match[i]}} & (((inst_pfn[i] & ~tlb_mask[i]) << 12) | (inst_vaddr & {tlb_mask[i], 12'hfff}));
            assign inst_lookup_c[i+1]        = inst_lookup_c[i]       | { 3{inst_match[i]}} & (inst_sel[i] ? tlb_c1[i]   : tlb_c0[i]);
            assign inst_lookup_v[i+1]        = inst_lookup_v[i]       | { 1{inst_match[i]}} & (inst_sel[i] ? tlb_v1[i]   : tlb_v0[i]);
        end
    endgenerate

    assign inst_paddr    = inst_lookup_paddr[ENTRIES];
    assign inst_cache    = inst_lookup_c[ENTRIES];
    assign inst_miss     = ~|inst_match;
    assign inst_invalid  = ~inst_lookup_v[ENTRIES];
    
    // data-side translation

    wire [ENTRIES-1:0] data_match;
    wire [ENTRIES-1:0] data_sel;
    wire [19:0] data_pfn [ENTRIES-1:0];
    wire [31:0] data_lookup_paddr    [ENTRIES:0];
    wire [2:0]  data_lookup_c        [ENTRIES:0];
    wire        data_lookup_d        [ENTRIES:0];
    wire        data_lookup_v        [ENTRIES:0];

    assign data_lookup_paddr[0]  = 32'd0;
    assign data_lookup_c[0]      = 3'd0;
    assign data_lookup_d[0]      = 1'd0; 
    assign data_lookup_v[0]      = 1'd0; 
    generate
        for (i=0; i<ENTRIES; i=i+1) begin
            assign data_match[i] = (data_vaddr[31:13] & ~tlb_mask[i]) == (tlb_vpn2[i] & ~tlb_mask[i])&& (tlb_g[i] || tlb_asid[i] == entryhi[`ENTRYHI_ASID]);
            assign data_sel[i]   = (data_vaddr[24:12] & {tlb_mask[i], 1'b1}) != (data_vaddr[24:12] & {1'b0, tlb_mask[i]});
            assign data_pfn[i]   = data_sel[i] ? tlb_pfn1[i] : tlb_pfn0[i];
            // all lookup results are OR'd together assuming match is at-most-one-hot
            assign data_lookup_paddr[i+1]    = data_lookup_paddr[i]   | {32{data_match[i]}} & (((data_pfn[i] & ~tlb_mask[i]) << 12) | (data_vaddr & {tlb_mask[i], 12'hfff}));
            assign data_lookup_c[i+1]        = data_lookup_c[i]       | { 3{data_match[i]}} & (data_sel[i] ? tlb_c1[i]   : tlb_c0[i]);
            assign data_lookup_d[i+1]        = data_lookup_d[i]       | { 1{data_match[i]}} & (data_sel[i] ? tlb_d1[i]   : tlb_d0[i]);
            assign data_lookup_v[i+1]        = data_lookup_v[i]       | { 1{data_match[i]}} & (data_sel[i] ? tlb_v1[i]   : tlb_v0[i]);
        end
    endgenerate

    assign data_paddr    = data_lookup_paddr[ENTRIES];
    assign data_cache    = data_lookup_c[ENTRIES];
    assign data_miss     = ~|data_match;
    assign data_invalid  = ~data_lookup_v[ENTRIES];
    assign data_dirty    = data_lookup_d[ENTRIES];
    
    // probe
    
    wire [ENTRIES-1:0] probe_match;
    wire [IDXBITS-1:0] probe_idx [ENTRIES:0];
    
    assign probe_idx[0] = 0;
    generate
        for (i=0; i<ENTRIES; i=i+1) begin
            assign probe_match[i] = (entryhi[`ENTRYHI_VPN2] & ~tlb_mask[i]) == (tlb_vpn2[i] & ~tlb_mask[i])&& (tlb_g[i] || tlb_asid[i] == entryhi[`ENTRYHI_ASID]);
            assign probe_idx[i+1] = probe_idx[i] | (probe_match[i] ? i : 0);
        end
    endgenerate
    
    assign probe_index = ((~|probe_match) << 31) | probe_idx[ENTRIES];
    
    // read
    
    assign read_hi = {
        tlb_vpn2[idx],
        5'd0,
        tlb_asid[idx]
    };
    
    assign read_lo0 = {
        6'd0,
        tlb_pfn0[idx],
        tlb_c0[idx],
        tlb_d0[idx],
        tlb_v0[idx],
        tlb_g[idx]
    };
    
    assign read_lo1 = {
        6'd0,
        tlb_pfn1[idx],
        tlb_c1[idx],
        tlb_d1[idx],
        tlb_v1[idx],
        tlb_g[idx]
    };
    
    assign read_mask = tlb_mask[idx];

endmodule
