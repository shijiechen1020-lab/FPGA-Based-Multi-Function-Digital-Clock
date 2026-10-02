// =====================================================================
// beep_gen.v -- square wave tone generator for the on-board SPEAKER
//   tone = 0 : silent
//   tone = 1 : low  tone  ~512 Hz
//   tone = 2 : high tone ~1024 Hz
// =====================================================================
`timescale 1ns/1ps
module beep_gen #(
    parameter CLK_HZ = 50000000
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire [1:0] tone,
    output reg        spk
);
    // Keep the constants at their natural 32-bit integer width and do the
    // comparison at 32 bits. Assigning them to a narrower target is what
    // produced the 10230 truncation warnings; zero-extending the counter
    // instead costs nothing after synthesis trims the constant upper bits.
    localparam integer DIV_LO = (CLK_HZ/1024 > 0) ? (CLK_HZ/1024) : 1;  // half period 512 Hz
    localparam integer DIV_HI = (CLK_HZ/2048 > 0) ? (CLK_HZ/2048) : 1;  // half period 1024 Hz

    reg  [16:0] cnt;
    wire [31:0] limit = (tone == 2'd2) ? DIV_HI : DIV_LO;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin cnt <= 17'd0; spk <= 1'b0; end
        else if (tone == 2'd0) begin cnt <= 17'd0; spk <= 1'b0; end
        else if ({15'd0, cnt} >= limit - 32'd1) begin cnt <= 17'd0; spk <= ~spk; end
        else cnt <= cnt + 17'd1;
    end
endmodule
