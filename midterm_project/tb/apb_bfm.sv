`timescale 1ns/1ps
`default_nettype none

// Reusable APB master bus-functional model for directed simulation.
module apb_bfm #(
    parameter integer APB_ADDR_WIDTH = 8
) (
    input  wire                      PCLK,
    output reg  [APB_ADDR_WIDTH-1:0] PADDR,
    output reg                       PSEL,
    output reg                       PENABLE,
    output reg                       PWRITE,
    output reg  [31:0]               PWDATA,
    output reg  [3:0]                PSTRB,
    output reg  [2:0]                PPROT,
    input  wire [31:0]               PRDATA,
    input  wire                      PREADY,
    input  wire                      PSLVERR
);
    initial begin
        PADDR = {APB_ADDR_WIDTH{1'b0}};
        PSEL = 1'b0;
        PENABLE = 1'b0;
        PWRITE = 1'b0;
        PWDATA = 32'b0;
        PSTRB = 4'b0;
        PPROT = 3'b0;
    end

    task automatic drive_setup(
        input logic                      is_write,
        input logic [APB_ADDR_WIDTH-1:0] addr,
        input logic [31:0]               write_value,
        input logic [3:0]                strobes,
        input logic [2:0]                protection
    );
        begin
            @(negedge PCLK);
            PADDR = addr;
            PSEL = 1'b1;
            PENABLE = 1'b0;
            PWRITE = is_write;
            PWDATA = write_value;
            PSTRB = strobes;
            PPROT = protection;
        end
    endtask

    task automatic drive_access;
        begin
            @(negedge PCLK);
            PENABLE = 1'b1;
        end
    endtask

    task automatic apb_transfer(
        input  logic                      is_write,
        input  logic [APB_ADDR_WIDTH-1:0] addr,
        input  logic [31:0]               write_value,
        input  logic [3:0]                strobes,
        input  logic [2:0]                protection,
        output logic [31:0]               read_value,
        output logic                      error
    );
        begin
            drive_setup(is_write, addr, write_value, strobes, protection);
            @(posedge PCLK);
            drive_access();
            @(posedge PCLK);
            while (!PREADY)
                @(posedge PCLK);
            #1;
            read_value = PRDATA;
            error = PSLVERR;
        end
    endtask

    task automatic apb_write(
        input  logic [APB_ADDR_WIDTH-1:0] addr,
        input  logic [31:0]               write_value,
        input  logic [3:0]                strobes,
        input  logic [2:0]                protection,
        output logic                      error
    );
        logic [31:0] unused_read_value;
        begin
            apb_transfer(1'b1, addr, write_value, strobes, protection,
                         unused_read_value, error);
        end
    endtask

    task automatic apb_read(
        input  logic [APB_ADDR_WIDTH-1:0] addr,
        input  logic [2:0]                protection,
        output logic [31:0]               read_value,
        output logic                      error
    );
        begin
            apb_transfer(1'b0, addr, 32'b0, 4'b0, protection,
                         read_value, error);
        end
    endtask

    task automatic apb_idle;
        begin
            @(negedge PCLK);
            PSEL = 1'b0;
            PENABLE = 1'b0;
            PWRITE = 1'b0;
            PSTRB = 4'b0;
        end
    endtask

    task automatic drive_unselected_access(
        input logic                      is_write,
        input logic [APB_ADDR_WIDTH-1:0] addr,
        input logic [31:0]               write_value,
        input logic [3:0]                strobes
    );
        begin
            @(negedge PCLK);
            PADDR = addr;
            PSEL = 1'b0;
            PENABLE = 1'b1;
            PWRITE = is_write;
            PWDATA = write_value;
            PSTRB = strobes;
        end
    endtask
endmodule

`default_nettype wire
