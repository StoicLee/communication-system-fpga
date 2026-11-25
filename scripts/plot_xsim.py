"""Plot an XSim segment ending between complete carrier bursts."""
import csv
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
out = Path(__file__).resolve().parents[1] / 'output'
with (out / 'xsim_samples.csv').open(newline='') as f:
    rows = list(csv.DictReader(f))
rows = [r for r in rows if 2_000_000 <= int(r['time_ps']) <= 12_800_000]
t = [(int(r['time_ps']) - 2_000_000) / 1e6 for r in rows]
fig, axes = plt.subplots(4, 1, figsize=(14, 8), sharex=True, constrained_layout=True)
for ax, key in zip(axes, ['pn_tx', 'ask', 'envelope', 'demod']):
    ax.plot(t, [int(r[key]) for r in rows], drawstyle='steps-post' if key in ('pn_tx', 'demod') else 'default', linewidth=1.4)
    ax.set_ylabel(key)
    ax.grid(alpha=.35)
axes[0].set_title('XSim FIR IP: zero-crossing 2ASK carrier cycles')
axes[-1].set_xlabel('Time (us)')
fig.savefig(out / 'xsim_carrier_and_envelope.png', dpi=180)
