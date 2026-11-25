// ============================================================================
// tb_step5_apb_gpio_random.v  -  Step 5: constrained-random self-checking test
//   * random APB transfers (legal + illegal addresses, random PSTRB, idle gaps)
//   * asynchronous random activity on the GPIO pins
//   * passive monitor + reference model (scoreboard) checks EVERY read
//   * functional coverage counters, SVA protocol checker when compiled with SVA
//   Icarus   : ./run_icarus.sh 5 [-DWS=2] [-DSEED=7]
//   (Verilator 5) ./run_verilator.sh 5 [-DWS=2]          (adds apb_sva.sv)
// ============================================================================
`timescale 1ns/1ps
`ifndef WS
 `define WS 1
`endif
`ifndef SEED
 `define SEED 1
`endif
`ifndef NTRANS
 `define NTRANS 4000
`endif
module tb_step5_apb_gpio_random;
    localparam N = 16;
    localparam [31:0] MASK = 32'h0000_FFFF, ID = 32'h4750_4901;

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

`ifdef SVA
    apb_sva u_sva (.PCLK(PCLK), .PRESETn(PRESETn), .PSEL(PSEL), .PENABLE(PENABLE),
        .PWRITE(PWRITE), .PREADY(PREADY), .PSLVERR(PSLVERR), .PADDR(PADDR),
        .PWDATA(PWDATA), .PRDATA(PRDATA), .PSTRB(PSTRB));
`endif

    `include "apb_bfm.vh"

    // ======================= reference model (scoreboard) =====================
    reg [31:0] m_reg [0:7];                     // model of the 8 registers
    reg [N-1:0] s1, s2, s3;                     // model of synchronizer + edge flop
    integer errors = 0, n_rd = 0, n_wr = 0, n_err = 0, b;
    reg [31:0] exp_rd, smask;
    reg        exp_err, legal, ro;
    reg [N-1:0] ev, clr;

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            for (b = 0; b < 8; b = b + 1) m_reg[b] = 32'h0;
            m_reg[7] = ID;  s1 = 0; s2 = 0; s3 = 0;
        end else begin
            // ---- events seen this clock (use values BEFORE the edge) ----
            ev  = (s2 & ~s3 & m_reg[4][N-1:0]) | (~s2 & s3 & m_reg[5][N-1:0]);
            clr = 0;
            // ---- transfer completing at this edge? ----
            if (PSEL && PENABLE && PREADY) begin
                legal   = (PADDR[11:5] == 0) && (PADDR[1:0] == 0);
                ro      = (PADDR[4:2] == 1) || (PADDR[4:2] == 7);
                exp_err = !legal || (PWRITE && ro);
                if (PSLVERR !== exp_err) begin
                    errors = errors + 1;
                    $display("[%0t] SCOREBOARD FAIL PSLVERR=%b exp=%b addr=%h wr=%b", $time, PSLVERR, exp_err, PADDR, PWRITE);
                end
                if (exp_err) n_err = n_err + 1;
                if (!PWRITE) begin
                    n_rd   = n_rd + 1;
                    exp_rd = !legal ? 32'h0 : (PADDR[4:2] == 1) ? {16'h0, s2} : m_reg[PADDR[4:2]];
                    if (PRDATA !== exp_rd) begin
                        errors = errors + 1;
                        $display("[%0t] SCOREBOARD FAIL read @%h = %h exp %h", $time, PADDR, PRDATA, exp_rd);
                    end
                end else if (!exp_err) begin
                    n_wr  = n_wr + 1;
                    smask = {{8{PSTRB[3]}}, {8{PSTRB[2]}}, {8{PSTRB[1]}}, {8{PSTRB[0]}}};
                    if (PADDR[4:2] == 6) clr = PWDATA[N-1:0] & smask[N-1:0];   // W1C
                    else m_reg[PADDR[4:2]] = ((m_reg[PADDR[4:2]] & ~smask) | (PWDATA & smask)) & MASK;
                end
            end
            m_reg[6] = {16'h0, (m_reg[6][N-1:0] & ~clr) | ev};
            s3 = s2;  s2 = s1;  s1 = gpio_in;
        end
    end

    // ============================ functional coverage ==========================
    integer cov_rd [0:7], cov_wr [0:7], cov_strb [0:15];
    integer cov_err_rd = 0, cov_err_wr = 0, cov_irq = 0, cov_w1c_hit = 0, cov_wait = 0, k;
    initial for (k = 0; k < 16; k = k + 1) begin cov_strb[k] = 0; if (k < 8) begin cov_rd[k] = 0; cov_wr[k] = 0; end end
    always @(posedge PCLK) if (PRESETn) begin
        if (PSEL && PENABLE && !PREADY) cov_wait = cov_wait + 1;
        if (PSEL && PENABLE && PREADY) begin
            if (PSLVERR) begin if (PWRITE) cov_err_wr = cov_err_wr + 1; else cov_err_rd = cov_err_rd + 1; end
            else if (PWRITE) begin
                cov_wr[PADDR[4:2]] = cov_wr[PADDR[4:2]] + 1;
                cov_strb[PSTRB]    = cov_strb[PSTRB] + 1;
                if (PADDR[4:2] == 6 && |(PWDATA[N-1:0] & dut.int_status)) cov_w1c_hit = cov_w1c_hit + 1;
            end else cov_rd[PADDR[4:2]] = cov_rd[PADDR[4:2]] + 1;
        end
    end
    always @(posedge irq) cov_irq = cov_irq + 1;

    // ============================== stimulus ==================================
    integer i, seed, r, holes;
    reg [11:0] a;  reg [31:0] d, rdat;  reg [3:0] s;  reg e;

    // pins change asynchronously in a separate thread
    initial seed = `SEED;
    initial begin                                           // waveform: first 30 us only
        $dumpfile("step5.vcd");  $dumpvars(0, tb_step5_apb_gpio_random);
        #30000 $dumpoff;
    end
    initial begin
        #100;
        forever begin
            #(15 + {$random(seed)} % 400);
            gpio_in = gpio_in ^ ($random(seed) & 16'hFFFF);
        end
    end

    initial begin
        $display("=== apb_gpio random test: WAIT_STATES=%0d SEED=%0d transfers=%0d ===", `WS, `SEED, `NTRANS);
        bfm_max_idle = 2;
        #35 PRESETn = 1'b1;
        for (i = 0; i < `NTRANS; i = i + 1) begin
            r = {$random(seed)} % 100;
            // address: 85 % legal registers, 15 % illegal (unmapped or unaligned)
            if (r < 85) a = ({$random(seed)} % 8) << 2;
            else if (r < 93) a = 12'h020 + (({$random(seed)} % 1000) << 2);
            else a = ({$random(seed)} % 32) | 12'h001;
            d = $random(seed);
            s = ({$random(seed)} % 4 == 0) ? $random(seed) : 4'hF;         // 25 % partial strobes
            if (a == 12'h018 && ({$random(seed)} % 2)) d = dut.int_status;   // often clear what is pending
            if ({$random(seed)} % 2) apb_write(a, d, s, e); else apb_read(a, rdat, e);
        end
        repeat (5) @(posedge PCLK);

        // ---- coverage report ----
        holes = 0;
        $display("--- coverage --------------------------------------------");
        $display(" reg :  0    1    2    3    4    5    6    7");
        $write  (" rd  :"); for (k = 0; k < 8; k = k + 1) $write("%5d", cov_rd[k]); $write("\n");
        $write  (" wr  :"); for (k = 0; k < 8; k = k + 1) $write("%5d", cov_wr[k]); $write("\n");
        $write  (" strb:"); for (k = 0; k < 16; k = k + 1) $write("%4d", cov_strb[k]); $write("\n");
        $display(" err read %0d, err write %0d, W1C that cleared a bit %0d, irq rises %0d, wait cycles %0d",
                 cov_err_rd, cov_err_wr, cov_w1c_hit, cov_irq, cov_wait);
        for (k = 0; k < 8; k = k + 1) begin
            if (cov_rd[k] == 0) holes = holes + 1;
            if (cov_wr[k] == 0 && k != 1 && k != 7) holes = holes + 1;
        end
        for (k = 0; k < 16; k = k + 1) if (cov_strb[k] == 0) holes = holes + 1;
        if (cov_err_rd == 0 || cov_err_wr == 0 || cov_w1c_hit == 0 || cov_irq == 0) holes = holes + 1;
        if (`WS > 0 && cov_wait == 0) holes = holes + 1;
        $display(" coverage holes: %0d", holes);
        $display("--- %0d reads, %0d writes, %0d error responses checked, %0d mismatches",
                 n_rd, n_wr, n_err, errors);
        if (errors == 0 && holes == 0) $display("*** STEP 5 PASS ***");
        else                           $display("*** STEP 5 FAIL ***");
        $finish;
    end
    initial begin #5000000; $display("TIMEOUT - the design never reached the end of the test (deadlock?)  *** FAIL ***"); $finish; end
endmodule
