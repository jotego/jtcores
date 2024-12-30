% Sampling frequency and cutoff frequency
fs = 192000; % Sampling frequency in Hz
fc = 10000;    % Cutoff frequency in Hz

% Calculate pre-warped frequency
omega_c = 2 * pi * fc;
Omega_c = tan(omega_c / (2 * fs));

% Calculate filter coefficients
b0 = 1 / (1 + Omega_c);
b1 = -b0;
a1 = (Omega_c - 1) / (Omega_c + 1);

% Define filter coefficients
b = [b0, b1];  % Numerator coefficients
a = [1, a1];   % Denominator coefficients

% Frequency response of the filter
[H, f] = freqz(b, a, 2048, fs); % Compute frequency response

% Plot magnitude response
figure;
% plot(f, abs(H));
semilogx(f, 20*log10(abs(H)));
grid on;
xlabel('Frequency (Hz)');
ylabel('Magnitude');
title('Magnitude Response of the 1st-Order High-Pass IIR Filter');

format long
round(b0*2^14)
round(a1*2^14)