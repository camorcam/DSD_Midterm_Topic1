// ============================================================================
// tb_step1_basic.v  -  Step 1 testbench: sync_2ff, edge_detect, rst_sync, debounce
// Self-checking: prints PASS / FAIL at the end.  Waveform: step1.vcd
// ============================================================================
`timescale 1ns/1ps
module tb_step1_basic;
    reg clk = 1'b0;
    always #10 clk = ~clk;                         // 50 MHz

    reg        rst_btn = 1'b0;                     // asynchronous reset button
    wire       rst_n;
    reg  [3:0] pin = 4'h0;                         // asynchronous inputs
    wire [3:0] s, rise, fall;

    rst_sync           u_rst  (.clk(clk), .rst_n_in(rst_btn), .rst_n_out(rst_n));
    sync_2ff   #(.N(4)) u_sync (.clk(clk), .rst_n(rst_n), .d_async(pin), .q_sync(s));
    edge_detect#(.N(4)) u_edge (.clk(clk), .rst_n(rst_n), .d(s), .rise(rise), .fall(fall));

    // debounce with a short STABLE time so the simulation is fast
    reg  btn = 1'b0;  wire btn_s, btn_clean;
    sync_2ff #(.N(1))                   u_bs (.clk(clk), .rst_n(rst_n), .d_async(btn), .q_sync(btn_s));
    debounce #(.N(1), .STABLE(8), .CW(4)) u_db (.clk(clk), .rst_n(rst_n), .d(btn_s), .q(btn_clean));

    integer errors = 0, n_rise_exp = 0, n_fall_exp = 0, n_rise = 0, n_fall = 0, i, k, n_clean = 0;
    reg [3:0] old;

    // ---------------- reference model (cycle based) for sync + edge ----------
    reg [3:0] m1, m2, m3;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin m1 <= 0; m2 <= 0; m3 <= 0; end
        else        begin m1 <= pin; m2 <= m1; m3 <= m2; end

    always @(negedge clk) if (rst_n) begin          // compare in the middle of the cycle
        if (s !== m2) begin errors = errors + 1; $display("[%0t] FAIL sync  s=%b exp=%b", $time, s, m2); end
        if (rise !== (m2 & ~m3) || fall !== (~m2 & m3)) begin
            errors = errors + 1; $display("[%0t] FAIL edge rise=%b fall=%b", $time, rise, fall);
        end
        for (k = 0; k < 4; k = k + 1) begin
            n_rise = n_rise + rise[k];
            n_fall = n_fall + fall[k];
        end
    end
    always @(posedge btn_clean or negedge btn_clean) if (rst_n) n_clean = n_clean + 1;

    initial begin
        $dumpfile("step1.vcd");
        $dumpvars(0, tb_step1_basic);

        // ---- Test 1: reset synchronizer --------------------------------------
        #33  rst_btn = 1'b1;                         // release between clock edges
        @(posedge clk); #1;
        if (rst_n !== 1'b0) begin errors = errors + 1; $display("FAIL rst_sync released after 1 edge"); end
        @(posedge clk); #1;
        if (rst_n !== 1'b1) begin errors = errors + 1; $display("FAIL rst_sync not released after 2 edges"); end
        else $display("[%0t] Test 1 rst_sync: reset released 2 clocks after the button", $time);

        // ---- Test 2: random asynchronous pin changes -------------------------
        for (i = 0; i < 200; i = i + 1) begin
            #(25 + ({$random} % 60));               // any time, not aligned to clk
            old = pin;
            pin = pin ^ (4'h1 << ({$random} % 4)); // toggle one bit
            for (k = 0; k < 4; k = k + 1) begin
                if (!old[k] &&  pin[k]) n_rise_exp = n_rise_exp + 1;
                if ( old[k] && !pin[k]) n_fall_exp = n_fall_exp + 1;
            end
        end
        repeat (4) @(posedge clk);
        @(negedge clk);
        $display("[%0t] Test 2 edges: rise %0d/%0d  fall %0d/%0d", $time, n_rise, n_rise_exp, n_fall, n_fall_exp);
        if (n_rise != n_rise_exp || n_fall != n_fall_exp) begin
            errors = errors + 1; $display("FAIL edge count");
        end

        // ---- Test 3: debounce a bouncing button -------------------------------
        for (i = 0; i < 12; i = i + 1) begin           // 12 bounces, 1..3 clocks each
            #(20 + 20 * ({$random} % 3)) btn = ~btn;
        end
        btn = 1'b1;  repeat (20) @(posedge clk);       // stays pressed
        for (i = 0; i < 9; i = i + 1) begin            // bouncy release
            #(20 + 20 * ({$random} % 3)) btn = ~btn;
        end
        btn = 1'b0;  repeat (20) @(posedge clk);
        $display("[%0t] Test 3 debounce: %0d input bounces -> %0d clean changes", $time, 21, n_clean);
        if (n_clean != 2) begin errors = errors + 1; $display("FAIL debounce"); end

        if (errors == 0) $display("*** STEP 1 PASS ***");
        else             $display("*** STEP 1 FAIL : %0d error(s) ***", errors);
        $finish;
    end
    initial begin #100000; $display("TIMEOUT - the design never reached the end of the test (deadlock?)  *** FAIL ***"); $finish; end
endmodule
