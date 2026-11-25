# 实验四：2ASK 调制与非相干解调

依据最新实验课件，采用 PN 序列、12 位输出和载波 8 倍采样率。课件没有给出码率和载波的具体数值，本工程沿用 Rb = 1.024 Mbps、fc = 1.024 MHz、fs = 8.192 MHz，每码元 8 点。接收路径为 OOK → 全波整流 → 低通 → 定时抽样判决；当前仿真为无噪声直接连接，未实现课件原理框图中接收带通滤波器或射频信道。

## 低通设计

使用 17 抽头（16 阶）对称等波纹 FIR，Q1.15 整数系数，直流增益为 1。通带 0–1 MHz，阻带 2–4.096 MHz；量化后通带峰峰起伏约 0.609 dB，整个阻带最小衰减约 50.19 dB。全波整流纹波位于 2.048 MHz；连续“1”稳定段的残余纹波约 2.5 个计数峰峰值，平均包络约 1235。码元边缘有滤波过渡和振铃，不能将其等同于稳定段载波纹波。判决门限为 618，FIR 群延迟 8 个采样点，按延迟后的码元中心抽样。上述指标不代表噪声信道的误码率。

## 重现步骤

在本目录执行：

1. `matlab -batch "run('matlab/verify_lab4.m')"`：设计和检查量化滤波器，生成 `coeff/lpf_ask_17tap.coe`、频响及 MATLAB 波形。
2. 首次建工程运行 `vivado -mode batch -source scripts/create_project_final.tcl`；已有最终工程则运行 `vivado -mode batch -source scripts/update_filter_and_ila.tcl`，更新 FIR IP。
3. `vivado -mode batch -source scripts/run_xsim.tcl -log output/xsim_simulation.log`：运行实际 FIR IP 仿真和 310 码元自检，写出 `output/xsim_samples.csv`。
4. `vivado -mode batch -source scripts/build_final.tcl -log output/build_final.log`：综合、实现、检查建立/保持时序并生成 `output/lab4_2ASK.bit` 和对应 `.ltx`。

`output/lpf_frequency_response.png` 和 `output/matlab_verification.png` 可查看设计结果；`output/xsim_simulation.log`、`output/lab4_timing.rpt` 和 `output/lab4_drc.rpt` 记录实际验证。上板 DAC CH1 输出 2ASK，CH2 输出恢复数据；比特流生成不等同于上板实测。

## 载波完整周期与 ILA

每个码元起点对齐载波零点：8 个采样依次为 0、1447、2047、1447、0、-1447、-2047、-1447，下一码元回到零点；PN 只在周期边界切换。仿真检查每个采样相位和 PN 切换位置。

ILA 使用 32.768 MHz 时钟采集 4096 点，约 127.9 us，可包含超过 4 个 31 码元 PN 周期。立即触发的原始窗口起点不固定；运行 `vivado -mode batch -source scripts/program_and_capture_ila.tcl` 将下载当前 bit/ltx、采集并从 PN 序列中定位完整周期，输出 `output/lab4_ila_full_period.png` 和 `.csv`。图中解调信号因滤波和判决延迟相对 PN 偏移，窗口边缘可能显示相邻码元的一部分。`lab4_ila_previous_capture_full_period.*` 是旧比特流的历史采集，仅用于展示对齐方法，不代表本次新滤波器的上板结果。需连接并上电 FPGA 才能重新采集。

## GitHub 协作与工程迁移

仓库包含最终版的源码、IP 配置、Vivado 工程，以及综合和实现运行目录、检查点、报告、bit 和 ltx。运行目录是 Vivado 2023.2 在原机器生成的历史产物，可能包含本机路径；其他机器请使用 `scripts/create_project_final.tcl` 重新生成工程，再按上述步骤运行。仓库当前只包含本地直连版本，尚未接入 AD9361 无线链路。

## AD9361 无线收发原型

无线版在独立的 `wireless/` 目录，保留本目录的直连版。软件配置、链路说明、仿真范围和复现步骤见 `wireless/README.md`。该原型尚未在板卡和天线上验证。
