`timescale 1ns/1ps
`default_nettype none

module tb_reset_sync;
    reg clk = 1'b0;
    always #5 clk = ~clk;
    reg reset_n_async = 1'b1;
    wire reset_n_sync;
    integer checks = 0;

    reset_sync dut (
        .clk(clk), .reset_n_async(reset_n_async), .reset_n_sync(reset_n_sync)
    );

    task automatic check1(input string label_text,
                          input logic actual,
                          input logic wanted);
        checks = checks + 1;
        if (actual !== wanted)
            $fatal(1, "%s: got %b, expected %b at %0t",
                   label_text, actual, wanted, $time);
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("tb_reset_sync.vcd");
            $dumpvars(0, tb_reset_sync);
        end
        #2 reset_n_async = 1'b0;
        #1 check1("asynchronous assertion", reset_n_sync, 0);
        @(negedge clk);
        reset_n_async = 1'b1;
        @(posedge clk);
        #1 check1("first release cycle", reset_n_sync, 0);
        @(posedge clk);
        #1 check1("second release cycle", reset_n_sync, 1);
        #2 reset_n_async = 1'b0;
        #1 check1("reassertion", reset_n_sync, 0);

        $display("PASS: tb_reset_sync (%0d checks)", checks);
        $finish;
    end
endmodule

`default_nettype wire
