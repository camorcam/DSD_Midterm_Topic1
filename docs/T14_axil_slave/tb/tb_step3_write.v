// ============================================================================
// tb_step3_write.v  -  Step 3: AXI4-Lite WRITE path (AW, W, B channels)
// Checks every ordering of AW and W, B back-pressure, WSTRB and SLVERR.
// The result of a write is observed on the gpio_out / seg_data pins.
// ============================================================================
`timescale 1ns/1ps
module tb_step3_write;
    `include "tb_axil_dut.vh"
    `include "axil_bfm.vh"
    integer errors = 0;  reg [1:0] r;

    task wr_check(input [11:0] a, input [31:0] d, input [3:0] s, input integer daw, input integer dw,
                  input integer db, input [1:0] exp_resp, input [8*30-1:0] msg);
        integer t0;
        begin
            t0 = $time;
            axi_write(a, d, s, daw, dw, db, r);
            if (r !== exp_resp) begin errors = errors + 1; $display("[%0t] FAIL %0s BRESP=%b", $time, msg, r); end
            else $display("[%0t]  ok  %-30s BRESP=%b  (%0d clocks)", $time, msg, r, ($time - t0) / 20);
        end
    endtask
    task pins(input [31:0] g, input [31:0] s);
        begin
            if (gpio_out !== g || seg_data !== s) begin
                errors = errors + 1; $display("[%0t] FAIL gpio_out=%h seg_data=%h (exp %h %h)", $time, gpio_out, seg_data, g, s);
            end
        end
    endtask

    initial begin
        $dumpfile("step3.vcd");  $dumpvars(0, tb_step3_write);
        #35 ARESETn = 1'b1;
        @(posedge ACLK);
        wr_check(GPIO_OUT, 32'h0000_0011, 4'hF, 0, 0, 0, OKAY, "AW and W in the same clock");   pins(32'h11, 0);
        wr_check(GPIO_OUT, 32'h0000_0022, 4'hF, 0, 3, 0, OKAY, "AW 3 clocks before W");         pins(32'h22, 0);
        wr_check(GPIO_OUT, 32'h0000_0033, 4'hF, 4, 0, 0, OKAY, "W 4 clocks before AW");         pins(32'h33, 0);
        wr_check(SEG_DATA, 32'h1234_5678, 4'hF, 1, 2, 6, OKAY, "BREADY late (back-pressure)");  pins(32'h33, 32'h1234_5678);
        wr_check(SEG_DATA, 32'hAB00_0000, 4'b1000, 0, 0, 0, OKAY, "WSTRB = 1000");              pins(32'h33, 32'hAB34_5678);
        wr_check(SEG_DATA, 32'hFFFF_FFFF, 4'b0000, 0, 0, 0, OKAY, "WSTRB = 0000 (no change)");  pins(32'h33, 32'hAB34_5678);
        wr_check(GPIO_IN,  32'hFFFF_FFFF, 4'hF, 0, 0, 0, SLVERR, "write to RO GPIO_IN");        pins(32'h33, 32'hAB34_5678);
        wr_check(ID_REG,   32'hFFFF_FFFF, 4'hF, 2, 0, 0, SLVERR, "write to RO ID");
        wr_check(12'h040,  32'hFFFF_FFFF, 4'hF, 0, 2, 1, SLVERR, "write to unmapped 0x040");
        wr_check(12'h001,  32'hFFFF_FFFF, 4'hF, 0, 0, 0, SLVERR, "unaligned write 0x001");      pins(32'h33, 32'hAB34_5678);
        // AWREADY must not wait for WVALID: send AW alone and look at AWREADY
        @(posedge ACLK); #1 AWVALID = 1; AWADDR = GPIO_OUT;
        @(posedge ACLK);
        if (!AWREADY) begin errors = errors + 1; $display("FAIL AWREADY waits for WVALID"); end
        else $display("[%0t]  ok  AWREADY = 1 without WVALID (no channel dependency)", $time);
        #1 AWVALID = 0;
        repeat (3) @(posedge ACLK);
        if (BVALID) begin errors = errors + 1; $display("FAIL BVALID before the data arrived"); end
        else $display("[%0t]  ok  no BVALID while the data is missing", $time);
        // now send only the W beat; the held address and this data make one write
        #1 WVALID = 1; WDATA = 32'h44; WSTRB = 4'hF; BREADY = 1;
        @(posedge ACLK); while (!WREADY) @(posedge ACLK);
        #1 WVALID = 0;
        @(posedge ACLK); while (!BVALID) @(posedge ACLK);
        #1 BREADY = 0;
        if (BRESP !== OKAY || gpio_out !== 32'h44) begin errors = errors + 1; $display("FAIL late W"); end
        else $display("[%0t]  ok  W sent alone later -> write done, gpio_out=%h", $time, gpio_out);
        if (errors == 0) $display("*** STEP 3 PASS ***");
        else             $display("*** STEP 3 FAIL : %0d error(s) ***", errors);
        $finish;
    end
    initial begin #100000; $display("TIMEOUT - the bus is stuck (deadlock?)  *** FAIL ***"); $finish; end
endmodule
