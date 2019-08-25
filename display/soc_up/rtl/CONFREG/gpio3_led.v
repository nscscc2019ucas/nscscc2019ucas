module gpio3_led(
    input         clk, //33MHz
    input         resetn,
    input  [31:0] control,
    output        pin
);
    reg  [31:0] counter;
    reg  [31:0] compare;
    reg  [31:0] old;
    reg         loop;
    wire        always_on;
    wire        always_off;
    wire [31:0] shift;

    assign always_on  = old[31] & old[30];
    assign always_off = !(old[31] | old[30]);
    assign shift = {control[29:0], 2'b00};
    assign pin = always_on  ? 1'b1 :
                 always_off ? 1'b0 :
                              loop ;

    always @(posedge clk)
    begin
        if (!resetn)
        begin
            counter <= 32'b0;
            old     <= 32'h803d0900;
            compare <= 32'h01f78a40;
            loop    <= 1'b1;
        end
        else if (control != old)
        begin
            counter <= 32'b0;
            old     <= control;
            compare <= shift;
            loop    <= 1'b1;
        end
        else if (counter == compare)
        begin
            counter <= 32'b0;
            loop    <= ~loop;
        end
        else
        begin
            counter <= counter + 1'b1;
        end
    end
endmodule