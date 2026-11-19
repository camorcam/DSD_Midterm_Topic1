`timescale 1ns/1ps
`default_nettype none

module tb_apb_master_demo;
    reg PCLK = 1'b0;
    always #5 PCLK = ~PCLK;
    reg PRESETn = 1'b1;
    wire [7:0] PADDR;
    wire PSEL, PENABLE, PWRITE;
    wire [31:0] PWDATA;
    wire [3:0] PSTRB;
    wire [2:0] PPROT;
    reg [31:0] PRDATA;
    reg PREADY = 1'b1;
    reg PSLVERR = 1'b0;
    reg irq = 1'b0;
    wire [31:0] captured_data_in, captured_int_status;
    wire demo_done, demo_error;
    wire [4:0] debug_state;
    reg [7:0] seen_addr [0:7];
    reg seen_write [0:7];
    reg [31:0] seen_data [0:7];
    integer transfer_count = 0;
    integer checks = 0;
    integer i;

    apb_master_demo dut (
        .PCLK(PCLK), .PRESETn(PRESETn), .PADDR(PADDR), .PSEL(PSEL),
        .PENABLE(PENABLE), .PWRITE(PWRITE), .PWDATA(PWDATA),
        .PSTRB(PSTRB), .PPROT(PPROT), .PRDATA(PRDATA),
        .PREADY(PREADY), .PSLVERR(PSLVERR), .irq(irq),
        .captured_data_in(captured_data_in),
        .captured_int_status(captured_int_status), .demo_done(demo_done),
        .demo_error(demo_error), .debug_state(debug_state)
    );

    apb_protocol_checker u_protocol_checker (
        .PCLK(PCLK), .PRESETn(PRESETn), .PADDR(PADDR), .PSEL(PSEL),
        .PENABLE(PENABLE), .PWRITE(PWRITE), .PWDATA(PWDATA),
        .PSTRB(PSTRB), .PPROT(PPROT)
    );

    always @* begin
        case (PADDR)
            8'h04: PRDATA = 32'hcafe_1200;
            8'h10: PRDATA = 32'h0000_0100;
            default: PRDATA = 32'b0;
        endcase
    end

    always @(posedge PCLK) begin
        if (PRESETn && PSEL && PENABLE && PREADY) begin
            seen_addr[transfer_count] <= PADDR;
            seen_write[transfer_count] <= PWRITE;
            seen_data[transfer_count] <= PWDATA;
            if (transfer_count == 5)
                irq <= 1'b1;
            if (transfer_count == 7)
                irq <= 1'b0;
            transfer_count <= transfer_count + 1;
        end
    end

    task automatic check32(input string label_text,
                           input logic [31:0] actual,
                           input logic [31:0] wanted);
        checks = checks + 1;
        if (actual !== wanted)
            $fatal(1, "%s: got %08h, expected %08h at %0t",
                   label_text, actual, wanted, $time);
    endtask

    initial begin
        #10000;
        $fatal(1, "Simulation watchdog expired");
    end

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("tb_apb_master_demo.vcd");
            $dumpvars(0, tb_apb_master_demo);
        end
        #2 PRESETn = 1'b0;
        #3;
        @(negedge PCLK);
        PRESETn = 1'b1;
        wait (demo_done);
        #1;

        check32("transfer count", transfer_count, 8);
        check32("captured DATA_IN", captured_data_in, 32'hcafe_1200);
        check32("captured INT_STATUS", captured_int_status, 32'h0000_0100);
        check32("demo error", {31'b0, demo_error}, 0);
        check32("final state", {27'b0, debug_state}, 17);

        check32("direction address", seen_addr[0], 8'h08);
        check32("direction data", seen_data[0], 32'h0000_00ff);
        check32("output 55 address", seen_addr[1], 8'h00);
        check32("output 55 data", seen_data[1], 32'h0000_0055);
        check32("output aa address", seen_addr[2], 8'h00);
        check32("output aa data", seen_data[2], 32'h0000_00aa);
        check32("DATA_IN address", seen_addr[3], 8'h04);
        check32("DATA_IN read", {31'b0, seen_write[3]}, 0);
        check32("rise address", seen_addr[4], 8'h14);
        check32("enable address", seen_addr[5], 8'h0c);
        check32("status address", seen_addr[6], 8'h10);
        check32("status read", {31'b0, seen_write[6]}, 0);
        check32("clear address", seen_addr[7], 8'h10);
        check32("clear write", {31'b0, seen_write[7]}, 1);
        check32("clear data", seen_data[7], 32'h0000_0100);
        check32("full strobes", {28'b0, PSTRB}, 4'hf);
        check32("unprivileged PPROT", {29'b0, PPROT}, 0);
        check32("protocol checks executed",
                {31'b0, (u_protocol_checker.checks > 0)}, 1);
        for (i = 0; i < 8; i = i + 1)
            check32("recorded transfer", {31'b0, (seen_addr[i] !== 8'hxx)}, 1);

        $display("PASS: tb_apb_master_demo (%0d checks)", checks);
        $finish;
    end
endmodule

`default_nettype wire
