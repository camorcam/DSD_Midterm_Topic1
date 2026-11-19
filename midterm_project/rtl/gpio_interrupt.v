`timescale 1ns/1ps
`default_nettype none

// Edge detection, write-one-to-clear pending status, and combined IRQ.
module gpio_interrupt #(
    parameter integer GPIO_WIDTH = 32
) (
    input  wire                  PCLK,
    input  wire                  PRESETn,
    input  wire [GPIO_WIDTH-1:0] gpio_in_sync,
    input  wire [GPIO_WIDTH-1:0] direction,
    input  wire [GPIO_WIDTH-1:0] int_enable,
    input  wire [GPIO_WIDTH-1:0] int_rise_enable,
    input  wire [GPIO_WIDTH-1:0] int_fall_enable,
    input  wire [GPIO_WIDTH-1:0] clear_mask,
    output reg  [GPIO_WIDTH-1:0] int_status,
    output wire                  irq
);
    reg [GPIO_WIDTH-1:0] previous_input;
    wire [GPIO_WIDTH-1:0] rise_event;
    wire [GPIO_WIDTH-1:0] fall_event;
    wire [GPIO_WIDTH-1:0] eligible_event;

    assign rise_event = gpio_in_sync & ~previous_input;
    assign fall_event = ~gpio_in_sync & previous_input;
    assign eligible_event = ~direction &
        ((rise_event & int_rise_enable) |
         (fall_event & int_fall_enable));
    assign irq = |(int_status & int_enable);

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            previous_input <= {GPIO_WIDTH{1'b0}};
            int_status <= {GPIO_WIDTH{1'b0}};
        end else begin
            previous_input <= gpio_in_sync;
            // A new eligible event has priority over a simultaneous clear.
            int_status <= (int_status & ~clear_mask) | eligible_event;
        end
    end
endmodule

`default_nettype wire
