`timescale 1ns/1ps
`default_nettype none

module tb_de10_standard_top;
    reg CLOCK_50 = 1'b0;
    always #10 CLOCK_50 = ~CLOCK_50;

    reg [3:0] KEY = 4'b1111;
    reg [9:0] SW = 10'b10_10100101;
    wire [9:0] LEDR;
    integer checks = 0;

    de10_standard_top #(
        .DEBOUNCE_COUNTER_WIDTH(3),
        .DEBOUNCE_CYCLES(3)
    ) dut (
        .CLOCK_50(CLOCK_50),
        .KEY(KEY),
        .SW(SW),
        .LEDR(LEDR)
    );

    task automatic check10(input string label_text,
                           input logic [9:0] actual,
                           input logic [9:0] wanted);
        checks = checks + 1;
        if (actual !== wanted)
            $fatal(1, "%s: got %03h, expected %03h at %0t",
                   label_text, actual, wanted, $time);
    endtask

    initial begin
        #40000;
        $fatal(1, "Simulation watchdog expired");
    end

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("tb_de10_standard_top.vcd");
            $dumpvars(0, tb_de10_standard_top);
        end

        #2 KEY[0] = 1'b0;
        #1 check10("active-low reset", LEDR, 10'b0);
        repeat (2) @(negedge CLOCK_50);
        KEY[0] = 1'b1;

        wait (dut.demo_state == 5'd12);
        #1;
        check10("GPIO pattern and idle status", LEDR, 10'b00_10101010);
        if (dut.captured_data_in !== 32'h0000_04a5)
            $fatal(1, "switch capture: got %08h, expected 000004a5",
                   dut.captured_data_in);
        checks = checks + 1;

        // A stable active-low KEY[1] press generates and then clears IRQ.
        @(negedge CLOCK_50);
        KEY[1] = 1'b0;
        wait (LEDR[9]);
        #1;
        check10("successful completion", LEDR, 10'b10_10101010);
        if (dut.captured_int_status !== 32'h0000_0100)
            $fatal(1, "interrupt capture: got %08h, expected 00000100",
                   dut.captured_int_status);
        checks = checks + 1;

        #2 KEY[0] = 1'b0;
        #1 check10("reset clears board outputs", LEDR, 10'b0);

        $display("PASS: tb_de10_standard_top (%0d checks)", checks);
        $finish;
    end
endmodule

`default_nettype wire
