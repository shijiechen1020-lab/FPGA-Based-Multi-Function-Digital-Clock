// =====================================================================
// stopwatch.v -- mm:ss.cc stopwatch, 10 ms resolution
//   run   : level, 1 = counting
//   clr   : clear counters and release the lap hold
//   lap   : toggles "hold display" (split time) while counting continues
// =====================================================================
`timescale 1ns/1ps
module stopwatch(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       en_100hz,     // 10 ms
    input  wire       run,
    input  wire       clr,
    input  wire       lap,          // 1-cycle pulse
    output wire [3:0] d_cs_l, d_cs_h, d_s_l, d_s_h, d_m_l, d_m_h,
    output reg        lap_hold
);
    reg [3:0] cs_l, cs_h, s_l, s_h, m_l, m_h;
    reg [23:0] latched;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cs_l<=0; cs_h<=0; s_l<=0; s_h<=0; m_l<=0; m_h<=0;
        end else if (clr) begin
            cs_l<=0; cs_h<=0; s_l<=0; s_h<=0; m_l<=0; m_h<=0;
        end else if (run && en_100hz) begin
            if (cs_l != 4'd9) cs_l <= cs_l + 4'd1;
            else begin
                cs_l <= 4'd0;
                if (cs_h != 4'd9) cs_h <= cs_h + 4'd1;
                else begin
                    cs_h <= 4'd0;
                    if (s_l != 4'd9) s_l <= s_l + 4'd1;
                    else begin
                        s_l <= 4'd0;
                        if (s_h != 4'd5) s_h <= s_h + 4'd1;
                        else begin
                            s_h <= 4'd0;
                            if (m_l != 4'd9) m_l <= m_l + 4'd1;
                            else begin m_l <= 4'd0;
                                       m_h <= (m_h == 4'd5) ? 4'd0 : m_h + 4'd1; end
                        end
                    end
                end
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin lap_hold <= 1'b0; latched <= 24'd0; end
        else if (clr) begin lap_hold <= 1'b0; latched <= 24'd0; end
        else if (lap) begin
            if (!lap_hold) begin latched <= {m_h,m_l,s_h,s_l,cs_h,cs_l}; lap_hold <= 1'b1; end
            else lap_hold <= 1'b0;
        end
    end

    assign {d_m_h,d_m_l,d_s_h,d_s_l,d_cs_h,d_cs_l} =
           lap_hold ? latched : {m_h,m_l,s_h,s_l,cs_h,cs_l};
endmodule
