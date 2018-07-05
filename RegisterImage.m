% Registers an image against a sequence dataset (which includes cluster
% position information)
%
% Performs both cross-correlation to find translations, and x.y scaling
%
% Original:  Jason Buenrostro (~2012)
% Rewritten: Peter McMahon (April 2013)
%
% Inputs:
%
% Outputs:
% 

function [adj_x,adj_y,xoff,yoff,x_vals,y_vals,xmin,ymin] = RegisterImage(seqdatafile, seqdataformat, seqdata_offset_x, seqdata_offset_y, cameraimage)
    % load camera image
    camera_img = double(imread(cameraimage));
    
    camera_img = rot90(camera_img, 2);
     % load sequencing data and make a synthetic image
    [x_vals, y_vals, sequences] = LoadSeqData(seqdatafile, seqdataformat);
    x_vals_mean=mean(x_vals);
    y_vals_mean=mean(y_vals);
    
    %imgsize_x = 1888;
    %imgsize_y = 2048;
    imgsize_x = 1; imgsize_y = 1;
    sf_x = 10.56; % scaling factor for x dimension
    sf_y = 10.41; % scaling factor for y dimension
    sf_x = 10.0244; sf_y = 10.0242; % from iter=100 search
    sf_x = 10.975; sf_y = 10.975;
    sf_x = 10.96; sf_y = 10.96; %From Johan
    % search over scaling factor space to find optimal scaling factors
    %[scaling_factors fval] = fminsearch(@ImageScaleXCorr, [sf_x sf_y], optimset ( 'MaxIter' , 25 , 'Display', 'iter' ), x_vals, y_vals, imgsize_x, imgsize_y, camera_img);
    %sf_x_optimum = scaling_factors(1);
    %sf_y_optimum = scaling_factors(2);
    sf_x_optimum = sf_x;
    sf_y_optimum = sf_y;
    
    % redo cross-correlation with optimal parameters, to extract the
    % offsets
    seqdata_img = MakeSyntheticImage(x_vals, y_vals, imgsize_x, imgsize_y, sf_x_optimum, sf_y_optimum);
    
    % get center of synthetic image
    imgsize_x = size(seqdata_img, 1);
    imgsize_y = size(seqdata_img, 2);
    xcent = imgsize_x/2;
    ycent = imgsize_y/2;
    w = 700; % use a subregion with width w and height h
    h = 700;
    rect_sub = [xcent-w/2 ycent-h/2 w h]; % define rectangular subregion of the synthesized image
    seqdata_img_subregion = imcrop(seqdata_img,rect_sub);

    % cross-correlation
    %corr = xcorr2_fft(camera_img,seqdata_img_subregion); % compute the correlation of the subregion of the synthesized image against the whole of the camera image
    corr = normxcorr2(seqdata_img_subregion,camera_img); % compute the correlation of the subregion of the synthesized image against the whole of the camera image

    % Find the offset between the synthesized image and the camera image
    %figure; imagesc(corr)
    % find peak for cross-correleation
    [curr_max, idxmax] = max(corr(:));
    [ypeak, xpeak] = ind2sub(size(corr),idxmax);

    max_corr_x = xpeak;
    max_corr_y = ypeak;
    

    x_offset = max_corr_x - rect_sub(1) - w;
    y_offset = max_corr_y - rect_sub(2) - h;
    
    %adj_x = round(x_vals/sf_x_optimum)+round(x_offset);
    %adj_y = round(y_vals/sf_y_optimum)+round(y_offset);
    adj_x = x_vals/sf_x_optimum + x_offset + 1;
    adj_y = y_vals/sf_y_optimum + y_offset + 1;
    
    %disp('x_offset = ');
    %disp(x_offset);
    %disp('y_offset = ');
    %disp(y_offset);
    %disp('optimum sf_x = ');
    %disp(sf_x_optimum);
    %disp('optimum sf_y = ');
    %disp(sf_y_optimum);
    xmin=x_offset
    ymin=y_offset
    %disp('middley y = ');
    %disp(mean(y_vals)/sf_y_optimum+1+y_offset);
    %disp(size(camera_img,2));
    yoff=(size(camera_img,2)/2-(mean(y_vals)/sf_y_optimum+1+y_offset))
    xoff=(size(camera_img,1)/2-(mean(x_vals)/sf_x_optimum+1+x_offset))
    %figure, imshow(camera_img,[min(camera_img(:)) max(camera_img(:))]); % display camera image with full dynamic range
    figure, imshow(camera_img,[130 200]); 
    hold on
    plot(adj_x,adj_y,'x','linestyle','none','Color','red');
    %input('y');
end
