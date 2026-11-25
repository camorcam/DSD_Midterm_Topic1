// ============================================================================
// axil_sva.sv  -  AXI4-Lite protocol checker (SystemVerilog Assertions)
// Passive module: connect it to any AXI4-Lite interface (or bind it).
// ============================================================================
module axil_sva (
    input logic        ACLK, ARESETn,
    input logic        AWVALID, AWREADY, input logic [11:0] AWADDR,
    input logic        WVALID,  WREADY,  input logic [31:0] WDATA, input logic [3:0] WSTRB,
    input logic        BVALID,  BREADY,  input logic [1:0]  BRESP,
    input logic        ARVALID, ARREADY, input logic [11:0] ARADDR,
    input logic        RVALID,  RREADY,  input logic [31:0] RDATA, input logic [1:0] RRESP
);
    default clocking cb @(posedge ACLK); endclocking
    default disable iff (!ARESETn);

    // ---- handshake rule on all five channels: once VALID, stay VALID with stable
    //      payload until READY (the source may not "take back" a transfer)
    a_aw : assert property (AWVALID && !AWREADY |=> AWVALID && $stable(AWADDR))
        else $error("AXI: AWVALID dropped or AWADDR changed before AWREADY");
    a_w  : assert property (WVALID && !WREADY |=> WVALID && $stable(WDATA) && $stable(WSTRB))
        else $error("AXI: WVALID dropped or WDATA/WSTRB changed before WREADY");
    a_b  : assert property (BVALID && !BREADY |=> BVALID && $stable(BRESP))
        else $error("AXI: BVALID dropped or BRESP changed before BREADY");
    a_ar : assert property (ARVALID && !ARREADY |=> ARVALID && $stable(ARADDR))
        else $error("AXI: ARVALID dropped or ARADDR changed before ARREADY");
    a_r  : assert property (RVALID && !RREADY |=> RVALID && $stable(RDATA) && $stable(RRESP))
        else $error("AXI: RVALID dropped or RDATA/RRESP changed before RREADY");

    // ---- no X / Z on control signals after reset
    a_no_x : assert property (!$isunknown({AWVALID, WVALID, BVALID, ARVALID, RVALID,
                                           AWREADY, WREADY, BREADY, ARREADY, RREADY}))
        else $error("AXI: X/Z on a VALID or READY signal");
    a_resp_legal : assert property (BVALID |-> BRESP inside {2'b00, 2'b10})
        else $error("AXI: this slave only returns OKAY or SLVERR");

    // ---- ordering: a response needs a request (count handshakes)
    int unsigned n_aw, n_w, n_b, n_ar, n_r;
    always_ff @(posedge ACLK or negedge ARESETn)
        if (!ARESETn) begin n_aw <= 0; n_w <= 0; n_b <= 0; n_ar <= 0; n_r <= 0; end
        else begin
            if (AWVALID && AWREADY) n_aw <= n_aw + 1;
            if (WVALID  && WREADY ) n_w  <= n_w  + 1;
            if (BVALID  && BREADY ) n_b  <= n_b  + 1;
            if (ARVALID && ARREADY) n_ar <= n_ar + 1;
            if (RVALID  && RREADY ) n_r  <= n_r  + 1;
        end
    a_b_after_aw_w : assert property (BVALID |-> (n_aw > n_b) && (n_w > n_b))
        else $error("AXI: BVALID before both AW and W were accepted");
    a_r_after_ar   : assert property (RVALID |-> (n_ar > n_r))
        else $error("AXI: RVALID without an accepted read address");

    // ---- coverage of the interesting orderings
    c_aw_first  : cover property (AWVALID && AWREADY && !WVALID);
    c_w_first   : cover property (WVALID && WREADY && !AWVALID);
    c_same_clk  : cover property (AWVALID && AWREADY && WVALID && WREADY);
    c_b_stall   : cover property (BVALID && !BREADY);
    c_r_stall   : cover property (RVALID && !RREADY);
    c_slverr    : cover property (RVALID && RREADY && RRESP == 2'b10);
endmodule
