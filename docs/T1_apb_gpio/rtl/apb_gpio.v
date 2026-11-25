// ============================================================================
// apb_gpio.v  -  AMBA APB4 GPIO peripheral with edge interrupts
// T1 APB GPIO  |  Step 4 : full peripheral
//
// Register map (byte offsets, 32-bit registers, bits >= N read as 0)
//   0x00 DATA_OUT   RW   value driven on output pins
//   0x04 DATA_IN    RO   synchronized pin values
//   0x08 DIR        RW   1 = pin is an output (gpio_oe)
//   0x0C INT_ENABLE RW   1 = pending status bit raises irq
//   0x10 INT_RISE   RW   1 = rising edge sets INT_STATUS
//   0x14 INT_FALL   RW   1 = falling edge sets INT_STATUS (both = any edge)
//   0x18 INT_STATUS W1C  pending edge events, write 1 to clear
//   0x1C ID         RO   peripheral identification (ID parameter)
//   other offsets   -> PSLVERR = 1 (read data 0, nothing written)
//   write to RO     -> PSLVERR = 1 (nothing written)
// ============================================================================
module apb_gpio #(
    parameter        N           = 16,            // number of GPIO pins (1..32)
    parameter        WAIT_STATES = 0,             // extra ACCESS cycles (0..15)
    parameter [31:0] ID          = 32'h4750_4901  // "GPI" + version 1
) (
    // APB4 slave port
    input  wire        PCLK,
    input  wire        PRESETn,
    input  wire        PSEL,
    input  wire        PENABLE,
    input  wire        PWRITE,
    input  wire [11:0] PADDR,
    input  wire [31:0] PWDATA,
    input  wire [3:0]  PSTRB,
    input  wire [2:0]  PPROT,                     // not used by this slave
    output reg  [31:0] PRDATA,
    output wire        PREADY,
    output reg         PSLVERR,
    // GPIO pins
    input  wire [N-1:0] gpio_in,                  // asynchronous pin inputs
    output wire [N-1:0] gpio_out,
    output wire [N-1:0] gpio_oe,
    output wire         irq
);
    localparam [31:0] MASK = (N == 32) ? 32'hFFFF_FFFF : ((32'h1 << N) - 1);

    // register offsets (word index = PADDR[4:2])
    localparam A_DATA_OUT = 3'd0, A_DATA_IN = 3'd1, A_DIR     = 3'd2, A_INT_EN = 3'd3,
               A_INT_RISE = 3'd4, A_INT_FALL = 3'd5, A_INT_STAT = 3'd6, A_ID    = 3'd7;

    // ------------------------------------------------------------------ 4.1
    // Wait-state generator: PREADY goes high after WAIT_STATES ACCESS cycles
    reg [3:0] wcnt;
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)                       wcnt <= 4'd0;
        else if (PSEL && PENABLE && !PREADY) wcnt <= wcnt + 4'd1;
        else                                 wcnt <= 4'd0;
    end
    assign PREADY = (WAIT_STATES == 0) ? 1'b1 : (wcnt == WAIT_STATES);

    // ------------------------------------------------------------------ 4.2
    // Address decode and error detection
    wire [2:0] idx      = PADDR[4:2];
    // TODO 4.2: mapped = offset is inside 0x00..0x1C and word aligned; ro = DATA_IN or ID.
    //   (replace the placeholder line(s) below with your design)
    wire       mapped   = 1'b1;
    wire       ro       = 1'b0;
    wire       access   = PSEL && PENABLE && PREADY;      // last cycle of a transfer
    wire       err      = !mapped || (PWRITE && ro);
    // TODO 4.3: A register is written only in the completing ACCESS cycle of a legal write.
    //   (replace the placeholder line(s) below with your design)
    wire       wr_en    = 1'b0;

    // ------------------------------------------------------------------ 4.4
    // Registers (byte strobes handled by byte_reg)
    wire [31:0] r_data_out, r_dir, r_int_en, r_int_rise, r_int_fall;
    byte_reg #(.MASK(MASK)) u_data_out (.clk(PCLK), .rst_n(PRESETn), .we(wr_en && idx == A_DATA_OUT),
                                        .strb(PSTRB), .wdata(PWDATA), .q(r_data_out));
    byte_reg #(.MASK(MASK)) u_dir      (.clk(PCLK), .rst_n(PRESETn), .we(wr_en && idx == A_DIR),
                                        .strb(PSTRB), .wdata(PWDATA), .q(r_dir));
    byte_reg #(.MASK(MASK)) u_int_en   (.clk(PCLK), .rst_n(PRESETn), .we(wr_en && idx == A_INT_EN),
                                        .strb(PSTRB), .wdata(PWDATA), .q(r_int_en));
    byte_reg #(.MASK(MASK)) u_int_rise (.clk(PCLK), .rst_n(PRESETn), .we(wr_en && idx == A_INT_RISE),
                                        .strb(PSTRB), .wdata(PWDATA), .q(r_int_rise));
    byte_reg #(.MASK(MASK)) u_int_fall (.clk(PCLK), .rst_n(PRESETn), .we(wr_en && idx == A_INT_FALL),
                                        .strb(PSTRB), .wdata(PWDATA), .q(r_int_fall));

    // Input synchronizer
    wire [N-1:0] pin_sync;
    sync_2ff #(.N(N)) u_sync (.clk(PCLK), .rst_n(PRESETn), .d_async(gpio_in), .q_sync(pin_sync));

    // W1C clear mask: bytes not selected by PSTRB never clear anything
    wire [31:0] strb_mask = {{8{PSTRB[3]}}, {8{PSTRB[2]}}, {8{PSTRB[1]}}, {8{PSTRB[0]}}};
    wire [31:0] clr_mask  = PWDATA & strb_mask;

    wire [N-1:0] int_status;
    gpio_irq #(.N(N)) u_irq (
        .clk(PCLK), .rst_n(PRESETn), .pin_sync(pin_sync),
        .rise_en(r_int_rise[N-1:0]), .fall_en(r_int_fall[N-1:0]), .int_en(r_int_en[N-1:0]),
        .clr_we(wr_en && idx == A_INT_STAT), .clr_mask(clr_mask[N-1:0]),
        .status(int_status), .irq(irq));

    // ------------------------------------------------------------------ 4.5
    // Read multiplexer and response (combinational, valid in ACCESS phase)
    reg  [31:0] pin_sync_32, int_status_32;        // zero-extended to 32 bits
    always @(*) begin
        pin_sync_32   = 32'h0;  pin_sync_32[N-1:0]   = pin_sync;
        int_status_32 = 32'h0;  int_status_32[N-1:0] = int_status;
    end
    always @(*) begin
        PRDATA  = 32'h0;
        PSLVERR = 1'b0;
        if (PSEL && PENABLE) begin
            PSLVERR = PREADY && err;
            if (!PWRITE && mapped) begin
                // TODO 4.5: Select the register addressed by idx.
                //   (replace the placeholder line(s) below with your design)
                PRDATA = 32'h0;   // <-- case statement over idx
            end
        end
    end

    assign gpio_out = r_data_out[N-1:0];
    assign gpio_oe  = r_dir[N-1:0];

    wire unused = &{1'b0, PPROT};                 // keep lint quiet
endmodule
