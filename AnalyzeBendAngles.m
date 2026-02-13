%% Video Bend Analysis - Main Script
% This script processes video files to analyze bending behavior using Radon transform
% Entry point for the video analysis workflow
%
% Required Files:
%   - video_analysis_workflow.m
%   - create_radon_bend_data.m
%
% Output:
%   - Analyzed video files with angle overlays
%   - Workspace data files with bend measurements

close all
clear
clc

%% Configuration
% Define list of video files to process
% Update this path to point to your video files
fileNameList = ["path\to\your\video\file.MP4"];

% Extract sample identifiers from filenames
% Assumes format: path\...\SAMPLEID_..._DATE.MP4
% The s(x:y) indices are very hardcoded to our data setup. I might fix this
% later, but probably not. In effect, it's stripping out just a name and
% getting rid of the prior path, a date/timecode, and the file extension.
FileNamesActual = string(cellfun(@(s) s(25:32), fileNameList, 'UniformOutput', false));

%% Main Processing Loop
for i = 1:length(fileNameList)
    % Clear variables for each iteration to avoid data contamination
    clear a change_points dangle_dt fileDir fileName fileType numChangePoints P passLength passTime S shifted_angles shifted_times slope smooth_da_dt std_dev stopLocations time_end time_start
    
    % Parse file information
    fileDir = fileNameList{i}(1:24);
    fileName = fileNameList{i};
    fileType = ".MP4";
    
    disp("Analyzing video for: " + fileNameList{i})

    %% Initialize Video Analysis Workflow
    % For first video, let user define crop region
    % For subsequent videos, reuse the crop region
    if i == 1
        a = video_analysis_workflow(fileName, 'Analyzed Videos');
        a.create_radon_bend_data;
        crop = a.video_crop_roi;  % Save crop region for reuse
    else
        a = video_analysis_workflow(fileName, 'Analyzed Videos', crop);
        a.create_radon_bend_data;
    end

    %% Extract and Process Data
    % Get raw time and angle data from analysis
    raw_times = a.data(:, 2);
    raw_angles = a.data(:, 1);
    
    % Define analysis time window (entire video by default)
    time_start = 1;
    time_end = length(raw_times);
    
    % Shift times to start at zero (for if the analysis window is not the
    % entire video)
    shifted_times = raw_times(time_start:time_end) - raw_times(time_start);
    shifted_angles = raw_angles(time_start:time_end);
    
    % Remove missing data points
    shifted_times = shifted_times(~ismissing(shifted_angles));
    shifted_angles = shifted_angles(~ismissing(shifted_angles));
    
    % Normalize angles to start at zero
    shifted_angles = shifted_angles - shifted_angles(1);
    
    %% Extract Bend Parameters from Filename
    % Parse laser power and speed from filename
    % Expected format: ..._PPPP_SSSS_...
    stopLocations = strfind(fileName, '_');
    P = str2double(fileName(stopLocations(2)+4:stopLocations(2)+5)); % Power (%)
    S = str2double(fileName(stopLocations(3)-3:stopLocations(3)-1)); % Speed (mm/s)
    
    % Calculate pass timing
    passLength = 20; % mm
    passTime = passLength / double(S); % seconds
    
    %% Generate Time vs Bend Plot (Raw Data)
    figure;
    plot(shifted_times, shifted_angles);
    xlabel('Time (s)');
    ylabel('Bend Angle (degrees)');
    title(fileName(25:32));
    PrettyPlotsSingle;  % Apply custom plotting style
    
    %% Optional: Smoothed Data Plot (Currently Commented Out)
    % Uncomment to generate smoothed bend angle plot
    % figure;
    % plot(shifted_times, smoothdata(shifted_angles, 'movmean', 100));
    % xlabel('Time (s)');
    % ylabel('Bend Angle (degrees)');
    % title('Curve fit to smooth data');
    % PrettyPlotsSingle;
    
    %% Optional: Slope Calculations (Currently Commented Out)
    % Uncomment and implement Slope_Calculations function as needed
    % numChangePoints = 4;
    % [slope, std_dev, smooth_da_dt, dangle_dt, change_points] = ...
    %     Slope_Calculations(shifted_times, shifted_angles, numChangePoints);
    
    %% Save Results
    % Save workspace variables for this sample
    save(FileNamesActual(i));
end