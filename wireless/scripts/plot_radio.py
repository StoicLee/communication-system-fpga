"""Plot the wireless simulation channel with four-sample delay and 0.5 gain."""
import csv
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
out=Path(__file__).resolve().parents[1]/'output'
with (out/'wireless_samples.csv').open(newline='') as f: rows=list(csv.DictReader(f))
rows=[r for r in rows if 100<=int(r['cycle'])<300]
t=[(int(r['cycle'])-100)/8.192 for r in rows]
fig, axes=plt.subplots(5,1,figsize=(13,9),sharex=True,constrained_layout=True)
for ax,key in zip(axes,['pn','tx_i','rx_i','envelope','demod']):
 ax.plot(t,[int(r[key]) for r in rows],drawstyle='steps-post' if key in ('pn','demod') else 'default',lw=1.2)
 ax.set_ylabel(key); ax.grid(alpha=.3)
 if key=='envelope': ax.axhline(250,color='red',ls='--',lw=.9,label='threshold'); ax.legend(loc='upper right')
axes[0].set_title('Simulated I/Q channel: 4-sample delay, gain 0.5')
axes[-1].set_xlabel('Time (us)')
fig.savefig(out/'radio_simulation.png',dpi=160)
