// ============================================================================
// tb_step2_byte_reg.v  -  Step 2 testbench: register with byte strobes
// ============================================================================
`timescale 1ns/1ps
module tb_step2_byte_reg;
    reg clk = 1'b0;  always #10 clk = ~clk;
    reg rst_n = 1'b0;
    reg        we = 1'b0;
    reg [3:0]  strb = 4'h0;
    reg [31:0] wdata = 32'h0;
    wire [31:0] q;
    // 16 implemented bits, reset value 0x1234 (try other MASK values!)
    byte_reg #(.W(32), .RESET_VAL(32'hABCD_1234), .MASK(32'h0000_FFFF)) dut (
        .clk(clk), .rst_n(rst_n), .we(we), .strb(strb), .wdata(wdata), .q(q));

    reg [31:0] model;  integer errors = 0, i, b;
    localparam [31:0] MASK = 32'h0000_FFFF;

    task wr(input [3:0] s, input [31:0] d);
        begin
            @(negedge clk); we = 1'b1; strb = s; wdata = d;
            @(negedge clk); we = 1'b0;
            for (b = 0; b < 4; b = b + 1)
                if (s[b]) model[8*b +: 8] = d[8*b +: 8] & MASK[8*b +: 8];
            if (q !== model) begin
                errors = errors + 1;
                $display("[%0t] FAIL strb=%b wdata=%h q=%h exp=%h", $time, s, d, q, model);
            end
        end
    endtask

    initial begin
        $dumpfile("step2.vcd");  $dumpvars(0, tb_step2_byte_reg);
        #25 rst_n = 1'b1;
        model = 32'h0000_1234;
        @(negedge clk);
        if (q !== model) begin errors = errors + 1; $display("FAIL reset value q=%h", q); end
        else $display("[%0t] reset value      q=%h  (RESET_VAL & MASK)", $time, q);

        wr(4'b1111, 32'hFFFF_FFFF); $display("[%0t] write all bytes  q=%h", $time, q);
        wr(4'b0001, 32'h0000_00A5); $display("[%0t] write byte 0     q=%h", $time, q);
        wr(4'b0010, 32'h0000_5A00); $display("[%0t] write byte 1     q=%h", $time, q);
        wr(4'b1100, 32'h1234_0000); $display("[%0t] write bytes 3:2  q=%h  (not implemented)", $time, q);
        wr(4'b0000, 32'h0000_0000); $display("[%0t] PSTRB = 0000     q=%h  (no change)", $time, q);

        // hold we=0 with changing data: nothing may change
        @(negedge clk); wdata = 32'hDEAD_BEEF; strb = 4'hF;
        repeat (3) @(negedge clk);
        if (q !== model) begin errors = errors + 1; $display("FAIL changed while we=0"); end

        for (i = 0; i < 500; i = i + 1) wr($random, $random);   // random strobes and data
        $display("[%0t] 500 random byte writes checked", $time);

        if (errors == 0) $display("*** STEP 2 PASS ***");
        else             $display("*** STEP 2 FAIL : %0d error(s) ***", errors);
        $finish;
    end
    initial begin #100000; $display("TIMEOUT - the design never reached the end of the test (deadlock?)  *** FAIL ***"); $finish; end
endmodule
