`timescale 1ns/1ps
`default_nettype none

// Two-flip-flop synchronizer for asynchronous GPIO inputs.
module gpio_input_sync #(
    parameter integer GPIO_WIDTH = 32
) (
    input  wire                  PCLK,
    input  wire                  PRESETn,
    input  wire [GPIO_WIDTH-1:0] gpio_in_async,
    output reg  [GPIO_WIDTH-1:0] gpio_in_sync
);
    reg [GPIO_WIDTH-1:0] sync_stage1;

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            sync_stage1 <= {GPIO_WIDTH{1'b0}};
            gpio_in_sync <= {GPIO_WIDTH{1'b0}};
        end else begin
            sync_stage1 <= gpio_in_async;
            gpio_in_sync <= sync_stage1;
        end
    end
endmodule

`default_nettype wire
