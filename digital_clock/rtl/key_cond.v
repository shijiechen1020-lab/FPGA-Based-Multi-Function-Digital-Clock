// =====================================================================
// key_cond.v -- key debounce + press detect + long-press auto repeat
//
// The GW48 key behaviour depends on the structure chart in use:
//   ACTIVE_HIGH=1, TOGGLE_STYLE=0 : NO.3 keyboard-style keys
//        (press -> high, release -> low)  <-- recommended
//   ACTIVE_HIGH=1, TOGGLE_STYLE=1 : NO.0 / NO.5 level generators
//        (each press flips the level, so BOTH edges are one press and
//         there is no "held" state, hence no auto repeat)
//   ACTIVE_HIGH=0                 : ordinary active-low push button
// =====================================================================
`timescale 1ns/1ps
module key_cond #(
    parameter ACTIVE_HIGH     = 1,
    parameter TOGGLE_STYLE    = 0,
    parameter REPEAT_DELAY_MS = 600,
    parameter REPEAT_RATE_MS  = 120
)(
    input  wire clk,
    input  wire rst_n,
    input  wire en_1khz,
    input  wire key_in,
    output reg  key_down,     // 1-cycle pulse, one per physical press
    output reg  key_rep,      // press pulse + auto repeat (momentary only)
    output wire key_level
);
    wire raw = ACTIVE_HIGH ? key_in : ~key_in;   // 1 = pressed

    reg [3:0]  shift;
    reg        stable, stable_d;
    reg [11:0] hold_ms;
    reg        repeating;
    reg [3:0]  boot;        // startup mask: ignore key events until the
    reg        started;     // debouncer has seen a full stable window

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin shift <= 4'h0; stable <= 1'b0; end
        else if (en_1khz) begin
            shift <= {shift[2:0], raw};
            if      (shift == 4'hF) stable <= 1'b1;
            else if (shift == 4'h0) stable <= 1'b0;
        end
    end
    assign key_level = stable;

    // Reset values above are constants on purpose: loading a signal on an
    // asynchronous reset forces the synthesiser to build register+latch
    // equivalents. The startup mask below covers the one side effect --
    // a key already held at power-up would otherwise register as a press.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin boot <= 4'd0; started <= 1'b0; end
        else if (en_1khz && !started) begin
            if (boot == 4'd8) started <= 1'b1;
            else boot <= boot + 4'd1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin stable_d <= 1'b0; key_down <= 1'b0; end
        else begin
            stable_d <= stable;
            key_down <= started & (TOGGLE_STYLE ? (stable ^ stable_d)   // any edge
                                                : (stable & ~stable_d)); // press edge
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin hold_ms <= 12'd0; repeating <= 1'b0; key_rep <= 1'b0; end
        else begin
            key_rep <= key_down;
            if (TOGGLE_STYLE) begin
                hold_ms <= 12'd0; repeating <= 1'b0;   // no hold state exists
            end else if (!stable) begin
                hold_ms <= 12'd0; repeating <= 1'b0;
            end else if (en_1khz) begin
                if (!repeating) begin
                    if (hold_ms == REPEAT_DELAY_MS-1) begin
                        repeating <= 1'b1; hold_ms <= 12'd0; key_rep <= 1'b1;
                    end else hold_ms <= hold_ms + 12'd1;
                end else begin
                    if (hold_ms == REPEAT_RATE_MS-1) begin
                        hold_ms <= 12'd0; key_rep <= 1'b1;
                    end else hold_ms <= hold_ms + 12'd1;
                end
            end
        end
    end
endmodule
