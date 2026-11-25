// ============================================================================
// tb_step6_system.v  -  Step 6 testbench: complete system (sequencer + APB
// master + apb_gpio).  Models the board: switches, push-button, LEDs.
// ============================================================================
`timescale 1ns/1ps
module tb_step6_system;
    localparam N = 16;
    reg clk = 1'b0;  always #10 clk = ~clk;
    reg rst_n = 1'b0;
    reg  [N-1:0] gpio_in = 0;                  // [15] = push-button, [14:0] = switches
    wire [N-1:0] led;
    wire irq, irq_led, id_err, bus_err;
    wire [7:0]  irq_count;
    wire [31:0] din_shown;

    gpio_system #(.N(N), .RISE_MASK(32'h0000_8001), .FALL_MASK(32'h0000_0003), .STRETCH(50)) dut (
        .clk(clk), .rst_n(rst_n), .gpio_in(gpio_in), .led(led), .irq(irq), .irq_led(irq_led),
        .irq_count(irq_count), .din_shown(din_shown), .id_err(id_err), .bus_err(bus_err));

    integer errors = 0;  reg [7:0] c0;

    task expect_count(input [7:0] inc, input [8*28-1:0] msg);
        begin
            repeat (300) @(posedge clk);
            if (irq_count !== c0 + inc) begin
                errors = errors + 1;
                $display("[%0t] FAIL %0s: irq_count=%0d expected %0d", $time, msg, irq_count, c0 + inc);
            end else $display("[%0t]  ok  %0s: irq_count=%0d", $time, msg, irq_count);
            c0 = irq_count;
        end
    endtask

    initial begin
        $dumpfile("step6.vcd");  $dumpvars(0, tb_step6_system);
        #55 rst_n = 1'b1;
        repeat (100) @(posedge clk);
        if (id_err || bus_err) begin errors = errors + 1; $display("FAIL id_err=%b bus_err=%b", id_err, bus_err); end
        else $display("[%0t]  ok  ID register read back correctly, configuration done", $time);

        gpio_in = 16'h0A50;  repeat (100) @(posedge clk);
        if (led !== 16'h0A50 || din_shown !== 32'h0A50) begin
            errors = errors + 1; $display("FAIL LEDs %h din_shown %h", led, din_shown);
        end else $display("[%0t]  ok  switches 0A50 -> LEDs %h (DATA_IN -> DATA_OUT over APB)", $time, led);
        c0 = irq_count;

        gpio_in[15] = 1'b1;  expect_count(1, "button press (rising)");
        gpio_in[15] = 1'b0;  expect_count(0, "button release (no fall)");
        gpio_in[0]  = 1'b1;  expect_count(1, "pin0 rising (both edges)");
        gpio_in[0]  = 1'b0;  expect_count(1, "pin0 falling (both edges)");
        gpio_in[1]  = 1'b1;  expect_count(0, "pin1 rising (fall only)");
        gpio_in[1]  = 1'b0;  expect_count(1, "pin1 falling (fall only)");
        gpio_in[7]  = 1'b1;  expect_count(0, "pin7 (no interrupt)");
        if (irq !== 1'b0) begin errors = errors + 1; $display("FAIL irq still pending"); end

        if (errors == 0) $display("*** STEP 6 PASS ***");
        else             $display("*** STEP 6 FAIL : %0d error(s) ***", errors);
        $finish;
    end
    initial begin #200000; $display("TIMEOUT - the design never reached the end of the test (deadlock?)  *** FAIL ***"); $finish; end
endmodule
