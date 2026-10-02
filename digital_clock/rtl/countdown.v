// =====================================================================
// countdown.v -- mm:ss countdown timer
//   set with inc/dec while stopped, counts down 1 step per tick,
//   emits a 1-cycle "expired" pulse when it reaches 00:00.
// =====================================================================
`timescale 1ns/1ps
module countdown(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tick,        // 1 Hz
    input  wire       run,
    input  wire       inc,
    input  wire       dec,
    input  wire [1:0] field,       // 0 = sec, 1 = min
    input  wire       clr,
    output reg  [3:0] s_l, s_h, m_l, m_h,
    output wire       zero,
    output reg        expired
);
    assign zero = (s_l==4'd0) && (s_h==4'd0) && (m_l==4'd0) && (m_h==4'd0);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_l<=0; s_h<=0; m_l<=0; m_h<=0; expired<=1'b0;
        end else begin
            expired <= 1'b0;

            if (clr) begin s_l<=0; s_h<=0; m_l<=0; m_h<=0; end
            else if (run && tick && !zero) begin
                if (m_h==4'd0 && m_l==4'd0 && s_h==4'd0 && s_l==4'd1) expired <= 1'b1;
                if (s_l != 4'd0) s_l <= s_l - 4'd1;
                else begin
                    s_l <= 4'd9;
                    if (s_h != 4'd0) s_h <= s_h - 4'd1;
                    else begin
                        s_h <= 4'd5;
                        if (m_l != 4'd0) m_l <= m_l - 4'd1;
                        else begin m_l <= 4'd9; m_h <= m_h - 4'd1; end
                    end
                end
            end
            else if (!run && inc) begin
                case (field)
                2'd0: if (s_l != 4'd9) s_l <= s_l + 4'd1;
                      else begin s_l <= 4'd0; s_h <= (s_h==4'd5) ? 4'd0 : s_h + 4'd1; end
                2'd1: if (m_l != 4'd9) m_l <= m_l + 4'd1;
                      else begin m_l <= 4'd0; m_h <= (m_h==4'd5) ? 4'd0 : m_h + 4'd1; end
                default: ;
                endcase
            end
            else if (!run && dec) begin
                case (field)
                2'd0: if (s_l != 4'd0) s_l <= s_l - 4'd1;
                      else begin s_l <= 4'd9; s_h <= (s_h==4'd0) ? 4'd5 : s_h - 4'd1; end
                2'd1: if (m_l != 4'd0) m_l <= m_l - 4'd1;
                      else begin m_l <= 4'd9; m_h <= (m_h==4'd0) ? 4'd5 : m_h - 4'd1; end
                default: ;
                endcase
            end
        end
    end
endmodule
