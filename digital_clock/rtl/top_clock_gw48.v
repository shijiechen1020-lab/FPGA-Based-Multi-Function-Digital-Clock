// =====================================================================
// top_clock_gw48.v -- TOP LEVEL for the GW48-CK + GW3C5 (EP3C5T144)
//
// Wired for 实验电路结构图 NO.3 (琴键式 keys: press = high, release = low)
//   数码管 1..8  <- PIO16..PIO47, four bits each, decoded on the board
//   发光管 D1..D8 <- PIO8..PIO15
//   键1..键8      -> PIO0..PIO7
//   SPEAKER, CLOCK0
//
// For 结构图 NO.5 (level-toggle keys) set KEY_TOGGLE = 1; the pinout is
// identical, only the key behaviour differs.
//
// The board decoder is a full hex decoder, so a digit cannot be blanked:
// "blanked" positions are driven to 0 and the setting indication is put
// on the LEDs instead.
//
// There is no external reset: the FPGA has no reset pin on this board
// (the panel 复位键 only resets the on-board monitor), so a power-on
// reset is generated internally.
// =====================================================================
`timescale 1ns/1ps
module top_clock_gw48 #(
    parameter CLK_HZ          = 12000000,  // CLOCK0 jumper -> 12 MHz
    parameter KEY_ACTIVE_HIGH = 1,
    parameter KEY_TOGGLE      = 0          // 0 = NO.3, 1 = NO.0 / NO.5
)(
    input  wire        clk,          // CLOCK0
    input  wire [7:0]  key,          // 键1..键8
    output wire [31:0] seg_bcd,      // {数码8 .. 数码1}, 4 bits each
    output wire [7:0]  led,          // D1..D8
    output wire        speaker
);
    // ---- power-on reset -------------------------------------------------
    // All registers come up as 0 after configuration, so por_cnt starts at
    // 0 and rst_n stays low for the first 4096 clocks (~0.34 ms @ 12 MHz).
    reg [11:0] por_cnt = 12'd0;
    reg        rst_n   = 1'b0;
    always @(posedge clk) begin
        if (por_cnt != 12'hFFF) por_cnt <= por_cnt + 12'd1;
        else                    rst_n   <= 1'b1;
    end

    wire [31:0] bcd;
    wire [7:0]  blank, dot;

    clock_core #(.CLK_HZ(CLK_HZ),
                 .KEY_ACTIVE_HIGH(KEY_ACTIVE_HIGH),
                 .KEY_TOGGLE(KEY_TOGGLE)) u_core(
        .clk(clk), .rst_n(rst_n), .key_in(key),
        .disp_bcd(bcd), .disp_blank(blank), .disp_dot(dot),
        .led(led), .speaker(speaker));

    // blanked positions -> 0 (the on-board hex decoder has no blank input)
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : g_dig
            assign seg_bcd[i*4 +: 4] = blank[i] ? 4'd0 : bcd[i*4 +: 4];
        end
    endgenerate
endmodule
