`timescale 1ns/1ps
`default_nettype none

module tb_fpga_top;
    reg board_clk = 1'b0;
    always #5 board_clk = ~board_clk;
    reg board_reset_n = 1'b1;
    reg [31:0] gpio_in_async = 32'ha500_0000;
    wire [31:0] gpio_out, gpio_oe;
    wire irq, demo_done, demo_error;
    wire [31:0] captured_data_in, captured_int_status;
    wire [4:0] demo_state;
    integer checks = 0;

    fpga_top #(
        .GPIO_WIDTH(32),
        .APB_ADDR_WIDTH(8),
        .DEBOUNCE_COUNTER_WIDTH(3),
        .DEBOUNCE_CYCLES(3)
    ) dut (
        .board_clk(board_clk), .board_reset_n(board_reset_n),
        .gpio_in_async(gpio_in_async), .gpio_out(gpio_out),
        .gpio_oe(gpio_oe), .irq(irq), .demo_done(demo_done),
        .demo_error(demo_error), .captured_data_in(captured_data_in),
        .captured_int_status(captured_int_status), .demo_state(demo_state)
    );

    task automatic check32(input string label_text,
                           input logic [31:0] actual,
                           input logic [31:0] wanted);
        checks = checks + 1;
        if (actual !== wanted)
            $fatal(1, "%s: got %08h, expected %08h at %0t",
                   label_text, actual, wanted, $time);
    endtask

    initial begin
        #20000;
        $fatal(1, "Simulation watchdog expired");
    end

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("tb_fpga_top.vcd");
            $dumpvars(0, tb_fpga_top);
        end
        #2 board_reset_n = 1'b0;
        #1;
        check32("reset gpio_out", gpio_out, 0);
        check32("reset gpio_oe", gpio_oe, 0);
        check32("reset irq", {31'b0, irq}, 0);
        check32("reset done", {31'b0, demo_done}, 0);
        @(negedge board_clk);
        board_reset_n = 1'b1;

        wait (demo_state == 5'd12);
        #1;
        check32("configured output enable", gpio_oe, 32'h0000_00ff);
        check32("final LED pattern", gpio_out, 32'h0000_00aa);
        check32("captured switches", captured_data_in, 32'ha500_0000);
        check32("waiting for button", {31'b0, demo_done}, 0);

        // A one-cycle bounce must not trigger the interrupt.
        @(negedge board_clk);
        gpio_in_async[8] = 1'b1;
        @(posedge board_clk);
        @(negedge board_clk);
        gpio_in_async[8] = 1'b0;
        repeat (8) @(posedge board_clk);
        #1;
        check32("button bounce rejected", {31'b0, irq}, 0);
        check32("demo still waiting", {27'b0, demo_state}, 12);

        // A stable press must set IRQ, allow status capture, and be cleared.
        @(negedge board_clk);
        gpio_in_async[8] = 1'b1;
        wait (demo_done);
        #2;
        check32("captured interrupt status", captured_int_status, 32'h0000_0100);
        check32("IRQ cleared", {31'b0, irq}, 0);
        check32("demo completed", {31'b0, demo_done}, 1);
        check32("no APB error", {31'b0, demo_error}, 0);

        #2 board_reset_n = 1'b0;
        #1;
        check32("reset clears output", gpio_out, 0);
        check32("reset clears direction", gpio_oe, 0);
        check32("reset clears done", {31'b0, demo_done}, 0);

        $display("PASS: tb_fpga_top (%0d checks)", checks);
        $finish;
    end
endmodule

`default_nettype wire
