`timescale 1ns/1ps
`default_nettype none

module tb_gpio_registers;
    reg PCLK = 1'b0;
    always #5 PCLK = ~PCLK;
    reg PRESETn = 1'b1;
    reg write_fire = 1'b0;
    reg [7:0] write_addr = 8'b0;
    reg [31:0] write_data = 32'b0;
    reg [3:0] write_strb = 4'b0;
    wire [31:0] data_out, direction, int_enable;
    wire [31:0] int_rise_enable, int_fall_enable, int_clear_mask;
    reg [31:0] expected [0:4];
    reg [7:0] addresses [0:4];
    integer checks = 0;
    integer r, s, lane;
    reg [31:0] value;
    reg [31:0] wanted_clear;

    gpio_registers dut (
        .PCLK(PCLK), .PRESETn(PRESETn), .write_fire(write_fire),
        .write_addr(write_addr), .write_data(write_data), .write_strb(write_strb),
        .data_out(data_out), .direction(direction), .int_enable(int_enable),
        .int_rise_enable(int_rise_enable), .int_fall_enable(int_fall_enable),
        .int_clear_mask(int_clear_mask)
    );

    task automatic check32(input string label_text,
                           input logic [31:0] actual,
                           input logic [31:0] wanted);
        checks = checks + 1;
        if (actual !== wanted)
            $fatal(1, "%s: got %08h, expected %08h at %0t",
                   label_text, actual, wanted, $time);
    endtask

    task automatic check_state;
        begin
            check32("DATA_OUT", data_out, expected[0]);
            check32("DIRECTION", direction, expected[1]);
            check32("INT_ENABLE", int_enable, expected[2]);
            check32("INT_RISE_ENABLE", int_rise_enable, expected[3]);
            check32("INT_FALL_ENABLE", int_fall_enable, expected[4]);
        end
    endtask

    task automatic write_request(input logic [7:0] addr,
                                 input logic [31:0] data,
                                 input logic [3:0] strobes);
        integer i, byte_index;
        begin
            @(negedge PCLK);
            write_fire = 1'b1;
            write_addr = addr;
            write_data = data;
            write_strb = strobes;
            #1;
            wanted_clear = 32'b0;
            if (addr == 8'h10) begin
                for (byte_index = 0; byte_index < 4; byte_index = byte_index + 1)
                    if (strobes[byte_index])
                        wanted_clear[byte_index*8 +: 8] = data[byte_index*8 +: 8];
            end
            check32("combinational clear mask", int_clear_mask, wanted_clear);
            @(posedge PCLK);
            for (i = 0; i < 5; i = i + 1)
                if (addr == addresses[i])
                    for (byte_index = 0; byte_index < 4; byte_index = byte_index + 1)
                        if (strobes[byte_index])
                            expected[i][byte_index*8 +: 8] = data[byte_index*8 +: 8];
            #1 check_state();
            @(negedge PCLK);
            write_fire = 1'b0;
            #1 check32("inactive clear mask", int_clear_mask, 0);
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("tb_gpio_registers.vcd");
            $dumpvars(0, tb_gpio_registers);
        end
        addresses[0] = 8'h00;
        addresses[1] = 8'h08;
        addresses[2] = 8'h0c;
        addresses[3] = 8'h14;
        addresses[4] = 8'h18;
        for (r = 0; r < 5; r = r + 1)
            expected[r] = 32'b0;

        #2 PRESETn = 1'b0;
        #1 check_state();
        check32("reset clear mask", int_clear_mask, 0);
        @(negedge PCLK);
        PRESETn = 1'b1;

        for (r = 0; r < 5; r = r + 1) begin
            write_request(addresses[r], 32'ha5a5_5a5a, 4'hf);
            for (s = 0; s < 16; s = s + 1) begin
                value = (s[0]) ? 32'h1234_5678 : 32'hedcb_a987;
                write_request(addresses[r], value, s[3:0]);
            end
        end

        write_request(8'h10, 32'h81a5_5a18, 4'b0101);
        write_request(8'h10, 32'hffff_ffff, 4'b0000);
        write_request(8'h04, 32'hffff_ffff, 4'hf);
        write_request(8'h1c, 32'hffff_ffff, 4'hf);

        @(negedge PCLK);
        write_fire = 1'b1;
        write_addr = 8'h00;
        write_data = 32'hffff_ffff;
        write_strb = 4'hf;
        #1 PRESETn = 1'b0;
        for (r = 0; r < 5; r = r + 1)
            expected[r] = 32'b0;
        #1;
        check_state();
        check32("reset suppresses clear", int_clear_mask, 0);

        $display("PASS: tb_gpio_registers (%0d checks)", checks);
        $finish;
    end
endmodule

`default_nettype wire
