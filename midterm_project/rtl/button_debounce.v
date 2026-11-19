`timescale 1ns/1ps
`default_nettype none

// Synchronize one asynchronous button and accept a change after it is stable.
module button_debounce #(
    parameter integer COUNTER_WIDTH = 20,
    parameter integer STABLE_CYCLES = 500000
) (
    input  wire clk,
    input  wire reset_n,
    input  wire button_async,
    output reg  button_debounced
);
    reg sync_stage1;
    reg sync_stage2;
    reg [COUNTER_WIDTH-1:0] stable_count;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            sync_stage1 <= 1'b0;
            sync_stage2 <= 1'b0;
            stable_count <= {COUNTER_WIDTH{1'b0}};
            button_debounced <= 1'b0;
        end else begin
            sync_stage1 <= button_async;
            sync_stage2 <= sync_stage1;
            if (sync_stage2 == button_debounced) begin
                stable_count <= {COUNTER_WIDTH{1'b0}};
            end else if (stable_count == STABLE_CYCLES - 1) begin
                button_debounced <= sync_stage2;
                stable_count <= {COUNTER_WIDTH{1'b0}};
            end else begin
                stable_count <= stable_count + 1'b1;
            end
        end
    end
endmodule

`default_nettype wire
