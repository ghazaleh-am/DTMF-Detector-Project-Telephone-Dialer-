clc; clear; close all;

%% --- بخش ۱: تنظیمات و دیتابیس فرکانس‌ها ---
Fs = 8000;       % فرکانس نمونه‌برداری (استاندارد مخابرات)
tone_time = 0.2; % مدت زمان هر دکمه (ثانیه)
silence_time = 0.1; % سکوت بین دکمه‌ها

% تعریف فرکانس‌های استاندارد DTMF
low_freqs = [697, 770, 852, 941];  % فرکانس‌های سطر
high_freqs = [1209, 1336, 1477];   % فرکانس‌های ستون

% تعریف دکمه‌ها در یک ماتریس (مثل صفحه کلید تلفن)
keypad = [
    '1', '2', '3';
    '4', '5', '6';
    '7', '8', '9';
    '*', '0', '#'
];

%% --- بخش ۲: فرستنده (تولید سیگنال DTMF) ---
phone_number = input('Enter phone number (e.g., 0912): ', 's');
full_signal = [];

for i = 1:length(phone_number)
    key = phone_number(i);
    
    % پیدا کردن موقعیت دکمه در ماتریس
    [row, col] = find(keypad == key);
    
    if isempty(row)
        disp(['Invalid key skipped: ', key]);
        continue;
    end
    
    % تولید دو موج سینوسی
    f_low = low_freqs(row);
    f_high = high_freqs(col);
    
    t = 0 : 1/Fs : tone_time;
    % سیگنال DTMF = جمع دو سینوسی
    tone = sin(2*pi*f_low*t) + sin(2*pi*f_high*t);
    
    % اضافه کردن نویز (برای واقعی‌تر شدن پروژه)
    noise = 0.2 * randn(size(tone)); 
    tone = tone + noise;
    
    % ساخت سیگنال نهایی (دکمه + سکوت)
    full_signal = [full_signal, tone, zeros(1, round(silence_time*Fs))];
end

% پخش صدای تولید شده
disp('Playing DTMF sound...');
sound(full_signal, Fs);
pause(length(full_signal)/Fs + 0.5);

%% --- بخش ۳: گیرنده (تشخیص با FFT) ---
disp('Decoding signal using FFT...');

% تقسیم سیگنال به قطعات جداگانه (بر اساس زمان‌بندی که می‌دانیم)
% نکته: در سیستم‌های واقعی از "تشخیص انرژی" برای یافتن شروع سیگنال استفاده می‌شود.
samples_per_tone = round(tone_time * Fs);
samples_total_step = round((tone_time + silence_time) * Fs);

decoded_number = '';

num_digits = length(phone_number);

figure; % باز کردن یک پنجره بزرگ قبل از حلقه

for i = 1:num_digits
    % ... (کدهای استخراج سیگنال و محاسبات FFT مثل قبل) ...
    start_idx = (i-1)*samples_total_step + 1;
    end_idx = start_idx + samples_per_tone - 1;
    segment = full_signal(start_idx:end_idx);
    
    N = length(segment);
    Y = fft(segment);
    P2 = abs(Y/N);
    P1 = P2(1:floor(N/2)+1);
    P1(2:end-1) = 2*P1(2:end-1);
    f = Fs * (0:(N/2)) / N;
    
    valid_idx = f > 600 & f < 1600;
    valid_f = f(valid_idx);
    valid_p = P1(valid_idx);
    
    [pks, locs] = findpeaks(valid_p, 'MinPeakHeight', 0.2, 'MinPeakDistance', 50);
    [~, sorted_idx] = sort(pks, 'descend');
    
    % ... (کد تشخیص عدد مثل قبل) ...
    detected_char = '?'; % پیش‌فرض
    if length(sorted_idx) >= 2
        detected_freqs = valid_f(locs(sorted_idx(1:2)));
        detected_freqs = sort(detected_freqs);
        
        [~, r_idx] = min(abs(low_freqs - detected_freqs(1)));
        [~, c_idx] = min(abs(high_freqs - detected_freqs(2)));
        detected_char = keypad(r_idx, c_idx);
    end
    decoded_number = [decoded_number, detected_char];

    % --- تغییرات برای رسم همه نمودارها ---
    
    % تقسیم صفحه به تعداد ارقام (مثلاً ۴ سطر و ۱ ستون)
    subplot(num_digits, 1, i); 
    
    plot(f, P1, 'b'); % رسم با رنگ آبی
    grid on; xlim([600 1600]); % زوم روی فرکانس‌های مهم
    
    % نوشتن عدد تشخیص داده شده بالای هر نمودار
    title(['Digit ', num2str(i), ': "', detected_char, '"']);
    
    % فقط برای نمودار آخر محور x را نامگذاری کن (تمیزکاری)
    if i == num_digits
        xlabel('Frequency (Hz)');
    end
    ylabel('Mag');
    
    % علامت‌گذاری قله‌ها با ستاره قرمز
    hold on;
    if length(sorted_idx) >= 2
        plot(valid_f(locs(sorted_idx(1:2))), pks(sorted_idx(1:2)), 'r*', 'MarkerSize', 8);
    end
end

sgtitle(['Decoded Number: ', decoded_number]); % تیتر کلی بالای صفحه

fprintf('\nOriginal Number: %s\n', phone_number);
fprintf('Decoded Number:  %s\n', decoded_number);