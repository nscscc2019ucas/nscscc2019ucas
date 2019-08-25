`define LCD_CMD_INST 4'd1
`define LCD_CMD_DATA 4'd2

`define STATE_IDLE   3'd0
`define STATE_RESET  3'd1
`define STATE_INIT   3'd2

`define LCD_BITS_VALID 31
`define LCD_BITS_CMD   19:16
`define LCD_BITS_DATA  15:0

module lcd(
    input          clk, //33MHz
    input          resetn, 
    input  [31: 0] lcd_confreg_i,
    output [31: 0] lcd_confreg_o,

    output         lcd_hw_rst,
    output         lcd_hw_cs,
    output         lcd_hw_rs,
    output         lcd_hw_wr,
    output         lcd_hw_rd,
    output [15: 0] lcd_hw_data,
    output         lcd_hw_bl_ctr
);
    reg [2:0] lcd_state;
    wire in_reset_state, hard_reset_end;
    
    reg [24:0] counter;
    always @(posedge clk)
        if (~resetn | hard_reset_end)
            counter <= 25'b0;
        else
            counter <= counter + 1;
    // lcd_confreg_i: {valid, 11'b0, cmd, data}

    // hard reset
    assign in_reset_state = (lcd_state == `STATE_RESET);
    assign hard_reset_end = in_reset_state & (counter == 25'hffffff);
    
    // init state, data from reset_ram
    wire in_init_state;
    assign in_init_state = (lcd_state == `STATE_INIT);
    reg [9:0] init_addr;
    always @(posedge clk)
        if (hard_reset_end)
            init_addr <= 10'b0;
        else 
            init_addr <= init_addr + 1;
    reg init_rdata_valid;
    always @(posedge clk)
        if (hard_reset_end)
            init_rdata_valid <= 1'b0;
        else
            init_rdata_valid <= 1'b1;
    wire [31:0] init_rdata;
    lcd_init_data reset_ram_module(//2KB
        .clka  (clk),
        .addra (init_addr),
        .douta (init_rdata),
        .ena   (1'b1)
    );
    reg init_seq1_end;
    always @(posedge clk)
        if (hard_reset_end | ~resetn)
            init_seq1_end <= 1'b0;
        else if (in_init_state && !init_rdata[`LCD_BITS_VALID])
            init_seq1_end <= 1'b1;

    wire init_seq2_end = in_init_state & (counter == 25'h1fff);
    wire [31:0] init_data;
    assign init_data = (init_seq2_end) ? {1'b1, 11'b0, `LCD_CMD_INST, 16'h2900} : 
                       (init_seq1_end | ~init_rdata_valid) ? 32'b0 : init_rdata;

    //init image control sequence
    reg [18:0] init2_addr;
    wire [31:0] init2_rdata;
    reg init_img_end;
    always @(posedge clk) begin
        if (~resetn)
            init2_addr <= 19'b0;
        else if ((init_seq2_end || init2_addr) && ~init_img_end)
            init2_addr <= init2_addr + 1;
        
        if (~resetn)
            init_img_end <= 1'b0;
        else if (~init2_rdata[`LCD_BITS_VALID])
            init_img_end <= 1'b1;
    end
    init_img_rom init_image_module(
            .clka  (clk),
            .addra (init2_addr),
            .douta (init2_rdata),
            .ena   (1'b1)
        );

    reg resetn_latch;
    always @(posedge clk)
        resetn_latch <= resetn;
    wire reset_init = resetn & ~resetn_latch;
    always @(posedge clk)
        if (~resetn || init_seq2_end)
            lcd_state <= `STATE_IDLE;
        else if (reset_init)
            lcd_state <= `STATE_RESET;
        else if (hard_reset_end)
            lcd_state <= `STATE_INIT;

    // lcd output
    assign lcd_confreg_o = {31'b0, in_init_state | ~init_img_end};
    wire [31:0] lcd_out;
    assign lcd_out = (in_init_state) ? init_data : 
                     (~init_img_end) ? init2_rdata :
                     lcd_confreg_i;
    wire valid_o;
    wire [3:0] cmd_o;
    wire [15:0] data_o;
    assign valid_o = lcd_out[`LCD_BITS_VALID];
    assign cmd_o = lcd_out[`LCD_BITS_CMD];
    assign data_o = lcd_out[`LCD_BITS_DATA];
    
    wire is_inst = (cmd_o == `LCD_CMD_INST);
    wire is_data = (cmd_o == `LCD_CMD_DATA);
    
    assign lcd_hw_rst = resetn & ~in_reset_state;
    assign lcd_hw_cs  = 1'b0;
    assign lcd_hw_bl_ctr = 1'b1;
    assign lcd_hw_rs = valid_o & is_data;
    assign lcd_hw_rd = 1'b1;
    assign lcd_hw_data = data_o;
    reg clk_gen0, clk_gen1;
    always @(posedge clk)
        clk_gen0 <= clk_gen1;
    always @(negedge clk)
        if (~resetn)
            clk_gen1 <= 1'b0;
        else
            clk_gen1 <= ~clk_gen1;
    wire mask_gen;
    assign mask_gen = clk_gen0 ^ clk_gen1;
    assign lcd_hw_wr = mask_gen & valid_o;

endmodule
