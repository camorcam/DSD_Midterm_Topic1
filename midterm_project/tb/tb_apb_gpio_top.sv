`timescale 1ns/1ps
`default_nettype none

module tb_apb_gpio_top;
    localparam [7:0] ADDR_DATA_OUT = 8'h00;
    localparam [7:0] ADDR_DATA_IN = 8'h04;
    localparam [7:0] ADDR_DIRECTION = 8'h08;
    localparam [7:0] ADDR_INT_ENABLE = 8'h0c;
    localparam [7:0] ADDR_INT_STATUS = 8'h10;
    localparam [7:0] ADDR_INT_RISE_ENABLE = 8'h14;
    localparam [7:0] ADDR_INT_FALL_ENABLE = 8'h18;

    reg PCLK = 1'b0;
    always #5 PCLK = ~PCLK;
    reg PRESETn = 1'b1;
    wire [7:0] PADDR;
    wire PSEL, PENABLE, PWRITE;
    wire [31:0] PWDATA;
    wire [3:0] PSTRB;
    wire [2:0] PPROT;
    wire [31:0] PRDATA;
    wire PREADY, PSLVERR;
    reg [31:0] gpio_in_async = 32'b0;
    wire [31:0] gpio_out, gpio_oe;
    wire irq;
    integer checks = 0;

    apb_bfm u_bfm (
        .PCLK(PCLK), .PADDR(PADDR), .PSEL(PSEL), .PENABLE(PENABLE),
        .PWRITE(PWRITE), .PWDATA(PWDATA), .PSTRB(PSTRB), .PPROT(PPROT),
        .PRDATA(PRDATA), .PREADY(PREADY), .PSLVERR(PSLVERR)
    );

    apb_gpio_top dut (
        .PCLK(PCLK), .PRESETn(PRESETn), .PADDR(PADDR), .PSEL(PSEL),
        .PENABLE(PENABLE), .PWRITE(PWRITE), .PWDATA(PWDATA),
        .PSTRB(PSTRB), .PPROT(PPROT), .PRDATA(PRDATA),
        .PREADY(PREADY), .PSLVERR(PSLVERR),
        .gpio_in_async(gpio_in_async), .gpio_out(gpio_out),
        .gpio_oe(gpio_oe), .irq(irq)
    );

    task automatic check32(input string label_text,
                           input logic [31:0] actual,
                           input logic [31:0] wanted);
        checks = checks + 1;
        if (actual !== wanted)
            $fatal(1, "%s: got %08h, expected %08h at %0t",
                   label_text, actual, wanted, $time);
    endtask

    task automatic write_reg(input logic [7:0] addr,
                             input logic [31:0] data,
                             input logic [3:0] strobes,
                             input logic wanted_error);
        reg actual_error;
        begin
            u_bfm.apb_write(addr, data, strobes, 3'b000, actual_error);
            check32("APB write error", {31'b0, actual_error},
                    {31'b0, wanted_error});
        end
    endtask

    task automatic read_reg(input logic [7:0] addr,
                            input logic [31:0] wanted_data,
                            input logic wanted_error);
        reg [31:0] actual_data;
        reg actual_error;
        begin
            u_bfm.apb_read(addr, 3'b000, actual_data, actual_error);
            check32("APB read error", {31'b0, actual_error},
                    {31'b0, wanted_error});
            check32("APB read data", actual_data, wanted_data);
        end
    endtask

    task automatic wait_pipeline;
        begin
            repeat (3) @(posedge PCLK);
            #1;
        end
    endtask

    initial begin
        #200000;
        $fatal(1, "Simulation watchdog expired");
    end

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("tb_apb_gpio_top.vcd");
            $dumpvars(0, tb_apb_gpio_top);
        end

        #2 PRESETn = 1'b0;
        #1;
        check32("reset gpio_out", gpio_out, 0);
        check32("reset gpio_oe", gpio_oe, 0);
        check32("reset irq", {31'b0, irq}, 0);
        @(negedge PCLK);
        PRESETn = 1'b1;

        read_reg(ADDR_DATA_OUT, 0, 0);
        read_reg(ADDR_DATA_IN, 0, 0);
        read_reg(ADDR_DIRECTION, 0, 0);
        read_reg(ADDR_INT_ENABLE, 0, 0);
        read_reg(ADDR_INT_STATUS, 0, 0);
        read_reg(ADDR_INT_RISE_ENABLE, 0, 0);
        read_reg(ADDR_INT_FALL_ENABLE, 0, 0);

        write_reg(ADDR_DATA_OUT, 32'h1122_3344, 4'hf, 0);
        write_reg(ADDR_DIRECTION, 32'h0000_000f, 4'hf, 0);
        check32("gpio output value", gpio_out, 32'h1122_3344);
        check32("gpio output enable", gpio_oe, 32'h0000_000f);
        write_reg(ADDR_DATA_OUT, 32'haabb_ccdd, 4'b0101, 0);
        read_reg(ADDR_DATA_OUT, 32'h11bb_33dd, 0);

        // Confirm the synchronized input is visible through DATA_IN.
        @(negedge PCLK);
        gpio_in_async = 32'h0100_1000;
        wait_pipeline();
        read_reg(ADDR_DATA_IN, 32'h0100_1000, 0);
        @(negedge PCLK);
        gpio_in_async = 0;
        wait_pipeline();

        // Rising-edge interrupt, IRQ masking, and W1C through APB.
        write_reg(ADDR_INT_RISE_ENABLE, 32'h0000_0100, 4'hf, 0);
        write_reg(ADDR_INT_ENABLE, 32'h0000_0100, 4'hf, 0);
        @(negedge PCLK);
        gpio_in_async[8] = 1'b1;
        wait_pipeline();
        read_reg(ADDR_INT_STATUS, 32'h0000_0100, 0);
        check32("rising irq", {31'b0, irq}, 1);
        write_reg(ADDR_INT_STATUS, 0, 4'hf, 0);
        read_reg(ADDR_INT_STATUS, 32'h0000_0100, 0);
        write_reg(ADDR_INT_STATUS, 32'h0000_0100, 4'hf, 0);
        read_reg(ADDR_INT_STATUS, 0, 0);
        check32("cleared rising irq", {31'b0, irq}, 0);

        // Falling-edge interrupt.
        write_reg(ADDR_INT_FALL_ENABLE, 32'h0000_0200, 4'hf, 0);
        @(negedge PCLK);
        gpio_in_async[9] = 1'b1;
        wait_pipeline();
        @(negedge PCLK);
        gpio_in_async[9] = 1'b0;
        wait_pipeline();
        read_reg(ADDR_INT_STATUS, 32'h0000_0200, 0);
        write_reg(ADDR_INT_STATUS, 32'h0000_0200, 4'hf, 0);

        // Both-edge interrupt.
        write_reg(ADDR_INT_RISE_ENABLE, 32'h0000_0500, 4'hf, 0);
        write_reg(ADDR_INT_FALL_ENABLE, 32'h0000_0600, 4'hf, 0);
        @(negedge PCLK);
        gpio_in_async[10] = 1'b1;
        wait_pipeline();
        read_reg(ADDR_INT_STATUS, 32'h0000_0400, 0);
        write_reg(ADDR_INT_STATUS, 32'h0000_0400, 4'hf, 0);
        @(negedge PCLK);
        gpio_in_async[10] = 1'b0;
        wait_pipeline();
        read_reg(ADDR_INT_STATUS, 32'h0000_0400, 0);
        write_reg(ADDR_INT_STATUS, 32'h0000_0400, 4'hf, 0);

        // Direction suppresses interrupts from output pins.
        write_reg(ADDR_INT_RISE_ENABLE, 32'h0000_0508, 4'hf, 0);
        @(negedge PCLK);
        gpio_in_async[3] = 1'b1;
        wait_pipeline();
        read_reg(ADDR_INT_STATUS, 0, 0);
        @(negedge PCLK);
        gpio_in_async[3] = 1'b0;
        wait_pipeline();

        // Status capture is independent of INT_ENABLE.
        write_reg(ADDR_INT_RISE_ENABLE, 32'h0000_0d08, 4'hf, 0);
        write_reg(ADDR_INT_ENABLE, 0, 4'hf, 0);
        @(negedge PCLK);
        gpio_in_async[11] = 1'b1;
        wait_pipeline();
        read_reg(ADDR_INT_STATUS, 32'h0000_0800, 0);
        check32("masked pending irq", {31'b0, irq}, 0);
        write_reg(ADDR_INT_ENABLE, 32'h0000_0800, 4'hf, 0);
        check32("unmasked pending irq", {31'b0, irq}, 1);
        write_reg(ADDR_INT_STATUS, 32'h0000_0800, 4'hf, 0);
        check32("masked status cleared", {31'b0, irq}, 0);

        // Align a synchronized rising event with an APB W1C completion edge.
        write_reg(ADDR_INT_RISE_ENABLE, 32'h0000_1d08, 4'hf, 0);
        @(negedge PCLK);
        gpio_in_async[12] = 1'b1;
        @(posedge PCLK);
        #1;
        write_reg(ADDR_INT_STATUS, 32'h0000_1000, 4'hf, 0);
        read_reg(ADDR_INT_STATUS, 32'h0000_1000, 0);
        write_reg(ADDR_INT_STATUS, 32'h0000_1000, 4'hf, 0);

        // APB error responses remain correct at the integrated boundary.
        write_reg(ADDR_DATA_IN, 32'hffff_ffff, 4'hf, 1);
        read_reg(8'h1c, 0, 1);

        #2 PRESETn = 1'b0;
        #1;
        check32("final reset gpio_out", gpio_out, 0);
        check32("final reset gpio_oe", gpio_oe, 0);
        check32("final reset irq", {31'b0, irq}, 0);

        $display("PASS: tb_apb_gpio_top (%0d checks)", checks);
        $finish;
    end
endmodule

`default_nettype wire
