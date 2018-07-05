%#########################################################################
% Photometrics_PVCam_CameraController
% Hardware control interface with a Photometrics PVCam camera
% Written by Curtis Layton 09/2012
%#########################################################################

% NOTES: This module commuicates with the PVCam libraries through the
% MicroManager Java API.  Before using this script, PVCam and MicroManager 
% must be installed.  This module was developed with PVCam 2.7.9.1 and 
% MicroManager 1.4.10 on Windows XP.  Also, the filenames of all .jar files 
% in the "C:\Program Files\Micro-Manager-1.4\plugins\Micro-Manager" directory 
% were added to the matlab classpath.txt, and "C:\Program Files\Micro-Manager-1.4" 
% was added to the system path in Windows XP.  The camera was set up and
% tested in MicroManager. A MicroManager hardware config file was saved,
% which is imported into this program.

% To save time copying image data between functions, the local image buffer
% 'img' contains the data from the last image aquired, and it's
% corresponding width, height, minValue, and maxValue are all publically 
% accessible data members.  Typical usage might be:

% camera = Photometrics_PVCam_CameraController('C:\Program Files\Micro-Manager-1.4\ImagingStation.cfg');
% camera.setExposure(15);
% camera.acquireImage();
% imshow(camera.img, [camera.minValue camera.maxValue]);
% camera.saveImage('C:\temp\testImage.tif')


classdef Photometrics_PVCam_CameraController < handle
    
    properties % PROPERTIES
        mmc; %MicroManager Core API object
        bitDepth = 12; %bits per pixel coming in from camera
        pixedlDataType = 'uint16'; %data type appropriate for storing one pixel intensity according to the bitdepth
        
        % buffer data pertaining to the current image (the last image taken)
        img; %image buffer to hold the current image data
        width; %image width (in pixels) taken by this camera
        height; %image height (in pixels) taken by this camera
        minValue; %minimum pixel intensity in current image
        maxValue; %maximum pixel intensity in current image
    end % END PROPERTIES
    
    properties (Constant)
        %parameters
        minExposure = 1; % in milliseconds
        maxExposure = 10000; % in milliseconds      
        numSerialRetries = 3; %number of times to attempt to read from a serial device.  (Hiccups occur from time to time, and re-reading is necessary.)
        serialHiccupPause = 0.3; %seconds to pause after a serial hiccup to reattempt communication
    end % END CONSTANT PROPERTIES
    
    methods (Access = private) % PRIVATE METHODS
        function assignPixelDataType(PVCam)
            if(CheckParam.isInteger(PVCam.bitDepth,'Photometrics_PVCam_CameraController:assignPixelDataType:badInputs'))
                if(PVCam.bitDepth<=0)
                    error('Photometrics_PVCam_CameraController:assignPixelDataType:badInputs', 'Bit depth must be a positive integer > 0');
                end
            end
            
            if(PVCam.bitDepth <= 8)
                PVCam.pixedlDataType = 'uint8';
            elseif(PVCam.bitDepth <= 16)
                PVCam.pixedlDataType = 'uint16';
            elseif(PVCam.bitDepth <= 32)
                PVCam.pixedlDataType = 'uint32';
            elseif(PVCam.bitDepth <= 64)
                PVCam.pixedlDataType = 'uint64';
            else
                error('Photometrics_PVCam_CameraController:assignPixelDataType:badBitDepth','Bit depths of greater than 64 are not supported');
            end
        end
        
    end % END PRIVATE METHODS
    
    
    methods % PUBLIC METHODS
        
        %Constructor method
        function PVCam = Photometrics_PVCam_CameraController(MMConfigFilename, initialExposure)
            if(CheckParam.isString(MMConfigFilename, 'Photometrics_PVCam_CameraController:Photometrics_PVCam_CameraController:badInputs'))
                if(~exist(MMConfigFilename, 'file'))
                    error('Photometrics_PVCam_CameraController:Photometrics_PVCam_CameraController:badConfigFile', 'MicroManager config file "%s could not be found"', MMConfigFilename);
                end
            end
            
            if(~exist('initialExposure', 'var'))
                initialExposure = 10;
            end
            
            clear java;
            java.lang.System.gc();
            pause on; pause(1.0);
            import mmcorej.*;
            
            try
                PVCam.mmc=CMMCore();
            catch
                error('Photometrics_PVCam_CameraController:Photometrics_PVCam_CameraController:micromanagerObject', 'Could not create a core micromanager library object"');
            end
            
            try
                PVCam.mmc.loadSystemConfiguration(MMConfigFilename);
            catch err
                if(strfind(err.message, 'C0_CAM_ALREADY_OPEN'))
                    clear java;
                    java.lang.System.gc();
                    pause on; pause(1.0);
                    try
                        PVCam.mmc.loadSystemConfiguration(MMConfigFilename);
                    catch
                        error('Photometrics_PVCam_CameraController:Photometrics_PVCam_CameraController:badConfigFile', 'MicroManager config file "%s could not be loaded.  The associated camera is already open in another application or instance of the program."', MMConfigFilename);
                    end
                elseif(strfind(err.message, 'DDI_SYS_ERR_SEND_BYTE'))
                    error('Photometrics_PVCam_CameraController:Photometrics_PVCam_CameraController:badConfigFile', 'Could not communicate with the camera.  Is the camera turned on and connected?');
                else
                    rethrow(err);
                end
            end
            
            PVCam.bitDepth = PVCam.mmc.getImageBitDepth();
            PVCam.assignPixelDataType();
            PVCam.width=PVCam.mmc.getImageWidth();
            PVCam.height=PVCam.mmc.getImageHeight();
            PVCam.mmc.setExposure(initialExposure);
            PVCam.img = zeros(PVCam.height, PVCam.width);
            PVCam.minValue = 0;
            PVCam.maxValue = 0;
        end
        
%         function delete(PVCam)
%             delete(PVCam.mmc);
%         end
        
        function setExposure(PVCam, exposureTime)
            if(CheckParam.isInteger(exposureTime,'Photometrics_PVCam_CameraController:setExposure:badInputs'))
                errorMessage = sprintf('Exposure time must be between %d and %d milliseconds', PVCam.minExposure, PVCam.maxExposure);
                CheckParam.isWithinARange(exposureTime, PVCam.minExposure, PVCam.maxExposure, 'Photometrics_PVCam_CameraController:setExposure:badInputs', errorMessage);
            end
            PVCam.mmc.setExposure(exposureTime);
        end
        
        function exposureTime = getExposure(PVCam)
            exposureTime = PVCam.mmc.getExposure();
        end
        
        function acquireImage(PVCam)           
            PVCam.mmc.snapImage();
            PVCam.img = typecast(PVCam.mmc.getImage(),PVCam.pixedlDataType); 
            PVCam.img = (reshape(PVCam.img,[PVCam.height, PVCam.width]))'; % transform data into a matrix of the appropriate dimensions
            PVCam.minValue = min(PVCam.img(:));
            PVCam.maxValue = max(PVCam.img(:));
        end
        
        function saveImage(PVCam, filename)
            if((PVCam.minValue==PVCam.maxValue) && (PVCam.maxValue==0)) %image 
                error('Photometrics_PVCam_CameraController:saveImage:noImage', 'Attempting to save an image before any image data has been acquired');
            end
            
            if(CheckParam.isString(filename, 'Photometrics_PVCam_CameraController:saveImage:badInputs', 'Filename must be a string'))
               [pathstr, name, ext] = fileparts(filename);
               if( strcmp(pathstr,'') || strcmp(name,'') || ~exist(pathstr,'dir') )
                   error('Photometrics_PVCam_CameraController:saveImage:invalidFilename', '"%s" is an invalid filename.', filename);
               end
            end
            
            fileFormat = strrep(ext,'.',''); %strip the '.' from the file extension
            supportedImageFormats = {'tif' 'tiff'};
            
            if(~ismember(fileFormat, supportedImageFormats))
                error('Photometrics_PVCam_CameraController:saveImage:invalidFiletype', '"%s" is an unsupported image file extesion', ext);
            end
            
            try
                imwrite(PVCam.img, filename, fileFormat, 'Compression', 'none');
            catch err1
                error('Photometrics_PVCam_CameraController:saveImage:writeError', 'Could not save image file "%s": %s', filename, err1.message);
            end
        end
        
    end % END PUBLIC METHODS
end



