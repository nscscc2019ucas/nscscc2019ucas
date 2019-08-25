module gpio4_motor(
    input         clk, //33MHz
    input         resetn,
    input  [31:0] control,
    output reg   ack,
    output        pin
);
    reg  [ 6:0] loop;  // MAX = 64 = 0b1000000
    reg  [31:0] counter;
    reg  [31:0] high;
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
        else if (curr_state == 3'b010 & loop[6])
            next_state <= 3'b000;
        else if (curr_state == 3'b010)
            next_state <= 3'b011;
        else if (curr_state == 3'b011)
            next_state <= 3'b100;
        else if (curr_state == 3'b100 & (counter == high))
            next_state <= 3'b101;
        else if (curr_state == 3'b101)
            next_state <= 3'b110;
        else if (curr_state == 3'b110 & (counter == 32'h000a1220))
            next_state <= 3'b010;
        else
            next_state <= curr_state;
    end

    always @(posedge clk)
    begin
        case (curr_state)
            3'b000:
            begin
                ack     <= 1'b0;
                out     <= 1'b0;
            end
            3'b001:
            begin
                ack     <= 1'b1;
                loop    <= 7'b0;
                counter <= 32'b0;
                high    <= {13'b0, control[18:0]};
            end
            3'b010:
            begin
                loop    <= loop + 7'b1;
                counter <= 32'b0;
            end
            3'b011: out <= 1'b1;
            3'b101: out <= 1'b0;
            default:
                counter  <= counter + 32'b1;
        endcase
    end
endmodule