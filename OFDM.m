% ---------------------------------------------------------
% Project: End-to-End OFDM Wireless Link Simulation
% Simulates OFDM performance across multiple SNRs
% ---------------------------------------------------------

clear; clc; close all;

%% 1. SYSTEM PARAMETERS
N_fft = 64;          % FFT Size
N_cp = 16;           % Cyclic Prefix
num_symbols = 100;  % Total symbols
M = 4;               % Modulation Order (QPSK)
SNR_vec = [5, 10, 15, 20]; % SNR values to test (dB)

%% 2. TRANSMITTER (Tx)

% Step A: Generate Random Bits
num_bits = N_fft * num_symbols * log2(M);
tx_bits = randi([0 1], num_bits, 1);

% Step B: QPSK Modulation
tx_data = qammod(tx_bits, M, 'InputType', 'bit', 'UnitAveragePower', true);

% Step C: OFDM Frame Construction
tx_grid = reshape(tx_data, N_fft, num_symbols);

% Step D: IFFT
tx_time_domain = ifft(tx_grid, N_fft);

% Step E: Add Cyclic Prefix
cp = tx_time_domain(end-N_cp+1:end, :); 
tx_with_cp = [cp; tx_time_domain];

% Serialize
tx_serial = tx_with_cp(:);

%% 3. MULTIPATH CHANNEL SETUP

% Define Static Multipath Channel (Rayleigh Fading)
h_channel = [1, 0.2, 0.1, 0.05]; 
h_channel = h_channel / norm(h_channel); 

% Apply Fading (Convolution)
rx_faded = conv(tx_serial, h_channel);
rx_faded = rx_faded(1:length(tx_serial)); % Truncate tail

% Pre-calculate Frequency Response for Equalizer
H_freq = fft(h_channel, N_fft).'; 

%% 4. SIMULATION LOOP (Multiple SNRs)

ber_results = zeros(length(SNR_vec), 1);
figure;

for i = 1:length(SNR_vec)
    current_snr = SNR_vec(i);
    
    % --- A. CHANNEL NOISE ---
    rx_serial = awgn(rx_faded, current_snr, 'measured');

    % --- B. RECEIVER (Rx) ---
    % Serial to Parallel
    rx_parallel = reshape(rx_serial, N_fft + N_cp, num_symbols);

    % Remove Cyclic Prefix
    rx_no_cp = rx_parallel(N_cp+1:end, :);

    % FFT
    rx_grid = fft(rx_no_cp, N_fft);

    % --- C. EQUALIZATION (Zero-Forcing) ---
    % Divide received signal by channel response
    rx_equalized = rx_grid ./ H_freq;

    % --- D. DEMODULATION ---
    rx_data = rx_equalized(:);
    rx_bits = qamdemod(rx_data, M, 'OutputType', 'bit', 'UnitAveragePower', true);

    % --- E. METRICS ---
    [~, ber] = biterr(tx_bits, rx_bits);
    ber_results(i) = ber;
    
    fprintf('SNR: %2d dB | BER: %.5f\n', current_snr, ber);

    % --- F. VISUALIZATION ---
    subplot(2, 2, i);
    plot(real(rx_data(1:1000)), imag(rx_data(1:1000)), 'rx'); 
    hold on;

    plot(real(qammod([0:3], M, 'UnitAveragePower', true)), ...
         imag(qammod([0:3], M, 'UnitAveragePower', true)), 'bo', 'MarkerFaceColor', 'b', 'MarkerSize', 8);
    title(['SNR = ' num2str(current_snr) ' dB']);
    axis([-2 2 -2 2]); grid on; axis square;
    xlabel('In-Phase'); ylabel('Quadrature');
end
