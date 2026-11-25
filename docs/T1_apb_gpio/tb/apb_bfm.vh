// ============================================================================
// apb_bfm.vh  -  APB4 master Bus Functional Model (tasks), `include inside a tb
// The tb must declare: PCLK, PSEL, PENABLE, PWRITE, PADDR[11:0], PWDATA[31:0],
// PSTRB[3:0], PRDATA[31:0], PREADY, PSLVERR (all master outputs as reg).
// Signals change 1 ns after the rising edge (no race with the DUT).
// ============================================================================
integer bfm_max_idle = 0;          // random idle clocks between transfers (0 = back-to-back)

task apb_idle;
    integer n;
    begin
        n = (bfm_max_idle == 0) ? 0 : ({$random} % (bfm_max_idle + 1));
        repeat (n) @(posedge PCLK);
    end
endtask

task apb_write(input [11:0] addr, input [31:0] data, input [3:0] strb, output err);
    begin
        apb_idle;
        @(posedge PCLK); #1;                                  // SETUP phase
        PSEL = 1'b1; PENABLE = 1'b0; PWRITE = 1'b1;
        PADDR = addr; PWDATA = data; PSTRB = strb;
        @(posedge PCLK); #1;                                  // ACCESS phase
        PENABLE = 1'b1;
`ifdef BFM_BUG                                                // exercise: break rule R3
        @(posedge PCLK); #1 if (!PREADY) PWDATA = ~PWDATA;
        while (!PREADY) @(posedge PCLK);
`else
        @(posedge PCLK); while (!PREADY) @(posedge PCLK);     // wait states
`endif
        err = PSLVERR;                                        // sampled at the completing edge
        #1; PSEL = 1'b0; PENABLE = 1'b0; PWRITE = 1'b0; PSTRB = 4'h0;
    end
endtask

task apb_read(input [11:0] addr, output [31:0] data, output err);
    begin
        apb_idle;
        @(posedge PCLK); #1;
        PSEL = 1'b1; PENABLE = 1'b0; PWRITE = 1'b0;
        PADDR = addr; PSTRB = 4'h0;                           // PSTRB must be 0 for reads
        @(posedge PCLK); #1;
        PENABLE = 1'b1;
        @(posedge PCLK); while (!PREADY) @(posedge PCLK);
        data = PRDATA; err = PSLVERR;
        #1; PSEL = 1'b0; PENABLE = 1'b0;
    end
endtask
