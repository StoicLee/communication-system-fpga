clear; close all; clc;
here = fileparts(mfilename('fullpath'));
root = fileparts(here);
out = fullfile(root, 'output');
coe_path = fullfile(root, 'coeff', 'lpf_ask_17tap.coe');

% Design the FIR at the rate of the distinct carrier samples.
fs = 8.192e6;
fc = 1.024e6;
fpass = 1e6;
fstop = 2e6;
order = 16;
samples_per_symbol = round(fs/fc);
carrier = [0 1447 2047 1447 0 -1447 -2047 -1447];

b = firpm(order, [0 fpass fstop fs/2]/(fs/2), [1 1 0 0], [1 12]);
coeff_q15 = round(32768 * b / sum(b));
center = order/2 + 1;
coeff_q15(center) = coeff_q15(center) + 32768 - sum(coeff_q15);
assert(isequal(coeff_q15, fliplr(coeff_q15)), 'FIR must be symmetric.');
assert(all(coeff_q15 >= -32768 & coeff_q15 <= 32767), 'Q1.15 overflow.');
coeff = coeff_q15 / 32768;

one_envelope = mean(abs(carrier));
threshold = floor(one_envelope/2) + 1;
assert(one_envelope == 1235.25, 'Unexpected detector level.');

Hd = dfilt.dffir(coeff);
set(Hd, 'Arithmetic','fixed', 'InputWordLength',12, ...
    'InputFracLength',0, 'CoeffWordLength',16, ...
    'CoeffAutoScale',false, 'NumFracLength',15, ...
    'FilterInternals','FullPrecision');
save(fullfile(out, 'filter_designer.mat'), 'Hd', 'fs', 'fc', 'coeff_q15');

[H, freq] = freqz(coeff, 1, 65536, fs);
gain_db = 20*log10(max(abs(H), 1e-8));
passband_db = gain_db(freq <= fpass);
ripple_db = max(passband_db) - min(passband_db);
stop_attenuation_db = -max(gain_db(freq >= fstop));
steady_envelope = filter(coeff, 1, repmat(abs(carrier), 1, 16));
steady_ripple_pp = max(steady_envelope(end-7:end)) - min(steady_envelope(end-7:end));
assert(steady_ripple_pp <= 4, 'Steady one-symbol envelope ripple exceeds 4 counts.');
assert(ripple_db <= 0.65 && stop_attenuation_db >= 50, ...
    'Quantized FIR did not meet the response checks.');
fresp = figure('Color','w','Position',[160 160 920 520]);
plot(freq/1e6, gain_db, 'LineWidth', 1.2);
grid on; xlim([0 fs/2/1e6]); ylim([-110 5]);
xlabel('Frequency (MHz)'); ylabel('Magnitude (dB)');
title('17-tap ASK envelope low-pass FIR');
xline(fpass/1e6, '--', 'Fpass = 1 MHz');
xline(fstop/1e6, '--', 'Fstop = 2 MHz');
exportgraphics(fresp, fullfile(out, 'lpf_frequency_response.png'), 'Resolution', 180);
close(fresp);

state = uint8(1);
pn = zeros(1, 31);
for k = 1:31
    pn(k) = bitget(state, 5);
    feedback = bitxor(bitget(state, 5), bitget(state, 3));
    state = bitand(bitshift(state, 1), uint8(31)) + uint8(feedback);
end
assert(state == 1, 'PN state period is not 31.');

ask = kron(pn, carrier);
rectified = abs(ask);
envelope = max(0, floor(filter(coeff, 1, rectified)));
group_delay = (numel(coeff)-1)/2;
decision_first_0based = round(group_delay + (samples_per_symbol-1)/2);
decision_indices = (decision_first_0based+1):samples_per_symbol:numel(envelope);
symbol_level = envelope(decision_indices);
expected = pn(1:numel(symbol_level));
demod_bits = symbol_level >= threshold;
assert(all(demod_bits == expected), 'MATLAB demodulation contains bit errors.');
zero_max = max(symbol_level(expected == 0));
one_min = min(symbol_level(expected == 1));
assert(zero_max <= 300 && one_min >= 900, 'Insufficient decision margin.');

coe = fopen(coe_path, 'w');
assert(coe >= 0, 'Could not write the coefficient file.');
fprintf(coe, 'radix=10;\ncoefdata=\n');
fprintf(coe, '%d,\n', coeff_q15(1:end-1));
fprintf(coe, '%d;\n', coeff_q15(end));
fclose(coe);

demod = repelem(demod_bits, samples_per_symbol);
demod = [zeros(1, decision_first_0based), demod];
demod = demod(1:min(numel(demod),numel(ask)));
t = (0:numel(ask)-1)/fs*1e6;

f = figure('Color','w','Position',[120 120 1120 760]);
tiledlayout(4,1,'TileSpacing','compact','Padding','compact');
nexttile;
plot(t, ask, 'LineWidth', 1.0); grid on; xlim([0 12]);
ylabel('2ASK'); title('Lab 4: zero-crossing 2ASK and 17-tap envelope detector');
nexttile;
plot(t, rectified, 'LineWidth', 1.0); grid on; xlim([0 12]);
ylabel('|2ASK|');
nexttile;
plot(t, envelope, 'LineWidth', 1.1); hold on;
yline(threshold, '--', 'Threshold'); grid on; xlim([0 12]);
ylabel('Envelope');
nexttile;
stairs(t, repelem(pn,samples_per_symbol), 'LineWidth', 1.1); hold on;
stairs(t(1:numel(demod)), demod, '--', 'LineWidth', 1.1);
grid on; xlim([0 12]); xlabel('Time (us)'); ylabel('Bit');
legend('PN input','Delayed decision','Location','best');
exportgraphics(f, fullfile(out, 'matlab_verification.png'), 'Resolution', 180);
save(fullfile(out, 'matlab_verification.mat'), 'fs','fc','pn','ask', ...
    'rectified','envelope','demod','threshold','coeff_q15','group_delay');

fprintf(['MATLAB PASS: order=%d, taps=%d, Fs=%.3f MHz, ripple=%.3f dB, ' ...
    'stop attenuation=%.2f dB\n'], order, numel(coeff), fs/1e6, ...
    ripple_db, stop_attenuation_db);
fprintf('Steady one-symbol envelope ripple peak-to-peak = %.2f counts\n', steady_ripple_pp);
fprintf('Decision errors=0; 0 max=%d, threshold=%d, 1 min=%d\n', ...
    zero_max, threshold, one_min);
