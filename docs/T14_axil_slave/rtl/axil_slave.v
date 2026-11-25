// ============================================================================
// axil_slave.v  -  AMBA AXI4-Lite slave peripheral (GPIO + 7-segment + counter)
// T14 AXI4-Lite  |  Steps 3 and 4
//
//  AW ──►[aw hold]──┐
//                   ├──► do_write ──► periph_regs ──► B (BVALID until BREADY)
//  W  ──►[w  hold]──┘
//  AR ──────────────────► read  ────► periph_regs ──► R (RVALID until RREADY)
//
// * AW and W are accepted independently, in any order, even in the same clock.
// * One write and one read can be in progress at the same time.
// * BRESP / RRESP: 2'b00 = OKAY, 2'b10 = SLVERR.
// ============================================================================
module axil_slave #(
    parameter NIN = 16
) (
    input  wire           ACLK,
    input  wire           ARESETn,
    // write address channel
    input  wire           AWVALID,
    output wire           AWREADY,
    input  wire [11:0]    AWADDR,
    input  wire [2:0]     AWPROT,
    // write data channel
    input  wire           WVALID,
    output wire           WREADY,
    input  wire [31:0]    WDATA,
    input  wire [3:0]     WSTRB,
    // write response channel
    output reg            BVALID,
    input  wire           BREADY,
    output reg  [1:0]     BRESP,
    // read address channel
    input  wire           ARVALID,
    output wire           ARREADY,
    input  wire [11:0]    ARADDR,
    input  wire [2:0]     ARPROT,
    // read data channel
    output reg            RVALID,
    input  wire           RREADY,
    output reg  [31:0]    RDATA,
    output reg  [1:0]     RRESP,
    // peripheral pins
    input  wire [NIN-1:0] gpio_in,
    output wire [31:0]    gpio_out,
    output wire [31:0]    seg_data,
    output wire [7:0]     seg_en
);
    localparam OKAY = 2'b00, SLVERR = 2'b10;

    // =========================== write path (Step 3) ===========================
    reg        aw_full, w_full;                 // holding registers occupied
    reg [11:0] aw_addr_q;
    reg [31:0] w_data_q;
    reg [3:0]  w_strb_q;

    // TODO 3.1: Each channel is ready while its holding register is empty (never wait for the other channel).
    //   (replace the placeholder line(s) below with your design)
    assign AWREADY = 1'b0;
    assign WREADY  = 1'b0;

    // TODO 3.2: Write when address AND data are held and no response is waiting.
    //   (replace the placeholder line(s) below with your design)
    wire do_write = 1'b0;
    wire wr_err;

    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            aw_full <= 1'b0;  w_full <= 1'b0;
            aw_addr_q <= 12'd0;  w_data_q <= 32'd0;  w_strb_q <= 4'd0;
            BVALID <= 1'b0;   BRESP <= OKAY;
        end else begin
            // TODO 3.3: Capture AW and W on their handshakes; on do_write free both and raise BVALID; drop BVALID on BREADY.
            //   (replace the placeholder line(s) below with your design)
            BVALID <= 1'b0;
        end
    end

    // ============================ read path (Step 4) ===========================
    wire [31:0] rd_data;
    wire        rd_err;

    // TODO 4.1: Accept a new read address only when no read data is waiting.
    //   (replace the placeholder line(s) below with your design)
    assign ARREADY = 1'b0;

    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            RVALID <= 1'b0;  RDATA <= 32'd0;  RRESP <= OKAY;
        end else begin
            // TODO 4.2: On the AR handshake register the read data and raise RVALID; drop it on RREADY.
            //   (replace the placeholder line(s) below with your design)
            RVALID <= 1'b0;
        end
    end

    // ============================== register bank ==============================
    periph_regs #(.NIN(NIN)) u_regs (
        .clk(ACLK), .rst_n(ARESETn),
        .wr_en(do_write), .wr_addr(aw_addr_q), .wr_data(w_data_q), .wr_strb(w_strb_q), .wr_err(wr_err),
        .rd_addr(ARADDR), .rd_data(rd_data), .rd_err(rd_err),
        .gpio_in(gpio_in), .gpio_out(gpio_out), .seg_data(seg_data), .seg_en(seg_en));

    wire unused = &{1'b0, AWPROT, ARPROT};
endmodule
