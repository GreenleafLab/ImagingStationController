

function [commandList, subList] = xml2struct(xmlfile, hardware, displayImagePanel)
    if(~exist('displayImagePanel', 'var'))
        displayImagePanel = 'null';
    end
    
    clear globalVarList;
    global globalVarList;
    globalVarList = containers.Map();

    xml = xmlread(xmlfile);

    children = xml.getChildNodes;
    for i = 1:children.getLength
       out(i) = node2struct(children.item(i-1));
    end
        
    [commandList, subList] = struct2commandList(out, hardware, displayImagePanel);
    assignVariables(commandList, subList);
    
    commandList.variableList = globalVarList;
end

function assignVariables(commandList, subList)
    keyList = keys(subList);
    for i = 1:length(keyList)
        currKey = keyList{i};
        currSub = subList(currKey);
        assignVariables2(currSub.commandList);
    end
    assignVariables2(commandList);
end

function assignVariables2(commandList)
    global globalVarList;    
    for i = 1:commandList.getNumCommands()  %iterate through each individual command
        currCommand = commandList.getCommand(i);
        if(strcmp(class(currCommand),'LoopCommand'))
            assignVariables2(currCommand.commandList);
        elseif(strcmp(class(currCommand),'SubCallCommand'))
            %do nothing
        else
            parameterNames = fieldnames(currCommand.parameters);
            for j = 1:length(parameterNames)
                currParameterName = parameterNames{j};
                currParameter = currCommand.parameters.(currParameterName);
                if(strcmp(class(currParameter),'ScriptVariable'))
                    try
                        currCommand.parameters.(currParameterName) = globalVarList(currParameter.name(5:end));
                    catch err
                        error('xml2struct:assignVariables2:badVariable','The variable "%s" was never declared.', currParameter.name);
                    end
                end
            end    
        end
    end
end

function [commandList, subList] = struct2commandList(s, hardware, displayImagePanel, commandList, subList, parent)
    global globalVarList;
    if(~exist('commandList','var'))
        commandList = CommandList();
    end
    if(~exist('subList','var'))
        subList = containers.Map();
    end
    if(~exist('parent','var'))
        parent = [];
    end
    
    switch lower(s.name)
        case 'imagingstationscript' % root node
            currChildren = s.children;
            nChildren = length(currChildren);
            if(nChildren ~= 0)
               for i = 1:nChildren
                    struct2commandList(currChildren(i), hardware, displayImagePanel, commandList, subList);
               end
            end
        case 'loop'
            currCommand = getLoopCommand(s, hardware);
            currChildren = s.children;
            nChildren = length(currChildren);
            if(nChildren ~= 0)
               for i = 1:nChildren
                    struct2commandList(currChildren(i), hardware, displayImagePanel, currCommand.commandList, subList, currCommand);
               end
            end
            commandList.addCommand(currCommand);
        case 'sub'
            currSub = getSubCommand(s, hardware);
            currChildren = s.children;
            nChildren = length(currChildren);
            if(nChildren ~= 0)
               for i = 1:nChildren
                    struct2commandList(currChildren(i), hardware, displayImagePanel, currSub.commandList, subList, currSub);
               end
            end
            currSub.setParent(commandList);
            subList(currSub.name) = currSub;
        case 'subcall'
            currCommand = getSubCallCommand(s, hardware, subList);
            currChildren = s.children;
            nChildren = length(currChildren);
            if(nChildren ~= 0)
                for i = 1:nChildren
                    if(strcmp(currChildren(i).name,'var'))
                        if(isKey(subList,currCommand.mySubroutine.name))
                            currSub = subList(currCommand.mySubroutine.name);
                        else
                            error('xml2struct:struct2commandList:invalidXML', 'subcall to invalid sub "%s".  Note that subs must be defined in the XML before the subcall.', currName);
                        end
                        struct2commandList(currChildren(i), hardware, displayImagePanel, currSub.commandList, subList, currCommand);                     
                    else
                        error('xml2struct:struct2commandList:invalidXML','only var definitions are allowed inside of a subcall');
                    end
                end
            end
            commandList.addCommand(currCommand);
        case 'var'
            if(isempty(parent))
                %global variable
                [varName, currVariable] = getVarCommand(s);
                globalVarList(varName) = currVariable;
            else
                varName = getVarCommand(s, parent);
                currVariable = parent.variableList(varName);
                if(strcmp(class(parent),'SubCallCommand'))
                    if(~isKey(globalVarList, varName))
                        error('xml2struct:struct2commandList:invalidXML', 'the variable "%s" may not be used in a subcall before it is defined in the XML.', varName);
                    end
                else
                    if(isKey(globalVarList, varName))
                        error('xml2struct:struct2commandList:invalidXML', 'the variable name "%s" may only be assigned once in a script', varName);
                    else
                        globalVarList(varName) = currVariable;
                    end
                end
            end
        case 'pump'
            currCommand = getPumpCommand(s, hardware);
            commandList.addCommand(currCommand);
        case 'temp'
            currCommand = getTempCommand(s, hardware);
            commandList.addCommand(currCommand);  
        %Bojan added November 1, 2013
        case 'tempspecial'
            currCommand = getTempSpecialCommand(s, hardware);
            commandList.addCommand(currCommand); 
        %
        case 'wait'
            currCommand = getWaitCommand(s, hardware);
            commandList.addCommand(currCommand);
        case 'userwait'
            currCommand = getUserWaitCommand(s, hardware);
            commandList.addCommand(currCommand);
        case 'gototile'
            currCommand = getGotoTileCommand(s, hardware);
            commandList.addCommand(currCommand);
        case 'image'
            currCommand = getImageCommand(s, hardware, displayImagePanel);
            commandList.addCommand(currCommand);
        case 'focusmap'
            currCommand = getFocusmapCommand(s, hardware);
            commandList.addCommand(currCommand);
        case 'findedge'
            currCommand = getFindedgeCommand(s, hardware);
            commandList.addCommand(currCommand);
        otherwise
            error('xml2struct:struct2commandList:invalidTag','invalid XML tag "%s".', s.name);
    end
end

function sub = getSubCommand(s, hardware)
    attributeMap = containers.Map();
    
    %init
    attributeMap('name') = '';
    
    for i = 1:length(s.attributes)
        currName = lower(s.attributes(i).name);
        switch currName
            case 'name'
                attributeMap(currName) = s.attributes(i).value;
            otherwise
                error('xml2struct:getWaitCommand:invalidAttribute', '"%s" is an invalid attribute of the sub command', s.attributes(i).name);
        end
    end
       
    unassignedParams = find(cellfun('isempty',values(attributeMap))); %find any values that were unassigned
    
    if(~isempty(unassignedParams)==1) %if any values are left empty
        allKeys = keys(attributeMap);
        unassignedParamKeys = StringFun.all2str(allKeys(unassignedParams));
        error('xml2struct:getSubCommand:invalidAttribute', 'Attribute(s) "%s" of the sub command must be assigned', unassignedParamKeys);
    end
    
    sub = SubCommand(hardware, attributeMap('name'));
end

function cmd = getSubCallCommand(s, hardware, subList)
    attributeMap = containers.Map();
    
    %init
    attributeMap('name') = '';
    
    for i = 1:length(s.attributes)
        currName = lower(s.attributes(i).name);
        switch currName
            case 'name'
                attributeMap(currName) = s.attributes(i).value;
            otherwise
                error('xml2struct:getWaitCommand:invalidAttribute', '"%s" is an invalid attribute of the subcall command', s.attributes(i).name);
        end
    end
       
    unassignedParams = find(cellfun('isempty',values(attributeMap))); %find any values that were unassigned
    
    if(~isempty(unassignedParams)==1) %if any values are left empty
        allKeys = keys(attributeMap);
        unassignedParamKeys = StringFun.all2str(allKeys(unassignedParams));
        error('xml2struct:getSubCallCommand:invalidAttribute', 'Attribute(s) "%s" of the subcall command must be assigned', unassignedParamKeys);
    end
    
    currName = attributeMap('name');
    if(~isKey(subList,currName))
        error('xml2struct:getSubCallCommand:invalidSub','subcall to unknown sub "%s".  Note that subs must be defined in the XML file before the point where they are called.', currName)
    end

    cmd = SubCallCommand(hardware, subList(currName));
end

function [varName, newGlobalVariable] = getVarCommand(s, parent)
    attributeMap = containers.Map();
    
    %init
    attributeMap('name') = '';
    attributeMap('numiterations') = '';
    attributeMap('datatype') = '';

    if(~exist('parent','var')) %global variable
        attributeMap('value') = '';
    elseif(strcmp(class(parent),'SubCallCommand'))
        attributeMap('value') = '';
    elseif(strcmp(class(parent),'SubCommand'))
        %do nothing
    elseif(strcmp(class(parent),'LoopCommand'))
        attributeMap('value') = '';
    else
        error('xml2struct:getWaitCommand:invalidAttribute','invald parent class of the var');
    end
    
    for i = 1:length(s.attributes)
        currName = lower(s.attributes(i).name);
        switch currName
            case 'name'
                attributeMap(currName) = s.attributes(i).value;
            case 'numiterations'
                attributeMap(currName) = str2double(s.attributes(i).value);
            case 'value'
                attributeMap(currName) = s.attributes(i).value;
            case 'datatype'
                attributeMap(currName) = s.attributes(i).value;
            otherwise
                error('xml2struct:getWaitCommand:invalidAttribute', '"%s" is an invalid attribute of the var command', s.attributes(i).name);
        end
    end
    
    if(isempty(attributeMap('numiterations')))
        attributeMap('numiterations') = 1;
    end
    
    unassignedParams = find(cellfun('isempty',values(attributeMap))); %find any values that were unassigned
    
    if(~isempty(unassignedParams)==1) %if any values are left empty
        allKeys = keys(attributeMap);
        unassignedParamKeys = StringFun.all2str(allKeys(unassignedParams));
        error('xml2struct:getVarCommand:invalidAttribute', 'Attribute(s) "%s" of the var command must be assigned', unassignedParamKeys);
    end
    
    varName = attributeMap('name');
    dataType = attributeMap('datatype');
    
    if(~exist('parent','var'))
        %global variable
        CheckParam.isString(varName, 'xml2struct:assignVarValues:badInputs');
        newGlobalVariable = ScriptVariable(varName, dataType, 1);
    elseif(strcmp(class(parent),'SubCommand'))
        parent.addVariable(varName, dataType);
    elseif(strcmp(class(parent),'SubCallCommand'))
        parent.updateVariableList();
        if(~parent.isVariable(varName))
            error('xml2struct:assignVarValues:invalidAttribute','subcall variable "%s" is not defined in the sub it calls', varName);
        end
    elseif(strcmp(class(parent),'LoopCommand'))
        parent.addVariable(varName, dataType);
    else
        error('xml2struct:assignVarValues:invalidAttribute','invald parent class of the var');
    end
    
    if(isKey(attributeMap,'value'))
        valueString = attributeMap('value');
        if(~exist('parent','var'))
            %global variable
            newGlobalVariable.valueArray(1) = string2value(valueString, dataType);
        elseif(strcmp(class(parent),'SubCommand'))
            error('xml2struct:assignVarValues:invalidAttribute','Sub vars should not be assigned values.  Values will be assigned in the respective subcall');
        elseif(strcmp(class(parent),'SubCallCommand'))
            parent.assignVariableValues(varName, string2value(valueString, dataType));
        elseif(strcmp(class(parent),'LoopCommand'))
            parent.assignVariableValues(varName, string2value(valueString, dataType));
        else
            error('xml2struct:assignVarValues:invalidAttribute','invald parent class of the var');
        end
    end
end

function returnValue = string2value(valueString, dataType)
    cellArrayOfValueStrings = tokenizeValueString(valueString, ';');
    numValues = length(cellArrayOfValueStrings);
    for i = 1:numValues
        currValueString = cellArrayOfValueStrings{i};
        switch dataType
            case 'num'
                returnValue{i} = str2double(currValueString);
            case 'str'
                returnValue{i} = currValueString;
            case 'bool'
                if(strcmpi(currValueString,'true'))
                    returnValue{i} = true;
                elseif(strcmpi(currValueString,'false'))
                    returnValue{i} = false;
                else
                    error('xml2struct:string2value:invalidAttribute','bool var values must be either "true" or "false"');
                end
            otherwise
                error('xml2struct:string2value:invalidDataType','invald var data type "%s".  Valid types are "num" "str" and "bool"', dataType);
        end
    end
end

function cellArrayOfValueStrings = tokenizeValueString(valueString, delimiter)
    c = textscan(valueString,'%s','delimiter',delimiter);
    c = c{1};
    for i = 1:length(c);
        cellArrayOfValueStrings{i} = c{i};
    end
end

function cmd = getLoopCommand(s, hardware)
        attributeMap = containers.Map();
    
    %init
    attributeMap('numiterations') = '';
    
    for i = 1:length(s.attributes)
        currName = lower(s.attributes(i).name);
        switch currName
            case 'numiterations'
                if(isVarString(s.attributes(i).value))
                    error('xml2struct:getLoopCommand:invalidAttribute', 'because loop variables are explictly defined as arrays of fixed length, the loop parameter "numIterations" must be explicitly defined and cannot be not be assigned to a variable');
                else
                    attributeMap(currName) = assignValue(s.attributes(i).value, 'num');
                end
            otherwise
                error('xml2struct:getLoopCommand:invalidAttribute', '"%s" is an invalid attribute of the loop command', s.attributes(i).name);
        end
    end
    
    if(isempty(attributeMap('numiterations')))
        attributeMap('numiterations') = 1;
    end
    
    unassignedParams = find(cellfun('isempty',values(attributeMap))); %find any values that were unassigned
    
    if(~isempty(unassignedParams)==1) %if any values are left empty
        allKeys = keys(attributeMap);
        unassignedParamKeys = StringFun.all2str(allKeys(unassignedParams));
        error('xml2struct:getVarCommand:invalidAttribute', 'Attribute(s) "%s" of the loop command must be assigned', unassignedParamKeys);
    end
    
    cmd = LoopCommand(hardware, attributeMap('numiterations'));
end

function cmd = getUserWaitCommand(s, hardware)
    attributeMap = containers.Map();
    
    %init
    attributeMap('message') = '';
    
    for i = 1:length(s.attributes)
        currName = lower(s.attributes(i).name);
        switch currName
            case 'message'
                attributeMap(currName) = assignValue(s.attributes(i).value, 'str');
            case 'timeout'
                attributeMap(currName) = assignValue(s.attributes(i).value, 'num');
            otherwise
                error('xml2struct:getWaitCommand:invalidAttribute', '"%s" is an invalid attribute of the userwait command', s.attributes(i).name);
        end
    end
    
    unassignedParams = find(cellfun('isempty',values(attributeMap))); %find any values that were unassigned
    
    if(~isempty(unassignedParams)==1) %if any values are left empty
        allKeys = keys(attributeMap);
        unassignedParamKeys = StringFun.all2str(allKeys(unassignedParams));
        error('xml2struct:getWaitCommand:invalidAttribute', 'Attribute(s) "%s" of the userwait command must be assigned', unassignedParamKeys);
    end
    
    if(~isKey(attributeMap,'timeout'))
        attributeMap('timeout') = 0;
    end
    
    cmd = UserWaitCommand(hardware, attributeMap('message'), attributeMap('timeout'));
end

function cmd = getWaitCommand(s, hardware)
    attributeMap = containers.Map();
    
    %init
    attributeMap('time') = '';
    
    for i = 1:length(s.attributes)
        currName = lower(s.attributes(i).name);
        switch currName
            case 'time'
                attributeMap(currName) = assignValue(s.attributes(i).value, 'num');
            otherwise
                error('xml2struct:getWaitCommand:invalidAttribute', '"%s" is an invalid attribute of the wait command', s.attributes(i).name);
        end
    end
    
    unassignedParams = find(cellfun('isempty',values(attributeMap))); %find any values that were unassigned
    
    if(~isempty(unassignedParams)==1) %if any values are left empty
        allKeys = keys(attributeMap);
        unassignedParamKeys = StringFun.all2str(allKeys(unassignedParams));
        error('xml2struct:getWaitCommand:invalidAttribute', 'Attribute(s) "%s" of the wait command must be assigned', unassignedParamKeys);
    end
    
    cmd = WaitCommand(hardware, attributeMap('time'));
end

function cmd = getTempCommand(s, hardware)
    attributeMap = containers.Map();
    
    %init
    attributeMap('settemp') = '';
    
    for i = 1:length(s.attributes)
        currName = lower(s.attributes(i).name);
        switch currName
            case 'ramprate'
                attributeMap(currName) = assignValue(s.attributes(i).value, 'num');
            case 'settemp'
                attributeMap(currName) = assignValue(s.attributes(i).value, 'num');
            case 'waittillcomplete'
                attributeMap(currName) = assignValue(s.attributes(i).value, 'bool');
            otherwise
                error('xml2struct:getTempCommand:invalidAttribute', '"%s" is an invalid attribute of the temp command', s.attributes(i).name);
        end
    end
    
    unassignedParams = find(cellfun('isempty',values(attributeMap))); %find any values that were unassigned
    
    if(~isempty(unassignedParams)==1) %if any values are left empty
        allKeys = keys(attributeMap);
        unassignedParamKeys = StringFun.all2str(allKeys(unassignedParams));
        error('xml2struct:getTempCommand:invalidAttribute', 'Attribute(s) "%s" of the temp command must be assigned', unassignedParamKeys);
    end
    
    if(~isKey(attributeMap,'ramprate'))
        attributeMap('ramprate') = 0;
    end
    
    if(~isKey(attributeMap,'waittillcomplete'))
        attributeMap('waittillcomplete') = false;
    end
    
    cmd = TempCommand(hardware, attributeMap('settemp'), attributeMap('ramprate'), attributeMap('waittillcomplete'));
end
%Bojan added Nov 1, 2013
function cmd = getTempSpecialCommand(s, hardware)
    attributeMap = containers.Map();
    
    %init
    attributeMap('settempspecial') = '';
    
    for i = 1:length(s.attributes)
        currName = lower(s.attributes(i).name);
        switch currName
            case 'ramprate'
                attributeMap(currName) = assignValue(s.attributes(i).value, 'num');
            case 'settempspecial'
                attributeMap(currName) = assignValue(s.attributes(i).value, 'num');
            case 'waittillcomplete'
                attributeMap(currName) = assignValue(s.attributes(i).value, 'bool');
            otherwise
                error('xml2struct:getTempSpecialCommand:invalidAttribute', '"%s" is an invalid attribute of the temp special command', s.attributes(i).name);
        end
    end
    
    unassignedParams = find(cellfun('isempty',values(attributeMap))); %find any values that were unassigned
    
    if(~isempty(unassignedParams)==1) %if any values are left empty
        allKeys = keys(attributeMap);
        unassignedParamKeys = StringFun.all2str(allKeys(unassignedParams));
        error('xml2struct:getTempSpecialCommand:invalidAttribute', 'Attribute(s) "%s" of the temp special command must be assigned', unassignedParamKeys);
    end
    
    if(~isKey(attributeMap,'ramprate'))
        attributeMap('ramprate') = 0;
    end
    
    if(~isKey(attributeMap,'waittillcomplete'))
        attributeMap('waittillcomplete') = false;
    end
    
    cmd = TempSpecialCommand(hardware, attributeMap('settempspecial'), attributeMap('ramprate'), attributeMap('waittillcomplete'));
end

function cmd = getPumpCommand(s, hardware)
    attributeMap = containers.Map();
    
    %init
    attributeMap('fromposition') = '';
    attributeMap('volume') = '';
    attributeMap('waittillcomplete') = '';
    attributeMap('flowrate') = '';
    
    for i = 1:length(s.attributes)
        currName = lower(s.attributes(i).name);
        switch currName
            case 'flowrate'
                attributeMap(currName) = assignValue(s.attributes(i).value, 'num');
            case 'volume'
                attributeMap(currName) = assignValue(s.attributes(i).value, 'num');
            case 'waittillcomplete'
                attributeMap(currName) = assignValue(s.attributes(i).value, 'bool');
            case 'fromposition'
                attributeMap(currName) = assignValue(s.attributes(i).value, 'num');
            otherwise
                error('xml2struct:getPumpCommand:invalidAttribute', '"%s" is an invalid attribute of the pump command', s.attributes(i).name);
        end
    end

    unassignedParams = find(cellfun('isempty',values(attributeMap))); %find any values that were unassigned
    if(~isempty(unassignedParams)==1) %if any values are left empty
        allKeys = keys(attributeMap);
        unassignedParamKeys = StringFun.all2str(allKeys(unassignedParams));
        error('xml2struct:getPumpCommand:invalidAttribute', 'Attribute(s) "%s" of the pump command must be assigned', unassignedParamKeys);
    end
    
    cmd = PumpCommand(hardware, attributeMap('volume'), attributeMap('flowrate'), attributeMap('fromposition'), attributeMap('waittillcomplete'));
end

function cmd = getGotoTileCommand(s, hardware)
    attributeMap = containers.Map();
    
    %init
    attributeMap('tile') = '';
    
    for i = 1:length(s.attributes)
        currName = lower(s.attributes(i).name);
        switch currName
            case 'tile'
                attributeMap(currName) = assignValue(s.attributes(i).value, 'str');
            case 'focus'
                attributeMap(currName) = assignValue(s.attributes(i).value, 'bool');
            otherwise
                error('xml2struct:getGotoTileCommand:invalidAttribute', '"%s" is an invalid attribute of the gototile command', s.attributes(i).name);
        end
    end
    
    unassignedParams = find(cellfun('isempty',values(attributeMap))); %find any values that were unassigned
    if(~isempty(unassignedParams)==1) %if any values are left empty
        allKeys = keys(attributeMap);
        unassignedParamKeys = StringFun.all2str(allKeys(unassignedParams));
        error('xml2struct:getPumpCommand:invalidAttribute', 'Attribute(s) "%s" of the pump command must be assigned', unassignedParamKeys);
    end
    
    if(~isKey(attributeMap,'focus'))
        attributeMap('focus') = 'map';
    end
    
    cmd = GotoTileCommand(hardware, attributeMap('tile'), attributeMap('focus'));
end

function cmd = getImageCommand(s, hardware, displayImagePanel)
    attributeMap = containers.Map();
    
    %init
    attributeMap('laser') = '';
    attributeMap('laserpower') = '';
    attributeMap('filter') = '';
    attributeMap('exposuretime') = '';
    attributeMap('filename') = '';
    
    for i = 1:length(s.attributes)
        currName = lower(s.attributes(i).name);
        switch currName
            case 'laser'
                attributeMap(currName) = assignValue(s.attributes(i).value, 'str');
            case 'laserpower'
                attributeMap(currName) = assignValue(s.attributes(i).value, 'num');
            case 'filter'
                attributeMap(currName) = assignValue(s.attributes(i).value, 'str');
            case 'exposuretime'
                attributeMap(currName) = assignValue(s.attributes(i).value, 'num');
            case 'filename'
                attributeMap(currName) = assignValue(s.attributes(i).value, 'str');
            otherwise
                error('xml2struct:getImageCommand:invalidAttribute', '"%s" is an invalid attribute of the image command', s.attributes(i).name);
        end
    end
    
    unassignedParams = find(cellfun('isempty',values(attributeMap))); %find any values that were unassigned
    if(~isempty(unassignedParams)==1) %if any values are left empty
        allKeys = keys(attributeMap);
        unassignedParamKeys = StringFun.all2str(allKeys(unassignedParams));
        error('xml2struct:getPumpCommand:invalidAttribute', 'Attribute(s) "%s" of the image command must be assigned', unassignedParamKeys);
    end
        
    cmd = ImageCommand(hardware, attributeMap('laser'), attributeMap('laserpower'), attributeMap('filter'), attributeMap('exposuretime'), attributeMap('filename'), displayImagePanel);
end

function cmd = getFocusmapCommand(s, hardware)
    attributeMap = containers.Map();
       
    %init
    attributeMap('selectedlaser') = '';
    attributeMap('selectedfilter') = '';
    
    for i = 1:length(s.attributes)
        currName = lower(s.attributes(i).name);
        switch currName
            case 'selectedlaser'
                attributeMap(currName) = assignValue(s.attributes(i).value, 'str');
            case 'selectedfilter'
                attributeMap(currName) = assignValue(s.attributes(i).value, 'num');
            otherwise
                error('xml2struct:getImageCommand:invalidAttribute', '"%s" is an invalid attribute of the focusmap command', s.attributes(i).name);
        end
    end
    
    unassignedParams = find(cellfun('isempty',values(attributeMap))); %find any values that were unassigned
    if(~isempty(unassignedParams)==1) %if any values are left empty
        allKeys = keys(attributeMap);
        unassignedParamKeys = StringFun.all2str(allKeys(unassignedParams));
        error('xml2struct:getPumpCommand:invalidAttribute', 'Attribute(s) "%s" of the focusmap command must be assigned', unassignedParamKeys);
    end
    
    cmd = FocusMapCommand(hardware, attributeMap('selectedlaser'), attributeMap('selectedfilter'));
end

function cmd = getFindedgeCommand(s, hardware)
    attributeMap = containers.Map();
       
    %init
    attributeMap('selectedlaser') = '';
    attributeMap('selectedfilter') = '';
    
    for i = 1:length(s.attributes)
        currName = lower(s.attributes(i).name);
        switch currName
            case 'selectedlaser'
                attributeMap(currName) = assignValue(s.attributes(i).value, 'str');
            case 'selectedfilter'
                attributeMap(currName) = assignValue(s.attributes(i).value, 'num');
            otherwise
                error('xml2struct:getFindedgeCommand:invalidAttribute', '"%s" is an invalid attribute of the findedge command', s.attributes(i).name);
        end
    end
    
    unassignedParams = find(cellfun('isempty',values(attributeMap))); %find any values that were unassigned
    if(~isempty(unassignedParams)==1) %if any values are left empty
        allKeys = keys(attributeMap);
        unassignedParamKeys = StringFun.all2str(allKeys(unassignedParams));
        error('xml2struct:getFindedgeCommand:invalidAttribute', 'Attribute(s) "%s" of the findedge command must be assigned', unassignedParamKeys);
    end
    
    cmd = FindEdgeCommand(hardware, attributeMap('selectedlaser'), attributeMap('selectedfilter'));
end

function assignedVal = assignValue(valueString, dataType)
    switch dataType
        case 'num'
            if isVarString(valueString)
                assignedVal = ScriptVariable(valueString, dataType); %placeholder dummy variable, will be assigned later
            else
                assignedVal = str2num(valueString);
            end
        case 'str'
            if isVarString(valueString)
                assignedVal = ScriptVariable(valueString, dataType); %placeholder dummy variable, will be assigned later
            else
                assignedVal = valueString;
            end
        case 'bool'
            if isVarString(valueString)
                assignedVal = ScriptVariable(valueString, dataType); %placeholder dummy variable, will be assigned later
            else
                if(strcmpi(valueString,'true'))
                    assignedVal = true;
                elseif(strcmpi(valueString,'false'))
                    assignedVal = false;
                else
                    error('xml2struct:assignValue:invalidAttribute', '"%s" is an not a valid value.  bool vars must be "true" or "false"', valueString);
                end
            end
        otherwise
            error('xml2struct:assignValue:invalidDataType','only values of type "num" "str" or "bool" are supported');
    end
end

function TF = isVarString(valueString)
    if(length(valueString)<4)
        TF = false;
    else
        if(strcmpi(valueString(1:4), 'var_'))
            TF = true;
        else
            TF = false;
        end
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