// ============================================================================
// tb_step2_regs.v  -  Step 2: wstrb_merge, free_counter, periph_regs
// ============================================================================
`timescale 1ns/1ps
module tb_step2_regs;
    reg clk = 1'b0;  always #10 clk = ~clk;
    reg rst_n = 1'b0;
    integer errors = 0, i, k;

    // ---------------- 2a: wstrb_merge, all 16 strobe patterns -----------------
    reg  [31:0] o, d;  reg [3:0] st;  wire [31:0] nv;  reg [31:0] e;
    wstrb_merge u_m (.old_val(o), .wdata(d), .wstrb(st), .new_val(nv));

    // ---------------- 2b: free_counter ---------------------------------------
    reg en = 1'b0, clr = 1'b0;  reg [31:0] presc = 32'd0;  wire [31:0] cnt;
    free_counter u_c (.clk(clk), .rst_n(rst_n), .enable(en), .clear(clr), .presc(presc), .count(cnt));

    // ---------------- 2c: periph_regs through its simple bus -------------------
    reg wr_en = 1'b0;  reg [11:0] wa = 0, ra = 0;  reg [31:0] wd = 0;  reg [3:0] ws = 0;
    wire wr_err, rd_err;  wire [31:0] rd_data, gpio_out, seg_data;  wire [7:0] seg_en;
    reg [15:0] gin = 16'h0;
    periph_regs #(.NIN(16)) u_r (.clk(clk), .rst_n(rst_n), .wr_en(wr_en), .wr_addr(wa), .wr_data(wd),
        .wr_strb(ws), .wr_err(wr_err), .rd_addr(ra), .rd_data(rd_data), .rd_err(rd_err),
        .gpio_in(gin), .gpio_out(gpio_out), .seg_data(seg_data), .seg_en(seg_en));

    task reg_wr(input [11:0] a, input [31:0] v, input [3:0] s, input exp_err);
        begin
            @(negedge clk); wr_en = 1; wa = a; wd = v; ws = s; #1;
            if (wr_err !== exp_err) begin errors = errors + 1; $display("FAIL wr_err @%h = %b", a, wr_err); end
            @(negedge clk); wr_en = 0;
        end
    endtask
    task reg_rd(input [11:0] a, input [31:0] exp, input exp_err);
        begin
            @(negedge clk); ra = a; #1;
            if (rd_data !== exp || rd_err !== exp_err) begin
                errors = errors + 1; $display("[%0t] FAIL rd @%h = %h err=%b (exp %h err=%b)", $time, a, rd_data, rd_err, exp, exp_err);
            end else $display("[%0t]  ok  rd @%h = %h err=%b", $time, a, rd_data, rd_err);
        end
    endtask

    integer t0, t1;
    initial begin
        $dumpfile("step2.vcd");  $dumpvars(0, tb_step2_regs);
        // ---- 2a
        for (i = 0; i < 2000; i = i + 1) begin
            o = $random; d = $random; st = i[3:0]; #1;
            for (k = 0; k < 4; k = k + 1) e[8*k +: 8] = st[k] ? d[8*k +: 8] : o[8*k +: 8];
            if (nv !== e) begin errors = errors + 1; $display("FAIL merge strb=%b", st); end
        end
        $display("2a wstrb_merge: 2000 random vectors, all 16 strobe patterns checked");

        // ---- 2b
        #35 rst_n = 1'b1;
        @(negedge clk); presc = 32'd4; en = 1'b1;               // tick every 5 clocks
        @(posedge cnt[0]); t0 = $time;  @(posedge cnt[1]); t1 = $time;
        if ((t1 - t0) != 5 * 20) begin errors = errors + 1; $display("FAIL counter period %0d ns", t1 - t0); end
        else $display("2b free_counter: PRESC=4 -> one increment every %0d ns (5 clocks)", (t1 - t0) / 1);
        @(negedge clk); en = 1'b0; k = cnt; repeat (20) @(negedge clk);
        if (cnt !== k) begin errors = errors + 1; $display("FAIL counter runs while disabled"); end
        @(negedge clk); clr = 1'b1; @(negedge clk); clr = 1'b0;
        if (cnt !== 0) begin errors = errors + 1; $display("FAIL clear"); end
        else $display("2b free_counter: enable=0 holds, clear -> 0");

        // ---- 2c
        $display("2c periph_regs:");
        reg_rd(12'h00C, 32'h0000_00FF, 0);              // SEG_CTRL reset value
        reg_rd(12'h014, 32'h0000_0001, 0);              // CNT_CTRL reset value
        reg_rd(12'h020, 32'h4158_4C01, 0);              // ID
        reg_wr(12'h000, 32'hCAFE_F00D, 4'hF, 0);  reg_rd(12'h000, 32'hCAFE_F00D, 0);
        reg_wr(12'h000, 32'h1111_2222, 4'b0100, 0); reg_rd(12'h000, 32'hCA11_F00D, 0);
        reg_wr(12'h00C, 32'hFFFF_FF0F, 4'hF, 0);  reg_rd(12'h00C, 32'h0000_000F, 0);
        reg_wr(12'h01C, 32'h1234_5678, 4'hF, 0);  reg_rd(12'h01C, 32'h1234_5678, 0);
        gin = 16'hA5A5; repeat (3) @(negedge clk);  reg_rd(12'h004, 32'h0000_A5A5, 0);
        reg_wr(12'h004, 32'h0, 4'hF, 1);  reg_wr(12'h010, 32'h0, 4'hF, 1);  reg_wr(12'h020, 32'h0, 4'hF, 1);
        reg_wr(12'h024, 32'h0, 4'hF, 1);  reg_wr(12'h002, 32'h0, 4'hF, 1);
        reg_rd(12'h024, 32'h0, 1);  reg_rd(12'h100, 32'h0, 1);  reg_rd(12'h003, 32'h0, 1);
        reg_wr(12'h018, 32'd1, 4'hF, 0);                  // PRESC = 1
        reg_wr(12'h014, 32'd3, 4'hF, 0);                  // enable + clear
        repeat (10) @(negedge clk);
        reg_rd(12'h010, 32'd5, 0);                        // 10 clocks / 2 = 5
        if (errors == 0) $display("*** STEP 2 PASS ***");
        else             $display("*** STEP 2 FAIL : %0d error(s) ***", errors);
        $finish;
    end
    initial begin #100000; $display("TIMEOUT - the design never reached the end of the test (deadlock?)  *** FAIL ***"); $finish; end
endmodule
