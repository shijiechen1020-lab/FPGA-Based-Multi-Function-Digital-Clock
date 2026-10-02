// =====================================================================
// clock_core.v -- digital clock core (mode FSM + all function blocks)
//
// KEYS (active low)                 SWITCHES
//   key_n[0] MODE   mode switch       sw_alarm_en : alarm on/off
//   key_n[1] SEL    field select      sw_12h      : 0 = 24 h, 1 = 12 h
//   key_n[2] INC    +1 (auto repeat)
//   key_n[3] DEC    -1 (auto repeat)
//   key_n[4] START  start/stop, stop ringing
//   key_n[5] CLR    clear
//
// MODES: 0 RUN | 1 SET time | 2 SET alarm | 3 stopwatch | 4 countdown
//
// DISPLAY (digit 7 = left-most)
//   RUN / SET : HH MM SS  + d1 = mode  + d0 = {alarm_en, chime_en}
//   ALARM     : HH MM --  + d1 = 2     + d0 = {alarm_en, chime_en}
//   STOPWATCH : MM SS CC  + d1 = 3     + d0 = running
//   COUNTDOWN : -- MM SS  + d1 = 4     + d0 = running
// =====================================================================
`timescale 1ns/1ps
module clock_core #(
    parameter CLK_HZ          = 12000000,
    parameter KEY_ACTIVE_HIGH = 1,       // GW48 NO.3 / NO.5 keys are active high
    parameter KEY_TOGGLE      = 0        // 1 for NO.0 / NO.5 level generators
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [7:0]  key_in,       // 键1..键8 straight from the board
    output wire [31:0] disp_bcd,
    output wire [7:0]  disp_blank,
    output wire [7:0]  disp_dot,
    output wire [7:0]  led,          // D1..D8
    output wire        speaker
);
    localparam M_RUN = 3'd0, M_SET = 3'd1, M_ALM = 3'd2, M_SW = 3'd3, M_CD = 3'd4;

    // ---------------- ticks --------------------------------------------
    wire en_1khz, en_100hz, en_10hz, en_1hz;
    clk_gen #(.CLK_HZ(CLK_HZ)) u_tick(
        .clk(clk), .rst_n(rst_n),
        .en_1khz(en_1khz), .en_100hz(en_100hz),
        .en_10hz(en_10hz), .en_1hz(en_1hz));

    // ---------------- keys ---------------------------------------------
    wire [7:0] k_down, k_rep, k_lvl;
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : g_key
            key_cond #(.ACTIVE_HIGH(KEY_ACTIVE_HIGH), .TOGGLE_STYLE(KEY_TOGGLE)) u_key(
                .clk(clk), .rst_n(rst_n), .en_1khz(en_1khz),
                .key_in(key_in[i]),
                .key_down(k_down[i]), .key_rep(k_rep[i]), .key_level(k_lvl[i]));
        end
    endgenerate

    wire k_mode  = k_down[0];
    wire k_sel   = k_down[1];
    wire k_inc   = k_rep [2];
    wire k_dec   = k_rep [3];
    wire k_start = k_down[4];
    wire k_clr   = k_down[5];

    // 键7 / 键8 are latched into flags instead of needing real switches
    reg sw_alarm_en, sw_12h;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin sw_alarm_en <= 1'b1; sw_12h <= 1'b0; end
        else begin
            if (k_down[6]) sw_alarm_en <= ~sw_alarm_en;
            if (k_down[7]) sw_12h      <= ~sw_12h;
        end
    end

    // ---------------- mode FSM / field / chime enable -------------------
    reg [2:0] mode;
    reg [1:0] field;
    reg       chime_en;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin mode <= M_RUN; field <= 2'd0; chime_en <= 1'b1; end
        else if (k_mode) begin
            mode  <= (mode == M_CD) ? M_RUN : mode + 3'd1;
            field <= 2'd0;
        end else if (k_sel) begin
            case (mode)
            M_RUN: chime_en <= ~chime_en;
            M_SET: field <= (field == 2'd2) ? 2'd0 : field + 2'd1;
            M_ALM: field <= field[0] ? 2'd0 : 2'd1;
            M_CD : field <= field[0] ? 2'd0 : 2'd1;
            default: ;
            endcase
        end
    end

    // ---------------- time keeper ---------------------------------------
    wire [3:0] sec_l, sec_h, min_l, min_h, hr_l, hr_h;
    wire       day_pulse;

    time_keeper u_time(
        .clk(clk), .rst_n(rst_n), .tick(en_1hz),
        .hold (mode == M_SET),
        .inc  (k_inc && (mode == M_SET)),
        .dec  (k_dec && (mode == M_SET)),
        .field(field),
        .clr_all(k_clr && (mode == M_SET)),
        .clr_sec(k_clr && (mode == M_RUN)),
        .sec_l(sec_l), .sec_h(sec_h),
        .min_l(min_l), .min_h(min_h),
        .hr_l (hr_l ), .hr_h (hr_h ),
        .day_pulse(day_pulse));

    // ---------------- alarm ---------------------------------------------
    wire [3:0] al_hr_h, al_hr_l, al_mn_h, al_mn_l;
    wire       ringing;

    alarm_unit u_alarm(
        .clk(clk), .rst_n(rst_n), .tick(en_1hz),
        .set_mode(mode == M_ALM),
        .inc(k_inc && (mode == M_ALM)),
        .dec(k_dec && (mode == M_ALM)),
        .field(field),
        .hr_h(hr_h), .hr_l(hr_l), .min_h(min_h), .min_l(min_l),
        .sec_h(sec_h), .sec_l(sec_l),
        .alarm_en(sw_alarm_en),
        .stop(k_start && (mode == M_RUN)),
        .al_hr_h(al_hr_h), .al_hr_l(al_hr_l),
        .al_mn_h(al_mn_h), .al_mn_l(al_mn_l),
        .ringing(ringing));

    // ---------------- hour chime ----------------------------------------
    wire low_beep, high_beep;
    chime_unit u_chime(
        .min_h(min_h), .min_l(min_l), .sec_h(sec_h), .sec_l(sec_l),
        .chime_en(chime_en), .low_beep(low_beep), .high_beep(high_beep));

    // ---------------- stopwatch / countdown run control ------------------
    reg sw_run, cd_run;
    wire cd_zero, cd_expired;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin sw_run <= 1'b0; cd_run <= 1'b0; end
        else begin
            if (k_start && (mode == M_SW)) sw_run <= ~sw_run;
            if (k_clr   && (mode == M_SW)) sw_run <= 1'b0;
            if (k_start && (mode == M_CD)) cd_run <= cd_run ? 1'b0 : ~cd_zero;
            if (k_clr   && (mode == M_CD)) cd_run <= 1'b0;
            if (cd_expired)                cd_run <= 1'b0;
        end
    end

    wire [3:0] sw_cs_l, sw_cs_h, sw_s_l, sw_s_h, sw_m_l, sw_m_h;
    wire       sw_lap_hold;
    stopwatch u_sw(
        .clk(clk), .rst_n(rst_n), .en_100hz(en_100hz),
        .run(sw_run),
        .clr(k_clr && (mode == M_SW)),
        .lap(k_sel && (mode == M_SW)),
        .d_cs_l(sw_cs_l), .d_cs_h(sw_cs_h),
        .d_s_l (sw_s_l ), .d_s_h (sw_s_h ),
        .d_m_l (sw_m_l ), .d_m_h (sw_m_h ),
        .lap_hold(sw_lap_hold));

    wire [3:0] cd_s_l, cd_s_h, cd_m_l, cd_m_h;
    countdown u_cd(
        .clk(clk), .rst_n(rst_n), .tick(en_1hz),
        .run(cd_run),
        .inc(k_inc && (mode == M_CD)),
        .dec(k_dec && (mode == M_CD)),
        .field(field),
        .clr(k_clr && (mode == M_CD)),
        .s_l(cd_s_l), .s_h(cd_s_h), .m_l(cd_m_l), .m_h(cd_m_h),
        .zero(cd_zero), .expired(cd_expired));

    // countdown ring: 5 s, cancelled by START or CLR
    reg [2:0] cd_ring_cnt;
    reg       cd_ring;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin cd_ring <= 1'b0; cd_ring_cnt <= 3'd0; end
        else if (cd_expired) begin cd_ring <= 1'b1; cd_ring_cnt <= 3'd0; end
        else if (k_start || k_clr) cd_ring <= 1'b0;
        else if (cd_ring && en_1hz) begin
            if (cd_ring_cnt == 3'd4) begin cd_ring <= 1'b0; cd_ring_cnt <= 3'd0; end
            else cd_ring_cnt <= cd_ring_cnt + 3'd1;
        end
    end

    // ---------------- 12/24 hour conversion ------------------------------
    wire [5:0] hr_bin = hr_h * 6'd10 + hr_l;
    wire       pm     = (hr_bin >= 6'd12);
    wire [5:0] h12    = (hr_bin == 6'd0)  ? 6'd12 :
                        (hr_bin >  6'd12) ? (hr_bin - 6'd12) : hr_bin;
    wire [5:0] hshow  = sw_12h ? h12 : hr_bin;
    wire [3:0] hs_h   = (hshow >= 6'd20) ? 4'd2 : (hshow >= 6'd10) ? 4'd1 : 4'd0;
    wire [5:0] hs_l6  = hshow - hs_h * 6'd10;   // range 0..9, fits in 4 bits
    wire [3:0] hs_l   = hs_l6[3:0];             // explicit slice, no implicit truncation

    // ---------------- blink (2 Hz) ---------------------------------------
    reg blink;
    reg [2:0] blink_cnt;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin blink <= 1'b0; blink_cnt <= 3'd0; end
        else if (en_10hz) begin
            if (blink_cnt == 3'd2) begin blink_cnt <= 3'd0; blink <= ~blink; end
            else blink_cnt <= blink_cnt + 3'd1;
        end
    end

    // ---------------- display mux ----------------------------------------
    reg [3:0] d7,d6,d5,d4,d3,d2,d1,d0;
    reg [7:0] bl;

    always @(*) begin
        d7=4'd0; d6=4'd0; d5=4'd0; d4=4'd0;
        d3=4'd0; d2=4'd0; d1=4'd0; d0=4'd0;
        bl = 8'h00;
        case (mode)
        M_RUN, M_SET: begin
            d7 = hs_h; d6 = hs_l;
            d5 = min_h; d4 = min_l;
            d3 = sec_h; d2 = sec_l;
            d1 = {1'b0, mode};
            d0 = {2'b00, sw_alarm_en, chime_en};
            if (sw_12h && hs_h == 4'd0) bl[7] = 1'b1;      // leading zero off in 12 h
            if (mode == M_SET && blink) begin
                case (field)
                2'd0: bl[3:2] = 2'b11;
                2'd1: bl[5:4] = 2'b11;
                2'd2: bl[7:6] = 2'b11;
                default: ;
                endcase
            end
        end
        M_ALM: begin
            d7 = al_hr_h; d6 = al_hr_l;
            d5 = al_mn_h; d4 = al_mn_l;
            bl[3:2] = 2'b11;
            d1 = {1'b0, mode};
            d0 = {2'b00, sw_alarm_en, chime_en};
            if (blink) begin
                case (field)
                2'd0: bl[5:4] = 2'b11;
                2'd1: bl[7:6] = 2'b11;
                default: ;
                endcase
            end
        end
        M_SW: begin
            d7 = sw_m_h; d6 = sw_m_l;
            d5 = sw_s_h; d4 = sw_s_l;
            d3 = sw_cs_h; d2 = sw_cs_l;
            d1 = {1'b0, mode};
            d0 = {3'b000, sw_run};
        end
        M_CD: begin
            bl[7:6] = 2'b11;
            d5 = cd_m_h; d4 = cd_m_l;
            d3 = cd_s_h; d2 = cd_s_l;
            d1 = {1'b0, mode};
            d0 = {3'b000, cd_run};
            if (!cd_run && blink) begin
                case (field)
                2'd0: bl[3:2] = 2'b11;
                2'd1: bl[5:4] = 2'b11;
                default: ;
                endcase
            end
            if (cd_ring && blink) bl[5:2] = 4'b1111;       // flash when expired
        end
        default: ;
        endcase
    end

    assign disp_bcd   = {d7,d6,d5,d4,d3,d2,d1,d0};
    assign disp_blank = bl;
    // decimal points act as the HH.MM.SS separators / stopwatch point
    assign disp_dot   = (mode == M_SW) ? 8'b0101_0000 : 8'b1010_0000;

    // ---------------- beeper ----------------------------------------------
    reg [1:0] beat_cnt;
    reg       beat;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin beat <= 1'b0; beat_cnt <= 2'd0; end
        else if (en_10hz) begin
            if (beat_cnt == 2'd2) begin beat_cnt <= 2'd0; beat <= ~beat; end
            else beat_cnt <= beat_cnt + 2'd1;
        end
    end

    wire [1:0] tone = cd_ring   ? (beat ? 2'd2 : 2'd0) :   // highest priority
                      ringing   ? (beat ? 2'd2 : 2'd0) :
                      high_beep ? 2'd2 :
                      low_beep  ? 2'd1 : 2'd0;

    beep_gen #(.CLK_HZ(CLK_HZ)) u_beep(
        .clk(clk), .rst_n(rst_n), .tone(tone), .spk(speaker));

    // ---------------- LEDs -------------------------------------------------
    reg led_1hz;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) led_1hz <= 1'b0;
        else if (en_1hz) led_1hz <= ~led_1hz;
    end

    // D1..D8. In the setting modes the LEDs carry the "which field" blink,
    // because the GW48 on-board decoder is a full hex decoder and cannot
    // blank a digit (4'hF shows "F", not a blank).
    reg [7:0] led_r;
    always @(*) begin
        led_r = 8'h00;
        case (mode)
        M_RUN: led_r = {2'b00, sw_12h & pm, ringing, sw_12h, chime_en, sw_alarm_en, led_1hz};
        M_SET: begin
                  led_r[0] = blink & (field == 2'd0);   // seconds field
                  led_r[1] = blink & (field == 2'd1);   // minutes field
                  led_r[2] = blink & (field == 2'd2);   // hours field
                  led_r[7] = 1'b1;                      // "setting" marker
               end
        M_ALM: begin
                  led_r[1] = blink & (field == 2'd0);   // alarm minutes
                  led_r[2] = blink & (field == 2'd1);   // alarm hours
                  led_r[3] = sw_alarm_en;
                  led_r[7] = 1'b1;
               end
        M_SW : led_r = {6'b000000, sw_lap_hold, sw_run};
        M_CD : begin
                  led_r[0] = blink & (field == 2'd0) & ~cd_run;
                  led_r[1] = blink & (field == 2'd1) & ~cd_run;
                  led_r[2] = cd_run;
                  led_r[3] = cd_ring;
               end
        default: ;
        endcase
    end
    assign led = led_r;
endmodule
