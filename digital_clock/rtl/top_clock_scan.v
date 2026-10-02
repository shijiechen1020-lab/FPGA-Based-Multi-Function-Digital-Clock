// =====================================================================
// top_clock_scan.v -- alternative TOP for a board where the FPGA drives
// the 7-segment tubes directly (segment bus + digit select).
// NOT needed on the GW48 with structure chart NO.3/NO.5 -- use
// top_clock_gw48.v there. Kept for portability to other boards.
// =====================================================================
`timescale 1ns/1ps
module top_clock_scan #(
    parameter CLK_HZ          = 50000000,
    parameter COMMON_ANODE    = 0,
    parameter SEL_ACTIVE_LOW  = 0,
    parameter KEY_ACTIVE_HIGH = 0,
    parameter KEY_TOGGLE      = 0
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] key,
    output wire [7:0] seg,
    output wire [7:0] sel,
    output wire [7:0] led,
    output wire       speaker
);
    wire [31:0] bcd;
    wire [7:0]  blank, dot;
    wire        en_1khz_scan, d100, d10, d1;

    clock_core #(.CLK_HZ(CLK_HZ),
                 .KEY_ACTIVE_HIGH(KEY_ACTIVE_HIGH),
                 .KEY_TOGGLE(KEY_TOGGLE)) u_core(
        .clk(clk), .rst_n(rst_n), .key_in(key),
        .disp_bcd(bcd), .disp_blank(blank), .disp_dot(dot),
        .led(led), .speaker(speaker));

    clk_gen #(.CLK_HZ(CLK_HZ)) u_scan_tick(
        .clk(clk), .rst_n(rst_n),
        .en_1khz(en_1khz_scan), .en_100hz(d100), .en_10hz(d10), .en_1hz(d1));

    seg_scan #(.COMMON_ANODE(COMMON_ANODE), .SEL_ACTIVE_LOW(SEL_ACTIVE_LOW)) u_scan(
        .clk(clk), .rst_n(rst_n), .en_1khz(en_1khz_scan),
        .bcd(bcd), .blank(blank), .dot(dot), .seg(seg), .sel(sel));
endmodule
