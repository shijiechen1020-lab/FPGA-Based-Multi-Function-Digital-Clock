# =====================================================================
# run_time_keeper.do  --  计数进位链专项仿真（波形最干净）
#   cd {.../digital_clock/sim}
#   do run_time_keeper.do
# tick 每个时钟拍一次，所以整整一天只要 86400 个时钟周期。
# =====================================================================
quit -sim
if {[file exists work]} { vdel -all -lib work }
vlib work
vmap work work
vlog -work work ../rtl/time_keeper.v
vlog -work work tb_time_keeper.v
vsim -voptargs="+acc" work.tb_time_keeper

add wave -divider "控制"
add wave /tb_time_keeper/clk /tb_time_keeper/rst_n /tb_time_keeper/tick
add wave -label 校时冻结 /tb_time_keeper/hold
add wave -label 加1 /tb_time_keeper/inc
add wave -label 减1 /tb_time_keeper/dec
add wave -label 字段 -radix unsigned /tb_time_keeper/field
add wave -divider "计数值"
add wave -radix unsigned /tb_time_keeper/hr_h  /tb_time_keeper/hr_l
add wave -radix unsigned /tb_time_keeper/min_h /tb_time_keeper/min_l
add wave -radix unsigned /tb_time_keeper/sec_h /tb_time_keeper/sec_l
add wave -label 跨日脉冲 /tb_time_keeper/day_pulse
run -all
wave zoom full
