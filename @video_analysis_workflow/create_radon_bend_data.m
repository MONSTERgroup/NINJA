function create_radon_bend_data(wf, varargin)
    % CREATE_RADON_BEND_DATA Analyzes video using Radon transform to measure bend angles
    %
    % This function processes video frames to detect and measure bending angles
    % using the Radon transform. It creates an output video with angle annotations
    % and stores angle/time data in the workflow object.
    %
    % Inputs:
    %   wf       - video_analysis_workflow object
    %   varargin - Optional [first_frame, last_frame] to process subset
    %
    % Outputs:
    %   Creates annotated video: [filename]_angle.avi
    %   Populates wf.data with [bend_angle, timestamp] for each frame

    %% Parse Input Arguments
    % Default: process entire video
    first = 1;
    last = Inf;

    if nargin > 1 && isnumeric(varargin{1}) && length(varargin{1}) == 2
        first = varargin{1}(1);
        last = varargin{1}(2);
    end

    %% Initialize Video Reader
    video_reader = VideoReader(wf.path_to_video);

    % Read first and last frames for ROI selection
    first_frame = video_reader.read(first);
    last_frame = video_reader.read(last);

    %% Define or Use Existing Crop Region
    if isempty(wf.video_crop_roi)
        % Interactive ROI selection
        f1 = figure('Name', 'Difference between first and last frames -- Crop video area');
        im_first_last = imshowpair(first_frame, last_frame);
        xlabel('Double click rectangle when done.');
        h_rectangular_ROI = drawrectangle(im_first_last.Parent, 'Color', 'magenta', 'Label', 'Crop');
        wf.video_crop_roi = wait_after_ROI(h_rectangular_ROI);
        clear('h_rectangular_ROI');
        close(f1);
    else
        disp('Using existing crop region for this video')
    end

    %% Initialize Output Video Writer
    % Create video with angle annotations
    vw_angle = VideoWriter(fullfile(wf.output_dir, [wf.file_name '_angle.avi']), 'Uncompressed AVI');
    vw_angle.FrameRate = video_reader.FrameRate;
    
    % Preallocate data array [angle, time]
    wf.data = zeros(video_reader.NumFrames, 2);
    video_reader.CurrentTime = 0;
    
    %% Setup Progress Tracking
    fc = video_reader.NumFrames;
    w = waitbar(0, {sprintf('Writing, cropping, and analyzing frame 0/%d', fc),...
        'Average time per frame: unknown',...
        'Time to complete: unknown'});

    % Radon transform angles (0-179 degrees)
    theta = 0:1:179;
    times = [];
    average = 0;
    open(vw_angle);

    %% Main Processing Loop
    while video_reader.hasFrame
        tic;
        
        % Read and preprocess frame
        frame = video_reader.readFrame;
        frame = imcrop(frame, wf.video_crop_roi);
        frame = imlocalbrighten(frame);  % Enhance local brightness
        frame = flip(frame, 2);           % Flip horizontally
        frame = rgb2gray(frame);          % Convert to grayscale
        frame = adapthisteq(frame);       % Adaptive histogram equalization
        
        %% Radon Transform Analysis
        % Compute Radon transform for all angles
        [R, xp] = radon(frame, theta);

        % Find peaks in Radon transform (indicates line orientations)
        [row_peak, col_peak] = find(R > 0.999 * max(R, [], 'all'));
        xp_peak_offset = xp(row_peak);
        theta_peak = theta(col_peak);

        % Calculate mean angle and offset
        mean_theta = mean(theta_peak);
        mean_offset = mean(xp_peak_offset);
        
        %% Filter Angles Based on Reference
        new_theta_peak = [];
        allDeltas = [];
        new_xp_peak_offset = [];

        if vw_angle.FrameCount == 0
            % First frame: establish reference angle
            original = mean_theta;
        else
            % Subsequent frames: filter angles within ±2 degrees of reference
            allDeltas = theta_peak - original;
            new_theta_peak = theta_peak(allDeltas > -2);
            mean_theta = mean(new_theta_peak);
            new_xp_peak_offset = xp_peak_offset(allDeltas > -2);
            mean_offset = mean(new_xp_peak_offset);
        end
        
        % Calculate angle change from reference
        delta = mean_theta - original;

        %% Annotate Frame
        centerX = ceil(size(frame, 2) / 2);
        centerY = ceil(size(frame, 1) / 2);

        % Draw detected lines (semi-transparent red)
        for i = 1:length(new_xp_peak_offset)
            [x, y] = pol2cart(deg2rad(new_theta_peak(i) + 90), 300);
            frame = insertShape(frame, 'line', ...
                [centerX - x, centerY + y - new_xp_peak_offset(i), ...
                 centerX + x, centerY - y - new_xp_peak_offset(i)], ...
                'LineWidth', 1, 'Color', 'red', 'Opacity', 0.1);
        end
        
        % Add text annotation with angle and delta
        [x, y] = pol2cart(deg2rad(mean_theta + 90), 300);
        frame = insertText(frame, [10, 10], ...
            ['Angle: ' num2str(mean_theta) ' Delta: ' num2str(delta)], ...
            'BoxColor', 'cyan', 'BoxOpacity', 0.3);
        
        %% Save Results
        vw_angle.writeVideo(frame);
        wf.data(vw_angle.FrameCount, :) = [delta, video_reader.CurrentTime];

        %% Update Progress Bar
        times(end + 1) = toc;
        average = mean(times);
        ttc = seconds((fc - vw_angle.FrameCount) * average);
        ttc.Format = 'hh:mm:ss';
        waitbar(vw_angle.FrameCount / fc, w, ...
            {sprintf('Writing, cropping, and analyzing frame %d/%d', vw_angle.FrameCount, fc),...
             sprintf('Average time per frame: %f s', average),...
             sprintf('Time to complete: %s', ttc)});
    end
    
    %% Cleanup
    close(vw_angle);
    close(w);
end

%% Helper Functions
function pos = wait_after_ROI(h_rectangular_ROI)
    % WAIT_AFTER_ROI Waits for user to double-click ROI before continuing
    %
    % Inputs:
    %   h_rectangular_ROI - Handle to rectangular ROI object
    %
    % Outputs:
    %   pos - Position vector [x, y, width, height]

    % Listen for double-click on the ROI
    l = addlistener(h_rectangular_ROI, 'ROIClicked', @ROI_clicked_callback);

    % Block execution until double-click
    uiwait;

    % Cleanup listener
    delete(l);

    % Return the final position
    pos = h_rectangular_ROI.Position;
end

function ROI_clicked_callback(~, event)
    % ROI_CLICKED_CALLBACK Resumes execution on double-click
    %
    % Inputs:
    %   event - Event data containing click information

    if strcmp(event.SelectionType, 'double')
        uiresume;
    end
end