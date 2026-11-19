`timescale 1ns/1ps
`default_nettype none

// Asynchronous assertion and two-cycle synchronous reset release.
module reset_sync (
    input  wire clk,
    input  wire reset_n_async,
    output wire reset_n_sync
);
    reg [1:0] release_pipe;

    always @(posedge clk or negedge reset_n_async) begin
        if (!reset_n_async)
            release_pipe <= 2'b00;
        else
            release_pipe <= {release_pipe[0], 1'b1};
    end

    assign reset_n_sync = release_pipe[1];
endmodule

`default_nettype wire
