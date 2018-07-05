% Convert MiSeq/GA sequencing data of (x,y) locations of called clusters and
% convert this to a matrix that can be interpreted as an image

% Original: Jason Buenrostro (circa 2012)
% Rewritten: Peter McMahon (April 2013)

% input:
%   x_vals, y_vals:         x and y positions of the called clusters
%   imgsize_x, imgsize_y:   size of synthetic image to produce
%   sf_x, sf_y:             scaling factor for x and y dimensions (to
%                           convert from MiSeq/GA cluster coordinate units 
%                           to camera image pixel units)
%
% output:
%   a matrix representing an image

function img = MakeSyntheticImage(x_vals, y_vals, imgsize_x, imgsize_y, sf_x, sf_y)
    img=zeros(imgsize_x, imgsize_y);
    
    % add data points to data matrix
    for i=1:length(y_vals)
        xval = round((x_vals(i)/sf_x)) + 1;
        yval = round((y_vals(i)/sf_y)) + 1;
        try
            img(yval,xval) = img(yval,xval) + 1; % image pixel indices are (y,x)
        catch
            img(yval,xval) = 1;
        end
    end
    
    %img(img==0) = -1; % set elements of img that are zero to be -1 (i.e. mismatch penalty so that cross-corr gives a penalty for aligning a camera pixel with a cluster to a synthetic pixel that does not have a cluster)
    
    % add gaussian blur
    %filter = fspecial('gaussian',[3 3],2);
    %img = imfilter(img,filter,'same');
end
