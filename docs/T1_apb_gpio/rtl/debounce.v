// ============================================================================
// debounce.v  -  Counter-based debounce filter (one per bit)   [stretch goal]
// T1 APB GPIO  |  Step 1 : basic circuits
// The output follows the input only after the input has stayed at the same
// value for STABLE consecutive clocks.  At 50 MHz, STABLE = 500_000 is 10 ms.
// The input must already be synchronized.
// ============================================================================
module debounce #(
    parameter N      = 1,
    parameter STABLE = 500000,            // clocks the input must be stable
    parameter CW     = 20                 // counter width, 2**CW > STABLE
) (
    input  wire         clk,
    input  wire         rst_n,
    input  wire [N-1:0] d,                // synchronized, bouncing input
    output reg  [N-1:0] q                 // clean output
);
    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin : g_bit
            reg [CW-1:0] cnt;
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    cnt  <= {CW{1'b0}};
                    q[i] <= 1'b0;
                end else if (d[i] == q[i]) begin
                    cnt  <= {CW{1'b0}};             // no change requested
                end else if (cnt == STABLE - 1) begin
                    q[i] <= d[i];                   // stable long enough: accept
                    cnt  <= {CW{1'b0}};
                end else begin
                    cnt  <= cnt + 1'b1;             // still counting
                end
            end
        end
    endgenerate
endmodule
