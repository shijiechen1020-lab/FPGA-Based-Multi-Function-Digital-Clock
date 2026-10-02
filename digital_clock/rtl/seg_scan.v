// =====================================================================
// seg_scan.v -- 8 digit dynamic scan, 1 kHz per digit (125 Hz refresh)
// Digit 7 is the left-most tube (digital tube 8 on the GW48 panel).
// =====================================================================
`timescale 1ns/1ps
module seg_scan #(
    parameter COMMON_ANODE   = 0,
    parameter SEL_ACTIVE_LOW = 0
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        en_1khz,
    input  wire [31:0] bcd,      // {d7,d6,d5,d4,d3,d2,d1,d0}
    input  wire [7:0]  blank,
    input  wire [7:0]  dot,
    output wire [7:0]  seg,
    output wire [7:0]  sel
);
    reg [2:0] idx;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) idx <= 3'd0;
        else if (en_1khz) idx <= idx + 3'd1;
    end

    wire [3:0] cur_bcd   = bcd[idx*4 +: 4];
    wire       cur_blank = blank[idx];
    wire       cur_dot   = dot[idx];

    bin2seg #(.COMMON_ANODE(COMMON_ANODE)) u_dec(
        .bcd(cur_bcd), .blank(cur_blank), .dp(cur_dot), .seg(seg));

    wire [7:0] onehot = (8'd1 << idx);
    assign sel = SEL_ACTIVE_LOW ? ~onehot : onehot;
endmodule
