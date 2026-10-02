// =====================================================================
// tb_clock_core.v -- system level test
// CLK_HZ is overridden to 1000 so that 1 "second" = 1000 clock cycles
// (20 us at a 20 ns clock). Covers: reset, mode FSM, key debounce and
// time setting, hour chime, day roll-over, alarm ring + stop,
// stopwatch with lap, countdown with expiry beep.
// =====================================================================
`timescale 1ns/1ps
module tb_clock_core;
    reg clk = 0, rst_n = 0;
    reg [7:0] key_in = 8'h00;         // 琴键式: released = low
    wire [31:0] bcd;
    wire [7:0]  blank, dot;
    wire [7:0]  led;
    wire        speaker;
    integer errors = 0;
    integer i;

    localparam K_MODE=0, K_SEL=1, K_INC=2, K_DEC=3, K_START=4, K_CLR=5,
               K_ALMEN=6, K_12H=7;

    clock_core #(.CLK_HZ(1000)) dut(
        .clk(clk), .rst_n(rst_n), .key_in(key_in),
        .disp_bcd(bcd), .disp_blank(blank), .disp_dot(dot),
        .led(led), .speaker(speaker));

    always #10 clk = ~clk;

    // display helpers
    wire [7:0] shown_hi = bcd[31:28]*10 + bcd[27:24];
    wire [7:0] shown_md = bcd[23:20]*10 + bcd[19:16];
    wire [7:0] shown_lo = bcd[15:12]*10 + bcd[11:8];
    wire [3:0] shown_mode = bcd[7:4];

    task press; input integer k;
        begin
            key_in[k] = 1'b1; repeat (20) @(posedge clk);
            key_in[k] = 1'b0; repeat (20) @(posedge clk);
        end
    endtask

    task press_n; input integer k; input integer n; integer j;
        begin for (j=0;j<n;j=j+1) press(k); end
    endtask

    task wait_sec; input integer n; begin repeat (n) @(posedge dut.en_1hz); end endtask

    task expect_eq; input [8*40:1] name; input [15:0] got; input [15:0] exp;
        begin
            if (got !== exp) begin
                errors = errors + 1;
                $display("  [FAIL] %0s : got %0d expected %0d", name, got, exp);
            end else $display("  [ OK ] %0s = %0d", name, got);
        end
    endtask

    initial begin
        $dumpfile("tb_clock_core.vcd"); $dumpvars(0, tb_clock_core);
        $display("=== tb_clock_core ===");
        repeat (10) @(posedge clk); rst_n = 1; repeat (10) @(posedge clk);

        // ---------- 1. reset state -------------------------------------
        expect_eq("reset mode (0=RUN)", shown_mode, 0);
        expect_eq("reset HH", shown_hi, 0);
        expect_eq("reset MM", shown_md, 0);
        expect_eq("reset SS", shown_lo, 0);

        // ---------- 2. free running ------------------------------------
        wait_sec(3); repeat (5) @(posedge clk);
        expect_eq("after 3 s, SS", shown_lo, 3);

        // ---------- 3. mode FSM ----------------------------------------
        press(K_MODE); expect_eq("MODE x1 -> SET",   shown_mode, 1);
        press(K_MODE); expect_eq("MODE x2 -> ALARM", shown_mode, 2);
        press(K_MODE); expect_eq("MODE x3 -> SW",    shown_mode, 3);
        press(K_MODE); expect_eq("MODE x4 -> CD",    shown_mode, 4);
        press(K_MODE); expect_eq("MODE x5 -> RUN",   shown_mode, 0);

        // ---------- 4. time setting via keys ---------------------------
        press(K_MODE);                       // -> SET, field = sec
        press(K_SEL);                        // -> field = min
        press_n(K_INC, 5);                   // minutes +5
        press(K_SEL);                        // -> field = hour
        press_n(K_INC, 8);                   // hours +8
        press_n(K_MODE, 4);                  // back to RUN
        expect_eq("set HH via keys", shown_hi, 8);
        expect_eq("set MM via keys", shown_md, 5);
        expect_eq("back in RUN",     shown_mode, 0);

        // ---------- 5. hour chime + day roll-over ----------------------
        $display("  -- chime / roll-over trace (tone: 0=off 1=low 2=high) --");
        force dut.u_time.hr_h=2; force dut.u_time.hr_l=3;
        force dut.u_time.min_h=5; force dut.u_time.min_l=9;
        force dut.u_time.sec_h=4; force dut.u_time.sec_l=9;
        repeat (2) @(posedge clk);
        release dut.u_time.hr_h; release dut.u_time.hr_l;
        release dut.u_time.min_h; release dut.u_time.min_l;
        release dut.u_time.sec_h; release dut.u_time.sec_l;

        for (i = 0; i < 12; i = i + 1) begin
            @(posedge dut.en_1hz); repeat (5) @(posedge clk);
            $display("     %02d:%02d:%02d  tone=%0d", shown_hi, shown_md, shown_lo, dut.tone);
            if (shown_hi==23 && shown_md==59 &&
                (shown_lo==51||shown_lo==53||shown_lo==55||shown_lo==57)) begin
                if (dut.tone !== 2'd1) begin errors=errors+1;
                    $display("  [FAIL] expected LOW chime at :%0d", shown_lo); end
            end else if (shown_hi==23 && shown_md==59 && shown_lo==59) begin
                if (dut.tone !== 2'd2) begin errors=errors+1;
                    $display("  [FAIL] expected HIGH chime at :59"); end
            end else if (dut.tone !== 2'd0) begin
                errors=errors+1; $display("  [FAIL] unexpected tone at %02d:%02d:%02d",
                                          shown_hi, shown_md, shown_lo);
            end
        end
        expect_eq("day roll-over HH", shown_hi, 0);
        expect_eq("day roll-over MM", shown_md, 0);

        // ---------- 6. alarm -------------------------------------------
        force dut.u_alarm.al_hr_h=0; force dut.u_alarm.al_hr_l=0;
        force dut.u_alarm.al_mn_h=0; force dut.u_alarm.al_mn_l=1;   // 00:01
        repeat (2) @(posedge clk);
        release dut.u_alarm.al_hr_h; release dut.u_alarm.al_hr_l;
        release dut.u_alarm.al_mn_h; release dut.u_alarm.al_mn_l;
        // alarm enable defaults to ON after reset
        expect_eq("alarm enabled by default", dut.sw_alarm_en, 1);
        while (!(shown_md == 1 && shown_lo == 0)) @(posedge dut.en_1hz);
        repeat (5) @(posedge clk);
        expect_eq("alarm ringing at 00:01:00", dut.ringing, 1);
        press(K_START);
        expect_eq("START stops the ring", dut.ringing, 0);
        wait_sec(2); repeat (5) @(posedge clk);
        expect_eq("no re-trigger in same minute", dut.ringing, 0);
        press(K_ALMEN);
        expect_eq("key 7 turns the alarm off", dut.sw_alarm_en, 0);
        press(K_12H);
        expect_eq("key 8 switches to 12 h mode", dut.sw_12h, 1);
        press(K_12H);

        // ---------- 7. stopwatch ---------------------------------------
        press_n(K_MODE, 3);                  // RUN -> SET -> ALM -> SW
        expect_eq("mode = stopwatch", shown_mode, 3);
        press(K_START);
        repeat (500) @(posedge clk);         // ~0.5 s
        $display("     stopwatch reads %02d:%02d.%02d", shown_hi, shown_md, shown_lo);
        if (shown_lo < 40 || shown_lo > 60) begin
            errors=errors+1; $display("  [FAIL] stopwatch centiseconds out of range"); end
        else $display("  [ OK ] stopwatch ~0.5 s");
        press(K_SEL);                        // LAP hold
        expect_eq("lap hold active", dut.u_sw.lap_hold, 1);
        begin : lap_chk
            reg [7:0] frozen;
            frozen = shown_lo;
            repeat (300) @(posedge clk);
            expect_eq("display frozen during lap", shown_lo, frozen);
        end
        press(K_SEL);                        // release lap
        press(K_START);                      // stop
        press(K_CLR);
        expect_eq("stopwatch cleared", shown_lo, 0);

        // ---------- 8. countdown ---------------------------------------
        press(K_MODE);
        expect_eq("mode = countdown", shown_mode, 4);
        press_n(K_INC, 3);                   // 00:03 (field 0 = seconds)
        expect_eq("countdown preset SS", shown_lo, 3);
        press(K_START);
        wait_sec(4); repeat (5) @(posedge clk);
        expect_eq("countdown reached 00", shown_lo, 0);
        expect_eq("expiry beep active",   dut.cd_ring, 1);
        press(K_CLR);
        expect_eq("CLR stops expiry beep", dut.cd_ring, 0);

        $display("=== tb_clock_core finished, %0d error(s) ===", errors);
        $finish;
    end
endmodule
