// =====================================================================
// bin2seg.v -- BCD -> 7 segment, seg = {dp,g,f,e,d,c,b,a}
// COMMON_ANODE = 0 : common cathode, segment lit by '1'
// COMMON_ANODE = 1 : common anode,   segment lit by '0'
// =====================================================================
`timescale 1ns/1ps
module bin2seg #(
    parameter COMMON_ANODE = 0
)(
    input  wire [3:0] bcd,
    input  wire       blank,
    input  wire       dp,
    output wire [7:0] seg
);
    reg [6:0] pat;
    always @(*) begin
        case (bcd)
        4'd0: pat = 7'h3F;  4'd1: pat = 7'h06;
        4'd2: pat = 7'h5B;  4'd3: pat = 7'h4F;
        4'd4: pat = 7'h66;  4'd5: pat = 7'h6D;
        4'd6: pat = 7'h7D;  4'd7: pat = 7'h07;
        4'd8: pat = 7'h7F;  4'd9: pat = 7'h6F;
        default: pat = 7'h00;               // A..F are displayed blank
        endcase
    end
    wire [7:0] raw = blank ? 8'h00 : {dp, pat};
    assign seg = COMMON_ANODE ? ~raw : raw;
endmodule
