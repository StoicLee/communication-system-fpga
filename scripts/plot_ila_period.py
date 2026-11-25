"""Align a hardware ILA capture to one complete PN period and plot it."""
import csv
import sys
from pathlib import Path
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

root = Path(__file__).resolve().parents[1]
out = root / 'output'
path = Path(sys.argv[1]) if len(sys.argv) > 1 else out / 'lab4_ila_capture.csv'
with path.open(newline='', encoding='utf-8-sig') as f:
    rows = list(csv.DictReader(f))[1:]  # Vivado's radix row
if not rows:
    raise ValueError('ILA capture is empty')
def column(prefix):
    matches = [k for k in rows[0] if k == prefix or k.startswith(prefix + '[')]
    if len(matches) != 1:
        raise ValueError(f'Expected one probe {prefix}, found {matches}')
    return matches[0]
def values(name, signed=False, width=None):
    key = column(name)
    a = np.array([int(r[key], 16) for r in rows], dtype=int)
    if signed:
        a = np.where(a >= (1 << (width - 1)), a - (1 << width), a)
    return a
pn = values('pn_tx')
state = 1
bits = []
for _ in range(31):
    bits.append((state >> 4) & 1)
    state = ((state << 1) & 31) | (((state >> 4) ^ (state >> 2)) & 1)
assert state == 1
clocks_per_symbol = 32
period = 31 * clocks_per_symbol
# PN begins with 00001; its first rising edge provides an unambiguous
# phase reference. Check every bit at its centre and require a full window.
starts = []
for edge in np.flatnonzero((pn[1:] == 1) & (pn[:-1] == 0)) + 1:
    start = int(edge) - 4 * clocks_per_symbol
    if start >= 0 and start + period <= len(pn):
        centres = start + np.arange(31) * clocks_per_symbol + clocks_per_symbol // 2
        if np.array_equal(pn[centres], bits):
            starts.append(start)
if not starts:
    raise ValueError('No complete aligned PN period found in capture')
start = starts[0]
end = start + period
names = ['pn_tx', 'carrier', 'ask', 'rectified', 'envelope', 'demod']
traces = [(n, values(n, signed=(n in ('carrier', 'ask')), width=12)) for n in names if n != 'rectified' or any(k == n or k.startswith(n+'[') for k in rows[0])]
t = np.arange(period) / 32.768
clk_sample = values('clk_sample')
rises = np.flatnonzero((clk_sample[1:] == 1) & (clk_sample[:-1] == 0)) + 1
fig, axes = plt.subplots(len(traces), 1, figsize=(15, 9), sharex=True, constrained_layout=True)
for ax, (name, data) in zip(axes, traces):
    if name in ('pn_tx', 'demod'):
        ax.plot(t, data[start:end], drawstyle='steps-post', linewidth=1)
    else:
        # Plot each distinct 8.192 MHz sample once; joining repeated ILA
        # clock samples directly makes a misleading staircase waveform.
        idx = rises[(rises >= start) & (rises < end)]
        ax.plot((idx - start) / 32.768, data[idx], linewidth=1)
    ax.set_ylabel(name)
    ax.grid(True, alpha=.3)
    if name in ('pn_tx','demod'):
        ax.set_ylim(-.2, 1.2)
        ax.set_yticks([0, 1])
axes[0].set_title('ILA: one complete aligned 31-symbol PN period')
axes[-1].set_xlabel('Time from PN period start (us)')
axes[-1].set_xlim(0, period / 32.768)
fig.savefig(out / 'lab4_ila_full_period.png', dpi=180)
with (out / 'lab4_ila_full_period.csv').open('w', newline='', encoding='utf-8') as f:
    writer = csv.DictWriter(f, fieldnames=rows[0].keys())
    writer.writeheader()
    writer.writerows(rows[start:end])
print(f'ILA aligned: samples {start}..{end-1}, 31 symbols, {period / 32.768:.3f} us')
