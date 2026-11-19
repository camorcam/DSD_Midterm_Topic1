`timescale 1ns/1ps
`default_nettype none

// Cycle-accurate reference model for the complete APB GPIO core.
module gpio_scoreboard (
    input wire        PCLK,
    input wire        PRESETn,
    input wire [7:0]  PADDR,
    input wire        PSEL,
    input wire        PENABLE,
    input wire        PWRITE,
    input wire [31:0] PWDATA,
    input wire [3:0]  PSTRB,
    input wire [31:0] PRDATA,
    input wire        PREADY,
    input wire        PSLVERR,
    input wire [31:0] gpio_in_async,
    input wire [31:0] actual_data_out,
    input wire [31:0] actual_data_in,
    input wire [31:0] actual_direction,
    input wire [31:0] actual_int_enable,
    input wire [31:0] actual_int_status,
    input wire [31:0] actual_int_rise_enable,
    input wire [31:0] actual_int_fall_enable,
    input wire [31:0] actual_gpio_out,
    input wire [31:0] actual_gpio_oe,
    input wire        actual_irq
);
    integer checks = 0;
    reg [31:0] ref_data_out;
    reg [31:0] ref_direction;
    reg [31:0] ref_int_enable;
    reg [31:0] ref_int_rise_enable;
    reg [31:0] ref_int_fall_enable;
    reg [31:0] ref_sync_stage1;
    reg [31:0] ref_data_in;
    reg [31:0] ref_previous_input;
    reg [31:0] ref_int_status;

    reg [31:0] next_data_out;
    reg [31:0] next_direction;
    reg [31:0] next_int_enable;
    reg [31:0] next_int_rise_enable;
    reg [31:0] next_int_fall_enable;
    reg [31:0] next_int_status;
    reg [31:0] event_mask;
    reg [31:0] clear_mask;
    reg valid_write;

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

    function automatic [31:0] byte_mask(input logic [3:0] strobes);
        byte_mask = {{8{strobes[3]}}, {8{strobes[2]}},
                     {8{strobes[1]}}, {8{strobes[0]}}};
    endfunction

    function automatic [31:0] merge_bytes(
        input logic [31:0] old_value,
        input logic [31:0] new_value,
        input logic [3:0] strobes
    );
        reg [31:0] mask;
        begin
            mask = byte_mask(strobes);
            merge_bytes = (old_value & ~mask) | (new_value & mask);
        end
    endfunction

    task automatic check32(input string label_text,
                           input logic [31:0] actual,
                           input logic [31:0] wanted);
        checks = checks + 1;
        if (actual !== wanted)
            $fatal(1, "scoreboard %s: got %08h, expected %08h at %0t",
                   label_text, actual, wanted, $time);
    endtask

    task automatic check_state;
        begin
            check32("DATA_OUT", actual_data_out, ref_data_out);
            check32("DATA_IN", actual_data_in, ref_data_in);
            check32("DIRECTION", actual_direction, ref_direction);
            check32("INT_ENABLE", actual_int_enable, ref_int_enable);
            check32("INT_STATUS", actual_int_status, ref_int_status);
            check32("INT_RISE_ENABLE", actual_int_rise_enable, ref_int_rise_enable);
            check32("INT_FALL_ENABLE", actual_int_fall_enable, ref_int_fall_enable);
            check32("gpio_out", actual_gpio_out, ref_data_out);
            check32("gpio_oe", actual_gpio_oe, ref_direction);
            check32("irq", {31'b0, actual_irq},
                    {31'b0, |(ref_int_status & ref_int_enable)});
        end
    endtask

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            ref_data_out = 0;
            ref_direction = 0;
            ref_int_enable = 0;
            ref_int_rise_enable = 0;
            ref_int_fall_enable = 0;
            ref_sync_stage1 = 0;
            ref_data_in = 0;
            ref_previous_input = 0;
            ref_int_status = 0;
        end else begin
            event_mask = ~ref_direction &
                ((ref_data_in & ~ref_previous_input & ref_int_rise_enable) |
                 (~ref_data_in & ref_previous_input & ref_int_fall_enable));
            clear_mask = 0;
            valid_write = PSEL && PENABLE && PWRITE &&
                          address_is_mapped(PADDR) && PADDR != 8'h04;
            if (valid_write && PADDR == 8'h10)
                clear_mask = PWDATA & byte_mask(PSTRB);

            next_data_out = ref_data_out;
            next_direction = ref_direction;
            next_int_enable = ref_int_enable;
            next_int_rise_enable = ref_int_rise_enable;
            next_int_fall_enable = ref_int_fall_enable;
            if (valid_write) begin
                case (PADDR)
                    8'h00: next_data_out = merge_bytes(ref_data_out, PWDATA, PSTRB);
                    8'h08: next_direction = merge_bytes(ref_direction, PWDATA, PSTRB);
                    8'h0c: next_int_enable = merge_bytes(ref_int_enable, PWDATA, PSTRB);
                    8'h14: next_int_rise_enable =
                        merge_bytes(ref_int_rise_enable, PWDATA, PSTRB);
                    8'h18: next_int_fall_enable =
                        merge_bytes(ref_int_fall_enable, PWDATA, PSTRB);
                    default: begin end
                endcase
            end
            next_int_status = (ref_int_status & ~clear_mask) | event_mask;

            ref_data_out = next_data_out;
            ref_direction = next_direction;
            ref_int_enable = next_int_enable;
            ref_int_rise_enable = next_int_rise_enable;
            ref_int_fall_enable = next_int_fall_enable;
            ref_int_status = next_int_status;
            ref_previous_input = ref_data_in;
            ref_data_in = ref_sync_stage1;
            ref_sync_stage1 = gpio_in_async;
            #1 check_state();
        end
    end

    always @(negedge PRESETn) begin
        #1 check_state();
    end

    // Check APB read data against the independent model before completion.
    always @(negedge PCLK) begin : read_response_check
        reg [31:0] wanted_read;
        reg wanted_error;
        #2;
        check32("PREADY", {31'b0, PREADY}, 1);
        wanted_error = PRESETn && PSEL && PENABLE &&
                       (!address_is_mapped(PADDR) ||
                        (PWRITE && PADDR == 8'h04));
        check32("PSLVERR", {31'b0, PSLVERR}, {31'b0, wanted_error});
        wanted_read = 0;
        if (PRESETn && PSEL && PENABLE && !PWRITE && address_is_mapped(PADDR)) begin
            case (PADDR)
                8'h00: wanted_read = ref_data_out;
                8'h04: wanted_read = ref_data_in;
                8'h08: wanted_read = ref_direction;
                8'h0c: wanted_read = ref_int_enable;
                8'h10: wanted_read = ref_int_status;
                8'h14: wanted_read = ref_int_rise_enable;
                8'h18: wanted_read = ref_int_fall_enable;
                default: wanted_read = 0;
            endcase
        end
        check32("PRDATA", PRDATA, wanted_read);
    end
endmodule

`default_nettype wire
