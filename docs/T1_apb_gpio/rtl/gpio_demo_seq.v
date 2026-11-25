// ============================================================================
// gpio_demo_seq.v  -  "Software" for the board demo, written as an FSM
// T1 APB GPIO  |  Step 6 : system
// It plays the role of a CPU running this program:
//     id = rd(ID);  if (id != EXP_ID) id_err = 1;
//     wr(DIR, DIR_VAL); wr(INT_RISE, RISE); wr(INT_FALL, FALL); wr(INT_ENABLE, RISE|FALL);
//     forever {
//         din = rd(DATA_IN);  wr(DATA_OUT, din);         // switches -> LEDs over APB
//         if (irq) { st = rd(INT_STATUS); wr(INT_STATUS, st); irq_count++; }
//     }
// Every rd/wr is one command to apb_master; the FSM waits for rsp_valid.
// ============================================================================
module gpio_demo_seq #(
    parameter [31:0] EXP_ID    = 32'h4750_4901,
    parameter [31:0] DIR_VAL   = 32'hFFFF_FFFF,
    parameter [31:0] RISE_MASK = 32'h0000_0001,
    parameter [31:0] FALL_MASK = 32'h0000_0001
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        irq,
    // command / response interface of apb_master
    output reg         cmd_valid,
    output reg         cmd_write,
    output reg  [11:0] cmd_addr,
    output reg  [31:0] cmd_wdata,
    output wire [3:0]  cmd_strb,
    input  wire        rsp_valid,
    input  wire [31:0] rsp_rdata,
    input  wire        rsp_err,
    // status for the board display
    output reg  [31:0] din_shown,
    output reg  [7:0]  irq_count,
    output reg         id_err,
    output reg         bus_err
);
    localparam S_ID = 4'd0, S_DIR = 4'd1, S_RISE = 4'd2, S_FALL = 4'd3, S_EN = 4'd4,
               S_RDIN = 4'd5, S_WROUT = 4'd6, S_RDST = 4'd7, S_CLR = 4'd8;

    reg [3:0]  state;
    reg        busy;                       // a command is in flight
    reg [31:0] st;                         // last INT_STATUS value
    assign cmd_strb = 4'hF;

    // command issued in each state
    reg        c_wr;  reg [11:0] c_addr;  reg [31:0] c_data;
    always @(*) begin
        c_wr = 1'b0; c_addr = 12'h000; c_data = 32'h0;
        case (state)
            S_ID   : begin c_wr = 1'b0; c_addr = 12'h01C;                         end
            S_DIR  : begin c_wr = 1'b1; c_addr = 12'h008; c_data = DIR_VAL;        end
            S_RISE : begin c_wr = 1'b1; c_addr = 12'h010; c_data = RISE_MASK;      end
            S_FALL : begin c_wr = 1'b1; c_addr = 12'h014; c_data = FALL_MASK;      end
            S_EN   : begin c_wr = 1'b1; c_addr = 12'h00C; c_data = RISE_MASK | FALL_MASK; end
            S_RDIN : begin c_wr = 1'b0; c_addr = 12'h004;                         end
            S_WROUT: begin c_wr = 1'b1; c_addr = 12'h000; c_data = din_shown;      end
            S_RDST : begin c_wr = 1'b0; c_addr = 12'h018;                         end
            S_CLR  : begin c_wr = 1'b1; c_addr = 12'h018; c_data = st;             end
            default: ;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_ID; busy <= 1'b0; cmd_valid <= 1'b0; cmd_write <= 1'b0;
            cmd_addr <= 12'h0; cmd_wdata <= 32'h0; st <= 32'h0;
            din_shown <= 32'h0; irq_count <= 8'h0; id_err <= 1'b0; bus_err <= 1'b0;
        end else begin
            cmd_valid <= 1'b0;
            if (!busy) begin                               // issue the command of this state
                cmd_valid <= 1'b1;  cmd_write <= c_wr;
                cmd_addr  <= c_addr; cmd_wdata <= c_data;
                busy      <= 1'b1;
            end else if (rsp_valid) begin                  // command finished
                busy <= 1'b0;
                if (rsp_err) bus_err <= 1'b1;
                // TODO 6.3: Use the response and choose the next state (see the program above).
                //   (replace the placeholder line(s) below with your design)
                state <= state;
            end
        end
    end
endmodule
