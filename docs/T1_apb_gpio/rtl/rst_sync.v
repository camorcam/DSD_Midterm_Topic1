// ============================================================================
// rst_sync.v  -  Reset synchronizer: asynchronous assert, synchronous release
// T1 APB GPIO  |  Step 1 : basic circuits
// A push-button reset may be released at any moment; releasing reset close to
// a clock edge can break the flip-flops' recovery/removal timing. This circuit
// asserts rst_n_out immediately but releases it two clocks after rst_n_in.
// ============================================================================
module rst_sync (
    input  wire clk,
    input  wire rst_n_in,                 // e.g. KEY[0] (active-low)
    output wire rst_n_out                 // safe system reset (active-low)
);
    reg r1, r2;
    always @(posedge clk or negedge rst_n_in) begin
        if (!rst_n_in) begin r1 <= 1'b0; r2 <= 1'b0; end
        else           begin r1 <= 1'b1; r2 <= r1;   end
    end
    assign rst_n_out = r2;
endmodule
