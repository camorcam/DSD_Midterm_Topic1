// ============================================================================
// axil_demo_seq.v  -  "Software" of the board demo, written as an FSM
// T14 AXI4-Lite  |  Step 6 : system
//     if (rd(ID) != 0x41584C01) id_err = 1;
//     wr(CNT_PRESC, PRESC); wr(CNT_CTRL, 3 /*enable+clear*/); wr(SEG_CTRL, SEG_EN);
//     forever {
//         gin = rd(GPIO_IN);   wr(GPIO_OUT, gin);              // switches -> LEDs
//         if (gin[CLR_BIT]) wr(CNT_CTRL, 3);                   // button clears the counter
//         cnt = rd(CNT_VALUE);
//         wr(SEG_DATA, gin[SEL_BIT] ? gin : cnt);              // what the display shows
//     }
// ============================================================================
module axil_demo_seq #(
    parameter [31:0] PRESC   = 32'd4999999,     // 50 MHz / 5e6 = 10 counts per second
    parameter [31:0] SEG_EN  = 32'h0000_00FF,
    parameter        CLR_BIT = 10,
    parameter        SEL_BIT = 9
) (
    input  wire        clk,
    input  wire        rst_n,
    output reg         cmd_valid,
    output reg         cmd_write,
    output reg  [11:0] cmd_addr,
    output reg  [31:0] cmd_wdata,
    output wire [3:0]  cmd_strb,
    input  wire        rsp_valid,
    input  wire [31:0] rsp_rdata,
    input  wire        rsp_err,
    output reg         id_err,
    output reg         bus_err
);
    localparam S_ID = 4'd0, S_PRESC = 4'd1, S_CTRL = 4'd2, S_SEGEN = 4'd3, S_RDIN = 4'd4,
               S_WROUT = 4'd5, S_CLR = 4'd6, S_RDCNT = 4'd7, S_WRSEG = 4'd8;
    reg [3:0]  state;
    reg        busy;
    reg [31:0] gin, cnt;
    assign cmd_strb = 4'hF;

    reg c_wr; reg [11:0] c_addr; reg [31:0] c_data;
    always @(*) begin
        c_wr = 1'b1; c_addr = 12'h000; c_data = 32'd0;
        case (state)
            S_ID   : begin c_wr = 1'b0; c_addr = 12'h020; end
            S_PRESC: begin c_addr = 12'h018; c_data = PRESC;  end
            S_CTRL : begin c_addr = 12'h014; c_data = 32'd3;  end
            S_SEGEN: begin c_addr = 12'h00C; c_data = SEG_EN; end
            S_RDIN : begin c_wr = 1'b0; c_addr = 12'h004; end
            S_WROUT: begin c_addr = 12'h000; c_data = gin;    end
            S_CLR  : begin c_addr = 12'h014; c_data = 32'd3;  end
            S_RDCNT: begin c_wr = 1'b0; c_addr = 12'h010; end
            S_WRSEG: begin c_addr = 12'h008; c_data = gin[SEL_BIT] ? gin : cnt; end
            default: ;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_ID; busy <= 1'b0; cmd_valid <= 1'b0; cmd_write <= 1'b0;
            cmd_addr <= 12'd0; cmd_wdata <= 32'd0; gin <= 32'd0; cnt <= 32'd0;
            id_err <= 1'b0; bus_err <= 1'b0;
        end else begin
            cmd_valid <= 1'b0;
            if (!busy) begin
                cmd_valid <= 1'b1; cmd_write <= c_wr; cmd_addr <= c_addr; cmd_wdata <= c_data;
                busy <= 1'b1;
            end else if (rsp_valid) begin
                busy <= 1'b0;
                if (rsp_err) bus_err <= 1'b1;
                // TODO 6.3: Follow the program above: use the response, choose the next state.
                //   (replace the placeholder line(s) below with your design)
                state <= state;
            end
        end
    end
endmodule
