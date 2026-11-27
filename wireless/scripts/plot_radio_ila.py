"""Plot one complete PN period from the wireless ILA or simulation preview.

Hardware input is a Vivado write_hw_ila_data -csv_file export, including its
radix row. Simulated input comes from tb_iq_link. All values in the period CSV
are signed/unsigned decimal, not analog RF voltages.
"""
import argparse
import csv
import re
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

ROOT = Path(__file__).resolve().parents[1]
SIGNALS = ('pn','tx_i','tx_q','rx_i','rx_q','envelope','demod','valid','timing_locked')
WIDTHS = dict(pn=1,tx_i=12,tx_q=12,rx_i=12,rx_q=12,envelope=13,demod=1,valid=1,timing_locked=1)
SIGNED = {'tx_i','tx_q','rx_i','rx_q'}

def number(value, radix, width, signed):
    value=value.strip().replace('_','')
    if value.lower().startswith('0x'): value=value[2:]
    if re.search(r'[xXzZ?]',value):
        raise ValueError(f'Unknown or incomplete ILA value: {value}')
    tag=radix.strip().upper()
    base=16 if 'HEX' in tag else 2 if 'BIN' in tag else 10
    v=int(value,base)
    if signed and v>=1<<(width-1): v-=1<<width
    return v

def load(path, kind):
    with path.open(newline='',encoding='utf-8-sig') as f:
        reader=csv.reader(f)
        headers=next(reader)
        rows=list(reader)
    radix=['UNSIGNED']*len(headers)
    if kind=='hardware':
        if not rows or not rows[0] or not rows[0][0].strip().lower().startswith('radix'):
            raise ValueError('Expected the Vivado radix row after the CSV header')
        radix=rows.pop(0)
    cols={}
    for name in SIGNALS:
        pattern=re.compile(r'(?:^|[/\.])'+re.escape(name)+r'(?:\[[^]]+\])?$',re.I)
        matches=[i for i,h in enumerate(headers) if pattern.search(h.strip())]
        if len(matches)!=1:
            raise ValueError(f'Expected exactly one {name} probe; columns={headers}')
        cols[name]=matches[0]
    data={n:[] for n in SIGNALS}
    for row in rows:
        if len(row)<len(headers): raise ValueError('Truncated CSV row')
        for n,k in cols.items():
            data[n].append(number(row[k],radix[k] if k<len(radix) else '',WIDTHS[n],n in SIGNED))
    if len(data['pn'])<31*8: raise ValueError('Capture is shorter than one PN period')
    return data

def aligned_start(pn):
    state=1; bits=[]
    for _ in range(31):
        bits.append((state>>4)&1)
        state=((state<<1)&31)|(((state>>4)^(state>>2))&1)
    assert state==1
    # First bit after the four initial zeros goes 0->1. Matching all 31
    # centre samples identifies the period, not merely an arbitrary edge.
    for edge in range(1,len(pn)):
        if pn[edge-1]==0 and pn[edge]==1:
            start=edge-4*8
            if start>=12 and start+31*8+16<len(pn) and all(pn[start+8*j+4]==v for j,v in enumerate(bits)):
                return start
    raise ValueError('No aligned 31-symbol PN period with surrounding samples found')

def main():
    p=argparse.ArgumentParser()
    p.add_argument('--source',choices=('sim','hardware'),required=True)
    p.add_argument('csv',type=Path,nargs='?')
    args=p.parse_args()
    path=args.csv or ROOT/'output'/('radio_ila_sim.csv' if args.source=='sim' else 'radio_ila_capture.csv')
    data=load(path,args.source)
    start=aligned_start(data['pn']); count=31*8
    out=ROOT/'output'; out.mkdir(parents=True,exist_ok=True)
    prefix='radio_ila_sim' if args.source=='sim' else 'radio_ila_capture'
    with (out/(prefix+'_period.csv')).open('w',newline='',encoding='utf-8') as f:
        w=csv.writer(f); w.writerow(('sample',)+SIGNALS)
        for k in range(count): w.writerow((k,)+tuple(data[n][start+k] for n in SIGNALS))
    fig,axes=plt.subplots(len(SIGNALS),1,figsize=(15,11),sharex=True,constrained_layout=True)
    left_period=start-12
    right_period=start+count+16
    t=[(k-start)/8.192 for k in range(left_period,right_period+1)]
    for ax,n in zip(axes,SIGNALS):
        v=data[n][left_period:right_period+1]
        is_logic=n in ('pn','demod','valid','timing_locked')
        ax.plot(t,v,drawstyle='steps-post' if is_logic else 'default',linewidth=1)
        ax.axvline(0,color='darkorange',ls='--',lw=.8)
        ax.axvline(count/8.192,color='darkorange',ls='--',lw=.8)
        if is_logic: ax.set_ylim(-.25,1.25); ax.set_yticks([0,1])
        if n=='envelope': ax.axhline(250,color='darkorange',ls='--',lw=.8,label='threshold=250'); ax.legend(loc='upper right',fontsize=8)
        ax.set_ylabel(n,rotation=0,ha='right',fontsize=9); ax.grid(alpha=.25)
    label='SIMULATION (synthetic I/Q channel)' if args.source=='sim' else 'HARDWARE ILA (received I/Q)'
    axes[0].set_title(label+' — full PN period between dashed lines, with captured context')
    axes[-1].set_xlabel('Time from PN period start (µs); dashed lines mark period boundaries')
    axes[-1].set_xlim(t[0],t[-1])
    fig.savefig(out/(prefix+'_period.png'),dpi=160)
    plt.close(fig)
    # Include samples on both sides of an isolated 1 symbol. In particular,
    # the sample after the final carrier point shows how the gate turns off.
    left=start+3*8
    right=min(start+9*8-1,len(data['pn'])-1)
    names=('pn','tx_i','tx_q','rx_i','rx_q')
    fig,axes=plt.subplots(len(names),1,figsize=(12,9),sharex=True,constrained_layout=True)
    t=[(k-left)/8.192 for k in range(left,right+1)]
    for ax,n in zip(axes,names):
        v=data[n][left:right+1]
        if n=='pn':
            ax.step(t,v,where='post'); ax.set_ylim(-.25,1.25); ax.set_yticks([0,1])
        else:
            ax.plot(t,v,marker='o',markersize=3,linewidth=1)
            ax.axhline(0,color='black',lw=.4)
        for k in range(start+4*8,right+1,8):
            ax.axvline((k-left)/8.192,color='grey',ls=':',lw=.6)
        ax.set_ylabel(n,rotation=0,ha='right'); ax.grid(alpha=.2)
    axes[0].set_title(label+' — TX/RX digital I/Q, sample points and symbol boundaries')
    axes[-1].set_xlabel('Time (µs); markers = actual samples, dotted lines = PN symbol boundaries')
    axes[-1].set_xlim(t[0],t[-1])
    fig.savefig(out/(prefix+'_tx_rx_detail.png'),dpi=160)
    plt.close(fig)
    print(f'{label}: samples {start}..{start+count-1}; 31 symbols; {count/8.192:.3f} us')

if __name__=='__main__': main()
