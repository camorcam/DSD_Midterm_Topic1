// ============================================================================
// tb_step4_apb_gpio.v  -  Step 4 testbench: directed tests of apb_gpio
// Run with wait states:  ./run_icarus.sh 4 -DWS=2
// ============================================================================
`timescale 1ns/1ps
`ifndef WS
 `define WS 0
`endif
module tb_step4_apb_gpio;
    localparam N = 16;
    localparam [31:0] MASK = 32'h0000_FFFF, ID = 32'h4750_4901;
    localparam DATA_OUT = 12'h000, DATA_IN = 12'h004, DIR = 12'h008, INT_EN = 12'h00C,
               INT_RISE = 12'h010, INT_FALL = 12'h014, INT_STAT = 12'h018, ID_REG = 12'h01C;

    reg PCLK = 1'b0;  always #10 PCLK = ~PCLK;
    reg PRESETn = 1'b0;
    reg PSEL = 0, PENABLE = 0, PWRITE = 0;
    reg [11:0] PADDR = 0;  reg [31:0] PWDATA = 0;  reg [3:0] PSTRB = 0;
    wire [31:0] PRDATA;  wire PREADY, PSLVERR;
    reg  [N-1:0] gpio_in = 0;
    wire [N-1:0] gpio_out, gpio_oe;
    wire irq;

    apb_gpio #(.N(N), .WAIT_STATES(`WS)) dut (
        .PCLK(PCLK), .PRESETn(PRESETn), .PSEL(PSEL), .PENABLE(PENABLE), .PWRITE(PWRITE),
        .PADDR(PADDR), .PWDATA(PWDATA), .PSTRB(PSTRB), .PPROT(3'b000),
        .PRDATA(PRDATA), .PREADY(PREADY), .PSLVERR(PSLVERR),
        .gpio_in(gpio_in), .gpio_out(gpio_out), .gpio_oe(gpio_oe), .irq(irq));

    `include "apb_bfm.vh"

    integer errors = 0, tests = 0;
    reg [31:0] rd;  reg err;

    task check_read(input [11:0] a, input [31:0] exp, input exp_err, input [8*20-1:0] name);
        begin
            apb_read(a, rd, err);  tests = tests + 1;
            if (rd !== exp || err !== exp_err) begin
                errors = errors + 1;
                $display("[%0t] FAIL rd %-12s @%h = %h err=%b  (exp %h err=%b)", $time, name, a, rd, err, exp, exp_err);
            end else
                $display("[%0t]  ok  rd %-12s @%h = %h err=%b", $time, name, a, rd, err);
        end
    endtask
    task do_write(input [11:0] a, input [31:0] d, input [3:0] s, input exp_err);
        begin
            apb_write(a, d, s, err);  tests = tests + 1;
            if (err !== exp_err) begin
                errors = errors + 1; $display("[%0t] FAIL wr @%h err=%b exp=%b", $time, a, err, exp_err);
            end
        end
    endtask

    initial begin
        $dumpfile("step4.vcd");  $dumpvars(0, tb_step4_apb_gpio);
        $display("=== apb_gpio directed test, WAIT_STATES = %0d ===", `WS);
        #35 PRESETn = 1'b1;

        $display("--- T1 reset values");
        check_read(DATA_OUT, 0, 0, "DATA_OUT");  check_read(DIR, 0, 0, "DIR");
        check_read(INT_EN, 0, 0, "INT_ENABLE");  check_read(INT_RISE, 0, 0, "INT_RISE");
        check_read(INT_FALL, 0, 0, "INT_FALL");  check_read(INT_STAT, 0, 0, "INT_STATUS");
        check_read(ID_REG, ID, 0, "ID");

        $display("--- T2 read/write every RW register (unimplemented bits read 0)");
        do_write(DATA_OUT, 32'hFFFF_FFFF, 4'hF, 0);  check_read(DATA_OUT, MASK, 0, "DATA_OUT");
        do_write(DIR,      32'h1234_A5C3, 4'hF, 0);  check_read(DIR, 32'h0000_A5C3, 0, "DIR");
        do_write(INT_EN,   32'h0000_5555, 4'hF, 0);  check_read(INT_EN, 32'h0000_5555, 0, "INT_ENABLE");
        do_write(INT_RISE, 32'h0000_AAAA, 4'hF, 0);  check_read(INT_RISE, 32'h0000_AAAA, 0, "INT_RISE");
        do_write(INT_FALL, 32'h0000_0F0F, 4'hF, 0);  check_read(INT_FALL, 32'h0000_0F0F, 0, "INT_FALL");
        if (gpio_oe !== 16'hA5C3 || gpio_out !== 16'hFFFF) begin
            errors = errors + 1; $display("FAIL pins gpio_out=%h gpio_oe=%h", gpio_out, gpio_oe);
        end else $display("[%0t]  ok  pins gpio_out=%h gpio_oe=%h", $time, gpio_out, gpio_oe);

        $display("--- T3 byte strobes");
        do_write(DATA_OUT, 32'h0000_0000, 4'hF, 0);
        do_write(DATA_OUT, 32'h0000_1234, 4'b0001, 0);  check_read(DATA_OUT, 32'h0000_0034, 0, "DATA_OUT b0");
        do_write(DATA_OUT, 32'h0000_5678, 4'b0010, 0);  check_read(DATA_OUT, 32'h0000_5634, 0, "DATA_OUT b1");
        do_write(DATA_OUT, 32'h0000_FFFF, 4'b0000, 0);  check_read(DATA_OUT, 32'h0000_5634, 0, "DATA_OUT none");

        $display("--- T4 DATA_IN through the synchronizer");
        gpio_in = 16'hBEEF;  repeat (3) @(posedge PCLK);
        check_read(DATA_IN, 32'h0000_BEEF, 0, "DATA_IN");

        $display("--- T5 interrupts: pin0 rising, pin1 falling, pin2 both");
        // good driver practice: disable, set the pins, then clear stale events
        do_write(INT_EN, 0, 4'hF, 0); do_write(INT_RISE, 0, 4'hF, 0); do_write(INT_FALL, 0, 4'hF, 0);
        gpio_in = 16'h0002;  repeat (4) @(posedge PCLK);          // pin1 high, others low
        do_write(INT_STAT, 32'hFFFF, 4'hF, 0);
        do_write(INT_RISE, 32'h0005, 4'hF, 0);  do_write(INT_FALL, 32'h0006, 4'hF, 0);
        do_write(INT_EN,   32'h0007, 4'hF, 0);
        check_read(INT_STAT, 0, 0, "INT_STATUS");
        gpio_in = 16'h0005;  repeat (4) @(posedge PCLK);          // pin0 up, pin1 down, pin2 up
        check_read(INT_STAT, 32'h0007, 0, "INT_STATUS");
        if (irq !== 1'b1) begin errors = errors + 1; $display("FAIL irq not set"); end
        do_write(INT_STAT, 32'h0001, 4'hF, 0);  check_read(INT_STAT, 32'h0006, 0, "after W1C b0");
        do_write(INT_STAT, 32'h0006, 4'b0000, 0); check_read(INT_STAT, 32'h0006, 0, "W1C PSTRB=0");
        do_write(INT_STAT, 32'hFFFF, 4'hF, 0);  check_read(INT_STAT, 32'h0000, 0, "after W1C all");
        if (irq !== 1'b0) begin errors = errors + 1; $display("FAIL irq not cleared"); end
        gpio_in = 16'h0001;  repeat (4) @(posedge PCLK);          // pin2 falls (both edges)
        check_read(INT_STAT, 32'h0004, 0, "pin2 fall");
        do_write(INT_STAT, 32'hFFFF, 4'hF, 0);

        $display("--- T6 error responses (PSLVERR)");
        check_read(12'h020, 32'h0, 1, "unmapped 0x20");
        check_read(12'hFFC, 32'h0, 1, "unmapped 0xFFC");
        check_read(12'h002, 32'h0, 1, "unaligned 0x02");
        do_write(12'h040, 32'hFFFF_FFFF, 4'hF, 1);
        do_write(DATA_IN, 32'hFFFF_FFFF, 4'hF, 1);
        do_write(ID_REG,  32'h0, 4'hF, 1);
        do_write(12'h001, 32'hFFFF_FFFF, 4'hF, 1);                   // unaligned DATA_OUT
        check_read(DATA_OUT, 32'h0000_5634, 0, "DATA_OUT kept");
        check_read(ID_REG, ID, 0, "ID kept");

        $display("=== %0d transfers, %0d error(s) ===", tests, errors);
        if (errors == 0) $display("*** STEP 4 PASS ***");
        else             $display("*** STEP 4 FAIL ***");
        $finish;
    end
    initial begin #200000; $display("TIMEOUT - the bus is stuck (deadlock?)  *** FAIL ***"); $finish; end
endmodule
