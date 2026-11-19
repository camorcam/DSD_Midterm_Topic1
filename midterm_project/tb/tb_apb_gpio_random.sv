`timescale 1ns/1ps
`default_nettype none

module tb_apb_gpio_random;
    reg PCLK = 1'b0;
    always #5 PCLK = ~PCLK;
    reg PRESETn = 1'b1;
    wire [7:0] PADDR;
    wire PSEL, PENABLE, PWRITE;
    wire [31:0] PWDATA;
    wire [3:0] PSTRB;
    wire [2:0] PPROT;
    wire [31:0] PRDATA;
    wire PREADY, PSLVERR;
    reg [31:0] gpio_in_async = 32'b0;
    wire [31:0] gpio_out, gpio_oe;
    wire irq;

    wire [31:0] actual_data_out = dut.data_out;
    wire [31:0] actual_data_in = dut.data_in;
    wire [31:0] actual_direction = dut.direction;
    wire [31:0] actual_int_enable = dut.int_enable;
    wire [31:0] actual_int_status = dut.int_status;
    wire [31:0] actual_int_rise_enable = dut.int_rise_enable;
    wire [31:0] actual_int_fall_enable = dut.int_fall_enable;

    integer checks = 0;
    integer seed = 1;
    integer transactions = 500;
    integer transaction_index;
    integer register_index;
    integer strobe_index;
    integer prot_index;
    reg [31:0] prng_state;
    reg [31:0] random_value;
    reg [31:0] random_value2;
    reg [31:0] previous_gpio;
    reg [7:0] random_address;
    reg [6:0] read_register_seen = 0;
    reg [6:0] write_register_seen = 0;
    reg [15:0] strobe_seen = 0;
    reg [7:0] protection_seen = 0;
    reg [31:0] gpio_rise_seen = 0;
    reg [31:0] gpio_fall_seen = 0;
    reg [2:0] edge_mode_seen = 0;
    reg valid_response_seen = 0;
    reg error_response_seen = 0;
    string vcd_name;

    apb_bfm u_bfm (
        .PCLK(PCLK), .PADDR(PADDR), .PSEL(PSEL), .PENABLE(PENABLE),
        .PWRITE(PWRITE), .PWDATA(PWDATA), .PSTRB(PSTRB), .PPROT(PPROT),
        .PRDATA(PRDATA), .PREADY(PREADY), .PSLVERR(PSLVERR)
    );

    apb_gpio_top dut (
        .PCLK(PCLK), .PRESETn(PRESETn), .PADDR(PADDR), .PSEL(PSEL),
        .PENABLE(PENABLE), .PWRITE(PWRITE), .PWDATA(PWDATA),
        .PSTRB(PSTRB), .PPROT(PPROT), .PRDATA(PRDATA),
        .PREADY(PREADY), .PSLVERR(PSLVERR),
        .gpio_in_async(gpio_in_async), .gpio_out(gpio_out),
        .gpio_oe(gpio_oe), .irq(irq)
    );

    gpio_scoreboard u_scoreboard (
        .PCLK(PCLK), .PRESETn(PRESETn), .PADDR(PADDR), .PSEL(PSEL),
        .PENABLE(PENABLE), .PWRITE(PWRITE), .PWDATA(PWDATA),
        .PSTRB(PSTRB), .PRDATA(PRDATA), .PREADY(PREADY),
        .PSLVERR(PSLVERR), .gpio_in_async(gpio_in_async),
        .actual_data_out(actual_data_out), .actual_data_in(actual_data_in),
        .actual_direction(actual_direction), .actual_int_enable(actual_int_enable),
        .actual_int_status(actual_int_status),
        .actual_int_rise_enable(actual_int_rise_enable),
        .actual_int_fall_enable(actual_int_fall_enable),
        .actual_gpio_out(gpio_out), .actual_gpio_oe(gpio_oe),
        .actual_irq(irq)
    );

    apb_protocol_checker u_protocol_checker (
        .PCLK(PCLK), .PRESETn(PRESETn), .PADDR(PADDR), .PSEL(PSEL),
        .PENABLE(PENABLE), .PWRITE(PWRITE), .PWDATA(PWDATA),
        .PSTRB(PSTRB), .PPROT(PPROT)
    );

    function automatic integer mapped_index(input logic [7:0] addr);
        begin
            case (addr)
                8'h00: mapped_index = 0;
                8'h04: mapped_index = 1;
                8'h08: mapped_index = 2;
                8'h0c: mapped_index = 3;
                8'h10: mapped_index = 4;
                8'h14: mapped_index = 5;
                8'h18: mapped_index = 6;
                default: mapped_index = -1;
            endcase
        end
    endfunction

    function automatic logic expected_error(input logic [7:0] addr,
                                             input logic is_write);
        expected_error = mapped_index(addr) < 0 || (is_write && addr == 8'h04);
    endfunction

    function automatic [7:0] choose_address(input logic [31:0] value);
        begin
            case (value % 12)
                0: choose_address = 8'h00;
                1: choose_address = 8'h04;
                2: choose_address = 8'h08;
                3: choose_address = 8'h0c;
                4: choose_address = 8'h10;
                5: choose_address = 8'h14;
                6: choose_address = 8'h18;
                7: choose_address = 8'h01;
                8: choose_address = 8'h03;
                9: choose_address = 8'h1c;
                10: choose_address = 8'h80;
                default: choose_address = 8'hfc;
            endcase
        end
    endfunction

    task automatic check32(input string label_text,
                           input logic [31:0] actual,
                           input logic [31:0] wanted);
        checks = checks + 1;
        if (actual !== wanted)
            $fatal(1, "random test %s: got %08h, expected %08h at %0t",
                   label_text, actual, wanted, $time);
    endtask

    task automatic random32(output logic [31:0] value);
        begin
            prng_state = prng_state * 32'd1664525 + 32'd1013904223;
            value = prng_state;
        end
    endtask

    task automatic record_response(input logic had_error);
        begin
            if (had_error)
                error_response_seen = 1'b1;
            else
                valid_response_seen = 1'b1;
        end
    endtask

    task automatic do_write(input logic [7:0] addr,
                            input logic [31:0] data,
                            input logic [3:0] strobes,
                            input logic [2:0] protection);
        reg actual_error;
        reg wanted_error;
        integer index;
        begin
            u_bfm.apb_write(addr, data, strobes, protection, actual_error);
            wanted_error = expected_error(addr, 1'b1);
            check32("write error", {31'b0, actual_error}, {31'b0, wanted_error});
            index = mapped_index(addr);
            if (index >= 0)
                write_register_seen[index] = 1'b1;
            strobe_seen[strobes] = 1'b1;
            protection_seen[protection] = 1'b1;
            record_response(actual_error);
        end
    endtask

    task automatic do_read(input logic [7:0] addr,
                           input logic [2:0] protection);
        reg [31:0] unused_data;
        reg actual_error;
        reg wanted_error;
        integer index;
        begin
            u_bfm.apb_read(addr, protection, unused_data, actual_error);
            wanted_error = expected_error(addr, 1'b0);
            check32("read error", {31'b0, actual_error}, {31'b0, wanted_error});
            index = mapped_index(addr);
            if (index >= 0)
                read_register_seen[index] = 1'b1;
            protection_seen[protection] = 1'b1;
            record_response(actual_error);
        end
    endtask

    task automatic drive_gpio(input logic [31:0] new_value,
                              input integer wait_cycles);
        begin
            u_bfm.apb_idle();
            previous_gpio = gpio_in_async;
            gpio_rise_seen = gpio_rise_seen | (new_value & ~previous_gpio);
            gpio_fall_seen = gpio_fall_seen | (~new_value & previous_gpio);
            @(negedge PCLK);
            gpio_in_async = new_value;
            repeat (wait_cycles) @(posedge PCLK);
            #1;
        end
    endtask

    task automatic reset_dut;
        begin
            u_bfm.apb_idle();
            #3 PRESETn = 1'b0;
            #2;
            @(negedge PCLK);
            PRESETn = 1'b1;
        end
    endtask

    initial begin
        #1000000;
        $fatal(1, "Simulation watchdog expired");
    end

    initial begin
        if (!$value$plusargs("SEED=%d", seed))
            seed = 1;
        if (!$value$plusargs("TRANSACTIONS=%d", transactions))
            transactions = 500;
        prng_state = seed;
        if ($test$plusargs("vcd")) begin
            vcd_name = $sformatf("tb_apb_gpio_random_%0d.vcd", seed);
            $dumpfile(vcd_name);
            $dumpvars(0, tb_apb_gpio_random);
        end

        #2 PRESETn = 1'b0;
        #2;
        @(negedge PCLK);
        PRESETn = 1'b1;

        for (transaction_index = 0;
             transaction_index < transactions;
             transaction_index = transaction_index + 1) begin
            if (transaction_index > 0 && (transaction_index % 128) == 0)
                reset_dut();
            random32(random_value);
            random32(random_value2);
            random_address = choose_address(random_value2);
            case (random_value[2:0])
                3'd0, 3'd1:
                    do_write(random_address, random_value,
                             random_value2[3:0], random_value[10:8]);
                3'd2:
                    do_read(random_address, random_value[10:8]);
                3'd3, 3'd4:
                    drive_gpio(random_value2, (random_value[12:11] % 3) + 1);
                3'd5:
                    do_write(8'h10, random_value, random_value2[3:0],
                             random_value[10:8]);
                3'd6:
                    do_read(random_address, random_value[10:8]);
                default:
                    do_write(8'h14 + ({7'b0, random_value[3]} << 2),
                             random_value2, random_value[7:4], random_value[10:8]);
            endcase
        end

        // Deterministic coverage closure for registers, strobes, and PPROT.
        for (register_index = 0; register_index < 7; register_index = register_index + 1) begin
            case (register_index)
                0: random_address = 8'h00;
                1: random_address = 8'h04;
                2: random_address = 8'h08;
                3: random_address = 8'h0c;
                4: random_address = 8'h10;
                5: random_address = 8'h14;
                default: random_address = 8'h18;
            endcase
            do_read(random_address, register_index[2:0]);
            do_write(random_address, 32'h1357_9bdf ^ register_index,
                     4'hf, register_index[2:0]);
        end
        for (strobe_index = 0; strobe_index < 16; strobe_index = strobe_index + 1)
            do_write(8'h00, 32'ha5a5_0000 | strobe_index,
                     strobe_index[3:0], strobe_index[2:0]);
        for (prot_index = 0; prot_index < 8; prot_index = prot_index + 1)
            do_read(8'h00, prot_index[2:0]);
        do_read(8'h1c, 3'b000);
        do_write(8'h04, 32'hffff_ffff, 4'hf, 3'b000);

        // Close GPIO transition and interrupt-mode coverage.
        drive_gpio(0, 4);
        drive_gpio(32'hffff_ffff, 4);
        drive_gpio(0, 4);
        do_write(8'h08, 0, 4'hf, 0);
        do_write(8'h0c, 0, 4'hf, 0);
        do_write(8'h10, 32'hffff_ffff, 4'hf, 0);

        do_write(8'h14, 32'h0000_0001, 4'hf, 0);
        do_write(8'h18, 0, 4'hf, 0);
        drive_gpio(32'h0000_0001, 4);
        edge_mode_seen[0] = 1'b1;
        do_write(8'h10, 32'hffff_ffff, 4'hf, 0);

        do_write(8'h14, 0, 4'hf, 0);
        do_write(8'h18, 32'h0000_0002, 4'hf, 0);
        drive_gpio(32'h0000_0003, 4);
        drive_gpio(32'h0000_0001, 4);
        edge_mode_seen[1] = 1'b1;
        do_write(8'h10, 32'hffff_ffff, 4'hf, 0);

        do_write(8'h14, 32'h0000_0004, 4'hf, 0);
        do_write(8'h18, 32'h0000_0004, 4'hf, 0);
        drive_gpio(32'h0000_0005, 4);
        do_write(8'h10, 32'hffff_ffff, 4'hf, 0);
        drive_gpio(32'h0000_0001, 4);
        edge_mode_seen[2] = 1'b1;
        u_bfm.apb_idle();

        $display("COVERAGE: read_regs=%02h write_regs=%02h strobes=%04h pprot=%02h",
                 read_register_seen, write_register_seen, strobe_seen, protection_seen);
        $display("COVERAGE: gpio_rise=%08h gpio_fall=%08h edge_modes=%01h responses=%0d%0d",
                 gpio_rise_seen, gpio_fall_seen, edge_mode_seen,
                 valid_response_seen, error_response_seen);
        if (read_register_seen != 7'h7f || write_register_seen != 7'h7f ||
            strobe_seen != 16'hffff || protection_seen != 8'hff ||
            gpio_rise_seen != 32'hffff_ffff || gpio_fall_seen != 32'hffff_ffff ||
            edge_mode_seen != 3'b111 || !valid_response_seen || !error_response_seen)
            $fatal(1, "functional coverage closure failed");

        $display("PASS: tb_apb_gpio_random (seed=%0d transactions=%0d checks=%0d scoreboard=%0d protocol=%0d)",
                 seed, transactions, checks, u_scoreboard.checks,
                 u_protocol_checker.checks);
        $finish;
    end
endmodule

`default_nettype wire
