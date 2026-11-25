`timescale 1ns/1ps
module tb_apb_gpio_n32;
    reg PCLK = 0;
    always #10 PCLK = ~PCLK;
    reg PRESETn = 0, PSEL = 0, PENABLE = 0, PWRITE = 0;
    reg [11:0] PADDR = 0;
    reg [31:0] PWDATA = 0, gpio_in = 0;
    reg [3:0] PSTRB = 0;
    wire [31:0] PRDATA, gpio_out, gpio_oe;
    wire PREADY, PSLVERR, irq;
    reg err;
    reg [31:0] data;

    apb_gpio #(.N(32), .WAIT_STATES(2)) dut (
        .PCLK(PCLK), .PRESETn(PRESETn), .PSEL(PSEL), .PENABLE(PENABLE), .PWRITE(PWRITE),
        .PADDR(PADDR), .PWDATA(PWDATA), .PSTRB(PSTRB), .PPROT(3'b000),
        .PRDATA(PRDATA), .PREADY(PREADY), .PSLVERR(PSLVERR),
        .gpio_in(gpio_in), .gpio_out(gpio_out), .gpio_oe(gpio_oe), .irq(irq)
    );

    `include "apb_bfm.vh"

    task write_ok(input [11:0] addr, input [31:0] value, input [3:0] lanes);
        begin
            apb_write(addr, value, lanes, err);
            if (err !== 0) $fatal(1, "Write error at %h", addr);
        end
    endtask

    task read_check(input [11:0] addr, input [31:0] expected);
        begin
            apb_read(addr, data, err);
            if (err !== 0 || data !== expected)
                $fatal(1, "Address %h returned %h err=%b, expected %h", addr, data, err, expected);
        end
    endtask

    initial begin
        #35 PRESETn = 1;
        write_ok(12'h000, 32'h00001234, 4'b0011);
        write_ok(12'h000, 32'h00560000, 4'b0100);
        read_check(12'h000, 32'h00561234);
        write_ok(12'h000, 32'hAB000000, 4'b1000);
        read_check(12'h000, 32'hAB561234);
        if (gpio_out !== 32'hAB561234) $fatal(1, "GPIO output mismatch");

        write_ok(12'h010, 32'h80000000, 4'b1000);
        write_ok(12'h00C, 32'h80000000, 4'b1000);
        @(negedge PCLK);
        gpio_in[31] = 1;
        repeat (4) @(negedge PCLK);
        read_check(12'h004, 32'h80000000);
        read_check(12'h018, 32'h80000000);
        if (irq !== 1) $fatal(1, "GPIO31 did not assert IRQ");

        write_ok(12'h018, 32'h80000000, 4'b0100);
        read_check(12'h018, 32'h80000000);
        write_ok(12'h018, 32'h80000000, 4'b1000);
        read_check(12'h018, 32'h00000000);
        if (irq !== 0) $fatal(1, "GPIO31 IRQ did not clear");
        $display("PASS: N=32 upper byte lanes, GPIO31 input, IRQ and byte-qualified W1C");
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
