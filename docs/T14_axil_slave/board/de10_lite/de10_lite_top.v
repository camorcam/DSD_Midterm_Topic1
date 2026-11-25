// ============================================================================
// de10_lite_top.v  -  T14 AXI4-Lite demo on Terasic DE10-Lite
//   KEY[0] : reset            KEY[1] : clear the counter (GPIO_IN bit 10)
//   SW[8:0]: GPIO_IN -> GPIO_OUT -> LEDR[8:0]   (copied by the sequencer over AXI)
//   SW[9]  : display select   0 = counter (10 counts/s)   1 = switch value
//   HEX5..HEX0 : SEG_DATA[23:0]  (digits enabled by SEG_CTRL)   HEX5 DP : bus/ID error
// ============================================================================
module de10_lite_top (
    input  wire       MAX10_CLK1_50,
    input  wire [1:0] KEY,
    input  wire [9:0] SW,
    output wire [9:0] LEDR,
    output wire [7:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5
);
    wire clk = MAX10_CLK1_50;
    wire rst_n;
    rst_sync u_rst (.clk(clk), .rst_n_in(KEY[0]), .rst_n_out(rst_n));

    wire [31:0] gpio_out, seg_data;  wire [7:0] seg_en;  wire id_err, bus_err;
    axil_system #(.NIN(11), .PRESC(32'd4999999), .SEG_EN(32'h3F), .CLR_BIT(10), .SEL_BIT(9)) u_sys (
        .clk(clk), .rst_n(rst_n), .gpio_in({~KEY[1], SW}), .gpio_out(gpio_out),
        .seg_data(seg_data), .seg_en(seg_en), .id_err(id_err), .bus_err(bus_err));

    assign LEDR = gpio_out[9:0];

    wire [6:0] s [0:5];
    genvar k;
    generate for (k = 0; k < 6; k = k + 1) begin : g_hex
        hex7seg u_h (.hex(seg_data[4*k +: 4]), .blank(!seg_en[k]), .seg(s[k]));
    end endgenerate
    assign HEX0 = {1'b1, s[0]};  assign HEX1 = {1'b1, s[1]};  assign HEX2 = {1'b1, s[2]};
    assign HEX3 = {1'b1, s[3]};  assign HEX4 = {1'b1, s[4]};
    assign HEX5 = {~(id_err | bus_err), s[5]};
endmodule
