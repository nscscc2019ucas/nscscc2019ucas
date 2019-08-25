module gpio2_buzzer(
    input         clk, //33MHz
    input         resetn,
    input  [31:0] control,
    output        pin
);

    reg  [31:0] counter;
    reg  [31:0] freq;
    reg         out;
    assign pin = out;

    reg [ 2:0] curr_state;
    reg [ 2:0] next_state;
    always @(posedge clk)
    begin
        if (!resetn)
            curr_state <= 3'b000;
        else
            curr_state <= next_state;
    end

    always @(*)
    begin
        if (curr_state == 3'b000 & control[31])
            next_state <= 3'b001;
        else if (curr_state == 3'b001)
            next_state <= 3'b010;
        else if (curr_state == 3'b010 & (counter == freq))
            next_state <= 3'b011;
        else if (curr_state == 3'b011)
            next_state <= 3'b100;
        else if (curr_state == 3'b100 & (counter == freq))
            next_state <= 3'b000;
        else
            next_state <= curr_state;
    end

    always @(posedge clk)
    begin
        case (curr_state)
            3'b000: out <= 1'b0;
            3'b001:
            begin
                out     <= 1'b1;
                counter <= 32'b0;
                freq    <= {1'b0, control[30:0]};
            end
            3'b011:
            begin
                out     <= 1'b0;
                counter <= 32'b0;
            end
            default:
                counter <= counter + 32'b1;
        endcase
    end
endmodule