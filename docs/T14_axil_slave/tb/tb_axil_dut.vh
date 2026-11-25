// common DUT instance + signals for the T14 testbenches (`include inside the tb module)
reg ACLK = 1'b0;  always #10 ACLK = ~ACLK;          // 50 MHz
reg ARESETn = 1'b0;
reg        AWVALID = 0, WVALID = 0, BREADY = 0, ARVALID = 0, RREADY = 0;
reg [11:0] AWADDR = 0, ARADDR = 0;
reg [2:0]  AWPROT = 0, ARPROT = 0;
reg [31:0] WDATA = 0;
reg [3:0]  WSTRB = 0;
wire       AWREADY, WREADY, BVALID, ARREADY, RVALID;
wire [1:0] BRESP, RRESP;
wire [31:0] RDATA;
reg  [15:0] gpio_in = 16'h0;
wire [31:0] gpio_out, seg_data;
wire [7:0]  seg_en;

axil_slave #(.NIN(16)) dut (
    .ACLK(ACLK), .ARESETn(ARESETn),
    .AWVALID(AWVALID), .AWREADY(AWREADY), .AWADDR(AWADDR), .AWPROT(AWPROT),
    .WVALID(WVALID), .WREADY(WREADY), .WDATA(WDATA), .WSTRB(WSTRB),
    .BVALID(BVALID), .BREADY(BREADY), .BRESP(BRESP),
    .ARVALID(ARVALID), .ARREADY(ARREADY), .ARADDR(ARADDR), .ARPROT(ARPROT),
    .RVALID(RVALID), .RREADY(RREADY), .RDATA(RDATA), .RRESP(RRESP),
    .gpio_in(gpio_in), .gpio_out(gpio_out), .seg_data(seg_data), .seg_en(seg_en));

localparam [1:0] OKAY = 2'b00, SLVERR = 2'b10;
localparam [11:0] GPIO_OUT = 12'h000, GPIO_IN = 12'h004, SEG_DATA = 12'h008, SEG_CTRL = 12'h00C,
                  CNT_VALUE = 12'h010, CNT_CTRL = 12'h014, CNT_PRESC = 12'h018, SCRATCH = 12'h01C,
                  ID_REG = 12'h020;
