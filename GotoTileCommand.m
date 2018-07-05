%#########################################################################
% GotoTileCommand
% ImagingStationController command for traversing across tiles
% Written by Curtis Layton 02/2013
%#########################################################################

classdef GotoTileCommand < ControlCommand
    
    properties (Constant) % STATIC PROPERTIES

    end % END CONSTANT PROPERTIES
    
    properties % PROPERTIES

    end % END PROPERTIES
    
    
    methods (Static, Access = private) % PRIVATE STATIC METHODS
        
    end % END PRIVATE METHODS
    
        
    methods % PUBLIC METHODS
        
        function command = GotoTileCommand(hardware, tile, focus)
            CheckParam.isString(tile, 'GotoTileCommand:GotoTileCommand:badInputs');
            CheckParam.isBoolean(focus, 'GotoTileCommand:GotoTileCommand:badInputs');
            
            validatedTile = hardware.tileMap.validateTile(tile);
                        
            command = command@ControlCommand(hardware, 'gototile', 'move to a specific tile on the flow cell'); %call parent constructor

            command.parameters.tile = validatedTile;
            command.parameters.focus = focus;
        end
               
        function execute(command, scriptDepth, depthIndex)
            if(~exist('depthIndex','var'))
                depthIndex = 1;
            end

            %get a local copy of parameters that will be used
            %the 'getParameter' method substitutes any variables (e.g. for
            %the current loop iteration)
            tile = command.getParameter('tile', depthIndex);
            focus = command.getParameter('focus', depthIndex);
            
            validatedTile = command.hardware.tileMap.validateTile(tile);
            command.hardware.gotoTile(validatedTile, focus);
        end
        
    end % END PUBLIC METHODS
    
end