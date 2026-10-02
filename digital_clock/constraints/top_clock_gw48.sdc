# =====================================================================
# top_clock_gw48.sdc -- TimeQuest 时序约束
# GW48-CK, CLOCK0 短路帽选 12 MHz -> 周期 83.333 ns
# 如果你把 CLOCK0 改成别的频率，这里的 period 也要跟着改：
#   12 MHz -> 83.333    20 MHz -> 50.000    6 MHz -> 166.667
# =====================================================================

create_clock -name {clk} -period 83.333 [get_ports {clk}]
derive_clock_uncertainty

# 按键是机械开关，跟时钟完全异步，而且已经在 key_cond 里做过
# 1 kHz 采样消抖，不需要参与建立/保持时间分析
set_false_path -from [get_ports {key[*]}] -to [all_registers]

# 输出端接的是数码管译码器、发光管和扬声器，都是毫秒级慢速负载，
# 不构成时序约束对象
set_false_path -from [all_registers] -to [get_ports {seg_bcd[*]}]
set_false_path -from [all_registers] -to [get_ports {led[*]}]
set_false_path -from [all_registers] -to [get_ports {speaker}]
