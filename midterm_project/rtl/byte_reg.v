// ============================================================================
// byte_reg.v  -  Read/write register with byte write strobes
// T1 APB GPIO  |  Step 2 : building blocks
// One byte lane i (bits 8i+7 .. 8i) is written only when we=1 AND strb[i]=1.
// MASK marks the implemented bits: unimplemented bits always read 0.
// ============================================================================
module byte_reg #(
    parameter          W         = 32,              // multiple of 8
    parameter [W-1:0]  RESET_VAL = {W{1'b0}},
    parameter [W-1:0]  MASK      = {W{1'b1}}
) (
    input  wire           clk,
    input  wire           rst_n,
    input  wire           we,                       // write enable (one clock)
    input  wire [W/8-1:0] strb,                     // byte enables
    input  wire [W-1:0]   wdata,
    output reg  [W-1:0]   q
);
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q <= RESET_VAL & MASK;
        end else if (we) begin
            for (i = 0; i < W/8; i = i + 1)
                if (strb[i])
                    q[8*i +: 8] <= wdata[8*i +: 8] & MASK[8*i +: 8];
        end
    end
endmodule
