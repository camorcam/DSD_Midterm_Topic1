// ============================================================================
// apb_sva.sv  -  APB4 protocol checker (SystemVerilog Assertions)
// Passive: only inputs. Bind it to any APB slave or instantiate it in the tb.
// Run with Verilator (--assert) or Questa / ModelSim-Intel (SV).
// ============================================================================
module apb_sva (
    input logic        PCLK, PRESETn,
    input logic        PSEL, PENABLE, PWRITE, PREADY, PSLVERR,
    input logic [11:0] PADDR,
    input logic [31:0] PWDATA, PRDATA,
    input logic [3:0]  PSTRB
);
    default clocking cb @(posedge PCLK); endclocking
    default disable iff (!PRESETn);

    // ---- master rules ------------------------------------------------------
    // R1  PENABLE is only asserted together with PSEL
    a_en_needs_sel : assert property (PENABLE |-> PSEL)
        else $error("APB R1: PENABLE without PSEL");
    // R2  SETUP lasts exactly one clock, then ACCESS
    a_setup_access : assert property (PSEL && !PENABLE |=> PSEL && PENABLE)
        else $error("APB R2: SETUP not followed by ACCESS");
    // R3  address, control and write data stay stable while the slave waits
    a_stable       : assert property (PSEL && PENABLE && !PREADY |=>
                                      $stable(PADDR) && $stable(PWRITE) && $stable(PWDATA)
                                      && $stable(PSTRB) && PSEL && PENABLE)
        else $error("APB R3: signals changed during a wait state");
    // R4  after the last ACCESS clock PENABLE is removed
    a_en_drop      : assert property (PSEL && PENABLE && PREADY |=> !PENABLE)
        else $error("APB R4: PENABLE not removed after transfer");
    // R5  read transfers drive PSTRB = 0
    a_rd_strb      : assert property (PSEL && !PWRITE |-> PSTRB == 4'b0000)
        else $error("APB R5: PSTRB not zero on a read");
    // ---- slave rules -------------------------------------------------------
    // R6  PREADY / PSLVERR / PRDATA are never X during ACCESS
    a_no_x         : assert property (PSEL && PENABLE |-> !$isunknown({PREADY, PSLVERR}))
        else $error("APB R6: X on PREADY/PSLVERR");
    a_no_x_rdata   : assert property (PSEL && PENABLE && PREADY && !PWRITE |-> !$isunknown(PRDATA))
        else $error("APB R6: X on PRDATA");
    // R7  this slave drives PSLVERR only in the completing ACCESS clock
    a_err_window   : assert property (PSLVERR |-> PSEL && PENABLE && PREADY)
        else $error("APB R7: PSLVERR outside the transfer");

    // ---- coverage of interesting protocol situations ----------------------
    c_wait_state   : cover property (PSEL && PENABLE && !PREADY);
    c_error        : cover property (PSEL && PENABLE && PREADY && PSLVERR);
    c_back_to_back : cover property (PSEL && PENABLE && PREADY ##1 PSEL && !PENABLE);
endmodule
