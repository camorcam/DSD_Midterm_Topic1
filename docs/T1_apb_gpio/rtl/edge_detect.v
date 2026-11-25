// ============================================================================
// edge_detect.v  -  Rising / falling edge detector (one per bit)
// T1 APB GPIO  |  Step 1 : basic circuits
// The input MUST already be synchronous to clk (use sync_2ff first).
// rise/fall are one-clock pulses in the cycle after the input changed.
// ============================================================================
module edge_detect #(
    parameter N = 1
) (
    input  wire         clk,
    input  wire         rst_n,
    input  wire [N-1:0] d,                // synchronous input
    output wire [N-1:0] rise,             // 1 for one clock after a 0->1 change
    output wire [N-1:0] fall              // 1 for one clock after a 1->0 change
);
    reg [N-1:0] d_q;                      // value of d in the previous clock

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) d_q <= {N{1'b0}};
        else        d_q <= d;
    end

    // TODO 1.2: Compare the present value d with the previous value d_q (bitwise).
    //   (replace the placeholder line(s) below with your design)
    assign rise = {N{1'b0}};
    assign fall = {N{1'b0}};
endmodule
