// ============================================================================
// axil_bfm.vh  -  AXI4-Lite master Bus Functional Model, `include inside a tb
// The tb declares ACLK and all master outputs as reg:
//   AWVALID AWADDR AWPROT WVALID WDATA WSTRB BREADY ARVALID ARADDR ARPROT RREADY
// Every channel has its own delay (clocks) before VALID / READY is raised.
// The AW, W and B threads run in parallel (fork/join), so the address may
// arrive before, together with, or after the data.
// ============================================================================
task axi_write(input [11:0] addr, input [31:0] data, input [3:0] strb,
               input integer d_aw, input integer d_w, input integer d_b, output [1:0] resp);
    begin
        fork
            begin : aw_thread
                repeat (d_aw) @(posedge ACLK);
                #1 AWVALID = 1'b1;  AWADDR = addr;  AWPROT = 3'b000;
                @(posedge ACLK);  while (!AWREADY) @(posedge ACLK);
                #1 AWVALID = 1'b0;  AWADDR = $random;      // junk: the slave must not use it
            end
            begin : w_thread
                repeat (d_w) @(posedge ACLK);
                #1 WVALID = 1'b1;  WDATA = data;  WSTRB = strb;
                @(posedge ACLK);  while (!WREADY) @(posedge ACLK);
                #1 WVALID = 1'b0;  WDATA = $random;  WSTRB = $random;
            end
            begin : b_thread
                repeat (d_b) @(posedge ACLK);
                #1 BREADY = 1'b1;                          // may be high before BVALID
                @(posedge ACLK);  while (!BVALID) @(posedge ACLK);
                resp = BRESP;
                #1 BREADY = 1'b0;
            end
        join
    end
endtask

task axi_read(input [11:0] addr, input integer d_ar, input integer d_r,
              output [31:0] data, output [1:0] resp);
    begin
        fork
            begin : ar_thread
                repeat (d_ar) @(posedge ACLK);
                #1 ARVALID = 1'b1;  ARADDR = addr;  ARPROT = 3'b000;
                @(posedge ACLK);  while (!ARREADY) @(posedge ACLK);
                #1 ARVALID = 1'b0;  ARADDR = $random;
            end
            begin : r_thread
                repeat (d_r) @(posedge ACLK);
                #1 RREADY = 1'b1;
                @(posedge ACLK);  while (!RVALID) @(posedge ACLK);
                data = RDATA;  resp = RRESP;
                #1 RREADY = 1'b0;
            end
        join
    end
endtask

// short forms without delays
task wr(input [11:0] a, input [31:0] d, output [1:0] r);  begin axi_write(a, d, 4'hF, 0, 0, 0, r); end endtask
task rd(input [11:0] a, output [31:0] d, output [1:0] r); begin axi_read(a, 0, 0, d, r);           end endtask
