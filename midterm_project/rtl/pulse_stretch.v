// ============================================================================
// pulse_stretch.v - keeps out = 1 for LEN clocks after the last in = 1
// (a 1-clock interrupt pulse is invisible on an LED; 50e6*0.2 = 0.2 s)
// ============================================================================
module pulse_stretch #(
    parameter LEN = 10000000,
    parameter CW  = 24
) (
    input  wire clk, rst_n, in,
    output wire out
);
    reg [CW-1:0] cnt;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)          cnt <= {CW{1'b0}};
        else if (in)         cnt <= LEN[CW-1:0];
        else if (cnt != 0)   cnt <= cnt - 1'b1;
    end
    assign out = (cnt != 0);
endmodule
