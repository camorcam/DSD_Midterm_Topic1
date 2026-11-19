`timescale 1ns/1ps
`default_nettype none

// Zero-wait-state APB4 decoder. The master supplies legal SETUP/ACCESS phases.
module apb_slave_ctrl #(
    parameter integer APB_ADDR_WIDTH = 8
) (
    input  wire                      PRESETn,
    input  wire [APB_ADDR_WIDTH-1:0] PADDR,
    input  wire                      PSEL,
    input  wire                      PENABLE,
    input  wire                      PWRITE,
    input  wire [31:0]               PWDATA,
    input  wire [3:0]                PSTRB,
    input  wire [2:0]                PPROT,
    output reg  [31:0]               PRDATA,
    output wire                      PREADY,
    output wire                      PSLVERR,

    input  wire [31:0]               data_out,
    input  wire [31:0]               data_in,
    input  wire [31:0]               direction,
    input  wire [31:0]               int_enable,
    input  wire [31:0]               int_status,
    input  wire [31:0]               int_rise_enable,
    input  wire [31:0]               int_fall_enable,

    output wire                      write_fire,
    output wire [APB_ADDR_WIDTH-1:0] write_addr,
    output wire [31:0]               write_data,
    output wire [3:0]                write_strb
);
    localparam [APB_ADDR_WIDTH-1:0] ADDR_DATA_OUT = 'h00;
    localparam [APB_ADDR_WIDTH-1:0] ADDR_DATA_IN  = 'h04;
    localparam [APB_ADDR_WIDTH-1:0] ADDR_DIRECTION = 'h08;
    localparam [APB_ADDR_WIDTH-1:0] ADDR_INT_ENABLE = 'h0c;
    localparam [APB_ADDR_WIDTH-1:0] ADDR_INT_STATUS = 'h10;
    localparam [APB_ADDR_WIDTH-1:0] ADDR_INT_RISE_ENABLE = 'h14;
    localparam [APB_ADDR_WIDTH-1:0] ADDR_INT_FALL_ENABLE = 'h18;

    reg mapped;
    reg [31:0] read_value;
    wire access_active;

    // PPROT is intentionally unused: all protection attributes are accepted.
    assign PREADY = 1'b1;
    assign access_active = PRESETn && PSEL && PENABLE;
    assign PSLVERR = access_active &&
        (!mapped || (PWRITE && PADDR == ADDR_DATA_IN));
    assign write_fire = access_active && PREADY && PWRITE && !PSLVERR;
    assign write_addr = PADDR;
    assign write_data = PWDATA;
    assign write_strb = PSTRB;

    always @* begin
        mapped = 1'b1;
        read_value = 32'b0;
        // Compare the complete byte address to reject misalignment and aliases.
        case (PADDR)
            ADDR_DATA_OUT:        read_value = data_out;
            ADDR_DATA_IN:         read_value = data_in;
            ADDR_DIRECTION:       read_value = direction;
            ADDR_INT_ENABLE:      read_value = int_enable;
            ADDR_INT_STATUS:      read_value = int_status;
            ADDR_INT_RISE_ENABLE: read_value = int_rise_enable;
            ADDR_INT_FALL_ENABLE: read_value = int_fall_enable;
            default: mapped = 1'b0;
        endcase

        PRDATA = 32'b0;
        if (access_active && !PWRITE && mapped)
            PRDATA = read_value;
    end
endmodule

`default_nettype wire
