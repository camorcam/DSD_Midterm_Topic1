`timescale 1ns/1ps
`default_nettype none

// DE10-Standard board wrapper for the APB GPIO hardware demonstration.
module de10_standard_top #(
    parameter integer DEBOUNCE_COUNTER_WIDTH = 20,
    parameter integer DEBOUNCE_CYCLES = 500000
) (
    input  wire       CLOCK_50,
    input  wire [3:0] KEY,
    input  wire [9:0] SW,
    output wire [9:0] LEDR
);
    wire [31:0] gpio_in_async;
    wire [31:0] gpio_out;
    wire [31:0] gpio_oe;
    wire irq;
    wire demo_done;
    wire demo_error;
    wire [31:0] captured_data_in;
    wire [31:0] captured_int_status;
    wire [4:0] demo_state;

    // KEY[1] is active-low on the board. The generic wrapper expects an
    // active-high button on GPIO bit 8. SW[9:8] occupy GPIO bits [10:9].
    assign gpio_in_async = {21'b0, SW[9:8], ~KEY[1], SW[7:0]};

    // The demo configures GPIO[7:0] as outputs. LEDR[8] displays IRQ and
    // LEDR[9] lights only after successful completion of the demo sequence.
    assign LEDR[7:0] = gpio_out[7:0] & gpio_oe[7:0];
    assign LEDR[8] = irq;
    assign LEDR[9] = demo_done & ~demo_error;

    fpga_top #(
        .GPIO_WIDTH(32),
        .APB_ADDR_WIDTH(8),
        .DEBOUNCE_COUNTER_WIDTH(DEBOUNCE_COUNTER_WIDTH),
        .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)
    ) u_fpga_top (
        .board_clk(CLOCK_50),
        .board_reset_n(KEY[0]),
        .gpio_in_async(gpio_in_async),
        .gpio_out(gpio_out),
        .gpio_oe(gpio_oe),
        .irq(irq),
        .demo_done(demo_done),
        .demo_error(demo_error),
        .captured_data_in(captured_data_in),
        .captured_int_status(captured_int_status),
        .demo_state(demo_state)
    );

    // KEY[3:2] are intentionally reserved for future hardware debug controls.
    wire _unused = &{1'b0, KEY[3:2], captured_data_in,
                     captured_int_status, demo_state};
endmodule

`default_nettype wire
