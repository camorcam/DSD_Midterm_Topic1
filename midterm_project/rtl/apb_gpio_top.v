`timescale 1ns/1ps
`default_nettype none

module apb_gpio_top #(
    parameter integer GPIO_WIDTH = 32,
    parameter integer APB_ADDR_WIDTH = 8,
    parameter integer APB_DATA_WIDTH = 32
) (
    input  wire                            PCLK,
    input  wire                            PRESETn,
    input  wire [APB_ADDR_WIDTH-1:0]       PADDR,
    input  wire                            PSEL,
    input  wire                            PENABLE,
    input  wire                            PWRITE,
    input  wire [APB_DATA_WIDTH-1:0]       PWDATA,
    input  wire [(APB_DATA_WIDTH/8)-1:0]   PSTRB,
    input  wire [2:0]                      PPROT,
    output wire [APB_DATA_WIDTH-1:0]       PRDATA,
    output wire                            PREADY,
    output wire                            PSLVERR,
    input  wire [GPIO_WIDTH-1:0]           gpio_in_async,
    output wire [GPIO_WIDTH-1:0]           gpio_out,
    output wire [GPIO_WIDTH-1:0]           gpio_oe,
    output wire                            irq
);
    wire write_fire;
    wire [APB_ADDR_WIDTH-1:0] write_addr;
    wire [31:0] write_data;
    wire [3:0] write_strb;
    wire [31:0] data_out;
    wire [31:0] data_in;
    wire [31:0] direction;
    wire [31:0] int_enable;
    wire [31:0] int_status;
    wire [31:0] int_rise_enable;
    wire [31:0] int_fall_enable;
    wire [31:0] int_clear_mask;

    assign gpio_out = data_out;
    assign gpio_oe = direction;

    apb_slave_ctrl #(
        .APB_ADDR_WIDTH(APB_ADDR_WIDTH)
    ) u_apb_slave_ctrl (
        .PRESETn(PRESETn),
        .PADDR(PADDR),
        .PSEL(PSEL),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PWDATA(PWDATA),
        .PSTRB(PSTRB),
        .PPROT(PPROT),
        .PRDATA(PRDATA),
        .PREADY(PREADY),
        .PSLVERR(PSLVERR),
        .data_out(data_out),
        .data_in(data_in),
        .direction(direction),
        .int_enable(int_enable),
        .int_status(int_status),
        .int_rise_enable(int_rise_enable),
        .int_fall_enable(int_fall_enable),
        .write_fire(write_fire),
        .write_addr(write_addr),
        .write_data(write_data),
        .write_strb(write_strb)
    );

    gpio_registers #(
        .APB_ADDR_WIDTH(APB_ADDR_WIDTH)
    ) u_gpio_registers (
        .PCLK(PCLK),
        .PRESETn(PRESETn),
        .write_fire(write_fire),
        .write_addr(write_addr),
        .write_data(write_data),
        .write_strb(write_strb),
        .data_out(data_out),
        .direction(direction),
        .int_enable(int_enable),
        .int_rise_enable(int_rise_enable),
        .int_fall_enable(int_fall_enable),
        .int_clear_mask(int_clear_mask)
    );

    gpio_input_sync #(
        .GPIO_WIDTH(GPIO_WIDTH)
    ) u_gpio_input_sync (
        .PCLK(PCLK),
        .PRESETn(PRESETn),
        .gpio_in_async(gpio_in_async),
        .gpio_in_sync(data_in)
    );

    gpio_interrupt #(
        .GPIO_WIDTH(GPIO_WIDTH)
    ) u_gpio_interrupt (
        .PCLK(PCLK),
        .PRESETn(PRESETn),
        .gpio_in_sync(data_in),
        .direction(direction),
        .int_enable(int_enable),
        .int_rise_enable(int_rise_enable),
        .int_fall_enable(int_fall_enable),
        .clear_mask(int_clear_mask),
        .int_status(int_status),
        .irq(irq)
    );
endmodule

`default_nettype wire
