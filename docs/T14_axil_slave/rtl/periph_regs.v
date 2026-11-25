// ============================================================================
// periph_regs.v  -  Register bank of the peripheral (protocol independent)
// T14 AXI4-Lite  |  Step 2 : building blocks
// Simple internal bus: one write per clock (wr_en), combinational read.
//
//   offset  name       access  description
//   0x00    GPIO_OUT   RW      LEDs                               reset 0
//   0x04    GPIO_IN    RO      switches / buttons (synchronized)
//   0x08    SEG_DATA   RW      8 hex digits for the 7-segment     reset 0
//   0x0C    SEG_CTRL   RW      [7:0] digit enable (1 = on)        reset 0x000000FF
//   0x10    CNT_VALUE  RO      free-running counter
//   0x14    CNT_CTRL   RW      [0] enable (reset 1), [1] clear (write 1, reads 0)
//   0x18    CNT_PRESC  RW      counter increments every PRESC+1 clocks, reset 0
//   0x1C    SCRATCH    RW      free for software                  reset 0
//   0x20    ID         RO      0x41584C01  ("AXL", version 1)
//   other   -          -       error (SLVERR); writing a RO register is an error
// ============================================================================
module periph_regs #(
    parameter        NIN = 16,                    // GPIO input pins
    parameter [31:0] ID  = 32'h4158_4C01
) (
    input  wire           clk,
    input  wire           rst_n,
    // write port
    input  wire           wr_en,
    input  wire [11:0]    wr_addr,
    input  wire [31:0]    wr_data,
    input  wire [3:0]     wr_strb,
    output wire           wr_err,                 // combinational, valid with wr_en
    // read port
    input  wire [11:0]    rd_addr,
    output reg  [31:0]    rd_data,
    output wire           rd_err,
    // peripheral pins
    input  wire [NIN-1:0] gpio_in,
    output wire [31:0]    gpio_out,
    output wire [31:0]    seg_data,
    output wire [7:0]     seg_en
);
    localparam A_GPIO_OUT = 4'd0, A_GPIO_IN = 4'd1, A_SEG_DATA = 4'd2, A_SEG_CTRL = 4'd3,
               A_CNT_VAL  = 4'd4, A_CNT_CTRL = 4'd5, A_CNT_PRESC = 4'd6, A_SCRATCH = 4'd7,
               A_ID       = 4'd8;

    // ---- address decode (shared by read and write) ---------------------------
    function legal;   input [11:0] a;  legal = (a[11:6] == 0) && (a[1:0] == 0) && (a[5:2] <= A_ID);  endfunction
    function is_ro;   input [11:0] a;  is_ro = (a[5:2] == A_GPIO_IN) || (a[5:2] == A_CNT_VAL) || (a[5:2] == A_ID); endfunction

    // TODO 2.3: Write error: illegal address or read-only register. Read error: illegal address.
    //   (replace the placeholder line(s) below with your design)
    assign wr_err = 1'b0;
    assign rd_err = 1'b0;
    wire       we  = wr_en && !wr_err;
    wire [3:0] wix = wr_addr[5:2];

    // ---- RW registers ----------------------------------------------------------
    reg [31:0] r_gpio_out, r_seg_data, r_seg_ctrl, r_presc, r_scratch;
    reg        r_cnt_en;
    wire [31:0] merged;
    reg  [31:0] old_val;
    always @(*) begin
        case (wix)
            A_GPIO_OUT : old_val = r_gpio_out;
            A_SEG_DATA : old_val = r_seg_data;
            A_SEG_CTRL : old_val = r_seg_ctrl;
            A_CNT_CTRL : old_val = {31'd0, r_cnt_en};
            A_CNT_PRESC: old_val = r_presc;
            A_SCRATCH  : old_val = r_scratch;
            default    : old_val = 32'd0;
        endcase
    end
    wstrb_merge u_merge (.old_val(old_val), .wdata(wr_data), .wstrb(wr_strb), .new_val(merged));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_gpio_out <= 32'd0;  r_seg_data <= 32'd0;  r_seg_ctrl <= 32'h0000_00FF;
            r_presc    <= 32'd0;  r_scratch  <= 32'd0;  r_cnt_en   <= 1'b1;
        end else if (we) begin
            // TODO 2.4: Store "merged" into the addressed register (only implemented bits).
            //   (replace the placeholder line(s) below with your design)
            ;   // <-- case over wix
        end
    end

    // clear pulse: write CNT_CTRL with bit 1 = 1 (byte 0 strobed)
    wire cnt_clear = we && (wix == A_CNT_CTRL) && wr_strb[0] && wr_data[1];
    wire [31:0] cnt_value;
    free_counter u_cnt (.clk(clk), .rst_n(rst_n), .enable(r_cnt_en), .clear(cnt_clear),
                        .presc(r_presc), .count(cnt_value));

    wire [NIN-1:0] in_sync;
    sync_2ff #(.N(NIN)) u_sync (.clk(clk), .rst_n(rst_n), .d_async(gpio_in), .q_sync(in_sync));
    reg [31:0] in_32;
    always @(*) begin in_32 = 32'd0; in_32[NIN-1:0] = in_sync; end

    // ---- read multiplexer ------------------------------------------------------
    always @(*) begin
        rd_data = 32'd0;
        if (legal(rd_addr)) begin
            case (rd_addr[5:2])
                A_GPIO_OUT : rd_data = r_gpio_out;
                A_GPIO_IN  : rd_data = in_32;
                A_SEG_DATA : rd_data = r_seg_data;
                A_SEG_CTRL : rd_data = r_seg_ctrl;
                A_CNT_VAL  : rd_data = cnt_value;
                A_CNT_CTRL : rd_data = {31'd0, r_cnt_en};
                A_CNT_PRESC: rd_data = r_presc;
                A_SCRATCH  : rd_data = r_scratch;
                A_ID       : rd_data = ID;
                default    : rd_data = 32'd0;
            endcase
        end
    end

    assign gpio_out = r_gpio_out;
    assign seg_data = r_seg_data;
    assign seg_en   = r_seg_ctrl[7:0];
endmodule
