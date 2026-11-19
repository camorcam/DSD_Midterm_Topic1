`timescale 1ns/1ps
`default_nettype none

module tb_button_debounce;
    reg clk = 1'b0;
    always #5 clk = ~clk;
    reg reset_n = 1'b1;
    reg button_async = 1'b0;
    wire button_debounced;
    integer checks = 0;

    button_debounce #(
        .COUNTER_WIDTH(3),
        .STABLE_CYCLES(3)
    ) dut (
        .clk(clk), .reset_n(reset_n), .button_async(button_async),
        .button_debounced(button_debounced)
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
            $dumpfile("tb_button_debounce.vcd");
            $dumpvars(0, tb_button_debounce);
        end
        #2 reset_n = 1'b0;
        #1 check1("reset", button_debounced, 0);
        @(negedge clk);
        reset_n = 1'b1;
        repeat (3) @(posedge clk);

        // A short pulse must not change the debounced output.
        @(negedge clk);
        button_async = 1'b1;
        @(posedge clk);
        @(negedge clk);
        button_async = 1'b0;
        repeat (5) @(posedge clk);
        #1 check1("high glitch rejected", button_debounced, 0);

        // A stable high level must be accepted.
        @(negedge clk);
        button_async = 1'b1;
        repeat (6) @(posedge clk);
        #1 check1("stable high accepted", button_debounced, 1);

        // A short low pulse must also be rejected.
        @(negedge clk);
        button_async = 1'b0;
        @(posedge clk);
        @(negedge clk);
        button_async = 1'b1;
        repeat (5) @(posedge clk);
        #1 check1("low glitch rejected", button_debounced, 1);

        @(negedge clk);
        button_async = 1'b0;
        repeat (6) @(posedge clk);
        #1 check1("stable low accepted", button_debounced, 0);

        $display("PASS: tb_button_debounce (%0d checks)", checks);
        $finish;
    end
endmodule

`default_nettype wire
