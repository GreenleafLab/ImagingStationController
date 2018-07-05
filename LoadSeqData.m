% Load sequencing data from a MiSeq or GA run
%
% Input:  filename (file must be in "qseq" or "filt" or "fastq" format)
%         format (either "qseq" or "filt" or "fastq")
%         lastBaseFilter (use 'acgt' if you don't want filtering; otherwise
%         this parameter is a set of bases and the function will return
%         only data points whose sequences have a final base that is part
%         of the set)

% Output: arrays containing the (x,y) coordinates of each cluster, and the
%         sequence for each cluster
%
% Peter McMahon (pmcmahon@stanford.edu)
% April 2013

function [x, y, sequences] = LoadSeqData(filename, format)
    format = lower(format);
    if strcmp(format, 'filt')
        % file is in filt format
        fid = fopen(filename);
        data = textscan(fid, '%s %s %s %s %d %f %f %s', 'Delimiter', '\t');
        % file format: <unparsed header> <sequence> <q-scores> <barcode> <tile id> <cluster x position> <cluster y position> <?>
        %                      1              2         3          4         5               6                    7           8
        fclose(fid);
        
        x_unfiltered = data{6};
        y_unfiltered = data{7};
        sequences_unfiltered = data{2};
    elseif strcmp(format, 'cpseq')
        fid = fopen(filename);
        data = textscan(fid, '%s %s %s %s %s %s %s %s %s %s', 'Delimiter', '\t');
        cID = data{1};
        numLines = size(cID, 1);
        x_unfiltered = zeros(numLines,1);
        y_unfiltered = zeros(numLines,1);
        for cnt = 1:numLines
            data_1 = textscan(cID{cnt}, '%s %d %s %d %d %d %d', 'Delimiter', ':');
            x_unfiltered(cnt) = data_1{6};
            y_unfiltered(cnt) = data_1{7};
        end
        sequences_unfiltered = [];
        
        fclose(fid);
    elseif strcmp(format, 'qseq')
        % file is in qseq format
        fid = fopen(filename);
        data = textscan(fid, '%s %d %d %d %d %d %d %d %s %s %d', 'Delimiter', '\t');
        % file format: <machine id>  <?>  <lane>  <tile>  <cluster x position> <cluster y position>  <?>  <?>  <sequence>  <q-scores>  <?> 
        %                   1         2      3      4              5                    6             7    8        9          10       11
        fclose(fid);
        
        x_unfiltered = data{5};
        y_unfiltered = data{6};
        sequences_unfiltered = data{9};
    elseif strcmp(format, 'fastq')
        %file is in fastq format
        
        disp('Warning: fastq file reading is slow. Rather use qseq or filt.');
        
        fid = fopen(filename);
        
        x_unfiltered = [];
        y_unfiltered = [];
        sequences_unfiltered = {};

        blockIndex = 1;
        while (~feof(fid))
            line1 = textscan(fid, '%s %s', 1, 'Delimiter', ' '); %split line1 into two tokens by space...
            line1_1 = textscan(line1{1}{1}, '%s %d %s %d %d %d %d', 1, 'Delimiter', ':'); %...then tokenize the first half on colons
            line1_2 = textscan(line1{2}{1}, '%d %s %d %s', 1, 'Delimiter', ':'); %...and tokenize the second half on colons
            
            % [line 1] : @<machine id>:<run index>:<flowcell id>:<lane #>:<tile #>:<x coord>:<y coord> <read 1 or 2>:<pass filter>:<control bits>:<barcode index>
            %                 1-1          1-2          1-3        1-4       1-5      1-6       1-7         2-1           2-2           2-3             2-4         
            
            line2 = textscan(fid, '%s', 1);
            % [line 2] : <sequence>
            
            line3 = textscan(fid, '%s', 1);
            % [line 3] : +
            
            line4 = textscan(fid, '%s', 1);
            % [line 4] : <quality string>
            
            x_unfiltered(blockIndex,1) = line1_1{1,6};
            y_unfiltered(blockIndex,1) = line1_1{1,7};
            tmpstr = line2{1,1};
            sequences_unfiltered{blockIndex,1} = tmpstr{1};
            
            blockIndex = blockIndex + 1;
        end

        fclose(fid);
    else
        error('Invalid file format. Must be either "filt", "qseq" or "fastq".');
    end
    
    clear data;
    
    %filteredIndices = find(cellfun(@(s) IsLastCharacterInSet(lastBaseFilter, s), sequences_unfiltered)); % indices of the clusters whose last base was in the set given by lastBaseFilter
    x = x_unfiltered;
    y = y_unfiltered;
    %x = x_unfiltered(filteredIndices);
    %y = y_unfiltered(filteredIndices);
    %sequences = sequences_unfiltered(filteredIndices);
    sequences = sequences_unfiltered;
end