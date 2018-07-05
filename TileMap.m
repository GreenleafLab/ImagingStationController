% Tile Map
% Peter McMahon, March 2013

% INPUT: 1.) a set of points (x,y) corresponding to stage positions at which
%            the image is centered on the edge of the imaging flow cell.
%        2.) a set of points (delta_x,y) corresponding to where the tiles
%            are in absolute y positions, and where they are relative to
%            the edge of the flow cell (delta_x)

% FUNCTION: fits the set of edge points to a line. This produces a lookup
% table such that given a point (y), the corresponding x stage position to 
% get an image on the edge of the flow cell is returned. This is then
% combined with the input data of (delta_x,y) positions, where the offsets
% delta_x are added to the fitted edge positions.

% OUTPUT: a lookup table such that, given a tile number (1 to 14, for a
% MiSeq chip), it will output an absolute (x,y) stage position.

classdef TileMap < handle
    
    properties (Access = private) % PROPERTIES
        % input edge data points to fit
        Xedgepoints = [];
        Yedgepoints = [];
        
        % line function coefficients (after fit)
        % line function: x = coeffY*y + coeffConst
        coeffY;
        coeffConst;
        
        % input tilemap points (arrays with have length 14 for MiSeq chip)
        deltaXtilepoints = [];
        Ytilepoints = [];
        
        %reference to the stage and filter wheel
        stageAndFilterWheel;
        
        %default filenames
        % Assuming the edges.txt and tilemap.txt files is in the current directory
        % AHH 12/9/2014
        defaultFilenameEdges = strcat(pwd,'\','edges.txt');
        defaultFilenameTileMap = strcat(pwd,'\','tilemap.txt');
    end % END PROPERTIES
    
    methods %METHODS
        
    	function success = saveToFileEdges(TileMapObj, filename, Xpoints, Ypoints)
            if(~exist('filename', 'var') || strcmp(filename,'__DEFAULT__'))
                % XXXXX TODO XXXXX instead of a full hardcoded default filename, establish some sort of a relative path to the install or working directory
                filename = FileMapObj.getDefaultFilenameEdges();
            end
            
            if(~exist('Xpoints','var'))
                Xpoints = TileMapObj.Xedgepoints;
            end
            
            if(~exist('Ypoints','var'))
                Ypoints = TileMapObj.Yedgepoints;
            end
            
            %check to make sure the points are numeric, in the right range,
            %and that the arrays have a consistant length
            TileMapObj.checkEdgePoints(Xpoints, Ypoints);
            
            fid = fopen(filename,'wt');
            for i = 1:length(Xpoints)
                fprintf(fid, '%f %f\n', Xpoints(i), Ypoints(i));
            end
            fclose(fid);
            
            success = true;
        end
        
        function success = saveToFileTileMap(TileMapObj, filename, deltaXpoints, Ypoints)
            if(~exist('filename', 'var') || strcmp(filename,'__DEFAULT__'))
                % XXXXX TODO XXXXX instead of a full hardcoded default filename, establish some sort of a relative path to the install or working directory
                filename = TileMapObj.getDefaultFilenameTileMap();
            end
            
            if(~exist('deltaXpoints','var'))
                deltaXpoints = TileMapObj.deltaXtilepoints;
            end
            
            if(~exist('Ypoints','var'))
                Ypoints = TileMapObj.Ytilepoints;
            end
            
            %check to make sure the points are numeric, in the right range,
            %and that the arrays have a consistant length
            TileMapObj.checkTilePoints(deltaXpoints, Ypoints);
            
            fid = fopen(filename,'wt');
            for i = 1:length(deltaXpoints)
                fprintf(fid, '%f %f\n', deltaXpoints(i), Ypoints(i));
            end
            fclose(fid);
            
            success = true;
        end
        
        function [Xpoints, Ypoints] = loadEdgePointsFromFile(TileMapObj, filename)
            if(~exist('filename', 'var'))
                filename = TileMapObj.getDefaultFilenameEdges();
            end

            fid = fopen(filename); % format--each line: Xpoint Ypoint
            tmp = textscan(fid, '%f %f'); % load points
            Xpoints = tmp{1};
            Ypoints = tmp{2};
            fclose(fid);
            
            %check to make sure the points are numeric, in the right range,
            %and that the arrays have a consistant length
            TileMapObj.checkEdgePoints(Xpoints, Ypoints);
        end
        
        function [deltaXpoints, Ypoints] = loadTilePointsFromFile(TileMapObj, filename)
            if(~exist('filename', 'var'))
                filename = TileMapObj.getDefaultFilenameTileMap();
            end

            fid = fopen(filename); % format--each line: deltaXpoint Ypoint
            tmp = textscan(fid, '%f %f'); % load points
            deltaXpoints = tmp{1};
            Ypoints = tmp{2};
            fclose(fid);
            
            %check to make sure the points are numeric, in the right range,
            %and that the arrays have a consistant length
            TileMapObj.checkTilePoints(deltaXpoints, Ypoints);
        end

        % Constructor method
        function TileMapObj = TileMap(stageAndFilterWheel, Xedgepoints, Yedgepoints, deltaXtilepoints, Ytilepoints)
            TileMapObj.stageAndFilterWheel = stageAndFilterWheel;
            
            % load edge points
            if(~exist('Xedgepoints','var') || ~exist('Yedgepoints','var'))
                %if no edge points are passed in, load from file
                [Xedgepoints, Yedgepoints] = TileMapObj.loadEdgePointsFromFile(); 
            else
                TileMapObj.checkEdgePoints(Xedgepoints, Yedgepoints); %check to make sure the points are numeric, in the right range and that the arrays have a consistant length
            end
            TileMapObj.setEdgePoints(Xedgepoints, Yedgepoints);
            
            % load tile points
            if(~exist('deltaXtilepoints','var') || ~exist('Ytilepoints','var'))
                %if no tile points are passed in, load from file
                [deltaXtilepoints, Ytilepoints] = TileMapObj.loadTilePointsFromFile(); 
            else
                TileMapObj.checkTilePoints(deltaXtilepoints, Ytilepoints); %check to make sure the points are numeric, in the right range and that the arrays have a consistant length
            end
            TileMapObj.setTilePoints(deltaXtilepoints, Ytilepoints);
        end
        
        %make sure points are valid
        function valid = checkEdgePoints(TileMapObj, Xedgepoints, Yedgepoints)
            CheckParam.isNumeric(Xedgepoints, 'TileMap:checkEdgePoints:badInputs');
            CheckParam.isNumeric(Yedgepoints, 'TileMap:checkEdgePoints:badInputs');

            sizeX = size(Xedgepoints);
            sizeY = size(Yedgepoints);
            if ~isequal(sizeX, sizeY) % check that all points vectors are the same size
                error('TileMap:checkEdgePoints:mismatchedPoints', 'point X, Y coordinate lists must all have the same number of values');

            end

            lenX = length(Xedgepoints);
            if (lenX < 2)
                error('TileMap:checkEdgePoints:mismatchedEdges', 'a tile map must have at least 2 edge points to fit a line')
            end
            
            %check that X,Y points are within appropriate boundaries
            for i = 1:lenX
                if(~TileMapObj.stageAndFilterWheel.isAboveFlowCell(Xedgepoints(i), Yedgepoints(i)))
                    error('TileMap:checkEdgePoints:badCoordinates', 'coordinate #%d (x=%f, y=%f) is out of range', i, Xedgepoints(i), Yedgepoints(i));
                end
            end
            
            valid = true;
        end
        
        %make sure points are valid
        function valid = checkTilePoints(TileMapObj, deltaXtilepoints, Ytilepoints)
            CheckParam.isNumeric(deltaXtilepoints, 'TileMap:checkTilePoints:badInputs');
            CheckParam.isNumeric(Ytilepoints, 'TileMap:checkTilePoints:badInputs');

            sizeX = size(deltaXtilepoints);
            sizeY = size(Ytilepoints);
            if ~isequal(sizeX, sizeY) % check that all points vectors are the same size
                error('TileMap:checkTilePoints:mismatchedPoints', 'point deltaX, Y coordinate lists must all have the same number of values');
            end

            lenX = length(deltaXtilepoints);
            if (lenX < 1)
                error('TileMap:checkTilePoints:noTiles', 'a tile map needs at least one tile')
            end
            
            valid = true;
        end
        
        % set the calibration (x,y) points and fit them to a line
        % The user can supply any number of (x,y) points >= 2 (you need 2
        % points to define a line)
        function setEdgePoints(TileMapObj, Xedgepoints, Yedgepoints)
            %check to make sure the points are numeric, in the right range,
            %and that the arrays have a consistant length
            TileMapObj.checkEdgePoints(Xedgepoints, Yedgepoints);
            
            % store points as column vectors 
            TileMapObj.Xedgepoints = Xedgepoints(:);
            TileMapObj.Yedgepoints = Yedgepoints(:);
            
            % now that we have new points, we must calculate a new fit: x = coeffY*Y + coeffConst
            const = ones(size(TileMapObj.Xedgepoints)); % vector of 1's for constant term input to fitter
            fitCoeffs = [ TileMapObj.Yedgepoints const ]\TileMapObj.Xedgepoints;
            
            TileMapObj.coeffY = fitCoeffs(1);
            TileMapObj.coeffConst = fitCoeffs(2);
            
            TileMapObj.saveToFileEdges(TileMapObj.getDefaultFilenameEdges(), Xedgepoints, Yedgepoints);
        end
        
        % set the points corresponding to tile positions
        function setTilePoints(TileMapObj, deltaXtilepoints, Ytilepoints)
            %check to make sure the points are numeric, in the right range,
            %and that the arrays have a consistant length
            TileMapObj.checkTilePoints(deltaXtilepoints, Ytilepoints);
            
            % store points as column vectors 
            TileMapObj.deltaXtilepoints = deltaXtilepoints(:);
            TileMapObj.Ytilepoints = Ytilepoints(:);
            
            TileMapObj.saveToFileTileMap(TileMapObj.getDefaultFilenameTileMap(), deltaXtilepoints, Ytilepoints);
        end
        
        %check if a given tile is valid, convert to integer from string if necessary
        function validatedTile = validateTile(TileMapObj, tile)
            tileClass = class(tile);
            if(strcmp(tileClass, 'double')) %numeric
                validatedTile = tile;
                CheckParam.isInteger(validatedTile, 'TileMap:isAValidTile:tileDoesNotExist');
                numTiles = TileMapObj.getNumTiles();
                CheckParam.isWithinARange(validatedTile, 1, numTiles, 'TileMap:isAValidTile:tileDoesNotExist');
            elseif(strcmp(tileClass, 'char')) %string
                validatedTile = str2double(tile);
                CheckParam.isInteger(validatedTile, 'TileMap:isAValidTile:tileDoesNotExist');
                numTiles = TileMapObj.getNumTiles();
                CheckParam.isWithinARange(validatedTile, 1, numTiles, 'TileMap:isAValidTile:tileDoesNotExist');
            elseif(strcmp(tileClass, 'ScriptVariable')) %variable
                validatedTile = tile;
            else
                error('TileMap:isAValidTile:tileDoesNotExist', 'tile must either be an integer or string');
            end
        end
        
        % given a point (y) return the x position of the edge of the tile
        function x = getEdgePos(TileMapObj, y)
            x = TileMapObj.coeffY*y + TileMapObj.coeffConst;
        end
        
        % given a tile number (1-14 for a MiSeq chip), output an (x,y) absolute position of the tile
        function [tileX, tileY] = getTilePos(TileMapObj, tileNumber)
            deltaX = TileMapObj.deltaXtilepoints(tileNumber);
            Y = TileMapObj.Ytilepoints(tileNumber);
            Xedge = TileMapObj.getEdgePos(Y);
            
            tileX = Xedge + deltaX;
            tileY = Y;
        end
               
        function filename = getDefaultFilenameEdges(TileMapObj)
            % XXXXX TODO XXXXX instead of using the full hardcoded default filename, establish a relative path to the install or working directory
            filename = TileMapObj.defaultFilenameEdges;
        end
        
        function filename = getDefaultFilenameTileMap(TileMapObj)
            % XXXXX TODO XXXXX instead of using the full hardcoded default filename, establish a relative path to the install or working directory
            filename = TileMapObj.defaultFilenameTileMap;
        end
        
        function numEdgePoints = getNumEdgePoints(TileMapObj)
            CheckParam.isNumeric(TileMapObj.Xedgepoints, 'TileMap:getNumEdgePoints:badInputs');
            CheckParam.isNumeric(TileMapObj.Yedgepoints, 'TileMap:getNumEdgePoints:badInputs');

            lenX = length(TileMapObj.Xedgepoints);
            lenY = length(TileMapObj.Yedgepoints);
            if (~(lenX == lenY))
                error('TileMap:getNumEdgePoints:mismatchedPoints', 'point X, Y coordinate lists must all have the same number of values');
            end

            numEdgePoints = lenX;
        end
        
        % returns the number of tiles that this tile map knows about
        function numTiles = getNumTiles(TileMapObj)
            numTiles = length(TileMapObj.Ytilepoints);
        end
        
        function Xedgepoints = getXedgepoints(TileMapObj)
            Xedgepoints = TileMapObj.Xedgepoints;
        end
        
        function Yedgepoints = getYedgepoints(TileMapObj)
            Yedgepoints = TileMapObj.Yedgepoints;
        end
        
        
        
    end % END PUBLIC METHODS

end 

