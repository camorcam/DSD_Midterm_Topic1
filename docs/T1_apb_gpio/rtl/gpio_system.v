// ============================================================================
// gpio_system.v  -  Board-independent system: sequencer -> APB master -> GPIO
// T1 APB GPIO  |  Step 6 : system
//
//   +---------------+  cmd/rsp  +------------+   APB   +----------+  pins
//   | gpio_demo_seq |---------->| apb_master |-------->| apb_gpio |<------> SW/KEY/LED
//   +---------------+<----------+------------+<--------+----------+
//          ^                                                |
//          +------------------------- irq ------------------+
// ============================================================================
module gpio_system #(
    parameter        N         = 16,
    parameter [31:0] RISE_MASK = 32'h0000_0001,
    parameter [31:0] FALL_MASK = 32'h0000_0001,
    parameter        STRETCH   = 10000000      // irq LED on-time in clocks
) (
    input  wire         clk,
    input  wire         rst_n,               // already synchronized
    input  wire [N-1:0] gpio_in,
    output wire [N-1:0] led,                 // gpio_out where DIR=1
    output wire         irq,
    output wire         irq_led,
    output wire [7:0]   irq_count,
    output wire [31:0]  din_shown,
    output wire         id_err,
    output wire         bus_err
);
    wire        cmd_valid, cmd_ready, cmd_write, rsp_valid, rsp_err;
    wire [11:0] cmd_addr;
    wire [31:0] cmd_wdata, rsp_rdata;
    wire [3:0]  cmd_strb;

    wire        PSEL, PENABLE, PWRITE, PREADY, PSLVERR;
    wire [11:0] PADDR;
    wire [31:0] PWDATA, PRDATA;
    wire [3:0]  PSTRB;
    wire [2:0]  PPROT;
    wire [N-1:0] gpio_out, gpio_oe;

    gpio_demo_seq #(.RISE_MASK(RISE_MASK), .FALL_MASK(FALL_MASK)) u_seq (
        .clk(clk), .rst_n(rst_n), .irq(irq),
        .cmd_valid(cmd_valid), .cmd_write(cmd_write), .cmd_addr(cmd_addr),
        .cmd_wdata(cmd_wdata), .cmd_strb(cmd_strb),
        .rsp_valid(rsp_valid), .rsp_rdata(rsp_rdata), .rsp_err(rsp_err),
        .din_shown(din_shown), .irq_count(irq_count), .id_err(id_err), .bus_err(bus_err));

    apb_master u_mst (
        .clk(clk), .rst_n(rst_n),
        .cmd_valid(cmd_valid), .cmd_ready(cmd_ready), .cmd_write(cmd_write),
        .cmd_addr(cmd_addr), .cmd_wdata(cmd_wdata), .cmd_strb(cmd_strb),
        .rsp_valid(rsp_valid), .rsp_rdata(rsp_rdata), .rsp_err(rsp_err),
        .PSEL(PSEL), .PENABLE(PENABLE), .PWRITE(PWRITE), .PADDR(PADDR),
        .PWDATA(PWDATA), .PSTRB(PSTRB), .PPROT(PPROT),
        .PRDATA(PRDATA), .PREADY(PREADY), .PSLVERR(PSLVERR));

    apb_gpio #(.N(N)) u_gpio (
        .PCLK(clk), .PRESETn(rst_n), .PSEL(PSEL), .PENABLE(PENABLE), .PWRITE(PWRITE),
        .PADDR(PADDR), .PWDATA(PWDATA), .PSTRB(PSTRB), .PPROT(PPROT),
        .PRDATA(PRDATA), .PREADY(PREADY), .PSLVERR(PSLVERR),
        .gpio_in(gpio_in), .gpio_out(gpio_out), .gpio_oe(gpio_oe), .irq(irq));

    pulse_stretch #(.LEN(STRETCH)) u_str (.clk(clk), .rst_n(rst_n), .in(irq), .out(irq_led));

    assign led = gpio_out & gpio_oe;
    wire unused = cmd_ready;
endmodule
