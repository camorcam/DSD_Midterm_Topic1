// ============================================================================
// axil_system.v  -  Board-independent system: sequencer -> AXI4-Lite master -> slave
// T14 AXI4-Lite  |  Step 6 : system
//   +---------------+ cmd/rsp +-------------+ AXI4-Lite (5 channels) +------------+
//   | axil_demo_seq |-------->| axil_master |=======================>| axil_slave |--> LEDs, HEX
//   +---------------+<--------+-------------+<=======================+------------+<-- SW, KEY
// ============================================================================
module axil_system #(
    parameter        NIN     = 16,
    parameter [31:0] PRESC   = 32'd4999999,
    parameter [31:0] SEG_EN  = 32'h0000_00FF,
    parameter        CLR_BIT = 10,
    parameter        SEL_BIT = 9
) (
    input  wire           clk,
    input  wire           rst_n,
    input  wire [NIN-1:0] gpio_in,
    output wire [31:0]    gpio_out,
    output wire [31:0]    seg_data,
    output wire [7:0]     seg_en,
    output wire           id_err,
    output wire           bus_err
);
    wire        cmd_valid, cmd_ready, cmd_write, rsp_valid, rsp_err;
    wire [11:0] cmd_addr;  wire [31:0] cmd_wdata, rsp_rdata;  wire [3:0] cmd_strb;
    wire        AWVALID, AWREADY, WVALID, WREADY, BVALID, BREADY, ARVALID, ARREADY, RVALID, RREADY;
    wire [11:0] AWADDR, ARADDR;  wire [2:0] AWPROT, ARPROT;
    wire [31:0] WDATA, RDATA;    wire [3:0] WSTRB;  wire [1:0] BRESP, RRESP;

    axil_demo_seq #(.PRESC(PRESC), .SEG_EN(SEG_EN), .CLR_BIT(CLR_BIT), .SEL_BIT(SEL_BIT)) u_seq (
        .clk(clk), .rst_n(rst_n), .cmd_valid(cmd_valid), .cmd_write(cmd_write), .cmd_addr(cmd_addr),
        .cmd_wdata(cmd_wdata), .cmd_strb(cmd_strb), .rsp_valid(rsp_valid), .rsp_rdata(rsp_rdata),
        .rsp_err(rsp_err), .id_err(id_err), .bus_err(bus_err));

    axil_master u_mst (
        .ACLK(clk), .ARESETn(rst_n),
        .cmd_valid(cmd_valid), .cmd_ready(cmd_ready), .cmd_write(cmd_write), .cmd_addr(cmd_addr),
        .cmd_wdata(cmd_wdata), .cmd_strb(cmd_strb), .rsp_valid(rsp_valid), .rsp_rdata(rsp_rdata), .rsp_err(rsp_err),
        .AWVALID(AWVALID), .AWREADY(AWREADY), .AWADDR(AWADDR), .AWPROT(AWPROT),
        .WVALID(WVALID), .WREADY(WREADY), .WDATA(WDATA), .WSTRB(WSTRB),
        .BVALID(BVALID), .BREADY(BREADY), .BRESP(BRESP),
        .ARVALID(ARVALID), .ARREADY(ARREADY), .ARADDR(ARADDR), .ARPROT(ARPROT),
        .RVALID(RVALID), .RREADY(RREADY), .RDATA(RDATA), .RRESP(RRESP));

    axil_slave #(.NIN(NIN)) u_slv (
        .ACLK(clk), .ARESETn(rst_n),
        .AWVALID(AWVALID), .AWREADY(AWREADY), .AWADDR(AWADDR), .AWPROT(AWPROT),
        .WVALID(WVALID), .WREADY(WREADY), .WDATA(WDATA), .WSTRB(WSTRB),
        .BVALID(BVALID), .BREADY(BREADY), .BRESP(BRESP),
        .ARVALID(ARVALID), .ARREADY(ARREADY), .ARADDR(ARADDR), .ARPROT(ARPROT),
        .RVALID(RVALID), .RREADY(RREADY), .RDATA(RDATA), .RRESP(RRESP),
        .gpio_in(gpio_in), .gpio_out(gpio_out), .seg_data(seg_data), .seg_en(seg_en));

    wire unused = cmd_ready;
endmodule
