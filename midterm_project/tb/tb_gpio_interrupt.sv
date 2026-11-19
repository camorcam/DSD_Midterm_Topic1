`timescale 1ns/1ps
`default_nettype none

module tb_gpio_interrupt;
    reg PCLK = 1'b0;
    always #5 PCLK = ~PCLK;
    reg PRESETn = 1'b1;
    reg [31:0] gpio_in_sync = 32'b0;
    reg [31:0] direction = 32'b0;
    reg [31:0] int_enable = 32'b0;
    reg [31:0] int_rise_enable = 32'b0;
    reg [31:0] int_fall_enable = 32'b0;
    reg [31:0] clear_mask = 32'b0;
    wire [31:0] int_status;
    wire irq;
    integer checks = 0;

    gpio_interrupt dut (
        .PCLK(PCLK), .PRESETn(PRESETn), .gpio_in_sync(gpio_in_sync),
        .direction(direction), .int_enable(int_enable),
        .int_rise_enable(int_rise_enable),
        .int_fall_enable(int_fall_enable), .clear_mask(clear_mask),
        .int_status(int_status), .irq(irq)
    );

    task automatic check32(input string label_text,
                           input logic [31:0] actual,
                           input logic [31:0] wanted);
        checks = checks + 1;
        if (actual !== wanted)
            $fatal(1, "%s: got %08h, expected %08h at %0t",
                   label_text, actual, wanted, $time);
    endtask

    task automatic clock_and_check(input logic [31:0] wanted_status,
                                   input logic wanted_irq);
        begin
            @(posedge PCLK);
            #1;
            check32("interrupt status", int_status, wanted_status);
            check32("irq", {31'b0, irq}, {31'b0, wanted_irq});
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("tb_gpio_interrupt.vcd");
            $dumpvars(0, tb_gpio_interrupt);
        end
        #2 PRESETn = 1'b0;
        #1;
        check32("reset status", int_status, 0);
        check32("reset irq", {31'b0, irq}, 0);
        @(negedge PCLK);
        PRESETn = 1'b1;

        // Rising event is captured even while the combined IRQ is masked.
        int_rise_enable[0] = 1'b1;
        gpio_in_sync[0] = 1'b1;
        clock_and_check(32'h0000_0001, 1'b0);
        int_enable[0] = 1'b1;
        #1 check32("unmasked irq", {31'b0, irq}, 1);
        clock_and_check(32'h0000_0001, 1'b1);

        // Clear the pending bit while the input remains stable.
        @(negedge PCLK);
        clear_mask[0] = 1'b1;
        clock_and_check(0, 1'b0);
        clear_mask = 0;

        // Falling-edge detection.
        @(negedge PCLK);
        gpio_in_sync[1] = 1'b1;
        int_fall_enable[1] = 1'b1;
        clock_and_check(0, 1'b0);
        @(negedge PCLK);
        gpio_in_sync[1] = 1'b0;
        clock_and_check(32'h0000_0002, 1'b0);

        // Both-edge detection on bit 2.
        @(negedge PCLK);
        int_rise_enable[2] = 1'b1;
        int_fall_enable[2] = 1'b1;
        gpio_in_sync[2] = 1'b1;
        clock_and_check(32'h0000_0006, 1'b0);
        @(negedge PCLK);
        clear_mask = 32'h0000_0006;
        clock_and_check(0, 1'b0);
        @(negedge PCLK);
        clear_mask = 0;
        gpio_in_sync[2] = 1'b0;
        clock_and_check(32'h0000_0004, 1'b0);

        // Pins configured as outputs cannot create pending interrupts.
        @(negedge PCLK);
        clear_mask = 32'hffff_ffff;
        direction[3] = 1'b1;
        int_rise_enable[3] = 1'b1;
        int_fall_enable[3] = 1'b1;
        clock_and_check(0, 1'b0);
        @(negedge PCLK);
        clear_mask = 0;
        gpio_in_sync[3] = 1'b1;
        clock_and_check(0, 1'b0);
        @(negedge PCLK);
        gpio_in_sync[3] = 1'b0;
        clock_and_check(0, 1'b0);

        // A new event wins over a simultaneous clear of the same bit.
        @(negedge PCLK);
        int_rise_enable[5] = 1'b1;
        clear_mask[5] = 1'b1;
        gpio_in_sync[5] = 1'b1;
        clock_and_check(32'h0000_0020, 1'b0);
        @(negedge PCLK);
        clear_mask = 0;
        clock_and_check(32'h0000_0020, 1'b0);

        #2 PRESETn = 1'b0;
        #1;
        check32("final reset status", int_status, 0);
        check32("final reset irq", {31'b0, irq}, 0);

        $display("PASS: tb_gpio_interrupt (%0d checks)", checks);
        $finish;
    end
endmodule

`default_nettype wire
