// ============================================================================
// tb_step6_system.v  -  Step 6: complete AXI4-Lite system (board model)
// gpio_in[10] = button (clear counter), gpio_in[9] = display select, [8:0] switches
// ============================================================================
`timescale 1ns/1ps
module tb_step6_system;
    reg clk = 1'b0;  always #10 clk = ~clk;
    reg rst_n = 1'b0;
    reg  [10:0] gpio_in = 11'h0;
    wire [31:0] gpio_out, seg_data;  wire [7:0] seg_en;  wire id_err, bus_err;

    axil_system #(.NIN(11), .PRESC(32'd9), .SEG_EN(32'h3F), .CLR_BIT(10), .SEL_BIT(9)) dut (
        .clk(clk), .rst_n(rst_n), .gpio_in(gpio_in), .gpio_out(gpio_out),
        .seg_data(seg_data), .seg_en(seg_en), .id_err(id_err), .bus_err(bus_err));

    integer errors = 0;  reg [31:0] a, b;
    initial begin
        $dumpfile("step6.vcd");  $dumpvars(0, tb_step6_system);
        #55 rst_n = 1'b1;
        repeat (60) @(posedge clk);
        if (id_err || bus_err || seg_en !== 8'h3F) begin errors = errors + 1; $display("FAIL init"); end
        else $display("[%0t]  ok  ID checked, counter and display configured (SEG_CTRL=%h)", $time, seg_en);

        gpio_in = 11'h0A5;  repeat (60) @(posedge clk);
        if (gpio_out[10:0] !== 11'h0A5) begin errors = errors + 1; $display("FAIL LEDs %h", gpio_out); end
        else $display("[%0t]  ok  switches 0A5 -> LEDs %h (AXI read + AXI write)", $time, gpio_out[10:0]);

        a = seg_data;  repeat (400) @(posedge clk);  b = seg_data;
        if (b - a < 35 || b - a > 45) begin errors = errors + 1; $display("FAIL counter display %0d -> %0d", a, b); end
        else $display("[%0t]  ok  display shows the counter: %0d -> %0d in 400 clocks (PRESC=9)", $time, a, b);

        gpio_in[10] = 1'b1;  repeat (40) @(posedge clk);  gpio_in[10] = 1'b0;  repeat (30) @(posedge clk);
        if (seg_data > 8) begin errors = errors + 1; $display("FAIL clear button: %0d", seg_data); end
        else $display("[%0t]  ok  button clears the counter: display = %0d", $time, seg_data);

        gpio_in[9] = 1'b1;  repeat (60) @(posedge clk);
        if (seg_data !== 32'h2A5) begin errors = errors + 1; $display("FAIL select: %h", seg_data); end
        else $display("[%0t]  ok  select switch: display shows the switches %h", $time, seg_data);

        if (errors == 0) $display("*** STEP 6 PASS ***");
        else             $display("*** STEP 6 FAIL : %0d error(s) ***", errors);
        $finish;
    end
    initial begin #200000; $display("TIMEOUT - the design never reached the end of the test (deadlock?)  *** FAIL ***"); $finish; end
endmodule
