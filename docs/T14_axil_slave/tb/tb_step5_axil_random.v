// ============================================================================
// tb_step5_axil_random.v  -  Step 5: constrained-random verification
//   * a WRITER thread and a READER thread run at the same time
//   * random delay before every VALID and every READY (all 5 channels)
//   * random addresses (legal / RO / unmapped / unaligned) and WSTRB
//   * reference model + scoreboard check EVERY BRESP, RDATA and RRESP
//   * functional coverage; SVA checker (axil_sva.sv) when compiled with SVA
//   Icarus: ./run_icarus.sh 5 [-DSEED=3]     (Verilator 5) ./run_verilator.sh 5
// ============================================================================
`timescale 1ns/1ps
`ifndef SEED
 `define SEED 1
`endif
`ifndef NTRANS
 `define NTRANS 3000
`endif
`ifndef MAXD
 `define MAXD 4
`endif
module tb_step5_axil_random;
    `include "tb_axil_dut.vh"
    `include "axil_bfm.vh"

`ifdef SVA
    axil_sva u_sva (.ACLK(ACLK), .ARESETn(ARESETn),
        .AWVALID(AWVALID), .AWREADY(AWREADY), .AWADDR(AWADDR),
        .WVALID(WVALID), .WREADY(WREADY), .WDATA(WDATA), .WSTRB(WSTRB),
        .BVALID(BVALID), .BREADY(BREADY), .BRESP(BRESP),
        .ARVALID(ARVALID), .ARREADY(ARREADY), .ARADDR(ARADDR),
        .RVALID(RVALID), .RREADY(RREADY), .RDATA(RDATA), .RRESP(RRESP));
`endif

    // ============================ reference model ============================
    reg [31:0] m_gpio_out, m_seg_data, m_seg_ctrl, m_presc, m_scratch, m_cnt, m_pcnt;
    reg        m_en;
    reg [15:0] s1, s2;                                    // synchronizer model
    reg [11:0] m_awaddr;  reg [31:0] m_wdata, mk;  reg [3:0] m_wstrb;  // captured by the monitor
    reg [1:0]  exp_bresp, exp_rresp;  reg [31:0] exp_rdata;
    reg        legal, ro, clr;
    integer    errors = 0, n_w = 0, n_r = 0;

    function [31:0] model_read(input [11:0] a);
        begin
            case (a[5:2])
                0: model_read = m_gpio_out;   1: model_read = {16'h0, s2};
                2: model_read = m_seg_data;   3: model_read = m_seg_ctrl;
                4: model_read = m_cnt;        5: model_read = {31'h0, m_en};
                6: model_read = m_presc;      7: model_read = m_scratch;
                8: model_read = 32'h4158_4C01; default: model_read = 0;
            endcase
            if (!((a[11:6] == 0) && (a[1:0] == 0) && (a[5:2] <= 8))) model_read = 0;
        end
    endfunction

    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            m_gpio_out = 0; m_seg_data = 0; m_seg_ctrl = 32'hFF; m_presc = 0; m_scratch = 0;
            m_cnt = 0; m_pcnt = 0; m_en = 1; s1 = 0; s2 = 0;
        end else begin
            // (1) responses leaving the slave at this edge -> compare
            if (BVALID && BREADY) begin
                n_w = n_w + 1;
                if (BRESP !== exp_bresp) begin errors = errors + 1;
                    $display("[%0t] SB FAIL BRESP=%b exp=%b addr=%h", $time, BRESP, exp_bresp, m_awaddr); end
            end
            if (RVALID && RREADY) begin
                n_r = n_r + 1;
                if (RDATA !== exp_rdata || RRESP !== exp_rresp) begin errors = errors + 1;
                    $display("[%0t] SB FAIL RDATA=%h RRESP=%b exp %h %b", $time, RDATA, RRESP, exp_rdata, exp_rresp); end
            end
            // (2) requests accepted at this edge (values BEFORE the edge)
            if (AWVALID && AWREADY) m_awaddr = AWADDR;
            if (WVALID && WREADY) begin m_wdata = WDATA; m_wstrb = WSTRB; end
            if (ARVALID && ARREADY) begin
                exp_rdata = model_read(ARADDR);
                exp_rresp = ((ARADDR[11:6] == 0) && (ARADDR[1:0] == 0) && (ARADDR[5:2] <= 8)) ? OKAY : SLVERR;
            end
            // (3) counter (uses register values before the edge)
            clr = 0;
            if (dut.do_write) begin                       // white-box hook: write commit clock
                legal = (m_awaddr[11:6] == 0) && (m_awaddr[1:0] == 0) && (m_awaddr[5:2] <= 8);
                ro    = (m_awaddr[5:2] == 1) || (m_awaddr[5:2] == 4) || (m_awaddr[5:2] == 8);
                clr   = legal && !ro && (m_awaddr[5:2] == 5) && m_wstrb[0] && m_wdata[1];
            end
            if (clr) begin m_cnt = 0; m_pcnt = 0; end
            else if (m_en) begin
                if (m_pcnt >= m_presc) begin m_pcnt = 0; m_cnt = m_cnt + 1; end
                else m_pcnt = m_pcnt + 1;
            end
            // (4) the committed write updates the model registers
            if (dut.do_write) begin
                exp_bresp = (legal && !ro) ? OKAY : SLVERR;
                mk = {{8{m_wstrb[3]}}, {8{m_wstrb[2]}}, {8{m_wstrb[1]}}, {8{m_wstrb[0]}}};
                if (legal && !ro) case (m_awaddr[5:2])
                    0: m_gpio_out = (m_wdata & mk) | (m_gpio_out & ~mk);
                    2: m_seg_data = (m_wdata & mk) | (m_seg_data & ~mk);
                    3: m_seg_ctrl = ((m_wdata & mk) | (m_seg_ctrl & ~mk)) & 32'hFF;
                    5: if (m_wstrb[0]) m_en = m_wdata[0];
                    6: m_presc    = (m_wdata & mk) | (m_presc & ~mk);
                    7: m_scratch  = (m_wdata & mk) | (m_scratch & ~mk);
                    default: ;
                endcase
            end
            s2 = s1;  s1 = gpio_in;
        end
    end

    // ============================ coverage ===================================
    integer cv_aw_first = 0, cv_w_first = 0, cv_same = 0, cv_bstall = 0, cv_rstall = 0;
    integer cv_wr_err = 0, cv_rd_err = 0, cv_rw_same = 0, cv_reg_w [0:8], cv_reg_r [0:8], k, holes;
    initial for (k = 0; k < 9; k = k + 1) begin cv_reg_w[k] = 0; cv_reg_r[k] = 0; end
    always @(posedge ACLK) if (ARESETn) begin
        if (AWVALID && AWREADY && !(WVALID && WREADY) && !dut.w_full)  cv_aw_first = cv_aw_first + 1;
        if (WVALID && WREADY && !(AWVALID && AWREADY) && !dut.aw_full) cv_w_first  = cv_w_first + 1;
        if (AWVALID && AWREADY && WVALID && WREADY) cv_same = cv_same + 1;
        if (BVALID && !BREADY) cv_bstall = cv_bstall + 1;
        if (RVALID && !RREADY) cv_rstall = cv_rstall + 1;
        if (BVALID && BREADY && BRESP == SLVERR) cv_wr_err = cv_wr_err + 1;
        if (RVALID && RREADY && RRESP == SLVERR) cv_rd_err = cv_rd_err + 1;
        if (dut.do_write && ARVALID && ARREADY) cv_rw_same = cv_rw_same + 1;
        if (BVALID && BREADY && BRESP == OKAY) cv_reg_w[m_awaddr[5:2]] = cv_reg_w[m_awaddr[5:2]] + 1;
        if (ARVALID && ARREADY && ARADDR[11:6] == 0 && ARADDR[1:0] == 0 && ARADDR[5:2] <= 8)
            cv_reg_r[ARADDR[5:2]] = cv_reg_r[ARADDR[5:2]] + 1;
    end

    // ============================ stimulus ===================================
    integer seed, i, j;  reg [1:0] wr_resp, rd_resp;  reg [31:0] rd_data;
    reg wdone = 0, rdone = 0;

    function [11:0] rand_addr(input integer dummy);
        integer p;
        begin
            p = {$random(seed)} % 100;
            if (p < 85)      rand_addr = ({$random(seed)} % 9) << 2;         // registers
            else if (p < 93) rand_addr = 12'h024 + (({$random(seed)} % 900) << 2);
            else             rand_addr = (({$random(seed)} % 9) << 2) | ({$random(seed)} % 3 + 1);
        end
    endfunction

    initial seed = `SEED;
    initial begin                                        // waveform: first 20 us
        $dumpfile("step5.vcd");  $dumpvars(0, tb_step5_axil_random);
        #20000 $dumpoff;
    end
    initial begin                                        // asynchronous pin activity
        #100; forever begin #(30 + {$random(seed)} % 500); gpio_in = $random(seed); end
    end

    initial begin
        $display("=== axil_slave random test: SEED=%0d, %0d writes + %0d reads, max delay %0d ===",
                 `SEED, `NTRANS, `NTRANS, `MAXD);
        #35 ARESETn = 1'b1;
        fork
            begin : writer
                for (i = 0; i < `NTRANS; i = i + 1) begin : one_w
                    reg [11:0] a; reg [31:0] dd; reg [3:0] st;
                    a  = rand_addr(0);
                    dd = $random(seed);
                    if (a == CNT_PRESC) dd = {$random(seed)} % 4;              // keep the counter moving
                    if (a == CNT_CTRL)  dd = ({$random(seed)} % 8 != 0) ? 1 : 3; // mostly enabled
                    st = ({$random(seed)} % 4 == 0) ? $random(seed) : 4'hF;
                    axi_write(a, dd, st, {$random(seed)} % (`MAXD + 1), {$random(seed)} % (`MAXD + 1),
                              {$random(seed)} % (`MAXD + 1), wr_resp);
                end
                wdone = 1;
            end
            begin : reader
                for (j = 0; j < `NTRANS; j = j + 1)
                    axi_read(rand_addr(0), {$random(seed)} % (`MAXD + 1), {$random(seed)} % (`MAXD + 1),
                             rd_data, rd_resp);
                rdone = 1;
            end
        join
        repeat (5) @(posedge ACLK);

        $display("--- coverage ------------------------------------------------");
        $display(" AW first %0d | W first %0d | same clock %0d | B stalls %0d | R stalls %0d",
                 cv_aw_first, cv_w_first, cv_same, cv_bstall, cv_rstall);
        $display(" SLVERR writes %0d | SLVERR reads %0d | write+read same clock %0d",
                 cv_wr_err, cv_rd_err, cv_rw_same);
        $write(" OKAY writes per reg:"); for (k = 0; k < 9; k = k + 1) $write(" %0d", cv_reg_w[k]); $write("\n");
        $write(" reads per reg      :"); for (k = 0; k < 9; k = k + 1) $write(" %0d", cv_reg_r[k]); $write("\n");
        holes = 0;
        if (!cv_aw_first || !cv_w_first || !cv_same || !cv_bstall || !cv_rstall) holes = holes + 1;
        if (!cv_wr_err || !cv_rd_err || !cv_rw_same) holes = holes + 1;
        for (k = 0; k < 9; k = k + 1) begin
            if (cv_reg_r[k] == 0) holes = holes + 1;
            if (cv_reg_w[k] == 0 && k != 1 && k != 4 && k != 8) holes = holes + 1;
        end
        $display(" coverage holes: %0d", holes);
        $display("--- %0d write responses, %0d read responses checked, %0d mismatches", n_w, n_r, errors);
        if (errors == 0 && holes == 0) $display("*** STEP 5 PASS ***");
        else                           $display("*** STEP 5 FAIL ***");
        $finish;
    end
    initial begin #50000000; $display("TIMEOUT - the bus is stuck (deadlock?)  *** FAIL ***"); $finish; end
endmodule
