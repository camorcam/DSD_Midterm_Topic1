`timescale 1ns/1ps
`default_nettype none

module tb_apb_slave_ctrl;
    reg PRESETn = 1'b1;
    reg [7:0] PADDR = 8'b0;
    reg PSEL = 1'b0;
    reg PENABLE = 1'b0;
    reg PWRITE = 1'b0;
    reg [31:0] PWDATA = 32'b0;
    reg [3:0] PSTRB = 4'b0;
    reg [2:0] PPROT = 3'b0;
    wire [31:0] PRDATA;
    wire PREADY, PSLVERR;
    reg [31:0] data_out = 32'h1020_3040;
    reg [31:0] data_in = 32'h5060_7080;
    reg [31:0] direction = 32'h90a0_b0c0;
    reg [31:0] int_enable = 32'hd0e0_f001;
    reg [31:0] int_status = 32'h1234_5678;
    reg [31:0] int_rise_enable = 32'h89ab_cdef;
    reg [31:0] int_fall_enable = 32'h55aa_a55a;
    wire write_fire;
    wire [7:0] write_addr;
    wire [31:0] write_data;
    wire [3:0] write_strb;
    integer checks = 0;
    integer p;

    apb_slave_ctrl dut (
        .PRESETn(PRESETn), .PADDR(PADDR), .PSEL(PSEL), .PENABLE(PENABLE),
        .PWRITE(PWRITE), .PWDATA(PWDATA), .PSTRB(PSTRB), .PPROT(PPROT),
        .PRDATA(PRDATA), .PREADY(PREADY), .PSLVERR(PSLVERR),
        .data_out(data_out), .data_in(data_in), .direction(direction),
        .int_enable(int_enable), .int_status(int_status),
        .int_rise_enable(int_rise_enable), .int_fall_enable(int_fall_enable),
        .write_fire(write_fire), .write_addr(write_addr),
        .write_data(write_data), .write_strb(write_strb)
    );

    task automatic check32(input string label_text,
                           input logic [31:0] actual,
                           input logic [31:0] wanted);
        checks = checks + 1;
        if (actual !== wanted)
            $fatal(1, "%s: got %08h, expected %08h", label_text, actual, wanted);
    endtask

    task automatic check_read(input logic [7:0] addr,
                              input logic [31:0] wanted);
        begin
            PADDR = addr;
            PSEL = 1'b1;
            PENABLE = 1'b1;
            PWRITE = 1'b0;
            #1;
            check32("read data", PRDATA, wanted);
            check32("read error", {31'b0, PSLVERR}, 0);
            check32("read write_fire", {31'b0, write_fire}, 0);
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("tb_apb_slave_ctrl.vcd");
            $dumpvars(0, tb_apb_slave_ctrl);
        end

        #1 PRESETn = 1'b0;
        #1 PRESETn = 1'b1;
        PADDR = 8'hff;
        #1 PADDR = 8'h00;
        #1;
        check32("PREADY", {31'b0, PREADY}, 1);
        check32("idle read data", PRDATA, 0);
        check32("idle error", {31'b0, PSLVERR}, 0);

        check_read(8'h00, data_out);
        check_read(8'h04, data_in);
        check_read(8'h08, direction);
        check_read(8'h0c, int_enable);
        check_read(8'h10, int_status);
        check_read(8'h14, int_rise_enable);
        check_read(8'h18, int_fall_enable);

        PADDR = 8'h00;
        PWRITE = 1'b1;
        PWDATA = 32'ha5a5_5a5a;
        PSTRB = 4'b1010;
        #1;
        check32("valid write error", {31'b0, PSLVERR}, 0);
        check32("valid write fire", {31'b0, write_fire}, 1);
        check32("forward address", {24'b0, write_addr}, 8'h00);
        check32("forward data", write_data, PWDATA);
        check32("forward strobes", {28'b0, write_strb}, 4'b1010);
        check32("write read data", PRDATA, 0);

        PADDR = 8'h04;
        #1;
        check32("DATA_IN write error", {31'b0, PSLVERR}, 1);
        check32("DATA_IN write rejected", {31'b0, write_fire}, 0);

        PADDR = 8'h03;
        #1;
        check32("misaligned error", {31'b0, PSLVERR}, 1);
        check32("misaligned write rejected", {31'b0, write_fire}, 0);

        PADDR = 8'h80;
        PWRITE = 1'b0;
        #1;
        check32("unmapped read error", {31'b0, PSLVERR}, 1);
        check32("unmapped read data", PRDATA, 0);

        PENABLE = 1'b0;
        #1;
        check32("SETUP error suppressed", {31'b0, PSLVERR}, 0);
        check32("SETUP read data suppressed", PRDATA, 0);
        check32("SETUP write suppressed", {31'b0, write_fire}, 0);

        PSEL = 1'b0;
        PENABLE = 1'b1;
        #1;
        check32("unselected error suppressed", {31'b0, PSLVERR}, 0);
        check32("unselected write suppressed", {31'b0, write_fire}, 0);

        PSEL = 1'b1;
        PWRITE = 1'b1;
        PADDR = 8'h00;
        PRESETn = 1'b0;
        #1;
        check32("reset error suppressed", {31'b0, PSLVERR}, 0);
        check32("reset write suppressed", {31'b0, write_fire}, 0);
        PRESETn = 1'b1;

        for (p = 0; p < 8; p = p + 1) begin
            PPROT = p[2:0];
            #1;
            check32("PPROT accepted", {31'b0, PSLVERR}, 0);
            check32("PPROT write accepted", {31'b0, write_fire}, 1);
        end

        $display("PASS: tb_apb_slave_ctrl (%0d checks)", checks);
        $finish;
    end
endmodule

`default_nettype wire
