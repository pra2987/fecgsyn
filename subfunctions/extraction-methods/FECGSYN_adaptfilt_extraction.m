function ecg_res = FECGSYN_adaptfilt_extraction(ecg_target,ecg_ref,method,debug,varargin)
% MECG cancellation algorithms using a adaptive filtring methods.
% Implemented methods as in [1]:
%               Least Mean Square (LMS)
%               Recursive Least Square (RLS)
%               Echo State Neural Network (ESN)
% inputs
%   peaks:      MQRS markers in ms. Each marker corresponds to the
%               position of a MQRS
%   ecg:        matrix of abdominal ecg channels
%   refecg:     reference ECG with maternal signal
%   method:     method to use (LMS,RLS,ESN)
%   debug:      debug mode (boolean)
%
%  (optional inputs)
%  fs:          sampling frequency (default = 250 Hz)
%  metStruct:   structure containing parameters relative to desired method
%
% output
%   residual:   residual containing the FECG
%
% References:
% [1] Behar, J., Johnson, A. E. W., Clifford, G. D., & Oster, J. (2014). A
%     Comparison of Single Channel Fetal ECG Extraction Methods. Annals of
%     Biomedical Engineering. doi:10.1007/s10439-014-0993-9
%
%
% Examples:
% TODO
%
% See also:
% FECGSYN_ts_extraction
% FECGSYN_bss_extraction
% FECGSYN_kf_extraction
%
% --
% fecgsyn toolbox, version 1.1, March 2016
% Released under the GNU General Public License
%
% Copyright (C) 2014  Joachim Behar & Fernando Andreotti
% Oxford university, Intelligent Patient Monitoring Group - Oxford 2014
% joachim.behar@eng.ox.ac.uk, fernando.andreotti@mailbox.tu-dresden.de
%
% 
% For more information visit: https://www.physionet.org/physiotools/ipmcode/fecgsyn/
% 
% Referencing this work
%
%   Behar Joachim, Andreotti Fernando, Zaunseder Sebastian, Li Qiao, Oster Julien, Clifford Gari D. 
%   An ECG simulator for generating maternal-foetal activity mixtures on abdominal ECG recordings. 
%   Physiological Measurement.35 1537-1550. 2014.
%
% Last updated : 10-03-2016
% 
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
% 
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
% 
% You should have received a copy of the GNU General Public License
% along with this program.  If not, see <http://www.gnu.org/licenses/>.




% == manage inputs
fs_new = 250; % data will be resampled to 250 since coefficients have
% been calibrated as such
method = upper(method);

switch length(varargin)
    case 0
        fs_orig = 1000;
        default_param = 1;
    case 1
        fs_orig = varargin{1};
        default_param = 1;
    case 2
        fs_orig = varargin{1};
        metStruct = varargin{2};
    otherwise
        error('adaptfilt_extractio: Too many inputs given to function')
end

% resampling input signals
ecg_target = resample(ecg_target,fs_new,fs_orig);
ecg_ref = resample(ecg_ref,fs_new,fs_orig);


% == running methods
switch method
    case 'LMS'
        % - using Least Mean Square -
        if default_param
            metStruct.mu             = 0.1; % 0.1- step size
            metStruct.Nunits         = 20; % 20- filter length
            metStruct.learningMode   = 'online'; % 'online'/'offline'
            metStruct.method         = 'LMS';
        end
        ecg_res =FECGESN_lmsrls_canceller(ecg_ref,ecg_target,fs_new,metStruct,debug);
    case 'RLS'
        % - using RLS -
        if default_param
            metStruct.mu             = 0.999; % 0.999- forgetting factor
            metStruct.Nunits         = 20; % 20- filter length
            metStruct.method         = 'RLS';
        end
        ecg_res = FECGESN_lmsrls_canceller(ecg_ref,ecg_target,fs_new,metStruct,debug);
    case 'ESN'
        % - using ESN -
        if default_param
            metStruct.nInternalUnits = 90;
            metStruct.leakage = 0.4;
            metStruct.spectralRadius = 0.4;
            metStruct.regenerate = 0;
            metStruct.useDeriv = 0;
            metStruct.learningMode = 'online';
            metStruct.noiseLevel = 0;
            nInputUnits = 1+metStruct.useDeriv; % one reference channel
            % define ESN parameters (old metStruct)
            esn = ESNTOOL_generate_esn(nInputUnits,metStruct.nInternalUnits,1, ...
                'spectralRadius',metStruct.spectralRadius,...
                'inputScaling',ones(nInputUnits,1),...
                'inputShift',zeros(nInputUnits,1), ...
                'teacherScaling',1,...
                'feedbackScaling',0, ...
                'learningMode',metStruct.learningMode,...
                'RLS_lambda',0.999,...
                'RLS_delta',0.01, ...
                'noiseLevel',metStruct.noiseLevel, ...
                'type','ESNTOOL_leaky_esn',...
                'leakage',metStruct.leakage);  
            esn.internalWeights = esn.spectralRadius*esn.internalWeights_UnitSR;
%             save('esn','esn');
        end
        ecg_res = FECGESN_esn_canceller(ecg_ref,ecg_target,fs_new,esn,debug);
    otherwise
        error('adaptfilt_extraction: Method not implemented.')
end

% upsample output
ecg_res = resample(ecg_res,fs_orig,fs_new);


% TODO: Debug mode













