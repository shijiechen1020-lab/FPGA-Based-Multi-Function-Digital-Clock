// =====================================================================
// clk_gen.v  -- tick generator
//
// Two INDEPENDENT chains, on purpose:
//   * timekeeping chain : cnt_cs -> 10 ms -> 100 ms -> 1 s
//     This one must be exact, so CLK_HZ should be a multiple of 100.
//     On GW48 use CLOCK0 = 12 MHz (12_000_000/100 = 120000, exact).
//     Do NOT use 65536 Hz: 65536/100 = 655.36, the rounding would make
//     the clock drift by roughly 8 minutes a day.
//   * housekeeping chain: cnt_ms -> 1 ms, used only for key debounce
//     and display scan, where a fraction of a percent does not matter.
// =====================================================================
`timescale 1ns/1ps
module clk_gen #(
    parameter CLK_HZ = 12000000
)(
    input  wire clk,
    input  wire rst_n,
    output reg  en_1khz,    // ~1 ms   (debounce / scan)
    output reg  en_100hz,   // 10 ms   (exact)
    output reg  en_10hz,    // 100 ms  (exact)
    output reg  en_1hz      // 1 s     (exact)
);
    localparam integer DIV_CS = (CLK_HZ/100  > 0) ? (CLK_HZ/100)  : 1;
    localparam integer DIV_MS = (CLK_HZ/1000 > 0) ? (CLK_HZ/1000) : 1;

    reg [19:0] cnt_cs, cnt_ms;
    reg [3:0]  c10, c100;

    // ---- exact 10 ms ---------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin cnt_cs <= 20'd0; en_100hz <= 1'b0; end
        else if (cnt_cs == DIV_CS-1) begin cnt_cs <= 20'd0; en_100hz <= 1'b1; end
        else begin cnt_cs <= cnt_cs + 20'd1; en_100hz <= 1'b0; end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin c10 <= 4'd0; en_10hz <= 1'b0; end
        else begin
            en_10hz <= 1'b0;
            if (en_100hz) begin
                if (c10 == 4'd9) begin c10 <= 4'd0; en_10hz <= 1'b1; end
                else c10 <= c10 + 4'd1;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin c100 <= 4'd0; en_1hz <= 1'b0; end
        else begin
            en_1hz <= 1'b0;
            if (en_10hz) begin
                if (c100 == 4'd9) begin c100 <= 4'd0; en_1hz <= 1'b1; end
                else c100 <= c100 + 4'd1;
            end
        end
    end

    // ---- approximate 1 ms ----------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin cnt_ms <= 20'd0; en_1khz <= 1'b0; end
        else if (cnt_ms == DIV_MS-1) begin cnt_ms <= 20'd0; en_1khz <= 1'b1; end
        else begin cnt_ms <= cnt_ms + 20'd1; en_1khz <= 1'b0; end
    end
endmodule
