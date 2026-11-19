`timescale 1ns/1ps
`default_nettype none

module gpio_registers #(
    parameter integer APB_ADDR_WIDTH = 8
) (
    input  wire                      PCLK,
    input  wire                      PRESETn,
    input  wire                      write_fire,
    input  wire [APB_ADDR_WIDTH-1:0] write_addr,
    input  wire [31:0]               write_data,
    input  wire [3:0]                write_strb,
    output reg  [31:0]               data_out,
    output reg  [31:0]               direction,
    output reg  [31:0]               int_enable,
    output reg  [31:0]               int_rise_enable,
    output reg  [31:0]               int_fall_enable,
    output wire [31:0]               int_clear_mask
);
    localparam [APB_ADDR_WIDTH-1:0] ADDR_DATA_OUT = 'h00;
    localparam [APB_ADDR_WIDTH-1:0] ADDR_DIRECTION = 'h08;
    localparam [APB_ADDR_WIDTH-1:0] ADDR_INT_ENABLE = 'h0c;
    localparam [APB_ADDR_WIDTH-1:0] ADDR_INT_STATUS = 'h10;
    localparam [APB_ADDR_WIDTH-1:0] ADDR_INT_RISE_ENABLE = 'h14;
    localparam [APB_ADDR_WIDTH-1:0] ADDR_INT_FALL_ENABLE = 'h18;

    wire [31:0] byte_mask;
    assign byte_mask = {{8{write_strb[3]}}, {8{write_strb[2]}},
                        {8{write_strb[1]}}, {8{write_strb[0]}}};

    // Combinational request: B samples this on the same completion edge.
    // INT_STATUS storage and event-over-clear priority belong to gpio_interrupt.
    assign int_clear_mask = (PRESETn && write_fire && write_addr == ADDR_INT_STATUS)
        ? (write_data & byte_mask) : 32'b0;

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            data_out <= 32'b0;
            direction <= 32'b0;
            int_enable <= 32'b0;
            int_rise_enable <= 32'b0;
            int_fall_enable <= 32'b0;
        end else if (write_fire) begin
            case (write_addr)
                ADDR_DATA_OUT:
                    data_out <= (data_out & ~byte_mask) | (write_data & byte_mask);
                ADDR_DIRECTION:
                    direction <= (direction & ~byte_mask) | (write_data & byte_mask);
                ADDR_INT_ENABLE:
                    int_enable <= (int_enable & ~byte_mask) | (write_data & byte_mask);
                ADDR_INT_RISE_ENABLE:
                    int_rise_enable <= (int_rise_enable & ~byte_mask) | (write_data & byte_mask);
                ADDR_INT_FALL_ENABLE:
                    int_fall_enable <= (int_fall_enable & ~byte_mask) | (write_data & byte_mask);
                default: begin end
            endcase
        end
    end
endmodule

`default_nettype wire
