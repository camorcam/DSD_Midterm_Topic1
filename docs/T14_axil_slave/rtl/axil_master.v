// ============================================================================
// axil_master.v  -  AXI4-Lite master: one command -> one AXI4-Lite transaction
// T14 AXI4-Lite  |  Step 6 : system
//   write: AWVALID and WVALID are raised together; each one is dropped when
//          its own READY is seen (the slave may accept them in any order);
//          then BREADY = 1 until BVALID.
//   read : ARVALID until ARREADY, then RREADY = 1 until RVALID.
// ============================================================================
module axil_master (
    input  wire        ACLK,
    input  wire        ARESETn,
    // command side
    input  wire        cmd_valid,
    output wire        cmd_ready,
    input  wire        cmd_write,
    input  wire [11:0] cmd_addr,
    input  wire [31:0] cmd_wdata,
    input  wire [3:0]  cmd_strb,
    output reg         rsp_valid,
    output reg  [31:0] rsp_rdata,
    output reg         rsp_err,
    // AXI4-Lite master port
    output reg         AWVALID,  input wire AWREADY, output reg [11:0] AWADDR, output wire [2:0] AWPROT,
    output reg         WVALID,   input wire WREADY,  output reg [31:0] WDATA,  output reg [3:0] WSTRB,
    input  wire        BVALID,   output reg BREADY,  input  wire [1:0] BRESP,
    output reg         ARVALID,  input wire ARREADY, output reg [11:0] ARADDR, output wire [2:0] ARPROT,
    input  wire        RVALID,   output reg RREADY,  input  wire [31:0] RDATA, input wire [1:0] RRESP
);
    localparam IDLE = 2'd0, WRITE = 2'd1, READ = 2'd2;
    reg [1:0] state;
    assign cmd_ready = (state == IDLE);
    assign AWPROT = 3'b000;
    assign ARPROT = 3'b000;

    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            state <= IDLE;  rsp_valid <= 1'b0;  rsp_rdata <= 32'd0;  rsp_err <= 1'b0;
            AWVALID <= 1'b0; AWADDR <= 12'd0; WVALID <= 1'b0; WDATA <= 32'd0; WSTRB <= 4'd0;
            BREADY <= 1'b0;  ARVALID <= 1'b0; ARADDR <= 12'd0; RREADY <= 1'b0;
        end else begin
            rsp_valid <= 1'b0;
            case (state)
                IDLE: if (cmd_valid) begin
                    if (cmd_write) begin
                        AWVALID <= 1'b1;  AWADDR <= cmd_addr;
                        WVALID  <= 1'b1;  WDATA  <= cmd_wdata;  WSTRB <= cmd_strb;
                        BREADY  <= 1'b1;
                        state   <= WRITE;
                    end else begin
                        ARVALID <= 1'b1;  ARADDR <= cmd_addr;
                        RREADY  <= 1'b1;
                        state   <= READ;
                    end
                end
                WRITE: begin
                    // TODO 6.1: Drop AWVALID / WVALID on their own READY; finish when the B handshake happens.
                    //   (replace the placeholder line(s) below with your design)
                    state <= WRITE;
                end
                READ: begin
                    // TODO 6.2: Drop ARVALID on ARREADY; on the R handshake return RDATA / RRESP.
                    //   (replace the placeholder line(s) below with your design)
                    state <= READ;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
