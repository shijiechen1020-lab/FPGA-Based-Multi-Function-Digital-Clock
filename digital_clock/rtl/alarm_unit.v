// =====================================================================
// alarm_unit.v -- alarm time register + match + ring timer
// Rings for RING_SEC seconds, or until the STOP key / alarm switch off.
// "armed" prevents re-triggering inside the same matching second.
// =====================================================================
`timescale 1ns/1ps
module alarm_unit #(
    parameter RING_SEC = 60
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tick,          // 1 Hz
    input  wire       set_mode,      // 1 = alarm-set mode
    input  wire       inc,
    input  wire       dec,
    input  wire [1:0] field,         // 0 = min, 1 = hour
    input  wire [3:0] hr_h, hr_l, min_h, min_l, sec_h, sec_l,
    input  wire       alarm_en,
    input  wire       stop,
    output reg  [3:0] al_hr_h, al_hr_l, al_mn_h, al_mn_l,
    output reg        ringing
);
    reg  [6:0] ring_cnt;
    reg        armed;

    wire match = alarm_en &&
                 (hr_h == al_hr_h) && (hr_l == al_hr_l) &&
                 (min_h == al_mn_h) && (min_l == al_mn_l) &&
                 (sec_h == 4'd0) && (sec_l == 4'd0);

    // ---- alarm time setting -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            al_hr_h <= 4'd0; al_hr_l <= 4'd7;    // default 07:30
            al_mn_h <= 4'd3; al_mn_l <= 4'd0;
        end else if (set_mode && inc) begin
            case (field)
            2'd0: if (al_mn_l != 4'd9) al_mn_l <= al_mn_l + 4'd1;
                  else begin al_mn_l <= 4'd0;
                             al_mn_h <= (al_mn_h == 4'd5) ? 4'd0 : al_mn_h + 4'd1; end
            2'd1: if (al_hr_h == 4'd2 && al_hr_l == 4'd3) begin al_hr_h <= 4'd0; al_hr_l <= 4'd0; end
                  else if (al_hr_l != 4'd9) al_hr_l <= al_hr_l + 4'd1;
                  else begin al_hr_l <= 4'd0; al_hr_h <= al_hr_h + 4'd1; end
            default: ;
            endcase
        end else if (set_mode && dec) begin
            case (field)
            2'd0: if (al_mn_l != 4'd0) al_mn_l <= al_mn_l - 4'd1;
                  else begin al_mn_l <= 4'd9;
                             al_mn_h <= (al_mn_h == 4'd0) ? 4'd5 : al_mn_h - 4'd1; end
            2'd1: if (al_hr_h == 4'd0 && al_hr_l == 4'd0) begin al_hr_h <= 4'd2; al_hr_l <= 4'd3; end
                  else if (al_hr_l != 4'd0) al_hr_l <= al_hr_l - 4'd1;
                  else begin al_hr_l <= 4'd9; al_hr_h <= al_hr_h - 4'd1; end
            default: ;
            endcase
        end
    end

    // ---- ring control --------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin ringing <= 1'b0; ring_cnt <= 7'd0; armed <= 1'b1; end
        else begin
            if (!match) armed <= 1'b1;

            if (stop || !alarm_en) begin
                ringing  <= 1'b0;
                ring_cnt <= 7'd0;
                if (match) armed <= 1'b0;      // do not restart in same second
            end else if (match && armed) begin
                ringing  <= 1'b1;
                ring_cnt <= 7'd0;
                armed    <= 1'b0;
            end else if (ringing && tick) begin
                if (ring_cnt == RING_SEC-1) begin ringing <= 1'b0; ring_cnt <= 7'd0; end
                else ring_cnt <= ring_cnt + 7'd1;
            end
        end
    end
endmodule
