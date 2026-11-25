// ============================================================================
// free_counter.v  -  32-bit free-running counter with prescaler
// T14 AXI4-Lite  |  Step 2 : building blocks
//   tick  = 1 every (presc + 1) clocks while enable = 1
//   count increments on tick;  clear has priority (count = 0, prescaler = 0)
// ============================================================================
module free_counter (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,
    input  wire        clear,              // one-clock pulse
    input  wire [31:0] presc,              // divide factor - 1
    output reg  [31:0] count
);
    reg  [31:0] pcnt;
    wire        tick = (pcnt >= presc);    // ">=" : safe if presc is made smaller
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pcnt <= 32'd0;  count <= 32'd0;
        end else if (clear) begin
            pcnt <= 32'd0;  count <= 32'd0;
        end else if (enable) begin
            // TODO 2.2: On tick: restart the prescaler and increment count; otherwise advance the prescaler.
            //   (replace the placeholder line(s) below with your design)
            pcnt <= pcnt;
        end
    end
endmodule
