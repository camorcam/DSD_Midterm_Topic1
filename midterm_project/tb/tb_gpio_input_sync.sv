`timescale 1ns/1ps
`default_nettype none

module tb_gpio_input_sync;
    reg PCLK = 1'b0;
    always #5 PCLK = ~PCLK;
    reg PRESETn = 1'b1;
    reg [31:0] gpio_in_async = 32'b0;
    wire [31:0] gpio_in_sync;
    integer checks = 0;

    gpio_input_sync dut (
        .PCLK(PCLK), .PRESETn(PRESETn),
        .gpio_in_async(gpio_in_async), .gpio_in_sync(gpio_in_sync)
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
        if ($test$plusargs("vcd")) begin
            $dumpfile("tb_gpio_input_sync.vcd");
            $dumpvars(0, tb_gpio_input_sync);
        end
        #2 PRESETn = 1'b0;
        #1 check32("asynchronous reset", gpio_in_sync, 0);
        gpio_in_async = 32'hffff_ffff;
        #1 check32("reset holds output", gpio_in_sync, 0);
        @(negedge PCLK);
        PRESETn = 1'b1;

        @(posedge PCLK);
        #1 check32("first stage latency", gpio_in_sync, 0);
        @(posedge PCLK);
        #1 check32("second stage update", gpio_in_sync, 32'hffff_ffff);

        @(negedge PCLK);
        gpio_in_async = 32'h1234_5678;
        @(posedge PCLK);
        #1 check32("new value first cycle", gpio_in_sync, 32'hffff_ffff);
        @(posedge PCLK);
        #1 check32("new value second cycle", gpio_in_sync, 32'h1234_5678);

        #2 PRESETn = 1'b0;
        #1 check32("reset after activity", gpio_in_sync, 0);

        $display("PASS: tb_gpio_input_sync (%0d checks)", checks);
        $finish;
    end
endmodule

`default_nettype wire
