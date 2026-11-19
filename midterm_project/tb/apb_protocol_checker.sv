`timescale 1ns/1ps
`default_nettype none

// Icarus-compatible procedural APB protocol assertions.
module apb_protocol_checker (
    input wire        PCLK,
    input wire        PRESETn,
    input wire [7:0]  PADDR,
    input wire        PSEL,
    input wire        PENABLE,
    input wire        PWRITE,
    input wire [31:0] PWDATA,
    input wire [3:0]  PSTRB,
    input wire [2:0]  PPROT
);
    integer checks = 0;
    reg setup_pending = 1'b0;
    reg [7:0] setup_addr;
    reg setup_write;
    reg [31:0] setup_wdata;
    reg [3:0] setup_strb;
    reg [2:0] setup_prot;

    task automatic check32(input string label_text,
                           input logic [31:0] actual,
                           input logic [31:0] wanted);
        checks = checks + 1;
        if (actual !== wanted)
            $fatal(1, "APB protocol %s: got %08h, expected %08h at %0t",
                   label_text, actual, wanted, $time);
    endtask

    always @(negedge PCLK) begin
        #2;
        if (!PRESETn) begin
            setup_pending = 1'b0;
        end else if (PSEL && !PENABLE) begin
            setup_pending = 1'b1;
            setup_addr = PADDR;
            setup_write = PWRITE;
            setup_wdata = PWDATA;
            setup_strb = PSTRB;
            setup_prot = PPROT;
        end else if (PSEL && PENABLE) begin
            check32("ACCESS follows SETUP", {31'b0, setup_pending}, 1);
            check32("stable PADDR", {24'b0, PADDR}, {24'b0, setup_addr});
            check32("stable PWRITE", {31'b0, PWRITE}, {31'b0, setup_write});
            check32("stable PWDATA", PWDATA, setup_wdata);
            check32("stable PSTRB", {28'b0, PSTRB}, {28'b0, setup_strb});
            check32("stable PPROT", {29'b0, PPROT}, {29'b0, setup_prot});
            setup_pending = 1'b0;
        end else begin
            setup_pending = 1'b0;
        end
    end
endmodule

`default_nettype wire
