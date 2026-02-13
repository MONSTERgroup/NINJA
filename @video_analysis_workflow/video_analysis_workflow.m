classdef video_analysis_workflow < handle
    % VIDEO_ANALYSIS_WORKFLOW Manages video analysis workflow for bend measurements
    %
    % This class handles the complete workflow for calculating bending
    % angles during laser sheet metal forming using a Randon transform
    % approach.
    %  
    % Properties:
    %   input_dir        - Directory containing input video files
    %   output_dir       - Directory for output files
    %   file_name        - Name of the video file (without extension)
    %   file_extension   - File extension (e.g., '.mp4', '.avi')
    %   video_crop_roi   - Region of interest for cropping [x, y, width, height]
    %   video_cropped    - Path to cropped video output
    %   data             - Nx2 array [bend_angle, timestamp] for each frame
    %
    % Methods:
    %   video_analysis_workflow - Constructor
    %   create_radon_bend_data  - Main analysis function using Radon transform
    
    properties
        input_dir           % Input directory path
        output_dir          % Output directory path
        file_name           % Video filename without extension
        file_extension      % File extension (e.g., '.mp4')
        video_crop_roi      % ROI coordinates [x, y, width, height]
        video_cropped       % Path to cropped video
        data                % Analysis results [angle, time]
    end

    properties(Dependent)
        path_to_video       % Full path to input video file
    end

    methods
        function wf = video_analysis_workflow(varargin)
            % VIDEO_ANALYSIS_WORKFLOW Constructor for workflow object
            %
            % Usage:
            %   wf = video_analysis_workflow()
            %   wf = video_analysis_workflow(input_path)
            %   wf = video_analysis_workflow(input_path, output_path)
            %   wf = video_analysis_workflow(input_path, output_path, crop_roi)
            %
            % Inputs:
            %   input_path  - Path to video file or input directory
            %   output_path - Path to output directory (optional)
            %   crop_roi    - Crop region [x, y, width, height] (optional)

            % Set default directories to current working directory
            wf.input_dir = pwd;
            wf.output_dir = pwd;

            % Parse first argument (input path)
            if nargin >= 1 && isText(varargin{1}) && exist(varargin{1}, 'file')
                [~, v] = fileattrib(varargin{1});
                if isfolder(v.Name)
                    % Input is a directory
                    wf.input_dir = v.Name;
                    wf.output_dir = v.Name;
                elseif isfile(v.Name)
                    % Input is a file
                    [p, wf.file_name, wf.file_extension] = fileparts(v.Name);
                    wf.input_dir = p;
                    wf.output_dir = p;
                end
            end

            % Parse second argument (output directory)
            if nargin >= 2 && isText(varargin{2}) && exist(varargin{2}, 'file')
                [~, v] = fileattrib(varargin{2});
                if isfolder(v.Name)
                    wf.output_dir = v.Name;
                end
            end

            % Parse third argument (crop ROI)
            if nargin >= 3 && ~isnan(any(varargin{3}))
                wf.video_crop_roi = varargin{3};
            end
        end
        
        % Method implementations
        create_radon_bend_data(wf, varargin)

        % Dependent property getter
        function path = get.path_to_video(wf)
            % GET.PATH_TO_VIDEO Returns full path to the video file
            path = fullfile(wf.input_dir, [wf.file_name wf.file_extension]);
        end
    end
end