`timescale 1ns/1ps
`default_nettype none

// Test the APB decoder and register bank; synchronized input and pending status are fixtures.
module tb_apb_registers;
    reg PCLK = 1'b0;
    always #5 PCLK = ~PCLK;
    reg PRESETn = 1'b1;
    wire [7:0] PADDR;
    wire PSEL, PENABLE, PWRITE;
    wire [31:0] PWDATA;
    wire [3:0] PSTRB;
    wire [2:0] PPROT;
    wire [31:0] PRDATA;
    wire PREADY, PSLVERR, write_fire;
    wire [7:0] write_addr;
    wire [31:0] write_data;
    wire [3:0] write_strb;
    wire [31:0] data_out, direction, int_enable;
    wire [31:0] int_rise_enable, int_fall_enable, int_clear_mask;
    reg [31:0] data_in = 32'h963c_a581;
    reg [31:0] int_status = 32'h8100_0181;

    reg [31:0] expected [0:4];
    reg [7:0] rw_addr [0:4];
    integer checks = 0;
    integer r, s, p;
    reg [31:0] pattern;
    reg [2:0] transfer_prot = 3'b0;
    reg setup_pending = 1'b0;
    reg [7:0] setup_addr;
    reg setup_write;
    reg [31:0] setup_wdata;
    reg [3:0] setup_strb;
    reg [2:0] setup_prot;

    apb_bfm u_bfm (
        .PCLK(PCLK), .PADDR(PADDR), .PSEL(PSEL), .PENABLE(PENABLE),
        .PWRITE(PWRITE), .PWDATA(PWDATA), .PSTRB(PSTRB), .PPROT(PPROT),
        .PRDATA(PRDATA), .PREADY(PREADY), .PSLVERR(PSLVERR)
    );

    apb_slave_ctrl u_apb (
        .PRESETn(PRESETn), .PADDR(PADDR), .PSEL(PSEL), .PENABLE(PENABLE),
        .PWRITE(PWRITE), .PWDATA(PWDATA), .PSTRB(PSTRB), .PPROT(PPROT),
        .PRDATA(PRDATA), .PREADY(PREADY), .PSLVERR(PSLVERR),
        .data_out(data_out), .data_in(data_in), .direction(direction),
        .int_enable(int_enable), .int_status(int_status),
        .int_rise_enable(int_rise_enable), .int_fall_enable(int_fall_enable),
        .write_fire(write_fire), .write_addr(write_addr),
        .write_data(write_data), .write_strb(write_strb)
    );

    gpio_registers u_registers (
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
        check32("DATA_OUT", data_out, expected[0]);
        check32("DIRECTION", direction, expected[1]);
        check32("INT_ENABLE", int_enable, expected[2]);
        check32("INT_RISE_ENABLE", int_rise_enable, expected[3]);
        check32("INT_FALL_ENABLE", int_fall_enable, expected[4]);
    endtask

    function automatic logic address_is_mapped(input logic [7:0] addr);
        begin
            case (addr)
                8'h00, 8'h04, 8'h08, 8'h0c, 8'h10, 8'h14, 8'h18:
                    address_is_mapped = 1'b1;
                default:
                    address_is_mapped = 1'b0;
            endcase
        end
    endfunction

    // Monitor the BFM-driven bus independently from the transaction results.
    // It checks inactive responses and SETUP-to-ACCESS signal stability.
    always @(negedge PCLK) begin : protocol_monitor
        reg expected_error;
        reg [31:0] expected_clear;
        #2;
        check32("PREADY", {31'b0, PREADY}, 1);
        if (!PRESETn) begin
            setup_pending = 1'b0;
            check32("reset error", {31'b0, PSLVERR}, 0);
            check32("reset write request", {31'b0, write_fire}, 0);
            check32("reset clear mask", int_clear_mask, 0);
        end else if (PSEL && !PENABLE) begin
            setup_pending = 1'b1;
            setup_addr = PADDR;
            setup_write = PWRITE;
            setup_wdata = PWDATA;
            setup_strb = PSTRB;
            setup_prot = PPROT;
            check32("SETUP error", {31'b0, PSLVERR}, 0);
            check32("SETUP write request", {31'b0, write_fire}, 0);
            check32("SETUP clear mask", int_clear_mask, 0);
            check32("SETUP read data", PRDATA, 0);
        end else if (PSEL && PENABLE) begin
            check32("ACCESS follows SETUP", {31'b0, setup_pending}, 1);
            check32("stable address", {24'b0, PADDR}, {24'b0, setup_addr});
            check32("stable direction", {31'b0, PWRITE}, {31'b0, setup_write});
            check32("stable write data", PWDATA, setup_wdata);
            check32("stable strobes", {28'b0, PSTRB}, {28'b0, setup_strb});
            check32("stable protection", {29'b0, PPROT}, {29'b0, setup_prot});
            expected_error = !address_is_mapped(PADDR) ||
                             (PWRITE && PADDR == 8'h04);
            check32("ACCESS error", {31'b0, PSLVERR}, {31'b0, expected_error});
            check32("ACCESS write request", {31'b0, write_fire},
                    {31'b0, (PWRITE && !expected_error)});
            expected_clear = 32'b0;
            if (PWRITE && !expected_error && PADDR == 8'h10) begin
                if (PSTRB[0]) expected_clear[7:0] = PWDATA[7:0];
                if (PSTRB[1]) expected_clear[15:8] = PWDATA[15:8];
                if (PSTRB[2]) expected_clear[23:16] = PWDATA[23:16];
                if (PSTRB[3]) expected_clear[31:24] = PWDATA[31:24];
            end
            check32("ACCESS clear mask", int_clear_mask, expected_clear);
            setup_pending = 1'b0;
        end else begin
            setup_pending = 1'b0;
            check32("inactive error", {31'b0, PSLVERR}, 0);
            check32("inactive write request", {31'b0, write_fire}, 0);
            check32("inactive clear mask", int_clear_mask, 0);
            check32("inactive read data", PRDATA, 0);
        end
    end

    // Check a BFM transaction against the directed-test expectations and model.
    task automatic transfer(input logic is_write,
                            input logic [7:0] addr,
                            input logic [31:0] value,
                            input logic [3:0] strobes,
                            input logic want_error,
                            input logic [31:0] want_read);
        integer i, lane;
        reg [31:0] want_clear;
        reg [31:0] actual_read;
        reg actual_error;
        begin
            actual_read = 32'b0;
            if (is_write)
                u_bfm.apb_write(addr, value, strobes, transfer_prot, actual_error);
            else
                u_bfm.apb_read(addr, transfer_prot, actual_read, actual_error);
            check32("transaction error", {31'b0, actual_error}, {31'b0, want_error});
            check32("transaction read data", actual_read, want_read);
            check32("write address forwarding", {24'b0, write_addr}, {24'b0, addr});
            check32("write data forwarding", write_data, value);
            check32("write strobe forwarding", {28'b0, write_strb}, {28'b0, strobes});
            want_clear = 0;
            if (is_write && !want_error && addr == 8'h10)
                for (lane = 0; lane < 4; lane = lane + 1)
                    if (strobes[lane])
                        want_clear[lane*8 +: 8] = value[lane*8 +: 8];
            check32("W1C request", int_clear_mask, want_clear);

            // Update the test model using individual bytes, independently of RTL.
            if (is_write && !want_error)
                for (i = 0; i < 5; i = i + 1)
                    if (addr == rw_addr[i])
                        for (lane = 0; lane < 4; lane = lane + 1)
                            if (strobes[lane])
                                expected[i][lane*8 +: 8] = value[lane*8 +: 8];
            #1;
            check_state();
        end
    endtask

    task automatic idle_bus;
        u_bfm.apb_idle();
        #1;
        check32("IDLE error", {31'b0, PSLVERR}, 0);
        check32("IDLE write request", {31'b0, write_fire}, 0);
        check32("IDLE clear mask", int_clear_mask, 0);
        check32("IDLE read data", PRDATA, 0);
        @(posedge PCLK);
        #1;
        check_state();
    endtask

    initial begin
        #100000;
        $fatal(1, "Simulation watchdog expired");
    end

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("apb_registers.vcd");
            $dumpvars(0, tb_apb_registers);
        end
        rw_addr[0] = 8'h00;
        rw_addr[1] = 8'h08;
        rw_addr[2] = 8'h0c;
        rw_addr[3] = 8'h14;
        rw_addr[4] = 8'h18;
        for (r = 0; r < 5; r = r + 1) expected[r] = 0;

        // Assert reset between clock edges to check asynchronous reset behavior.
        #2 PRESETn = 1'b0;
        #1 check_state();
        check32("reset clear mask", int_clear_mask, 0);
        @(negedge PCLK);
        PRESETn = 1'b1;
        for (r = 0; r < 5; r = r + 1)
            transfer(0, rw_addr[r], 0, 0, 0, 0);
        transfer(0, 8'h04, 0, 0, 0, data_in);
        transfer(0, 8'h10, 0, 0, 0, int_status);
        idle_bus();
        $display("PASS: reset defaults and external read sources");

        // Exercise all strobe combinations on every RW register.
        for (r = 0; r < 5; r = r + 1) begin
            transfer(1, rw_addr[r], 32'h69c3_a55a, 4'hf, 0, 0);
            for (s = 0; s < 16; s = s + 1) begin
                pattern = (s % 2) ? 32'h1234_5678 : 32'hedcb_a987;
                transfer(1, rw_addr[r], pattern, s[3:0], 0, 0);
                transfer(0, rw_addr[r], 0, 0, 0, expected[r]);
            end
        end
        idle_bus();
        $display("PASS: all RW registers, byte strobes, and back-to-back accesses");

        // Verify the clear request; pending-status storage requires interrupt block tests.
        for (s = 0; s < 16; s = s + 1)
            transfer(1, 8'h10, 32'h81a5_5a18, s[3:0], 0, 0);
        transfer(1, 8'h10, 0, 4'hf, 0, 0);
        transfer(0, 8'h10, 0, 0, 0, int_status);
        $display("PASS: byte-qualified W1C request and status read path");

        transfer(1, 8'h04, 32'hffff_ffff, 4'hf, 1, 0);
        transfer(1, 8'h04, 32'hffff_ffff, 0, 1, 0);
        transfer(0, 8'h04, 0, 0, 0, data_in);
        for (s = 1; s < 4; s = s + 1) begin
            transfer(1, s[7:0], 32'hffff_ffff, 4'hf, 1, 0);
            transfer(0, s[7:0], 0, 0, 1, 0);
        end
        transfer(1, 8'h1c, 32'hffff_ffff, 4'hf, 1, 0);
        transfer(0, 8'h1c, 0, 0, 1, 0);
        transfer(1, 8'h80, 32'hffff_ffff, 4'hf, 1, 0);
        transfer(0, 8'h80, 0, 0, 1, 0);
        transfer(1, 8'hfc, 32'hffff_ffff, 0, 1, 0);
        transfer(0, 8'hfc, 0, 0, 1, 0);
        idle_bus();
        $display("PASS: read-only, misaligned, unmapped, and upper-address errors");

        for (p = 0; p < 8; p = p + 1) begin
            transfer_prot = p[2:0];
            transfer(1, 8'h00, 32'h1020_3040 + p, 4'hf, 0, 0);
            transfer(0, 8'h00, 0, 0, 0, expected[0]);
        end
        idle_bus();

        // An unselected ACCESS-like bus must not write or report errors.
        u_bfm.drive_unselected_access(1'b1, 8'h00, 32'hffff_ffff, 4'hf);
        #1 check32("unselected write", {31'b0, write_fire}, 0);
        @(posedge PCLK);
        #1 check_state();
        u_bfm.drive_unselected_access(1'b1, 8'hff, 32'hffff_ffff, 4'hf);
        #1 check32("unselected error", {31'b0, PSLVERR}, 0);
        idle_bus();

        // Hold a write in SETUP for several clocks: no state change is allowed.
        u_bfm.drive_setup(1'b1, 8'h00, 32'hffff_ffff, 4'hf, transfer_prot);
        repeat (3) begin
            @(posedge PCLK);
            #1 check_state();
        end
        idle_bus();

        // Reset while a status-clear ACCESS is active, then while a RW ACCESS is active.
        transfer(1, 8'h10, 32'hffff_ffff, 4'hf, 0, 0);
        #1 PRESETn = 1'b0;
        for (r = 0; r < 5; r = r + 1) expected[r] = 0;
        #1;
        check_state();
        check32("reset suppresses clear", int_clear_mask, 0);
        check32("reset suppresses write", {31'b0, write_fire}, 0);
        check32("reset suppresses error", {31'b0, PSLVERR}, 0);
        idle_bus();
        @(negedge PCLK);
        PRESETn = 1'b1;
        transfer(1, 8'h00, 32'hffff_ffff, 4'hf, 0, 0);
        #1 PRESETn = 1'b0;
        expected[0] = 0;
        #1 check_state();
        @(posedge PCLK);
        #1 check_state();
        idle_bus();
        @(negedge PCLK);
        PRESETn = 1'b1;
        for (r = 0; r < 5; r = r + 1)
            transfer(0, rw_addr[r], 0, 0, 0, 0);
        idle_bus();
        $display("PASS: PPROT, inactive phases, and asynchronous reset during ACCESS");
        $display("PASS: tb_apb_registers (%0d checks)", checks);
        $finish;
    end
endmodule

`default_nettype wire
