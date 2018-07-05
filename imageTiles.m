%take images and save to folder
%function imageTiles(imageFolder, imagePrefix)
    imageFolder='C:\Documents and Settings\sbsuser\My Documents\Johan\2014_03_17\TileImages4\'
    imagePrefix='run1_'
    
    
    imgFile2='.tif';
    for i=1:17 
        disp(['Tile: ' num2str(i)]);
        validatedTile = myGui.hardware.tileMap.validateTile(i);
        focus = myGui.guiElements.guiPanelStagesObj.ZuseFocusMap();
        myGui.hardware.gotoTile(validatedTile, focus);
        myGui.guiElements.guiPanelImageObj.capture();
       % pause(2);
         x=myGui.hardware.stageAndFilterWheel.whereIsX();
         y=myGui.hardware.stageAndFilterWheel.whereIsY();
         z=myGui.hardware.stageAndFilterWheel.whereIsZ();
    
       imgFile=strcat(imageFolder, num2str(i),' ',num2str(x),' ',num2str(y),' ',num2str(z), imgFile2);
       myGui.hardware.camera.saveImage(imgFile);
        
    end
%end