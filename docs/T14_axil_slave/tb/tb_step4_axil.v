// ============================================================================
// tb_step4_axil.v  -  Step 4: directed test of the complete AXI4-Lite slave
// ============================================================================
`timescale 1ns/1ps
module tb_step4_axil;
    `include "tb_axil_dut.vh"
    `include "axil_bfm.vh"
    integer errors = 0, n = 0;
    reg [1:0] r, r2;  reg [31:0] d, c1, c2;

    task rd_check(input [11:0] a, input [31:0] exp, input [1:0] exp_resp, input [8*12-1:0] name);
        begin
            axi_read(a, 0, 0, d, r);  n = n + 1;
            if (d !== exp || r !== exp_resp) begin
                errors = errors + 1; $display("[%0t] FAIL rd %-10s @%h = %h RRESP=%b (exp %h %b)", $time, name, a, d, r, exp, exp_resp);
            end else $display("[%0t]  ok  rd %-10s @%h = %h RRESP=%b", $time, name, a, d, r);
        end
    endtask
    task wr_check(input [11:0] a, input [31:0] v, input [3:0] s, input [1:0] exp_resp);
        begin
            axi_write(a, v, s, 0, 0, 0, r);  n = n + 1;
            if (r !== exp_resp) begin errors = errors + 1; $display("[%0t] FAIL wr @%h BRESP=%b", $time, a, r); end
        end
    endtask

    initial begin
        $dumpfile("step4.vcd");  $dumpvars(0, tb_step4_axil);
        #35 ARESETn = 1'b1;
        $display("--- T1 reset values");
        rd_check(GPIO_OUT, 0, OKAY, "GPIO_OUT");     rd_check(SEG_DATA, 0, OKAY, "SEG_DATA");
        rd_check(SEG_CTRL, 32'hFF, OKAY, "SEG_CTRL"); rd_check(CNT_CTRL, 1, OKAY, "CNT_CTRL");
        rd_check(CNT_PRESC, 0, OKAY, "CNT_PRESC");   rd_check(SCRATCH, 0, OKAY, "SCRATCH");
        rd_check(ID_REG, 32'h4158_4C01, OKAY, "ID");

        $display("--- T2 write / read back");
        wr_check(GPIO_OUT, 32'hDEAD_BEEF, 4'hF, OKAY);  rd_check(GPIO_OUT, 32'hDEAD_BEEF, OKAY, "GPIO_OUT");
        wr_check(SEG_DATA, 32'h0123_4567, 4'hF, OKAY);  rd_check(SEG_DATA, 32'h0123_4567, OKAY, "SEG_DATA");
        wr_check(SEG_CTRL, 32'hFFFF_FF3C, 4'hF, OKAY);  rd_check(SEG_CTRL, 32'h0000_003C, OKAY, "SEG_CTRL");
        wr_check(SCRATCH,  32'h5555_AAAA, 4'b0011, OKAY); rd_check(SCRATCH, 32'h0000_AAAA, OKAY, "SCRATCH");
        if (seg_en !== 8'h3C || seg_data !== 32'h0123_4567) begin errors = errors + 1; $display("FAIL seg pins"); end

        $display("--- T3 GPIO_IN and the counter");
        gpio_in = 16'h8001;  repeat (3) @(posedge ACLK);
        rd_check(GPIO_IN, 32'h0000_8001, OKAY, "GPIO_IN");
        wr_check(CNT_PRESC, 32'd9, 4'hF, OKAY);            // +1 every 10 clocks
        wr_check(CNT_CTRL, 32'd3, 4'hF, OKAY);             // enable + clear
        repeat (100) @(posedge ACLK);
        axi_read(CNT_VALUE, 0, 0, c1, r);
        repeat (200) @(posedge ACLK);
        axi_read(CNT_VALUE, 0, 0, c2, r);
        $display("[%0t]  ..  counter %0d -> %0d after 200+ clocks (PRESC = 9)", $time, c1, c2);
        if (c2 - c1 < 20 || c2 - c1 > 21) begin errors = errors + 1; $display("FAIL counter rate"); end
        wr_check(CNT_CTRL, 32'd0, 4'hF, OKAY);             // stop
        axi_read(CNT_VALUE, 0, 0, c1, r); repeat (50) @(posedge ACLK); axi_read(CNT_VALUE, 0, 0, c2, r);
        if (c1 !== c2) begin errors = errors + 1; $display("FAIL counter not stopped"); end
        else $display("[%0t]  ok  counter stopped at %0d", $time, c2);

        $display("--- T4 read back-pressure and concurrent read + write");
        axi_read(SEG_DATA, 2, 7, d, r);                     // RREADY 7 clocks late
        if (d !== 32'h0123_4567) begin errors = errors + 1; $display("FAIL read with back-pressure"); end
        else $display("[%0t]  ok  read with RREADY 7 clocks late", $time);
        fork
            axi_write(SCRATCH, 32'hC0FF_EE00, 4'hF, 1, 0, 2, r2);
            axi_read(GPIO_OUT, 0, 3, d, r);
        join
        if (r2 !== OKAY || d !== 32'hDEAD_BEEF) begin errors = errors + 1; $display("FAIL concurrent"); end
        else $display("[%0t]  ok  write SCRATCH and read GPIO_OUT at the same time", $time);
        rd_check(SCRATCH, 32'hC0FF_EE00, OKAY, "SCRATCH");

        $display("--- T5 errors");
        rd_check(12'h024, 0, SLVERR, "unmapped");     rd_check(12'hFFC, 0, SLVERR, "unmapped");
        rd_check(12'h006, 0, SLVERR, "unaligned");
        wr_check(CNT_VALUE, 32'h0, 4'hF, SLVERR);     wr_check(12'h800, 32'h0, 4'hF, SLVERR);
        rd_check(GPIO_OUT, 32'hDEAD_BEEF, OKAY, "GPIO_OUT");

        $display("=== %0d transactions, %0d error(s) ===", n, errors);
        if (errors == 0) $display("*** STEP 4 PASS ***");
        else             $display("*** STEP 4 FAIL ***");
        $finish;
    end
    initial begin #200000; $display("TIMEOUT - the bus is stuck (deadlock?)  *** FAIL ***"); $finish; end
endmodule
