// ============================================================================
// wstrb_merge.v  -  new = old with the bytes selected by WSTRB replaced
// T14 AXI4-Lite  |  Step 2 : building blocks   (pure combinational)
// ============================================================================
module wstrb_merge (
    input  wire [31:0] old_val,
    input  wire [31:0] wdata,
    input  wire [3:0]  wstrb,
    output wire [31:0] new_val
);
    // TODO 2.1: Expand each strobe bit to 8 bits, then select per bit between wdata and old_val.
    //   (replace the placeholder line(s) below with your design)
    assign new_val = old_val;
endmodule
