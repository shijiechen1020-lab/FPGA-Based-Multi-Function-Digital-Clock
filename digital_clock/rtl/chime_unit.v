// =====================================================================
// chime_unit.v -- hour chime
//   at mm=59 and ss = 51 / 53 / 55 / 57  -> low tone  (1 s each)
//   at mm=59 and ss = 59                 -> high tone (1 s), the last
//   pulse ends exactly when the new hour begins.
// =====================================================================
`timescale 1ns/1ps
module chime_unit(
    input  wire [3:0] min_h, min_l, sec_h, sec_l,
    input  wire       chime_en,
    output wire       low_beep,
    output wire       high_beep
);
    wire minute59 = (min_h == 4'd5) && (min_l == 4'd9);
    wire sec5x    = (sec_h == 4'd5);

    assign low_beep  = chime_en && minute59 && sec5x &&
                       ((sec_l == 4'd1) || (sec_l == 4'd3) ||
                        (sec_l == 4'd5) || (sec_l == 4'd7));
    assign high_beep = chime_en && minute59 && sec5x && (sec_l == 4'd9);
endmodule
