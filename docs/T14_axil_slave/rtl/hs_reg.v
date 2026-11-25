// ============================================================================
// hs_reg.v  -  One-entry VALID/READY register stage ("register slice")
// T14 AXI4-Lite  |  Step 1 : basic circuits
// A transfer happens on a rising edge where VALID = 1 and READY = 1.
//   upstream   s_valid / s_ready / s_data   (this block is the receiver)
//   downstream m_valid / m_ready / m_data   (this block is the sender)
// Rules shown here (the same rules hold on every AXI channel):
//   * the sender keeps VALID = 1 and the data stable until READY = 1
//   * the sender must not wait for READY before asserting VALID
//   * the receiver may assert READY before, together with, or after VALID
// ============================================================================
module hs_reg #(
    parameter W = 32
) (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         s_valid,
    output wire         s_ready,
    input  wire [W-1:0] s_data,
    output reg          m_valid,
    input  wire         m_ready,
    output reg  [W-1:0] m_data
);
    // TODO 1.1: The stage can accept new data when it is empty or when its data leaves in this clock.
    //   (replace the placeholder line(s) below with your design)
    assign s_ready = 1'b0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_valid <= 1'b0;
            m_data  <= {W{1'b0}};
        end else if (s_ready) begin
            // TODO 1.2: When s_ready: load the input; m_valid follows s_valid.
            //   (replace the placeholder line(s) below with your design)
            m_valid <= m_valid;
        end
    end
endmodule
