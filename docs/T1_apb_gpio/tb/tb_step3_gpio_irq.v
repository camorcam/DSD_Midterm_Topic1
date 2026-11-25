// ============================================================================
// tb_step3_gpio_irq.v  -  Step 3 testbench: edge interrupt unit + W1C status
// ============================================================================
`timescale 1ns/1ps
module tb_step3_gpio_irq;
    localparam N = 8;
    reg clk = 1'b0;  always #10 clk = ~clk;
    reg rst_n = 1'b0;
    reg  [N-1:0] pin = 0, rise_en = 0, fall_en = 0, int_en = 0, clr_mask = 0;
    reg          clr_we = 1'b0;
    wire [N-1:0] status;
    wire         irq;

    gpio_irq #(.N(N)) dut (.clk(clk), .rst_n(rst_n), .pin_sync(pin), .rise_en(rise_en),
        .fall_en(fall_en), .int_en(int_en), .clr_we(clr_we), .clr_mask(clr_mask),
        .status(status), .irq(irq));

    integer errors = 0, i;
    reg [N-1:0] m_status, pin_q;

    // reference model of the status register (updated on every clock)
    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin m_status <= 0; pin_q <= 0; end
        else begin
            m_status <= (m_status & ~(clr_we ? clr_mask : {N{1'b0}}))
                      | (pin & ~pin_q & rise_en) | (~pin & pin_q & fall_en);
            pin_q    <= pin;
        end
    always @(negedge clk) if (rst_n) begin
        #1;                                   // let the stimulus of this negedge settle
        if (status !== m_status || irq !== |(m_status & int_en)) begin
            errors = errors + 1;
            $display("[%0t] FAIL status=%b exp=%b irq=%b", $time, status, m_status, irq);
        end
    end

    task expect_status(input [N-1:0] exp, input [8*24-1:0] msg);
        begin
            @(negedge clk);
            if (status !== exp) begin errors = errors + 1; $display("[%0t] FAIL %0s status=%b exp=%b", $time, msg, status, exp); end
            else $display("[%0t] %0s: status=%b irq=%b", $time, msg, status, irq);
        end
    endtask

    task w1c(input [N-1:0] m);
        begin @(negedge clk); clr_we = 1'b1; clr_mask = m; @(negedge clk); clr_we = 1'b0; clr_mask = 0; end
    endtask

    initial begin
        $dumpfile("step3.vcd");  $dumpvars(0, tb_step3_gpio_irq);
        #25 rst_n = 1'b1;
        // pin0: rising, pin1: falling, pin2: both, pin3: no interrupt
        @(negedge clk); rise_en = 8'b0000_0101; fall_en = 8'b0000_0110; int_en = 8'b0000_0111;
        @(negedge clk); pin = 8'b0000_1111;  @(negedge clk);           // rising edges on 0..3
        expect_status(8'b0000_0101, "rise on pins 0..3");
        @(negedge clk); pin = 8'b0000_0000;  @(negedge clk);           // falling edges on 0..3
        expect_status(8'b0000_0111, "fall on pins 0..3");
        w1c(8'b0000_0001);  expect_status(8'b0000_0110, "W1C bit 0");
        w1c(8'b0000_0110);  expect_status(8'b0000_0000, "W1C bits 2:1");
        if (irq !== 1'b0) begin errors = errors + 1; $display("FAIL irq still high"); end

        // event and clear in the same clock: set must win
        @(negedge clk); pin = 8'b0000_0001; clr_we = 1'b1; clr_mask = 8'b0000_0001;
        @(negedge clk); clr_we = 1'b0;
        @(negedge clk);   // event detected one clock after the change
        expect_status(8'b0000_0001, "set wins over clear");
        w1c(8'hFF);

        // masked: status records the event but irq stays low when INT_ENABLE=0
        @(negedge clk); int_en = 0; pin = 0; @(negedge clk);
        expect_status(8'b0000_0000, "pin0 fall (rise only)");
        @(negedge clk); pin = 8'b0000_0001; @(negedge clk);
        expect_status(8'b0000_0001, "masked event");
        if (irq !== 1'b0) begin errors = errors + 1; $display("FAIL irq not masked"); end
        @(negedge clk); int_en = 8'h01;  @(negedge clk);
        if (irq !== 1'b1) begin errors = errors + 1; $display("FAIL irq after enable"); end
        w1c(8'hFF);

        // random test against the model
        for (i = 0; i < 2000; i = i + 1) begin
            @(negedge clk);
            pin = $random; clr_we = $random; clr_mask = $random;
            if (i % 100 == 0) begin rise_en = $random; fall_en = $random; int_en = $random; end
        end
        clr_we = 0;  repeat (2) @(negedge clk);
        $display("[%0t] 2000 random cycles compared with the reference model", $time);

        if (errors == 0) $display("*** STEP 3 PASS ***");
        else             $display("*** STEP 3 FAIL : %0d error(s) ***", errors);
        $finish;
    end
    initial begin #200000; $display("TIMEOUT - the design never reached the end of the test (deadlock?)  *** FAIL ***"); $finish; end
endmodule
