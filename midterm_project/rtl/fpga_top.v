`timescale 1ns/1ps
`default_nettype none

// Board-independent FPGA demonstration wrapper. Pin mapping belongs in QSF.
module fpga_top #(
    parameter integer GPIO_WIDTH = 32,
    parameter integer APB_ADDR_WIDTH = 8,
    parameter integer DEBOUNCE_COUNTER_WIDTH = 20,
    parameter integer DEBOUNCE_CYCLES = 500000
) (
    input  wire                  board_clk,
    input  wire                  board_reset_n,
    input  wire [GPIO_WIDTH-1:0] gpio_in_async,
    output wire [GPIO_WIDTH-1:0] gpio_out,
    output wire [GPIO_WIDTH-1:0] gpio_oe,
    output wire                  irq,
    output wire                  demo_done,
    output wire                  demo_error,
    output wire [31:0]           captured_data_in,
    output wire [31:0]           captured_int_status,
    output wire [4:0]            demo_state
);
    wire core_reset_n;
    wire button_debounced;
    wire [GPIO_WIDTH-1:0] conditioned_gpio_in;
    wire [APB_ADDR_WIDTH-1:0] PADDR;
    wire PSEL, PENABLE, PWRITE;
    wire [31:0] PWDATA;
    wire [3:0] PSTRB;
    wire [2:0] PPROT;
    wire [31:0] PRDATA;
    wire PREADY, PSLVERR;

    reset_sync u_reset_sync (
        .clk(board_clk),
        .reset_n_async(board_reset_n),
        .reset_n_sync(core_reset_n)
    );

    button_debounce #(
        .COUNTER_WIDTH(DEBOUNCE_COUNTER_WIDTH),
        .STABLE_CYCLES(DEBOUNCE_CYCLES)
    ) u_button_debounce (
        .clk(board_clk),
        .reset_n(core_reset_n),
        .button_async(gpio_in_async[8]),
        .button_debounced(button_debounced)
    );

    assign conditioned_gpio_in =
        {gpio_in_async[GPIO_WIDTH-1:9], button_debounced, gpio_in_async[7:0]};

    apb_master_demo #(
        .APB_ADDR_WIDTH(APB_ADDR_WIDTH)
    ) u_apb_master_demo (
        .PCLK(board_clk), .PRESETn(core_reset_n), .PADDR(PADDR),
        .PSEL(PSEL), .PENABLE(PENABLE), .PWRITE(PWRITE),
        .PWDATA(PWDATA), .PSTRB(PSTRB), .PPROT(PPROT),
        .PRDATA(PRDATA), .PREADY(PREADY), .PSLVERR(PSLVERR),
        .irq(irq), .captured_data_in(captured_data_in),
        .captured_int_status(captured_int_status), .demo_done(demo_done),
        .demo_error(demo_error), .debug_state(demo_state)
    );

    apb_gpio_top #(
        .GPIO_WIDTH(GPIO_WIDTH),
        .APB_ADDR_WIDTH(APB_ADDR_WIDTH),
        .APB_DATA_WIDTH(32)
    ) u_apb_gpio_top (
        .PCLK(board_clk), .PRESETn(core_reset_n), .PADDR(PADDR),
        .PSEL(PSEL), .PENABLE(PENABLE), .PWRITE(PWRITE),
        .PWDATA(PWDATA), .PSTRB(PSTRB), .PPROT(PPROT),
        .PRDATA(PRDATA), .PREADY(PREADY), .PSLVERR(PSLVERR),
        .gpio_in_async(conditioned_gpio_in), .gpio_out(gpio_out),
        .gpio_oe(gpio_oe), .irq(irq)
    );
endmodule

`default_nettype wire
