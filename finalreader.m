function [wavelength, power_W, power_dBm] = read_advantest_spe(filename)
% READ_ADVANTEST_SPE  Read Advantest Q8383 OSA .SPE binary file
%
% Usage:
%   [wavelength, power_W, power_dBm] = read_advantest_spe('w2.SPE')
%
% Outputs:
%   wavelength  - wavelength axis in nm  [501x1]
%   power_W     - power in Watts         [501x1]
%   power_dBm   - power in dBm           [501x1]
%
% The function also plots the spectrum in dBm (OSA-style).

if nargin < 1
    filename = 'f1.SPE';
end

%% --- Open file ---
fid = fopen(filename, 'r', 'b');   % 'b' = big-endian
if fid == -1
    error('Cannot open file: %s', filename);
end
raw = fread(fid, inf, 'uint8');
fclose(fid);

%% --- Parse text header (starts at offset 257, 1-based) ---
% Header block contains: n_points, wl_start, wl_stop, center, span, ...
header_offset = 257;   % 1-based index in MATLAB
header_block  = char(raw(header_offset : min(end, header_offset+600)))';

% Extract fields separated by non-printable characters
fields = regexp(header_block, '[^\x20-\x7E]+', 'split');
fields = fields(~cellfun(@isempty, strtrim(fields)));

% Parse known fields
n_points  = str2double(fields{2});            % e.g. 501
wl_start  = str2double(fields{3}) * 1e9;     % metres -> nm, e.g. 758.46
wl_stop   = str2double(fields{4}) * 1e9;     % metres -> nm, e.g. 798.46

fprintf('File       : %s\n', filename);
fprintf('Points     : %d\n', n_points);
fprintf('Wavelength : %.2f – %.2f nm\n', wl_start, wl_stop);
fprintf('Date/Time  : %s  %s\n', strtrim(fields{12}), strtrim(fields{13}));

%% --- Read spectral data (big-endian float32, offset 2177 bytes, 1-based) ---
data_offset = 2177;   % 1-based byte offset where float32 data starts

% Reopen in big-endian float mode
fid = fopen(filename, 'r', 'ieee-be');
fseek(fid, data_offset - 1, 'bof');          % fseek is 0-based
power_W = fread(fid, n_points, 'float32');
fclose(fid);

%% --- Build wavelength axis ---
wavelength = linspace(wl_start, wl_stop, n_points)';

%% --- Convert to dBm ---
power_dBm = 10 .* log10(power_W ./ 1e-3);

%% --- Plot (OSA style: dBm vs nm) ---
figure;
plot(wavelength, power_dBm, 'b-', 'LineWidth', 1.2);
grid on;
xlabel('Wavelength (nm)');
ylabel('Power (dBm)');
title(sprintf('Advantest Q8383 Spectrum  —  %s', filename));
xlim([wl_start wl_stop]);

% Mark the peak
[pk_dBm, pk_idx] = max(power_dBm);
pk_wl = wavelength(pk_idx);
hold on;
plot(pk_wl, pk_dBm, 'rv', 'MarkerSize', 10, 'MarkerFaceColor', 'r');
text(pk_wl + 0.3, pk_dBm - 1.5, ...
     sprintf('%.2f nm\n%.1f dBm', pk_wl, pk_dBm), ...
     'Color', 'r', 'FontSize', 9);
hold off;

fprintf('Peak       : %.2f nm  (%.1f dBm)\n', pk_wl, pk_dBm);

end
