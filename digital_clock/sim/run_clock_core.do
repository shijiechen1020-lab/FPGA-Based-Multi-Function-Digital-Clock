# =====================================================================
# run_clock_core.do  --  ModelSim-Altera 系统级仿真
#
# 用法（在 ModelSim 的 Transcript 窗口里输入，注意用正斜杠）：
#   cd {C:/Users/s8937/Desktop/digital_clock_fpga/digital_clock/sim}
#   do run_clock_core.do
#
# 仿真里 CLK_HZ 被改成 1000，所以 1 "秒" = 1000 个时钟 = 20 us。
# 整个测试跑完约 1.66 ms 仿真时间。
# =====================================================================

quit -sim
if {[file exists work]} { vdel -all -lib work }
vlib work
vmap work work

vlog -work work ../rtl/clk_gen.v ../rtl/key_cond.v ../rtl/time_keeper.v
vlog -work work ../rtl/alarm_unit.v ../rtl/chime_unit.v ../rtl/stopwatch.v
vlog -work work ../rtl/countdown.v ../rtl/beep_gen.v ../rtl/clock_core.v
vlog -work work tb_clock_core.v

# +acc 保留内部信号可见性，否则波形窗口里看不到子模块的信号，
# testbench 里的 force/release 也会失效
vsim -voptargs="+acc" work.tb_clock_core

# ---------------- 波形分组 ----------------
add wave -divider "系统"
add wave -label clk        /tb_clock_core/clk
add wave -label rst_n      /tb_clock_core/rst_n
add wave -label 按键输入   -radix binary /tb_clock_core/key_in
add wave -label 1Hz使能    /tb_clock_core/dut/en_1hz

add wave -divider "当前时间 hh:mm:ss"
add wave -label 时十位 -radix unsigned /tb_clock_core/dut/u_time/hr_h
add wave -label 时个位 -radix unsigned /tb_clock_core/dut/u_time/hr_l
add wave -label 分十位 -radix unsigned /tb_clock_core/dut/u_time/min_h
add wave -label 分个位 -radix unsigned /tb_clock_core/dut/u_time/min_l
add wave -label 秒十位 -radix unsigned /tb_clock_core/dut/u_time/sec_h
add wave -label 秒个位 -radix unsigned /tb_clock_core/dut/u_time/sec_l
add wave -label 跨日脉冲 /tb_clock_core/dut/u_time/day_pulse

add wave -divider "模式状态机"
add wave -label 模式 -radix unsigned /tb_clock_core/dut/mode
add wave -label 字段 -radix unsigned /tb_clock_core/dut/field
add wave -label 校时冻结 /tb_clock_core/dut/u_time/hold
add wave -label 闪烁 /tb_clock_core/dut/blink

add wave -divider "报警与发声"
add wave -label 整点低音 /tb_clock_core/dut/low_beep
add wave -label 整点高音 /tb_clock_core/dut/high_beep
add wave -label 闹钟响铃 /tb_clock_core/dut/ringing
add wave -label 倒计时响 /tb_clock_core/dut/cd_ring
add wave -label 音调 -radix unsigned /tb_clock_core/dut/tone
add wave -label 扬声器 /tb_clock_core/speaker

add wave -divider "秒表与倒计时"
add wave -label 秒表运行 /tb_clock_core/dut/sw_run
add wave -label 计次锁存 /tb_clock_core/dut/sw_lap_hold
add wave -label 倒计时运行 /tb_clock_core/dut/cd_run

add wave -divider "显示输出"
add wave -label 数码管BCD -radix hexadecimal /tb_clock_core/bcd
add wave -label 发光管 -radix binary /tb_clock_core/led

# $finish 会让 ModelSim 断点暂停并中止宏，onbreak resume 让脚本继续往下走
onbreak {resume}
run -all
wave zoom full
echo "=== 仿真结束，用 Wave 窗口的 Zoom In / 输入时刻定位到下面的时间点截图 ==="
