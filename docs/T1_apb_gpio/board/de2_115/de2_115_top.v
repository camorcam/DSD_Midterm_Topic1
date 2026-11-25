// ============================================================================
// de2_115_top.v  -  T1 APB GPIO demo on Terasic DE2-115 (Cyclone IV E EP4CE115F29C7)
//   KEY[0]      : reset (active-low)
//   KEY[3:1]    : GPIO pins 20..18 -> interrupt on press; KEY3 also on release
//   SW[17:0]    : GPIO pins 17..0  (SW0 both edges, SW1 falling edge)
//   LEDR[17:0]  : DATA_OUT[17:0]        LEDG[2:0] : DATA_OUT[20:18] (keys)
//   LEDG[8]     : irq (stretched)       LEDG[7]   : ID / bus error
//   HEX1..HEX0  : interrupt counter     HEX7..HEX2: DATA_IN[23:0] read over APB
// ============================================================================
module de2_115_top (
    input  wire        CLOCK_50,
    input  wire [3:0]  KEY,
    input  wire [17:0] SW,
    output wire [17:0] LEDR,
    output wire [8:0]  LEDG,
    output wire [6:0]  HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, HEX6, HEX7
);
    localparam N = 21;
    wire clk = CLOCK_50;
    wire rst_n;
    rst_sync u_rst (.clk(clk), .rst_n_in(KEY[0]), .rst_n_out(rst_n));

    wire [N-1:0] led;
    wire irq, irq_led, id_err, bus_err;
    wire [7:0]  irq_count;
    wire [31:0] din;

    gpio_system #(
        .N(N),
        .RISE_MASK(32'h001C_0001),            // pins 20..18 (KEY3..1), pin 0
        .FALL_MASK(32'h0010_0003),            // pin 20 (KEY3 release), pins 1..0
        .STRETCH(10000000)
    ) u_sys (
        .clk(clk), .rst_n(rst_n), .gpio_in({~KEY[3:1], SW}),
        .led(led), .irq(irq), .irq_led(irq_led), .irq_count(irq_count),
        .din_shown(din), .id_err(id_err), .bus_err(bus_err));

    assign LEDR      = led[17:0];
    assign LEDG[2:0] = led[20:18];
    assign LEDG[6:3] = 4'b0000;
    assign LEDG[7]   = id_err | bus_err;
    assign LEDG[8]   = irq_led;

    hex7seg h0 (.hex(irq_count[3:0]), .blank(1'b0), .seg(HEX0));
    hex7seg h1 (.hex(irq_count[7:4]), .blank(1'b0), .seg(HEX1));
    hex7seg h2 (.hex(din[3:0]),   .blank(1'b0), .seg(HEX2));
    hex7seg h3 (.hex(din[7:4]),   .blank(1'b0), .seg(HEX3));
    hex7seg h4 (.hex(din[11:8]),  .blank(1'b0), .seg(HEX4));
    hex7seg h5 (.hex(din[15:12]), .blank(1'b0), .seg(HEX5));
    hex7seg h6 (.hex(din[19:16]), .blank(1'b0), .seg(HEX6));
    hex7seg h7 (.hex(din[23:20]), .blank(1'b0), .seg(HEX7));
endmodule
