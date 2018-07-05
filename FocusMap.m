% Focus Map Fitter
% Peter McMahon, March 2013

% INPUT: a set of points (x,y,z) corresponding to stage positions at which
% the image is in focus (determined either manually or through autofocus)

% FUNCTION: fits the set of points to a plane

% OUTPUT: a lookup table such that given a point (x,y), the corresponding z
% stage position to get an in-focus image is returned

classdef FocusMap < handle
    
    properties (Access = private) % PROPERTIES
        % input data points to fit
        Xpoints = [];
        Ypoints = [];
        Zpoints = [];
        
        % plane function coefficients (after fit)
        % plane function: z = coeffX*x + coeffY*y + coeffConst
        coeffX;
        coeffY;
        coeffConst;
        
        %Correction at different temperatures
        %z=z(20C)+coeffT*(t-20C)
        coeffT=9.97;
        
        %reference to the stage and filter wheel
        stageAndFilterWheel;
        
        %default focusmap filename
        % Assuming the focusmap.txt file is in the current directory
        % AHH 12/9/2014
        defaultFilename = strcat(pwd,'\','focusmap.txt');
    end % END PROPERTIES
    
    methods (Access = private) % PRIVATE METHODS
        
    	function success = saveToFile(FocusMapObj, filename, Xpoints, Ypoints, Zpoints)
            if(~exist('filename', 'var') || strcmp(filename,'__DEFAULT__'))
                % XXXXX TODO XXXXX instead of a full hardcoded default filename, establish some sort of a relative path to the install or working directory
                filename = FocusMapObj.getDefaultFilename();
            end
            
            if(~exist('Xpoints','var'))
                Xpoints = FocusMapObj.Xpoints;
            end
            
            if(~exist('Ypoints','var'))
                Ypoints = FocusMapObj.Ypoints;
            end
            
            if(~exist('Zpoints','var'))
                Zpoints = FocusMapObj.Zpoints;
            end
            
            %check to make sure the points are numeric, in the right range,
            %and that the arrays have a consistant length
            FocusMapObj.checkPoints(Xpoints, Ypoints, Zpoints);
            
            fid = fopen(filename,'wt');
            for i = 1:length(Xpoints)
                fprintf(fid, '%f %f %f\n', Xpoints(i), Ypoints(i), Zpoints(i));
            end
            fclose(fid);
            
            success = true;
        end
        
        function [Xpoints, Ypoints, Zpoints] = loadFromFile(FocusMapObj, filename)
            if(~exist('filename', 'var'))
                filename = FocusMapObj.getDefaultFilename();
            end

            fid = fopen(filename); % format--each line: Xpoint Ypoint Zpoint
            tmp = textscan(fid, '%f %f %f'); % load points
            Xpoints = tmp{1};
            Ypoints = tmp{2};
            Zpoints = tmp{3};
            fclose(fid);
            
            %check to make sure the points are numeric, in the right range,
            %and that the arrays have a consistant length
            FocusMapObj.checkPoints(Xpoints, Ypoints, Zpoints);
        end
        
    end % END PRIVATE METHODS
    
    methods  % PUBLIC METHODS
        
        % Constructor method
        % function FocusMapObj = FocusMap(stageAndFilterWheel, Xpoints, Ypoints, Zpoints)
        %    FocusMapObj.stageAndFilterWheel = stageAndFilterWheel;
        %    if(~exist('Xpoints','var') || ~exist('Ypoints','var') || ~exist('Zpoints','var'))
        %        [Xpoints, Ypoints, Zpoints] = FocusMapObj.loadFromFile(); %if no focus points are passed in, load from file
        %        FocusMapObj.setPoints(Xpoints, Ypoints, Zpoints);
        %    else
        %        FocusMapObj.checkPoints(Xpoints, Ypoints, Zpoints); %check to make sure the points are numeric, in the right range and that the arrays have a consistant length
        %        FocusMapObj.setPoints(Xpoints, Ypoints, Zpoints); %use the params that were passed in
        %    end
        %%end
        
        % Constructor method
        % ADDED BY JOHAN, Replaced by setPointsT
        function FocusMapObj = FocusMap(stageAndFilterWheel, Xpoints, Ypoints, Zpoints, temperature)
            %ADDED BY JOHAN
            if(~exist('temperature', 'var'))
                temperature = 20;
            end
            CheckParam.isNumeric(temperature, 'guiFocusMapWizard:btnSaveAndClose_callback:Temperature', 'Temperature is not numeric');
            if ~((temperature > 15) && (temperature < 75))
                temperature = 20;
            end
            %ADDED BY JOHAN END
            FocusMapObj.stageAndFilterWheel = stageAndFilterWheel;
            if(~exist('Xpoints','var') || ~exist('Ypoints','var') || ~exist('Zpoints','var'))
                [Xpoints, Ypoints, Zpoints] = FocusMapObj.loadFromFile(); %if no focus points are passed in, load from file
                FocusMapObj.setPoints(Xpoints, Ypoints, Zpoints, temperature);
            else
                FocusMapObj.checkPoints(Xpoints, Ypoints, Zpoints); %check to make sure the points are numeric, in the right range and that the arrays have a consistant length
                % COMMENTED BY JOHAN, Replaced by setPointsT
                %FocusMapObj.setPoints(Xpoints, Ypoints, Zpoints); %use the params that were passed in
                %
                FocusMapObj.setPoints(Xpoints, Ypoints, Zpoints, temperature);
            end
        end
        
        %make sure focusMap points are valid
        function valid = checkPoints(FocusMapObj, Xpoints, Ypoints, Zpoints)
            CheckParam.isNumeric(Xpoints, 'FocusMap:checkPoints:badInputs');
            CheckParam.isNumeric(Ypoints, 'FocusMap:checkPoints:badInputs');
            CheckParam.isNumeric(Zpoints, 'FocusMap:checkPoints:badInputs');

            sizeX = size(Xpoints);
            sizeY = size(Ypoints);
            sizeZ = size(Zpoints);
            if ~isequal(sizeX, sizeY, sizeZ) % check that all points vectors are the same size
                error('FocusMap:checkPoints:mismatchedFocusMap', 'in a focusmap, focus point X, Y, and Z coordinate lists must all have the same number of values');

            end

            lenX = length(Xpoints);
            if (lenX < 3)
                error('FocusMap:checkPoints:mismatchedFocusMap', 'a focusmap must have at least 3 points to fit a focus plane')
            end
            
            %check that X,Y points are within appropriate boundaries
            for i = 1:lenX
                if(~FocusMapObj.stageAndFilterWheel.isAboveFlowCell(Xpoints(i), Ypoints(i)))
                    error('FocusMap:checkPoints:badCoordinates', 'focus map coordinate #%d (x=%f, y=%f) is out of range', i, Xpoints(i), Ypoints(i));
                end
            end
            
            valid = true;
        end
        
        % set the calibration (x,y,z) points and fit them to a plane
        % The user can supply any number of (x,y,z) points >= 3 (you need 3
        % points to define a plane)
        % function setPoints(FocusMapObj, Xpoints, Ypoints, Zpoints)
        %    %check to make sure the points are numeric, in the right range,
        %    %and that the arrays have a consistant length
        %    FocusMapObj.checkPoints(Xpoints, Ypoints, Zpoints);
        %    
        %    % store points as column vectors 
        %    FocusMapObj.Xpoints = Xpoints(:);
        %    FocusMapObj.Ypoints = Ypoints(:);
        %    FocusMapObj.Zpoints = Zpoints(:);
        %    
        %    % now that we have new points, we must calculate a new fit
        %    const = ones(size(FocusMapObj.Xpoints)); % vector of 1's for constant term input to fitter
        %    fitCoeffs = [ FocusMapObj.Xpoints FocusMapObj.Ypoints const ]\FocusMapObj.Zpoints;
        %    
        %    FocusMapObj.coeffX = fitCoeffs(1);
        %    FocusMapObj.coeffY = fitCoeffs(2);
        %    FocusMapObj.coeffConst = fitCoeffs(3);
        %    
        %    FocusMapObj.saveToFile(FocusMapObj.defaultFilename, Xpoints, Ypoints, Zpoints);
        %end
        
        % set the calibration (x,y,z) points and fit them to a plane
        % The user can supply any number of (x,y,z) points >= 3 (you need 3
        % points to define a plane)
        % This method was added by Johan to take into account temperature
        % variations. It is identical to the function above at 20C, but
        % subtracts an offset that is linear with temperature such that
        % calibrations at arbitrary temperatures can be used together with
        % getZT below.
        function setPoints(FocusMapObj, Xpoints, Ypoints, Zpoints, temperature)
            %check to make sure the points are numeric, in the right range,
            %and that the arrays have a consistant length
            
            if(~exist('temperature', 'var'))
                temperature = 20;
            end
            FocusMapObj.checkPoints(Xpoints, Ypoints, Zpoints);
            if ~((temperature > 15) && (temperature < 75))
                error('FocusMap:setPointsT:badTemperature', 'in a focusmap the temperature must be between 15 and 75 degrees');
            end
            % store points as column vectors 
            FocusMapObj.Xpoints = Xpoints(:);
            FocusMapObj.Ypoints = Ypoints(:);
            FocusMapObj.Zpoints = Zpoints(:);
            
            % now that we have new points, we must calculate a new fit
            const = ones(size(FocusMapObj.Xpoints)); % vector of 1's for constant term input to fitter
            fitCoeffs = [ FocusMapObj.Xpoints FocusMapObj.Ypoints const ]\FocusMapObj.Zpoints;
            
            FocusMapObj.coeffX = fitCoeffs(1);
            FocusMapObj.coeffY = fitCoeffs(2);
            FocusMapObj.coeffConst = fitCoeffs(3)-FocusMapObj.coeffT*(temperature-20);
            
            FocusMapObj.saveToFile(FocusMapObj.defaultFilename, Xpoints, Ypoints, Zpoints);
        end
        
        % given a point (x,y) return the z position that will give an
        % in-focus image for that (x,y) position (based on the fit to the
        % plane from the calibration points)
        %function z = getZ(FocusMapObj, x, y)
        %    disp('looking up in-focus Z from focus map');
        %    z = FocusMapObj.coeffX*x + FocusMapObj.coeffY*y + FocusMapObj.coeffConst;
        %end
        
         % given a point (x,y) and a temperature (t) return the z position that will give an
        % in-focus image for that (x,y) position (based on the fit to the
        % plane from the calibration points plus extrapolation from a one-time temperature fit)
        function z = getZ(FocusMapObj, x, y, t)
            if(~exist('t', 'var'))
                t = 20;
            end
            disp('looking up in-focus Z from focus map');
            z = FocusMapObj.coeffX*x + FocusMapObj.coeffY*y + FocusMapObj.coeffConst+FocusMapObj.coeffT*(t-20);
        end
        
        function filename = getDefaultFilename(FocusMapObj)
            % XXXXX TODO XXXXX instead of using the full hardcoded default filename, establish a relative path to the install or working directory
            filename = FocusMapObj.defaultFilename;
        end
        
        function numPoints = getNumPoints(FocusMapObj)
            CheckParam.isNumeric(FocusMapObj.Xpoints, 'FocusMap:getNumPoints:badInputs');
            CheckParam.isNumeric(FocusMapObj.Ypoints, 'FocusMap:getNumPoints:badInputs');
            CheckParam.isNumeric(FocusMapObj.Zpoints, 'FocusMap:getNumPoints:badInputs');

            lenX = length(FocusMapObj.Xpoints);
            lenY = length(FocusMapObj.Ypoints);
            lenZ = length(FocusMapObj.Zpoints);
            if ~((lenX == lenY) && (lenY == lenZ))
                error('FocusMap:getNumPoints:mismatchedFocusMap', 'in a focusmap, focus point X, Y, and Z coordinate lists must all have the same number of values');
            end

            numPoints = lenX;
        end
        
        function Xpoints = getXpoints(FocusMapObj)
            Xpoints = FocusMapObj.Xpoints;
        end
        
        function Ypoints = getYpoints(FocusMapObj)
            Ypoints = FocusMapObj.Ypoints;
        end
        
        function Zpoints = getZpoints(FocusMapObj)
            Zpoints = FocusMapObj.Zpoints;
        end
        
        function T = getCoeffT(FocusMapObj)
            T = FocusMapObj.coeffT;
        end
        
    end % END PUBLIC METHODS

end 

