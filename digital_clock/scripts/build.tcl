# =====================================================================
# build.tcl -- Quartus 工程建立 + 引脚锁定 + 全编译
#
#   quartus_sh -t scripts/build.tcl      (从工程根目录)
#   quartus_sh -t build.tcl              (从 scripts 目录)
#   两种都可以，脚本自己定位工程根目录。
#
# 操作的是与 Quartus GUI 同一个工程 top_clock_gw48，不会另建工程。
# =====================================================================
package require ::quartus::project
package require ::quartus::flow

# 以脚本自身位置定位工程根目录，与调用时所在目录无关
set SCRIPT_DIR [file dirname [file normalize [info script]]]
set PROJ_DIR   [file normalize "$SCRIPT_DIR/.."]
cd $PROJ_DIR
puts "工程目录: $PROJ_DIR"

set PRJ    "top_clock_gw48"
set TOP    "top_clock_gw48"
set FAMILY "Cyclone III"
set DEVICE "EP3C5E144C8"      ;# 若芯片丝印是 EP3C10E144 改成 EP3C10E144C8

if {[project_exists $PRJ]} { project_open $PRJ } else { project_new $PRJ -overwrite }

set_global_assignment -name FAMILY $FAMILY
set_global_assignment -name DEVICE $DEVICE
set_global_assignment -name TOP_LEVEL_ENTITY $TOP
set_global_assignment -name RESERVE_ALL_UNUSED_PINS "AS INPUT TRI-STATED"

foreach f [lsort [glob -nocomplain rtl/*.v]] {
    set_global_assignment -name VERILOG_FILE $f
}
if {[file exists constraints/top_clock_gw48.sdc]} {
    set_global_assignment -name SDC_FILE constraints/top_clock_gw48.sdc
} else {
    puts "警告: 未找到 constraints/top_clock_gw48.sdc，时序分析将不受约束"
}

proc pin {loc port} { set_location_assignment PIN_$loc -to $port }

# ---- 引脚，来自讲义第一章引脚对照表 + 结构图 NO.3 ----
pin 88  clk            ;# CLOCK0  jumper -> 12 MHz
pin 11  {key[0]}   ;# PIO0  键1  MODE
pin 10  {key[1]}   ;# PIO1  键2  SEL
pin 7   {key[2]}   ;# PIO2  键3  INC +
pin 4   {key[3]}   ;# PIO3  键4  DEC -
pin 3   {key[4]}   ;# PIO4  键5  START/STOP
pin 2   {key[5]}   ;# PIO5  键6  CLR
pin 1   {key[6]}   ;# PIO6  键7  alarm on/off
pin 144 {key[7]}   ;# PIO7  键8  12/24 h
pin 143 {led[0]}   ;# PIO8  发光管 D1
pin 142 {led[1]}   ;# PIO9  发光管 D2
pin 141 {led[2]}   ;# PIO10  发光管 D3
pin 138 {led[3]}   ;# PIO11  发光管 D4
pin 137 {led[4]}   ;# PIO12  发光管 D5
pin 136 {led[5]}   ;# PIO13  发光管 D6
pin 135 {led[6]}   ;# PIO14  发光管 D7
pin 38  {led[7]}   ;# PIO15  发光管 D8
pin 39  {seg_bcd[0]}   ;# PIO16  数码1 A
pin 42  {seg_bcd[1]}   ;# PIO17  数码1 B
pin 43  {seg_bcd[2]}   ;# PIO18  数码1 C
pin 44  {seg_bcd[3]}   ;# PIO19  数码1 D
pin 53  {seg_bcd[4]}   ;# PIO20  数码2 A
pin 52  {seg_bcd[5]}   ;# PIO21  数码2 B
pin 51  {seg_bcd[6]}   ;# PIO22  数码2 C
pin 50  {seg_bcd[7]}   ;# PIO23  数码2 D
pin 49  {seg_bcd[8]}   ;# PIO24  数码3 A
pin 46  {seg_bcd[9]}   ;# PIO25  数码3 B
pin 54  {seg_bcd[10]}   ;# PIO26  数码3 C
pin 55  {seg_bcd[11]}   ;# PIO27  数码3 D
pin 58  {seg_bcd[12]}   ;# PIO28  数码4 A
pin 59  {seg_bcd[13]}   ;# PIO29  数码4 B
pin 60  {seg_bcd[14]}   ;# PIO30  数码4 C
pin 64  {seg_bcd[15]}   ;# PIO31  数码4 D
pin 65  {seg_bcd[16]}   ;# PIO32  数码5 A
pin 66  {seg_bcd[17]}   ;# PIO33  数码5 B
pin 67  {seg_bcd[18]}   ;# PIO34  数码5 C
pin 68  {seg_bcd[19]}   ;# PIO35  数码5 D
pin 69  {seg_bcd[20]}   ;# PIO36  数码6 A
pin 70  {seg_bcd[21]}   ;# PIO37  数码6 B
pin 71  {seg_bcd[22]}   ;# PIO38  数码6 C
pin 72  {seg_bcd[23]}   ;# PIO39  数码6 D
pin 73  {seg_bcd[24]}   ;# PIO40  数码7 A
pin 74  {seg_bcd[25]}   ;# PIO41  数码7 B
pin 75  {seg_bcd[26]}   ;# PIO42  数码7 C
pin 76  {seg_bcd[27]}   ;# PIO43  数码7 D
pin 77  {seg_bcd[28]}   ;# PIO44  数码8 A
pin 79  {seg_bcd[29]}   ;# PIO45  数码8 B
pin 80  {seg_bcd[30]}   ;# PIO46  数码8 C
pin 83  {seg_bcd[31]}   ;# PIO47  数码8 D
pin 86  speaker        ;# SPEAKER
export_assignments

# ---- 编译并追加一行供飞书阶段记录表使用 ----
set t0 [clock seconds]
if {[catch {execute_flow -compile} res]} { puts "COMPILE FAILED: $res"; set status "fail" } else { set status "ok" }
set secs [expr {[clock seconds] - $t0}]

set les "??" ; set regs "??" ; set fmax "??"
catch {
    set fh [open "output_files/$PRJ.fit.rpt" r] ; set txt [read $fh] ; close $fh
    if {[regexp {Total logic elements\s*;\s*([0-9,]+)} $txt -> m]} { set les $m }
    if {[regexp {Dedicated logic registers\s*;\s*([0-9,]+)} $txt -> m]} { set regs $m }
}
catch {
    set fh [open "output_files/$PRJ.sta.rpt" r] ; set txt [read $fh] ; close $fh
    # 直接匹配 Fmax Summary 的数据行（两个 MHz 值 + clk），-all -inline 按出现
    # 顺序返回，第一条就是 Slow 85C 模型——最坏情况，报告要引的就是它。
    # 不要用 ".*?" 锚表头：Tcl 的整体贪婪规则会让惰性量词失效，抓到 0C 那张表。
    set rows [regexp -all -inline {;\s*([0-9.]+) MHz\s*;\s*[0-9.]+ MHz\s*;\s*clk} $txt]
    if {[llength $rows] >= 2} { set fmax "[lindex $rows 1] MHz" }
}
set out [open "scripts/build_summary.csv" a]
puts $out "[clock format [clock seconds] -format %Y-%m-%d\ %H:%M:%S],$TOP,$status,${secs}s,$les,$regs,$fmax"
close $out
puts "---- build $status, ${secs}s, LEs=$les, Regs=$regs, Fmax=$fmax ----"
project_close
