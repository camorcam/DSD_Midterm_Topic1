// ============================================================================
// de2_115_top.v  -  T14 AXI4-Lite demo on Terasic DE2-115
//   KEY[0]  : reset            KEY[1] : clear the counter (GPIO_IN bit 18)
//   SW[16:0]: GPIO_IN -> GPIO_OUT -> LEDR      KEY[3:1] state -> LEDG[2:0]
//   SW[17]  : display select   0 = counter (10 counts/s)   1 = switch value
//   HEX7..HEX0 : SEG_DATA[31:0]                LEDG[7] : bus/ID error
// ============================================================================
module de2_115_top (
    input  wire        CLOCK_50,
    input  wire [3:0]  KEY,
    input  wire [17:0] SW,
    output wire [17:0] LEDR,
    output wire [8:0]  LEDG,
    output wire [6:0]  HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, HEX6, HEX7
);
    wire clk = CLOCK_50;
    wire rst_n;
    rst_sync u_rst (.clk(clk), .rst_n_in(KEY[0]), .rst_n_out(rst_n));

    wire [31:0] gpio_out, seg_data;  wire [7:0] seg_en;  wire id_err, bus_err;
    axil_system #(.NIN(21), .PRESC(32'd4999999), .SEG_EN(32'hFF), .CLR_BIT(18), .SEL_BIT(17)) u_sys (
        .clk(clk), .rst_n(rst_n), .gpio_in({~KEY[3:1], SW}), .gpio_out(gpio_out),
        .seg_data(seg_data), .seg_en(seg_en), .id_err(id_err), .bus_err(bus_err));

    assign LEDR      = gpio_out[17:0];
    assign LEDG[2:0] = gpio_out[20:18];
    assign LEDG[6:3] = 4'b0000;
    assign LEDG[7]   = id_err | bus_err;
    assign LEDG[8]   = 1'b0;

    hex7seg h0 (.hex(seg_data[3:0]),   .blank(!seg_en[0]), .seg(HEX0));
    hex7seg h1 (.hex(seg_data[7:4]),   .blank(!seg_en[1]), .seg(HEX1));
    hex7seg h2 (.hex(seg_data[11:8]),  .blank(!seg_en[2]), .seg(HEX2));
    hex7seg h3 (.hex(seg_data[15:12]), .blank(!seg_en[3]), .seg(HEX3));
    hex7seg h4 (.hex(seg_data[19:16]), .blank(!seg_en[4]), .seg(HEX4));
    hex7seg h5 (.hex(seg_data[23:20]), .blank(!seg_en[5]), .seg(HEX5));
    hex7seg h6 (.hex(seg_data[27:24]), .blank(!seg_en[6]), .seg(HEX6));
    hex7seg h7 (.hex(seg_data[31:28]), .blank(!seg_en[7]), .seg(HEX7));
endmodule
