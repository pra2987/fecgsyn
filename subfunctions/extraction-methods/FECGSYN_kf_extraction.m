function residual = FECGSYN_kf_extraction(peaks,ecg,debug,varargin)
% MECG cancellation algorithms using the Extended Kalman Filter/Smoother.
% The code is based on the code provided in OSET Toolbox (http://www.oset.ir/)
% by Dr. Reza Sameni and and also in (Andreotti 2014)
%
% Inputs
%   peaks:      MQRS markers in ms. Each marker corresponds to the
%               position of a MQRS
%   ecg:        matrix of abdominal ecg channels
%   varargin (in this order):
%       nbCycles:   number of cycles to use in order to build the mean MECG template
%       fs:         sampling frequency (NOTE: this code is meant to work at 1kHz)
%       smoothFlag: 0 for extraction using EKF and 1 for extraction using
%                   the offline smoothing (EKS) 
% output
%   residual:   residual containing the FECG
%
%
% Reference
% (Andreotti 2014) Andreotti, F., Riedl, M., Himmelsbach, T., Wedekind, D., 
% Wessel, N., Stepan, H., … Zaunseder, S. (2014). Robust fetal ECG extraction and 
% detection from abdominal leads. Physiol. Meas., 35(8), 1551–1567. 
% 
% (OSET) Sameni, R. (2010). The Open-Source Electrophysiological Toolbox (OSET). 
% Retrieved from http://www.oset.ir
% 
% More detailed help is in the <a href="https://fernandoandreotti.github.io/fecgsyn/">FECGSYN website</a>.
%
% Examples:
% TODO
%
% See also:
% FECGSYN_ts_extraction
% FECGSYN_bss_extraction
% FECGSYN_adaptfilt_extraction
% 
%
% fecgsyn toolbox, version 1.0, July 2014
% Released under the GNU General Public License
%
% Copyright (C) 2014  Joachim Behar & Fernando Andreotti
% Oxford university, Intelligent Patient Monitoring Group - Oxford 2014
% joachim.behar@eng.ox.ac.uk, fernando.andreotti@mailbox.tu-dresden.de
%
% Last updated : 19-01-2014
%
% This code was initialy developed by Joachim Behar for the Physionet
% Challenge 2013. More code available here:
% http://physionet.org/challenge/2013/sources/joachim.behar@gmail.com/
%
%
%
% This program is free software; you can redistribute it and/or modify it
% under the terms of the GNU General Public License as published by the
% Free Software Foundation; either version 2 of the License, or (at your
% option) any later version.
% This program is distributed in the hope that it will be useful, but
% WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
% Public License for more details.

%% == Manage inputs
optargs = {20 1000 0};  % default values for [nbCycles fs smoothFlag]
newVals = cellfun(@(x) ~isempty(x), varargin);
optargs(newVals) = varargin(newVals);
[nbCycles,fs,smoothFlag] = optargs{:};

% = input test
if nargin > 5
    error('kf_extraction: too many input arguments \n');
end

% check that number of peaks is higher than nbCycles
if nbCycles>length(peaks)
    error('MECGcancellation Error: more peaks than number of cycles for average ecg');
end

%% == Re-aligning maternal peaks to match channel's peaks

win = round(0.1*fs);       % max window for beat alignment (ms)
y = sort(ecg);
minmax = mean(abs(y(end-floor(0.1*length(y)):end)))>... % finding signal polarity
    mean(abs(y(1:floor(0.1*length(y)))));        % 1 = positive, 0 = negative
interv = arrayfun(@(x) ecg(1,x-win:x+win)',peaks(2:end-1),'UniformOutput',false);       % creates a maternal beat matrix
if minmax
    [~,delay]=cellfun(@(x) max(x), interv);
else
    [~,delay]=cellfun(@(x) min(x), interv);
end
delay = round(median(delay));
peaks = (delay-win-1) + peaks;
% test borders
if peaks(1)<1;peaks(1) = 1; end;
if peaks(end)>length(ecg);peaks(end) = length(ecg); end;

%% == Generate KF's mode
[OptimumParams,phase,ECGsd,w,wsd] = FECGSYN_kf_ECGmodelling(ecg,peaks,nbCycles,fs);


%% == MECG estimation using KF
% = Kalman Filter Parametrization
p = [0.01 0.001 0.001 1 1 0.00001 10]; % calibrated parameters for cov. mat.
y = [phase ; ecg];    % state
% covariance matrix of the process noise vector
N = length(OptimumParams)/3;
Q0 = diag([p(1)*OptimumParams(1:N).^2 p(2)*ones(1,N) p(3)*ones(1,N) p(4)*wsd^2 , p(5)*mean(ECGsd)^2]);
% covariance matrix of the observation noise vector
R0 = diag([p(6)*(w/fs).^2      p(7)*mean(ECGsd).^2]);
% covariance matrix for error
P0 = diag([(2*pi)^2,(10*max(abs(ecg))).^2]); % error covariance matrix
% noises
Wmean = [OptimumParams w 0]';
Vmean = [0 0]'; % mean observation noise vector
% initialize state
X0 = [-pi 0]';  % state initialization

% = Run KF
Xhat = FECGSYN_kf_EKFilter(y,X0,P0,Q0,R0,Wmean,Vmean,OptimumParams,w,fs,flag);

if smoothFlag
    warning('Smoothing not currently implemented.')
end
%% == compute residual
residual = ecg - Xhat(2,:);

% == debug
if debug
   FONT_SIZE = 15;
   tm = 1/fs:1/fs:length(residual)/fs;
   figure('name','MECG cancellation');
   plot(tm,ecg,'LineWidth',3);
   hold on, plot(tm,ecg-residual,'--k','LineWidth',3);
   hold on, plot(tm,residual-1.5,'--r','LineWidth',3);
   hold on, plot(tm(peaks),ecg(peaks),'+r','LineWidth',2);
   
   legend('mixture','template','residual','MQRS');
   title('Template subtraction for extracting the FECG');
   xlabel('Time [sec]'); ylabel('Amplitude [NU]')
   set(gca,'FontSize',FONT_SIZE);
   set(findall(gcf,'type','text'),'fontSize',FONT_SIZE);
end

end






















