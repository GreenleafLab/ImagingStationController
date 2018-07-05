

function tileList = readTileMapXML(xmlfile)
    xml = xmlread(xmlfile);
    
    children = xml.getChildNodes;
    for i = 1:children.getLength
       out(i) = node2struct(children.item(i-1));
    end
    
    tileList = struct2TileList(out);
end



function tileList = struct2TileList(s, tileList)  
    
    if(~exist('tileList', 'var'))
        tileList = containers.Map();
    end

    switch lower(s.name)
        case 'tilemap' % root node
            currChildren = s.children;
            nChildren = length(currChildren);
            if(nChildren ~= 0)
               for i = 1:nChildren
                    struct2TileList(currChildren(i), tileList);
               end
            end
            
        case 'tile'
            currChildren = s.children;
            nChildren = length(currChildren);
            if(nChildren ~= 0)
                error('readTileListXML:struct2tileList:invalidXML', 'a tile should not have any children');
            end
            
            currTile = struct();
            
            for i = 1:length(s.attributes)
                currName = lower(s.attributes(i).name);
                switch lower(currName)
                    case 'x'
                        xVal = str2double(s.attributes(i).value);
                        
                        if(isnan(xVal))
                            error('readTileListXML:struct2tileList:badAttribute', 'The x coordinate of a tile must be numeric');
                        end
                        
                        CheckParam.isNumeric(xVal, 'readTileListXML:struct2tileList:badAttribute', 'The x coordinate of a tile must be numeric');
                        %XXXXXXXXXX TODO XXXXXXXXXXXX read in bounds from hardware
                        lowerXBound = -590000;
                        upperXBound = -550000;
                        errorMessage = sprintf('The x coordinate of a tile must be between %f and %f', lowerXBound, upperXBound);
                        CheckParam.isWithinARange(xVal, lowerXBound, upperXBound, 'readTileListXML:struct2tileList:badAttribute', errorMessage);
                        currTile.x = xVal;
                    case 'y'
                        yVal = str2double(s.attributes(i).value);
                        
                        if(isnan(yVal))
                            error('readTileListXML:struct2tileList:badAttribute', 'The y coordinate of a tile must be numeric');
                        end                        
                        
                        CheckParam.isNumeric(yVal, 'readTileListXML:struct2tileList:badAttribute', 'The y coordinate of a tile must be numeric');
                        %XXXXXXXXXX TODO XXXXXXXXXXXX read in bounds from hardware
                        lowerYBound = -360000;
                        upperYBound = -200000;
                        errorMessage = sprintf('The y coordinate of a tile must be between %f and %f', lowerYBound, upperYBound);
                        CheckParam.isWithinARange(yVal, lowerYBound, upperYBound, 'readTileListXML:struct2tileList:badAttribute', errorMessage);
                        currTile.y = yVal;                      
                    otherwise
                        error('readTileListXML:struct2tileList:badAttribute', '"%s" is an invalid attribute of a tile', s.attributes(i).name);
                end
            end
            
            if(isfield(currTile, 'x') && isfield(currTile, 'y'))
                tileList(num2str(length(tileList)+1)) = currTile;
            else
                error('readTileListXML:struct2tileList:badAttribute', 'Both the "x" and "y" attribute must be assigned for all tiles.');
            end
            
        otherwise
            error('readTileListXML:struct2tileList:invalidTag','invalid XML tag "%s".', s.name);
    end
end


function s = node2struct(node)

    s.name = char(node.getNodeName);

    if node.hasAttributes
       attributes = node.getAttributes();
       nattr = attributes.getLength();
       s.attributes = struct('name',cell(1,nattr),'value',cell(1,nattr));
       for i = 1:nattr
          attr = attributes.item(i-1);
          s.attributes(i).name = char(attr.getName());
          s.attributes(i).value = char(attr.getValue());
       end
    else
       s.attributes = [];
    end

    try
       s.data = char(node.getData);
    catch
       s.data = '';
    end

    if node.hasChildNodes
       children = node.getChildNodes;
       nchildren = children.getLength();
       s.children = struct('name',{},'attributes',{},'data',{},'children',{}); %init
       childIndex = 1;
       for i = 1:nchildren
          child = children.item(i-1);
          currStruct = node2struct(child);
          if(~strcmp(currStruct.name,{'#text' '#comment'}))
             s.children(childIndex) = currStruct;
             childIndex = childIndex + 1;
          end
       end
    else
       s.children = [];
    end
    
end