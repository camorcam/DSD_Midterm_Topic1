// ============================================================================
// apb_master.v  -  APB4 master: turns one command into one APB transfer
// T1 APB GPIO  |  Step 6 : system
//   IDLE   : cmd_ready = 1, wait for cmd_valid
//   SETUP  : PSEL = 1, PENABLE = 0  (exactly one clock)
//   ACCESS : PSEL = 1, PENABLE = 1  (until PREADY = 1)
//   then rsp_valid = 1 for one clock with rsp_rdata / rsp_err
// ============================================================================
module apb_master (
    input  wire        clk,
    input  wire        rst_n,
    // command side (from a controller / CPU / sequencer)
    input  wire        cmd_valid,
    output wire        cmd_ready,
    input  wire        cmd_write,
    input  wire [11:0] cmd_addr,
    input  wire [31:0] cmd_wdata,
    input  wire [3:0]  cmd_strb,
    output reg         rsp_valid,
    output reg  [31:0] rsp_rdata,
    output reg         rsp_err,
    // APB master port
    output reg         PSEL,
    output reg         PENABLE,
    output reg         PWRITE,
    output reg  [11:0] PADDR,
    output reg  [31:0] PWDATA,
    output reg  [3:0]  PSTRB,
    output wire [2:0]  PPROT,
    input  wire [31:0] PRDATA,
    input  wire        PREADY,
    input  wire        PSLVERR
);
    localparam IDLE = 2'd0, SETUP = 2'd1, ACCESS = 2'd2;
    reg [1:0] state;

    assign cmd_ready = (state == IDLE);
    assign PPROT     = 3'b000;                    // normal, secure, data

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;  PSEL <= 1'b0;  PENABLE <= 1'b0;  PWRITE <= 1'b0;
            PADDR <= 12'h0; PWDATA <= 32'h0; PSTRB <= 4'h0;
            rsp_valid <= 1'b0; rsp_rdata <= 32'h0; rsp_err <= 1'b0;
        end else begin
            rsp_valid <= 1'b0;
            case (state)
                IDLE: if (cmd_valid) begin
                    PSEL    <= 1'b1;
                    PENABLE <= 1'b0;
                    PWRITE  <= cmd_write;
                    PADDR   <= cmd_addr;
                    PWDATA  <= cmd_wdata;
                    PSTRB   <= cmd_write ? cmd_strb : 4'b0;
                    state   <= SETUP;
                end
                SETUP: begin
                    PENABLE <= 1'b1;
                    state   <= ACCESS;
                end
                ACCESS: if (PREADY) begin
                    rsp_valid <= 1'b1;
                    rsp_rdata <= PRDATA;
                    rsp_err   <= PSLVERR;
                    PSEL      <= 1'b0;
                    PENABLE   <= 1'b0;
                    state     <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
