%#########################################################################
% TraverseCommand
% ImagingStationController command for traversing across tiles
% Written by Curtis Layton 02/2013
%#########################################################################

classdef TraverseCommand < ControlCommand
    
    properties (Constant) % STATIC PROPERTIES
        %For V2 tileList = {'1','2','3','4','5','6','7','8','9','10','11','12','13','14'};
        %For V3
        tileList = {'1','2','3','4','5','6','7','8','9','10','11','12','13','14','15','16','17'};
        focusMode = {'map', 'off'};    % 'map' - Z (focus) position is determined according to a focus map
                                       % 'off' - tiles are traversed without adjusting Z position(focus)
        
    end % END STATIC PROPERTIES
    
    properties % PROPERTIES
        currentTile;
        commandList; % list of ControlCommands to be iterated through
    end % END PROPERTIES
    
    
    methods (Static, Access = private) % PRIVATE STATIC METHODS
        
        function cellArrayOfValueStrings = tokenizeValueString(valueString, delimiter)
            c = textscan(valueString,'%s','delimiter',delimiter);
            c = c{1};
            for i = 1:length(c);
                cellArrayOfValueStrings{i} = c{i};
            end
        end
        
        function currTileList = parseTileList(valueString)
            if(strcmpi(valueString,'all'))
                currTileList = TraverseCommand.tileList;
            else
                cellArrayOfValueStrings = TraverseCommand.tokenizeValueString(valueString, ';');
                numValues = length(cellArrayOfValueStrings);
                currTileList = cell(1, numValues); %preallocate
                for i = 1:numValues
                    %if the current value is a valid tile
                    if(~isempty(find(ismember(TraverseCommand.tileList,cellArrayOfValueStrings{i}),1)))
                        currTileList{i} = cellArrayOfValueStrings{i};
                    else
                        error('TraverseCommand:TraverseCommand:badInputs', '"%s" is not a valid tile to be traversed.', cellArrayOfValueStrings{i});
                    end
                end
            end
        end
        
    end % END PRIVATE METHODS
    
        
    methods % PUBLIC METHODS
        
        function command = TraverseCommand(hardware, tiles, focus)
            CheckParam.isClassType(hardware, 'ImagingStationHardware', 'TraverseCommand:TraverseCommand:badInputs');
            CheckParam.isString(tiles, 'TraverseCommand:TraverseCommand:badInputs');
            CheckParam.isString(focus, 'TraverseCommand:TraverseCommand:badInputs');
            if(isempty(find(ismember(TraverseCommand.focusMode,focus),1)))
                error('TraverseCommand:TraverseCommand:badInputs', '"%s" is not a valid focus mode of the traverse command.', focus);
            end
            
            parsedTiles = TraverseCommand.parseTileList(tiles);
                        
            command = command@ControlCommand(hardware, 'traverse', 'traverse tiles on the flow cell'); %call parent constructor

            command.commandList = CommandList();
            command.commandList.setParent(command);
            command.parameters.tiles = parsedTiles;
            command.parameters.focus = focus;
            command.currentTile = -1; %init value.  Will be updated on execute
        end
               
        function execute(command, scriptDepth, depthIndex)
            if(~exist('depthIndex','var'))
                depthIndex = 1;
            else
                scriptDepth = scriptDepth + 1;
            end

            %read tile map
            %XXXXXXXXXXX TODO XXXXXXXXXXXX get TileMap filename from
            %somewhere not hardcoded
            tileMap = readTileMapXML('TileMap.xml');
            
            numTiles = length(command.parameters.tiles);
            for i = 1:numTiles
                depthIndex(scriptDepth) = i;
                command.currentTile = command.parameters.tiles(i);
                
                currTileIndex = num2str(i);
                
                if(~isKey(tileMap, currTileIndex))
                    error('TraverseCommand:TraverseCommand:badTile', 'tile "%s" requested in the traverse command is not a valid tile in the tilemap', command.parameters.tiles{currTileIndex});
                else
                    currTile = tileMap(currTileIndex);
                end
                
                %translate stage to X,Y position
                command.hardware.stageAndFilterWheel.moveX(currTile.x);
                command.hardware.stageAndFilterWheel.moveY(currTile.y);

                %move Z to the correct focus
                
                command.commandList.execute(scriptDepth, depthIndex);
            end
        end
        
    end % END PUBLIC METHODS
    
end