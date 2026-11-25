// ============================================================================
// tb_step1_hs_reg.v  -  Step 1: VALID/READY handshake register stage
// Random source (obeys the VALID rule) and random sink back-pressure.
// Checks: no data lost, none duplicated, order kept, output rule obeyed.
// ============================================================================
`timescale 1ns/1ps
module tb_step1_hs_reg;
    reg clk = 1'b0;  always #10 clk = ~clk;
    reg rst_n = 1'b0;
    reg        s_valid = 1'b0;  reg [7:0] s_data = 8'd0;
    wire       s_ready, m_valid;
    reg        m_ready = 1'b0;
    wire [7:0] m_data;

    hs_reg #(.W(8)) dut (.clk(clk), .rst_n(rst_n), .s_valid(s_valid), .s_ready(s_ready),
        .s_data(s_data), .m_valid(m_valid), .m_ready(m_ready), .m_data(m_data));

    integer errors = 0, n_in = 0, n_out = 0, cyc = 0, stall = 0;
    reg [7:0] next_out = 8'd0;
    reg       pv = 1'b0;  reg [7:0] pd = 8'd0;          // previous-cycle values

    // ---- source: a new item may start only when the previous one was taken ----
    reg took, run = 1'b1;
    always @(posedge clk) if (rst_n) begin
        took = s_valid && s_ready;               // handshake at this edge?
        if (took) n_in = n_in + 1;
        #1;
        if (run && (!s_valid || took)) begin             // free to change (previous item accepted)
            if (took) s_data = s_data + 8'd1;
            s_valid = ({$random} % 3) != 0;      // 2/3 of the clocks offer data
        end
        m_ready = ({$random} % 2);               // random back-pressure
    end

    // ---- sink checker ---------------------------------------------------------
    always @(posedge clk) if (rst_n) begin
        cyc = cyc + 1;
        if (pv && !m_valid) begin errors = errors + 1; $display("[%0t] FAIL m_valid dropped before m_ready", $time); end
        if (pv && m_data !== pd) begin errors = errors + 1; $display("[%0t] FAIL m_data changed while waiting", $time); end
        if (m_valid && m_ready) begin
            if (m_data !== next_out) begin errors = errors + 1; $display("[%0t] FAIL got %0d expected %0d", $time, m_data, next_out); end
            next_out = next_out + 8'd1;  n_out = n_out + 1;
        end
        if (m_valid && !m_ready) stall = stall + 1;
        pv = m_valid && !m_ready;  pd = m_data;
    end

    initial begin
        $dumpfile("step1.vcd");  $dumpvars(0, tb_step1_hs_reg);
        #35 rst_n = 1'b1;
        repeat (3000) @(posedge clk);
        #5 run = 1'b0;                                // stop the source (after the
        @(posedge clk); while (s_valid && !s_ready) @(posedge clk);   // current item)
        #2 s_valid = 1'b0;
        force m_ready = 1'b1;  repeat (5) @(posedge clk);
        $display("items in %0d, out %0d, stall cycles %0d in %0d clocks", n_in, n_out, stall, cyc);
        if (n_in != n_out) begin errors = errors + 1; $display("FAIL lost or extra items"); end
        if (errors == 0) $display("*** STEP 1 PASS ***");
        else             $display("*** STEP 1 FAIL : %0d error(s) ***", errors);
        $finish;
    end
    initial begin #200000; $display("TIMEOUT - the design never reached the end of the test (deadlock?)  *** FAIL ***"); $finish; end
endmodule
