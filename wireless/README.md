# 实验四无线收发原型（无板仿真）

此工程独立于上级目录中的直连版，不覆盖原 bit。平台资料和实验二参考报告采用单台 eNodeX30B：TXA 发射、RXA 接收，两路天线。该连接方式是当前设计假设，尚未在用户板卡验证；用户此前的实验二报告只记录本地 DAC 测试。综合设计课件还提到两台设备收发，它是另一种可能方案，不能由现有资料断定本任务必须使用两台。

## 链路

`PN → 8 点正交载波门控 → TX I/Q → AD9361 DDR → 信道 → AD9361 DDR → RX I/Q → 幅度近似 → 平滑 → 阈值与码元抽样`。

I/Q 为 12 位二补码，发送采样率 8.192 MSPS、码率 1.024 Mbps、数字正交载波 1.024 MHz。1 码的 I/Q 峰值约 1200，0 码两路均为 0。载波每码元从 I 路零点起始；Q 路是正交分量，码元边缘可有 Q 幅度跳变。无线射频本振频率由配置软件设置，与数字载波频率不是同一个参数。

接收采用 `(|I|+|Q|)/2` 的低成本包络近似和 2 点滑动平均，门限默认 250。该低通是面向 I/Q 包络的方案，不是直连版的 17 抽头整流低通；不能沿用直连版的频响结论。固定门限并非自适应，实际无线增益、噪声和 DC 偏置会改变合适门限。

当前定时器针对本工程的 31 位 PN、8 点/码元和单板共享采样时钟：门限状态须连续 3 个采样稳定才确认翻转，两个满足码元间隔关系的翻转用于获取定时；锁定后每 8 点输出一次判决。若连续 7 个码元没有有效翻转则丢锁并停止判决；因为 PN 序列最长连续码元数小于该超时，该规则不适用于可包含任意长连零或连一的普通数据。当前不跟踪采样时钟漂移、频偏，不实现一般意义的帧同步和自适应门限；两台独立设备或低信噪比下需要进一步设计。

## RF 配置软件和接线

资料附有 `通信实验综合设计/实验2/eNodeX_Control@20210510.exe`，无需为本仿真运行或下载。资料称软件可通过设备背面 DEBUG 串口（USB-D；可能需要 CH340 驱动）或 ETH 控制配置；上板时按实机配置。实验二课件示例为单收单发、TXA/RXA、收发采样率各 8.192 MSPS，频率 800 MHz 以上并按课程安排选频。平台手册示例为 800 MHz，参考报告为 860 MHz；不能仅凭资料认定用户应使用哪一个。收发增益及衰减要结合设备与现场调整，不能照抄报告数值。

教学 `AD9361_1RT_FDD` 来自实验二，使用 200 MHz IDELAY 校准，收发使用 AD9361 的数据时钟；其 DDR I/Q 边沿对应关系及 RX_FRAME 假设沿用实验二，板卡、射频芯片配置、时序裕量和软件与板卡固件的关系均需实机确认。仿真不会配置 AD9361，也未模拟其 RF 滤波、AGC、失真或内部校准；工程并未实现片上 SPI 配置。

## 复现

在 `exp4` 目录执行：

```
vivado -mode batch -source wireless/scripts/create_radio_project.tcl
vivado -mode batch -source wireless/scripts/run_radio_sim.tcl -log wireless/output/simulation.log
python wireless/scripts/plot_radio.py
vivado -mode batch -source wireless/scripts/synth_radio.tcl -log wireless/output/synthesis.log
```

新工程在 `wireless/build/lab4_radio.xpr`。请不要运行 `create_radio_project.tcl` 覆盖自己在该生成目录中手工修改的工程：脚本以 `-force` 重建工程。

`tb_iq_link` 测试五组离散信道：不同整点延迟、增益 1 和 0.5、0/45/90/180 度相位、一个确定性的有界扰动以及两次复位；每组超过 1200 次判决，并检查判决间隔严格为 8 点。`tb_rx_robust` 检查短脉冲、两采样点跌落、失锁和重新捕获；`tb_iq_width` 检查 12 位有符号 I/Q 极值及 13 位包络不会溢出。`tb_radio_interface` 使用 Vivado 的 DDR 原语模型，从 FPGA TX DDR 引脚经理想数字信道进入 RX DDR 引脚，验证发送 I/Q 边沿及 256 个 PN 判决。该仿真不是对射频环境的 BER 测试。

产出 `output/wireless_samples.csv` 和 `output/radio_simulation.png` 展示其中一组数字信道；时序和实板性能须后续验证。

综合检查完成（Vivado 2023.2），综合后 DRC 有 `ZPS7-1: PS7 block required` 警告。当前顶层没有实例化 PS7，也没有实现 AD9361 的控制软件或固件；需要确认实验平台原有 PS 固件与加载 PL 比特流时的工作方式，不能仅凭该工程断定射频配置一定可用。

## 无板实现结果

请以 `output/build.log`、`output/radio_timing.rpt`、`output/radio_drc.rpt` 及 `output/radio_methodology.rpt` 为准。`output/lab4_radio.bit` 与 `output/lab4_radio.ltx` 是同次实现的实验候选文件。

AD9361 接收约束明确指定保持乘数为 0，以保持 Vivado 的默认保持关系：模型将当前沿的数据由延迟后的接收时钟采样，并检查下一半周期数据变化。教学工程的虚拟时钟、±0.5 ns I/O 延迟和帧相位依然是未经板级资料或实测证实的假设；正时序余量不能证明真实 AD9361 接口满足时序。PS7 固件、控制软件、门限、空口和时序必须实机确认。代码未实现无线芯片 SPI 初始化。GPIO 仅供观察，未建立外部同步采集约束。

2026-11-25 本次修复后实现：已约束路径 WNS 3.675 ns、WHS 0.057 ns，脉宽余量 0.264 ns；3598 条可布线网络均完成，布线错误为 0。显式保持约束后 `XDCH-1` 方法学警告消失，其他 PS7、GPIO 外部延迟、复位及 IP 调试核心警告仍需留意。固定门限和 PN 特有失锁策略尚未经射频实测。

2026-11-27 重跑综合、布局布线和 bitstream：已约束路径 WNS 3.675 ns、WHS 0.057 ns、脉宽余量 0.264 ns；3598 条可布线网络全部完成，布线错误为 0。最终 DRC 有 PS7 和调试 IP 相关警告，板级时序、PS 固件和射频配置仍须实测。`lab4_radio.bit` 和 `lab4_radio.ltx` 均来自本次实现。

## 无线版 ILA：九路信号与完整周期

当前 `lab4_radio.bit` 和 `lab4_radio.ltx` 的同一个 ILA 已接入：`pn`（1 位）、`tx_i`/`tx_q`（各 12 位有符号）、`rx_i`/`rx_q`（各 12 位有符号）、`envelope`（13 位无符号）、`demod`、`valid`、`timing_locked`（各 1 位）。TX I/Q 是送往 AD9361 上变频的数字基带，RX I/Q 是天线信号经 AD9361 下变频、采样后的数字基带，不是天线上的模拟射频电压。`demod` 只在 `valid` 为 1 的时刻表示新的判决；`timing_locked` 为 1 表示当前 PN 定时已锁定。比对 PN 与判决时要考虑信道、滤波及判决延迟。

ILA 深度为 4096 点；在约定的 8.192 MSPS 下约为 500 微秒，覆盖约 16 个 31 码元 PN 周期。每个周期 248 点，约 30.273 微秒。画图脚本按 PN 序列匹配截取完整周期，避免只截到半个周期。无板预览来自 `tb_iq_link` 的数字信道（4 点延迟、0.5 倍增益），不是实际天线采集：

```
vivado -mode batch -source wireless/scripts/run_radio_sim.tcl -log wireless/output/simulation.log
python wireless/scripts/plot_radio_ila.py --source sim
```

结果保存在 `output/radio_ila_sim_period.png` 和 `output/radio_ila_sim_period.csv`。CSV 恰好保存一个周期；图在周期两端展示相邻的真实采样点，橙色虚线标出周期边界，避免在周期边缘人为截断。图上的数值是数字采样值而不是电压；实际信道延迟和噪声不同，窗口边缘不能保证始终落在静默处。

`output/radio_ila_sim_tx_rx_detail.png` 单独放大 TX/RX I/Q 和 PN：圆点是真实的仿真采样点，虚线是 PN 码元边界，连线仅帮助观察采样点关系。当前每码元只有 8 个点，Q 从余弦峰值开始，码元结束后归零可能出现跳变；这与 I 从零点开始的形状不同。接收 I/Q 在此例中还经过数字信道的延迟和增益变化。实板画图会生成 `radio_ila_capture_tx_rx_detail.png`，它使用实测采样数据，不插值成模拟射频波形。

上板时先确认板卡供电、JTAG、AD9361 控制软件配置和数据时钟；确认加载无线版不会干扰板上已有设计后，在 `exp4` 目录运行：

```
vivado -mode batch -source wireless/scripts/capture_radio_ila.tcl
python wireless/scripts/plot_radio_ila.py --source hardware
```

采集脚本会主动下载 `lab4_radio.bit`，绑定配套 LTX，立即触发并保存 `radio_ila_capture.ila/.csv/.vcd`；超时请检查数据时钟及射频配置。可以在 Vivado Hardware Manager 打开 `.ila` 查看九路信号，并将四路 I/Q 显示为有符号数及模拟波形。Python 画图会另外生成完整周期 PNG/CSV。实板采集、CSV 格式、时钟以及无线链路均尚未验证；如果捕获中没有完整且正确的 PN 序列，画图脚本会报错而不伪造波形。不要使用上级目录直连版的 ILA 脚本或 bit/ltx 来观察无线版。
