`timescale 1ns/1ps
`default_nettype none

// Exhaustive per-pin directed verification for the interrupt block.
module tb_gpio_interrupt_directed;
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
    integer pin;
    reg [31:0] pin_mask;

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
            $fatal(1, "%s pin %0d: got %08h, expected %08h at %0t",
                   label_text, pin, actual, wanted, $time);
    endtask

    task automatic clock_and_check(input logic [31:0] wanted_status,
                                   input logic wanted_irq);
        begin
            @(posedge PCLK);
            #1;
            check32("status", int_status, wanted_status);
            check32("irq", {31'b0, irq}, {31'b0, wanted_irq});
        end
    endtask

    task automatic prepare_zero;
        begin
            @(negedge PCLK);
            gpio_in_sync = 32'b0;
            direction = 32'b0;
            int_enable = 32'b0;
            int_rise_enable = 32'b0;
            int_fall_enable = 32'b0;
            clear_mask = 32'hffff_ffff;
            clock_and_check(0, 0);
            @(negedge PCLK);
            clear_mask = 32'b0;
        end
    endtask

    initial begin
        #100000;
        $fatal(1, "Simulation watchdog expired");
    end

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("tb_gpio_interrupt_directed.vcd");
            $dumpvars(0, tb_gpio_interrupt_directed);
        end

        #2 PRESETn = 1'b0;
        #1;
        check32("reset status", int_status, 0);
        check32("reset irq", {31'b0, irq}, 0);
        @(negedge PCLK);
        PRESETn = 1'b1;

        // Rising-edge capture and IRQ masking on every pin.
        for (pin = 0; pin < 32; pin = pin + 1) begin
            pin_mask = 32'b1 << pin;
            prepare_zero();
            int_rise_enable = pin_mask;
            int_enable = pin_mask;
            gpio_in_sync = pin_mask;
            clock_and_check(pin_mask, 1);
            @(negedge PCLK);
            clear_mask = pin_mask;
            clock_and_check(0, 0);
        end

        // Falling-edge capture on every pin.
        for (pin = 0; pin < 32; pin = pin + 1) begin
            pin_mask = 32'b1 << pin;
            prepare_zero();
            gpio_in_sync = pin_mask;
            clock_and_check(0, 0);
            @(negedge PCLK);
            int_fall_enable = pin_mask;
            int_enable = pin_mask;
            gpio_in_sync = 0;
            clock_and_check(pin_mask, 1);
        end

        // Both-edge mode must capture each transition on every pin.
        for (pin = 0; pin < 32; pin = pin + 1) begin
            pin_mask = 32'b1 << pin;
            prepare_zero();
            int_rise_enable = pin_mask;
            int_fall_enable = pin_mask;
            int_enable = pin_mask;
            gpio_in_sync = pin_mask;
            clock_and_check(pin_mask, 1);
            @(negedge PCLK);
            clear_mask = pin_mask;
            clock_and_check(0, 0);
            @(negedge PCLK);
            clear_mask = 0;
            gpio_in_sync = 0;
            clock_and_check(pin_mask, 1);
        end

        // Direction must suppress both edge types on every output pin.
        for (pin = 0; pin < 32; pin = pin + 1) begin
            pin_mask = 32'b1 << pin;
            prepare_zero();
            direction = pin_mask;
            int_rise_enable = pin_mask;
            int_fall_enable = pin_mask;
            int_enable = pin_mask;
            gpio_in_sync = pin_mask;
            clock_and_check(0, 0);
            @(negedge PCLK);
            gpio_in_sync = 0;
            clock_and_check(0, 0);
        end

        // A new event must beat a simultaneous clear on every pin.
        for (pin = 0; pin < 32; pin = pin + 1) begin
            pin_mask = 32'b1 << pin;
            prepare_zero();
            int_rise_enable = pin_mask;
            clear_mask = pin_mask;
            gpio_in_sync = pin_mask;
            clock_and_check(pin_mask, 0);
        end

        $display("PASS: tb_gpio_interrupt_directed (%0d checks)", checks);
        $finish;
    end
endmodule

`default_nettype wire
