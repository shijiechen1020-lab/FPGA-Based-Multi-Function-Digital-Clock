// =====================================================================
// tb_time_keeper.v -- boundary tests on the hh:mm:ss counter chain
// tick is asserted every clock so a full 24 h takes only 86400 clocks.
// Covers: sec/min/hour carry, 23:59:59 -> 00:00:00 (day roll-over),
//         field-limited setting, clear-all and clear-seconds.
// =====================================================================
`timescale 1ns/1ps
module tb_time_keeper;
    reg clk = 0, rst_n = 0, tick = 0, hold = 0, inc = 0, dec = 0;
    reg [1:0] field = 0;
    reg clr_all = 0, clr_sec = 0;
    wire [3:0] sec_l, sec_h, min_l, min_h, hr_l, hr_h;
    wire day_pulse;
    integer errors = 0;
    integer i;
    integer day_cnt = 0;

    time_keeper dut(.clk(clk), .rst_n(rst_n), .tick(tick), .hold(hold),
                    .inc(inc), .dec(dec), .field(field),
                    .clr_all(clr_all), .clr_sec(clr_sec),
                    .sec_l(sec_l), .sec_h(sec_h), .min_l(min_l),
                    .min_h(min_h), .hr_l(hr_l), .hr_h(hr_h),
                    .day_pulse(day_pulse));

    always #10 clk = ~clk;
    always @(posedge clk) if (day_pulse) day_cnt = day_cnt + 1;

    task check;
        input [8*40:1] name;
        input [7:0] eh, em, es;
        reg [7:0] gh, gm, gs;
        begin
            gh = hr_h*10 + hr_l; gm = min_h*10 + min_l; gs = sec_h*10 + sec_l;
            if (gh !== eh || gm !== em || gs !== es) begin
                errors = errors + 1;
                $display("  [FAIL] t=%0t %0s : got %02d:%02d:%02d expected %02d:%02d:%02d",
                         $time, name, gh, gm, gs, eh, em, es);
            end else
                $display("  [ OK ] t=%0t %0s : %02d:%02d:%02d", $time, name, gh, gm, gs);
        end
    endtask

    task run_sec; input integer n; integer j;
        begin for (j=0;j<n;j=j+1) begin @(negedge clk); tick=1; @(negedge clk); tick=0; end end
    endtask

    initial begin
        $dumpfile("tb_time_keeper.vcd"); $dumpvars(0, tb_time_keeper);
        $display("=== tb_time_keeper ===");
        repeat (4) @(negedge clk); rst_n = 1; @(negedge clk);
        check("reset value", 0, 0, 0);

        run_sec(59);  check("59 s (sec carry edge)", 0, 0, 59);
        run_sec(1);   check("60 s -> 00:01:00",      0, 1,  0);
        run_sec(3540);check("3600 s -> 01:00:00",    1, 0,  0);

        // jump close to midnight
        force dut.hr_h=2; force dut.hr_l=3; force dut.min_h=5;
        force dut.min_l=9; force dut.sec_h=5; force dut.sec_l=8;
        @(negedge clk);
        release dut.hr_h; release dut.hr_l; release dut.min_h;
        release dut.min_l; release dut.sec_h; release dut.sec_l;
        check("preload 23:59:58", 23, 59, 58);
        run_sec(1);   check("23:59:59",              23, 59, 59);
        run_sec(1);   check("day roll-over 00:00:00", 0,  0,  0);
        @(negedge clk);            // let the monitor sample the 1-cycle pulse
        if (day_cnt !== 1) begin errors=errors+1; $display("  [FAIL] day_pulse count = %0d", day_cnt); end
        else $display("  [ OK ] day_pulse asserted exactly once");

        // ---- SET mode: minutes must wrap without touching hours ----------
        run_sec(3725);                       // 01:02:05
        check("free run 01:02:05", 1, 2, 5);
        hold = 1; field = 2'd1;              // minutes
        for (i=0;i<58;i=i+1) begin @(negedge clk); inc=1; @(negedge clk); inc=0; end
        check("min +58 wraps 02->00 keeping hour", 1, 0, 5);
        field = 2'd2;                        // hours
        for (i=0;i<23;i=i+1) begin @(negedge clk); inc=1; @(negedge clk); inc=0; end
        check("hour +23 wraps 01->00", 0, 0, 5);
        @(negedge clk); dec=1; @(negedge clk); dec=0;
        check("hour -1 wraps 00->23", 23, 0, 5);

        // counting must be frozen while hold = 1
        run_sec(10);
        check("frozen during SET", 23, 0, 5);
        hold = 0;
        run_sec(5);
        check("resumes after SET", 23, 0, 10);

        // ---- clear ------------------------------------------------------
        @(negedge clk); clr_sec=1; @(negedge clk); clr_sec=0;
        check("clr_sec keeps hh:mm", 23, 0, 0);
        run_sec(70);
        @(negedge clk); clr_all=1; @(negedge clk); clr_all=0;
        check("clr_all -> 00:00:00", 0, 0, 0);

        $display("=== tb_time_keeper finished, %0d error(s) ===", errors);
        $finish;
    end
endmodule
