// =====================================================================
// time_keeper.v -- hh:mm:ss BCD counter chain (24 h) with set / clear
//  - free running when hold = 0 (one step per tick)
//  - counting frozen when hold = 1 (SET mode) so the user can adjust
//  - inc/dec adjust ONE field only, wrapping inside that field
//    (adjusting minutes never disturbs hours -> standard clock behaviour)
// =====================================================================
`timescale 1ns/1ps
module time_keeper(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tick,        // 1 Hz enable
    input  wire       hold,        // 1 = SET mode, counting suspended
    input  wire       inc,
    input  wire       dec,
    input  wire [1:0] field,       // 0 = sec, 1 = min, 2 = hour
    input  wire       clr_all,     // -> 00:00:00
    input  wire       clr_sec,     // seconds -> 00 (time sync)
    output reg  [3:0] sec_l, sec_h, min_l, min_h, hr_l, hr_h,
    output reg        day_pulse    // 23:59:59 -> 00:00:00
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hr_h <= 4'd0; hr_l <= 4'd0;
            min_h<= 4'd0; min_l<= 4'd0;
            sec_h<= 4'd0; sec_l<= 4'd0;
            day_pulse <= 1'b0;
        end else begin
            day_pulse <= 1'b0;

            if (clr_all) begin
                hr_h <= 4'd0; hr_l <= 4'd0;
                min_h<= 4'd0; min_l<= 4'd0;
                sec_h<= 4'd0; sec_l<= 4'd0;
            end
            else if (clr_sec) begin
                sec_h <= 4'd0; sec_l <= 4'd0;
            end
            else if (!hold && tick) begin
                // ---------------- normal counting + carry chain --------
                if (sec_l != 4'd9) sec_l <= sec_l + 4'd1;
                else begin
                    sec_l <= 4'd0;
                    if (sec_h != 4'd5) sec_h <= sec_h + 4'd1;
                    else begin
                        sec_h <= 4'd0;
                        if (min_l != 4'd9) min_l <= min_l + 4'd1;
                        else begin
                            min_l <= 4'd0;
                            if (min_h != 4'd5) min_h <= min_h + 4'd1;
                            else begin
                                min_h <= 4'd0;
                                if (hr_h == 4'd2 && hr_l == 4'd3) begin
                                    hr_h <= 4'd0; hr_l <= 4'd0;
                                    day_pulse <= 1'b1;          // day roll-over
                                end else if (hr_l != 4'd9) hr_l <= hr_l + 4'd1;
                                else begin hr_l <= 4'd0; hr_h <= hr_h + 4'd1; end
                            end
                        end
                    end
                end
            end
            else if (hold && inc) begin
                // ---------------- adjust +1 ----------------------------
                case (field)
                2'd0: if (sec_l != 4'd9) sec_l <= sec_l + 4'd1;
                      else begin sec_l <= 4'd0;
                                 sec_h <= (sec_h == 4'd5) ? 4'd0 : sec_h + 4'd1; end
                2'd1: if (min_l != 4'd9) min_l <= min_l + 4'd1;
                      else begin min_l <= 4'd0;
                                 min_h <= (min_h == 4'd5) ? 4'd0 : min_h + 4'd1; end
                2'd2: if (hr_h == 4'd2 && hr_l == 4'd3) begin hr_h <= 4'd0; hr_l <= 4'd0; end
                      else if (hr_l != 4'd9) hr_l <= hr_l + 4'd1;
                      else begin hr_l <= 4'd0; hr_h <= hr_h + 4'd1; end
                default: ;
                endcase
            end
            else if (hold && dec) begin
                // ---------------- adjust -1 ----------------------------
                case (field)
                2'd0: if (sec_l != 4'd0) sec_l <= sec_l - 4'd1;
                      else begin sec_l <= 4'd9;
                                 sec_h <= (sec_h == 4'd0) ? 4'd5 : sec_h - 4'd1; end
                2'd1: if (min_l != 4'd0) min_l <= min_l - 4'd1;
                      else begin min_l <= 4'd9;
                                 min_h <= (min_h == 4'd0) ? 4'd5 : min_h - 4'd1; end
                2'd2: if (hr_h == 4'd0 && hr_l == 4'd0) begin hr_h <= 4'd2; hr_l <= 4'd3; end
                      else if (hr_l != 4'd0) hr_l <= hr_l - 4'd1;
                      else begin hr_l <= 4'd9; hr_h <= hr_h - 4'd1; end
                default: ;
                endcase
            end
        end
    end
endmodule
