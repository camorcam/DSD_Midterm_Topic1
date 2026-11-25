// ============================================================================
// gpio_irq.v  -  Per-pin edge interrupt unit with W1C status register
// T1 APB GPIO  |  Step 3 : building blocks
//   event[i]  = (rise[i] & INT_RISE[i]) | (fall[i] & INT_FALL[i])
//   STATUS[i] : set by event[i], cleared by writing 1 (W1C). Set wins.
//   irq       = OR of (STATUS & INT_ENABLE)
// Both INT_RISE and INT_FALL = 1 gives "both edges".
// ============================================================================
module gpio_irq #(
    parameter N = 16
) (
    input  wire         clk,
    input  wire         rst_n,
    input  wire [N-1:0] pin_sync,         // synchronized pin values
    input  wire [N-1:0] rise_en,          // INT_RISE register
    input  wire [N-1:0] fall_en,          // INT_FALL register
    input  wire [N-1:0] int_en,           // INT_ENABLE register
    input  wire         clr_we,           // write to INT_STATUS this clock
    input  wire [N-1:0] clr_mask,         // bits written with 1 (after strobes)
    output reg  [N-1:0] status,           // INT_STATUS register
    output wire         irq               // interrupt request to the CPU
);
    wire [N-1:0] rise, fall;
    edge_detect #(.N(N)) u_edge (
        .clk(clk), .rst_n(rst_n), .d(pin_sync), .rise(rise), .fall(fall));

    wire [N-1:0] event_v = (rise & rise_en) | (fall & fall_en);
    wire [N-1:0] clr_v   = clr_we ? clr_mask : {N{1'b0}};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) status <= {N{1'b0}};
        else status <= (status & ~clr_v) | event_v;
    end

    assign irq = |(status & int_en);
endmodule
