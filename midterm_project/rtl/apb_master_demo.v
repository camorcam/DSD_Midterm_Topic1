`timescale 1ns/1ps
`default_nettype none

// Fixed APB transaction sequence used by the FPGA demonstration wrapper.
module apb_master_demo #(
    parameter integer APB_ADDR_WIDTH = 8
) (
    input  wire                       PCLK,
    input  wire                       PRESETn,
    output reg  [APB_ADDR_WIDTH-1:0]  PADDR,
    output reg                        PSEL,
    output reg                        PENABLE,
    output reg                        PWRITE,
    output reg  [31:0]                PWDATA,
    output reg  [3:0]                 PSTRB,
    output wire [2:0]                 PPROT,
    input  wire [31:0]                PRDATA,
    input  wire                       PREADY,
    input  wire                       PSLVERR,
    input  wire                       irq,
    output reg  [31:0]                captured_data_in,
    output reg  [31:0]                captured_int_status,
    output reg                        demo_done,
    output reg                        demo_error,
    output wire [4:0]                 debug_state
);
    localparam [4:0] ST_DIRECTION_SETUP = 5'd0;
    localparam [4:0] ST_DIRECTION_ACCESS = 5'd1;
    localparam [4:0] ST_OUTPUT1_SETUP = 5'd2;
    localparam [4:0] ST_OUTPUT1_ACCESS = 5'd3;
    localparam [4:0] ST_OUTPUT2_SETUP = 5'd4;
    localparam [4:0] ST_OUTPUT2_ACCESS = 5'd5;
    localparam [4:0] ST_DATA_IN_SETUP = 5'd6;
    localparam [4:0] ST_DATA_IN_ACCESS = 5'd7;
    localparam [4:0] ST_RISE_SETUP = 5'd8;
    localparam [4:0] ST_RISE_ACCESS = 5'd9;
    localparam [4:0] ST_ENABLE_SETUP = 5'd10;
    localparam [4:0] ST_ENABLE_ACCESS = 5'd11;
    localparam [4:0] ST_WAIT_IRQ = 5'd12;
    localparam [4:0] ST_STATUS_SETUP = 5'd13;
    localparam [4:0] ST_STATUS_ACCESS = 5'd14;
    localparam [4:0] ST_CLEAR_SETUP = 5'd15;
    localparam [4:0] ST_CLEAR_ACCESS = 5'd16;
    localparam [4:0] ST_DONE = 5'd17;

    localparam [APB_ADDR_WIDTH-1:0] ADDR_DATA_OUT = 'h00;
    localparam [APB_ADDR_WIDTH-1:0] ADDR_DATA_IN = 'h04;
    localparam [APB_ADDR_WIDTH-1:0] ADDR_DIRECTION = 'h08;
    localparam [APB_ADDR_WIDTH-1:0] ADDR_INT_ENABLE = 'h0c;
    localparam [APB_ADDR_WIDTH-1:0] ADDR_INT_STATUS = 'h10;
    localparam [APB_ADDR_WIDTH-1:0] ADDR_INT_RISE_ENABLE = 'h14;

    reg [4:0] state;
    reg [4:0] next_state;

    assign PPROT = 3'b000;
    assign debug_state = state;

    always @* begin
        PADDR = {APB_ADDR_WIDTH{1'b0}};
        PSEL = 1'b0;
        PENABLE = 1'b0;
        PWRITE = 1'b0;
        PWDATA = 32'b0;
        PSTRB = 4'hf;
        next_state = state;

        case (state)
            ST_DIRECTION_SETUP, ST_DIRECTION_ACCESS: begin
                PADDR = ADDR_DIRECTION;
                PSEL = 1'b1;
                PENABLE = (state == ST_DIRECTION_ACCESS);
                PWRITE = 1'b1;
                PWDATA = 32'h0000_00ff;
                next_state = (state == ST_DIRECTION_SETUP) ?
                             ST_DIRECTION_ACCESS :
                             (PREADY ? ST_OUTPUT1_SETUP : ST_DIRECTION_ACCESS);
            end
            ST_OUTPUT1_SETUP, ST_OUTPUT1_ACCESS: begin
                PADDR = ADDR_DATA_OUT;
                PSEL = 1'b1;
                PENABLE = (state == ST_OUTPUT1_ACCESS);
                PWRITE = 1'b1;
                PWDATA = 32'h0000_0055;
                next_state = (state == ST_OUTPUT1_SETUP) ?
                             ST_OUTPUT1_ACCESS :
                             (PREADY ? ST_OUTPUT2_SETUP : ST_OUTPUT1_ACCESS);
            end
            ST_OUTPUT2_SETUP, ST_OUTPUT2_ACCESS: begin
                PADDR = ADDR_DATA_OUT;
                PSEL = 1'b1;
                PENABLE = (state == ST_OUTPUT2_ACCESS);
                PWRITE = 1'b1;
                PWDATA = 32'h0000_00aa;
                next_state = (state == ST_OUTPUT2_SETUP) ?
                             ST_OUTPUT2_ACCESS :
                             (PREADY ? ST_DATA_IN_SETUP : ST_OUTPUT2_ACCESS);
            end
            ST_DATA_IN_SETUP, ST_DATA_IN_ACCESS: begin
                PADDR = ADDR_DATA_IN;
                PSEL = 1'b1;
                PENABLE = (state == ST_DATA_IN_ACCESS);
                next_state = (state == ST_DATA_IN_SETUP) ?
                             ST_DATA_IN_ACCESS :
                             (PREADY ? ST_RISE_SETUP : ST_DATA_IN_ACCESS);
            end
            ST_RISE_SETUP, ST_RISE_ACCESS: begin
                PADDR = ADDR_INT_RISE_ENABLE;
                PSEL = 1'b1;
                PENABLE = (state == ST_RISE_ACCESS);
                PWRITE = 1'b1;
                PWDATA = 32'h0000_0100;
                next_state = (state == ST_RISE_SETUP) ?
                             ST_RISE_ACCESS :
                             (PREADY ? ST_ENABLE_SETUP : ST_RISE_ACCESS);
            end
            ST_ENABLE_SETUP, ST_ENABLE_ACCESS: begin
                PADDR = ADDR_INT_ENABLE;
                PSEL = 1'b1;
                PENABLE = (state == ST_ENABLE_ACCESS);
                PWRITE = 1'b1;
                PWDATA = 32'h0000_0100;
                next_state = (state == ST_ENABLE_SETUP) ?
                             ST_ENABLE_ACCESS :
                             (PREADY ? ST_WAIT_IRQ : ST_ENABLE_ACCESS);
            end
            ST_WAIT_IRQ: begin
                if (irq)
                    next_state = ST_STATUS_SETUP;
            end
            ST_STATUS_SETUP, ST_STATUS_ACCESS: begin
                PADDR = ADDR_INT_STATUS;
                PSEL = 1'b1;
                PENABLE = (state == ST_STATUS_ACCESS);
                next_state = (state == ST_STATUS_SETUP) ?
                             ST_STATUS_ACCESS :
                             (PREADY ? ST_CLEAR_SETUP : ST_STATUS_ACCESS);
            end
            ST_CLEAR_SETUP, ST_CLEAR_ACCESS: begin
                PADDR = ADDR_INT_STATUS;
                PSEL = 1'b1;
                PENABLE = (state == ST_CLEAR_ACCESS);
                PWRITE = 1'b1;
                PWDATA = 32'h0000_0100;
                next_state = (state == ST_CLEAR_SETUP) ?
                             ST_CLEAR_ACCESS :
                             (PREADY ? ST_DONE : ST_CLEAR_ACCESS);
            end
            ST_DONE: begin
                next_state = ST_DONE;
            end
            default: next_state = ST_DIRECTION_SETUP;
        endcase
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            state <= ST_DIRECTION_SETUP;
            captured_data_in <= 32'b0;
            captured_int_status <= 32'b0;
            demo_done <= 1'b0;
            demo_error <= 1'b0;
        end else begin
            state <= next_state;
            if (PSEL && PENABLE && PREADY) begin
                if (PSLVERR)
                    demo_error <= 1'b1;
                if (!PWRITE && PADDR == ADDR_DATA_IN)
                    captured_data_in <= PRDATA;
                if (!PWRITE && PADDR == ADDR_INT_STATUS)
                    captured_int_status <= PRDATA;
            end
            if (next_state == ST_DONE)
                demo_done <= 1'b1;
        end
    end
endmodule

`default_nettype wire
