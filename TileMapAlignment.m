function tilePos=tmaps
    tileFile1='AAM97_ALL_tile0';
    tileFile3='_Bottom_filtered.CPseq';
    tileFolder='C:\Documents and Settings\sbsuser\My Documents\Johan\tileMappingV3\2014_09_02\filtered_tiles\subsetF10A\';
    imgFolder='D:\Johan\2014_09_02\registration\';
    imgFile1='tile';
    imgFile2='.tif';
    for i=[6]%5:5%length(17) 
        %i=8
        tileFile=strcat(tileFolder, tileFile1, num2str(i,'%02.f'), tileFile3)
        imgFile=strcat(imgFolder,imgFile1, num2str(i), imgFile2)
        %tileFile='filtered_tiles/tile8Read1perfect.CPseq';
        [adj_x,adj_y,xoff,yoff,x_vals,y_vals,xmin,ymin]=RegisterImage(tileFile,'cpseq', 0, 0, imgFile);
        tilePos(i,3)=xmin;
        tilePos(i,4)=ymin;
        tilePos(i,5)=xoff;
        tilePos(i,6)=yoff;
        
    %end
end