
%
%  High-Speed Tracking with Kernelized Correlation Filters
%
%  Joao F. Henriques, 2014
%  http://www.isr.uc.pt/~henriques/
%
%  Main interface for Kernelized/Dual Correlation Filters (KCF/DCF).
%  This function takes care of setting up parameters, loading video
%  information and computing precisions. For the actual tracking code,
%  check out the TRACKER function.
%
%  RUN_TRACKER
%    Without any parameters, will ask you to choose a video, track using
%    the Gaussian KCF on HOG, and show the results in an interactive
%    figure. Press 'Esc' to stop the tracker early. You can navigate the
%    video using the scrollbar at the bottom.
%
%  RUN_TRACKER VIDEO
%    Allows you to select a VIDEO by its name. 'all' will run all videos
%    and show average statistics. 'choose' will select one interactively.
%
%  RUN_TRACKER VIDEO KERNEL
%    Choose a KERNEL. 'gaussian'/'polynomial' to run KCF, 'linear' for DCF.
%
%  RUN_TRACKER VIDEO KERNEL FEATURE
%    Choose a FEATURE type, either 'hog' or 'gray' (raw pixels).
%
%  RUN_TRACKER(VIDEO, KERNEL, FEATURE, SHOW_VISUALIZATION, SHOW_PLOTS)
%    Decide whether to show the scrollable figure, and the precision plot.
%
%  Useful combinations:
%  >> run_tracker choose gaussian hog  %Kernelized Correlation Filter (KCF)
%  >> run_tracker choose linear hog    %Dual Correlation Filter (DCF)
%  >> run_tracker choose gaussian gray %Single-channel KCF (ECCV'12 paper)
%  >> run_tracker choose linear gray   %MOSSE filter (single channel)
%
%
%   revised by: Yang Li, August, 2014
%   http://ihpdep.github.io

function [precision, track_result ,fps, successes, success_auc] = run_tracker(video, kernel_type, feature_type, show_visualization, show_plots)

	%path to the videos (you'll be able to choose one with the GUI).
	base_path ='.\data\';

	%default settings
	if nargin < 1, video = 'choose'; end
	if nargin < 2, kernel_type = 'gaussian'; end
	if nargin < 3, feature_type = 'hogcolor'; end
	if nargin < 4, show_visualization = ~strcmp(video, 'all'); end
	if nargin < 5, show_plots = ~strcmp(video, 'all'); end


	%parameters according to the paper. at this point we can override
	%parameters based on the chosen kernel or feature type
	kernel.type = kernel_type;
	
	features.gray = false;
	features.hog = false;
    features.hogcolor = false;
	
	padding = 1.5;  %extra area surrounding the target
	lambda = 1e-4;  %regularization
	output_sigma_factor = 0.1;  %spatial bandwidth (proportional to target)
	
	switch feature_type
	case 'gray'
		interp_factor = 0.075;  %linear interpolation factor for adaptation

		kernel.sigma = 0.2;  %gaussian kernel bandwidth
		
		kernel.poly_a = 1;  %polynomial kernel additive term
		kernel.poly_b = 7;  %polynomial kernel exponent
	
		features.gray = true;
		cell_size = 1;
		
	case 'hog'
		interp_factor = 0.02;
		
		kernel.sigma = 0.5;
		
		kernel.poly_a = 1;
		kernel.poly_b = 9;
		
		features.hog = true;
		features.hog_orientations = 9;
		cell_size = 4;
	case 'hogcolor'
		interp_factor = 0.01;
		
		kernel.sigma = 0.5;
		
		kernel.poly_a = 1;
		kernel.poly_b = 9;
		
		features.hogcolor = true;
		features.hog_orientations = 9;
		cell_size = 4;	
	otherwise
		error('Unknown feature.')
	end


	assert(any(strcmp(kernel_type, {'linear', 'polynomial', 'gaussian'})), 'Unknown kernel.')


	switch video
	case 'choose'
		%ask the user for the video, then call self with that video name.
        validation_set = [base_path,'ValidationSet'];
		video = choose_video(validation_set);
		if ~isempty(video)
			[precision, track_result, fps, successes, success_auc ] = run_tracker(video, kernel_type, ...
				feature_type, show_visualization, show_plots);
			
			if nargout == 0  %don't output precision as an argument
				clear precision
			end
		end
		
		
	case 'all'
		%all videos, call self with each video name.
		
		%only keep valid directory names
%         validation_set = [base_path, 'ValidationSet'];
        evaluation_set = [base_path, 'EvaluationSet'];
        
% 		dirs = dir(validation_set);
% 		validation_videos = {dirs.name};
% 		validation_videos(strcmp('.', validation_videos) | strcmp('..', validation_videos) | ...
% 			strcmp('anno', validation_videos) | ~[dirs.isdir]) = [];
%         validation_videos = strcat('ValidationSet\',validation_videos);
        
        dirs = dir(evaluation_set);
        evaluation_videos = {dirs.name};
        evaluation_videos(strcmp('.', evaluation_videos) | strcmp('..', evaluation_videos) | ...
			strcmp('anno', evaluation_videos) | ~[dirs.isdir]) = [];
		evaluation_videos = strcat('EvaluationSet\', evaluation_videos);
        
%         videos = [validation_videos,evaluation_videos]; 
        videos = evaluation_videos;
		
% 		all_precisions = zeros(numel(videos),1);  %to compute averages
		all_fps = zeros(numel(videos),1);
        
        for k = 1:numel(videos)
            fprintf(['video %d: ', videos{k}, ' is going to run\n'], k);
            [~, ~, all_fps(k)] = run_tracker(videos{k}, ...
                kernel_type, feature_type, false, false);
        end
		
% 		if ~exist('parpool', 'file')
% 			%no parallel toolbox, use a simple 'for' to iterate
% 			for k = 1:numel(videos)
%                 fprintf(['video %d: ', videos{k}, ' is going to run\n'], k);
% 				[all_precisions(k), all_fps(k)] = run_tracker(videos{k}, ...
% 					kernel_type, feature_type, show_visualization, show_plots);
% 			end
% 		else
% 			%evaluate trackers for all videos in parallel
%             
%             p = gcp('nocreate');   
%             if isempty(p)
%                 parpool('local');
%             end
%             
% 			parfor k = 1:numel(videos)
%                 fprintf(['video %d: ', videos{k}, ' is going to run\n'], k);
% 				[all_precisions(k), all_fps(k)] = run_tracker(videos{k}, ...
% 					kernel_type, feature_type, show_visualization, show_plots);
% 			end
% 		end
		
		%compute average precision at 20px, and FPS
% 		mean_precision = mean(all_precisions);
		fps = mean(all_fps);
        precision = [];
        track_result = [];
% 		fprintf('\nAverage precision (20px):% 1.3f, Average FPS:% 4.2f\n\n', mean_precision, fps)
% 		if nargout > 0
% 			precision = mean_precision;
% 		end
		
		
	case 'benchmark'
		%running in benchmark mode - this is meant to interface easily
		%with the benchmark's code.
		
		%get information (image file names, initial position, etc) from
		%the benchmark's workspace variables
		seq = evalin('base', 'subS');
		target_sz = seq.init_rect(1,[4,3]);
		pos = seq.init_rect(1,[2,1]) + floor(target_sz/2);
		img_files = seq.s_frames;
		video_path = [];
		
		%call tracker function with all the relevant parameters
		[positions,rect_results,t]= tracker(video_path, img_files, pos, target_sz, ...
			padding, kernel, lambda, output_sigma_factor, interp_factor, ...
			cell_size, features, 0);
		
		%return results to benchmark, in a workspace variable
		rects =rect_results;
%         [positions(:,2) - target_sz(2)/2, positions(:,1) - target_sz(1)/2];
% 		rects(:,3) = target_sz(2);
% 		rects(:,4) = target_sz(1);
		res.type = 'rect';
		res.res = rects;
		assignin('base', 'res', res);
		
		
	otherwise
		%we were given the name of a single video to process.
	
		%get image file names, initial state, and ground truth for evaluation
		[rgbdimgs, pos, target_sz, ground_truth_position, ground_truth, video_path] = load_video_info(base_path, video);
		
		
% 		%call tracker function with all the relevant parameters
		[positions,track_result, time, occ_results] = tracker(video_path, rgbdimgs, pos, target_sz, ...
			padding, kernel, lambda, output_sigma_factor, interp_factor, ...
			cell_size, features, show_visualization);
        
        %call tracker function with all the relevant parameters
%         [positions,track_result, time, occ_results] = rgbtracker(video_path, rgbdimgs, pos, target_sz, ...
%             padding, kernel, lambda, output_sigma_factor, interp_factor, ...
%             cell_size, features, show_visualization);
		
%         [positions,track_result, time] = samf_tracker(video_path, rgbdimgs, pos, target_sz, ...
%             padding, kernel, lambda, output_sigma_factor, interp_factor, ...
%             cell_size, features, show_visualization);
		
		%calculate and show precision plot, as well as frames-per-second
        fps = numel(rgbdimgs.rgb) / time;
        if show_plots
            precisions = precision_plot(positions, ground_truth_position, video, 0);
%             fprintf('%12s - Precision (20px):% 1.3f, FPS:% 4.2f\n', video, precisions(20), fps)
            [success,auc] = success_plot(track_result, ground_truth, video, 0);
            if nargout > 0
                %return precisions at a 20 pixels threshold
                precision = precisions;
                successes = success;
                success_auc = auc;
            end
        else
            precision = [];
            successes = [];
            success_auc = [];
        end
        
%         result_path = [base_path, 'Result\', video, '.txt'];
%         
%         write_result(result_path, track_result, occ_results);

	end
end
