// ============================================================================
// sync_2ff.v  -  Two flip-flop synchronizer (one per bit)
// T1 APB GPIO  |  Step 1 : basic circuits
// An asynchronous input (switch, button, external pin) can change at any time
// relative to PCLK.  The first flip-flop may go metastable; the second one
// gives it one full clock period to settle before the value is used.
// ============================================================================
module sync_2ff #(
    parameter N = 1                       // number of independent bits
) (
    input  wire         clk,
    input  wire         rst_n,            // active-low, asynchronous
    input  wire [N-1:0] d_async,          // input from the outside world
    output wire [N-1:0] q_sync            // synchronized to clk
);
    reg [N-1:0] meta;                     // stage 1 (may be metastable)
    reg [N-1:0] sync;                     // stage 2 (stable)

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            meta <= {N{1'b0}};
            sync <= {N{1'b0}};
        end else begin
            meta <= d_async;
            sync <= meta;
        end
    end

    assign q_sync = sync;
endmodule
