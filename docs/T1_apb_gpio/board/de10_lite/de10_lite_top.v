// ============================================================================
// de10_lite_top.v  -  T1 APB GPIO demo on Terasic DE10-Lite (MAX 10 10M50DAF484C7G)
//   KEY[0]      : reset (active-low)
//   KEY[1]      : GPIO pin 10  -> interrupt on press (rising edge of ~KEY[1])
//   SW[9:0]     : GPIO pins 9..0  (SW0 interrupts on both edges, SW1 on falling edge)
//   LEDR[9:0]   : DATA_OUT (the sequencer copies DATA_IN to DATA_OUT over APB)
//   HEX1..HEX0  : interrupt counter (hex)        HEX0 DP : irq (stretched)
//   HEX4..HEX2  : DATA_IN[11:0] as read over APB HEX5    : 'E' on ID/bus error
// ============================================================================
module de10_lite_top (
    input  wire       MAX10_CLK1_50,
    input  wire [1:0] KEY,
    input  wire [9:0] SW,
    output wire [9:0] LEDR,
    output wire [7:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5
);
    localparam N = 11;
    wire clk = MAX10_CLK1_50;
    wire rst_n;
    rst_sync u_rst (.clk(clk), .rst_n_in(KEY[0]), .rst_n_out(rst_n));

    wire [N-1:0] led;
    wire irq, irq_led, id_err, bus_err;
    wire [7:0]  irq_count;
    wire [31:0] din;

    gpio_system #(
        .N(N),
        .RISE_MASK(32'h0000_0401),            // pin 10 (KEY1), pin 0 (SW0)
        .FALL_MASK(32'h0000_0003),            // pin 0 (both edges), pin 1 (falling)
        .STRETCH(10000000)                    // 0.2 s at 50 MHz
    ) u_sys (
        .clk(clk), .rst_n(rst_n), .gpio_in({~KEY[1], SW}),
        .led(led), .irq(irq), .irq_led(irq_led), .irq_count(irq_count),
        .din_shown(din), .id_err(id_err), .bus_err(bus_err));

    assign LEDR = led[9:0];

    wire [6:0] s0, s1, s2, s3, s4;
    hex7seg h0 (.hex(irq_count[3:0]), .blank(1'b0), .seg(s0));
    hex7seg h1 (.hex(irq_count[7:4]), .blank(1'b0), .seg(s1));
    hex7seg h2 (.hex(din[3:0]),       .blank(1'b0), .seg(s2));
    hex7seg h3 (.hex(din[7:4]),       .blank(1'b0), .seg(s3));
    hex7seg h4 (.hex(din[11:8]),      .blank(1'b0), .seg(s4));
    assign HEX0 = {~irq_led, s0};             // bit 7 = decimal point (active-low)
    assign HEX1 = {1'b1, s1};
    assign HEX2 = {1'b1, s2};
    assign HEX3 = {1'b1, s3};
    assign HEX4 = {1'b1, s4};
    assign HEX5 = (id_err | bus_err) ? 8'b1000_0110 : 8'hFF;   // 'E' or blank
endmodule
