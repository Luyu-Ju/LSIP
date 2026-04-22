% Derive predictors

function predictors = generatePredictors(filedtm, filescar, filelandslide,filecenterline)

    % read dtm
    load(filedtm,'DTM');
    
    % read labeled scars
    scar = importdata(filescar);
    
    % read labels landslides
    landslide = importdata(filelandslide);
    
    % read centerlines of landslides
    centerlineo = importdata(filecenterline);
    geoinfo = GRIDobj(filecenterline);
    
    % match scars, landslides, centerline and boundary of landslides
    uniquescar = unique(scar);
    
    boundary = zeros(size(landslide));
    centerline = zeros(size(landslide));
    for i = 2:length(uniquescar)
    
        % find index of scar
        [rowscari,colscari] = find(scar == uniquescar(i));
        globalidscari = sub2ind(size(scar), rowscari,colscari);
    
        % find index of correspond landslide
        landslidei = landslide(globalidscari);
        landslideid = mode(landslidei);
        [rowlandslidei,collandslidei] = find(landslide == landslideid(1));
        globalidlandslidei = sub2ind(size(landslide), rowlandslidei,collandslidei);
    
        % find index of correspond centerline
        centerlinei = centerlineo(globalidlandslidei);
        centerlinei(centerlinei == centerlineo(1)) = [];
        if ~isempty(centerlinei)
            [rowceni, colceni] = find(ismember(centerlineo, centerlinei));
            globalidcenterlinei = sub2ind(size(centerlineo), rowceni,colceni);
            centerline(globalidcenterlinei) = uniquescar(i);
        
            % find index of correspond boundary
            landslidei = zeros(size(landslide));
            landslidei(globalidlandslidei) = 1;
            BW = logical(landslidei);
            boundaryi = edge(BW, 'canny');
            boundaryi = bwlabel(boundaryi); 
            idbound = find(boundaryi == 1);
            boundary(idbound) = uniquescar(i);
        end
    
    end
    
    % derive predictors
    dist2centerline = zeros(size(landslide));
    dist2boundary = zeros(size(landslide));
    dist2crown = zeros(size(landslide));
    
    fallheight2crown = zeros(size(landslide));
    fallheight = zeros(size(landslide));
    
    uniquescar = unique(scar);
    for i = 2:length(uniquescar)
    
        % find index of scar
        [rowscari,colscari] = find(scar == uniquescar(i));
        globalidscari = sub2ind(size(scar), rowscari,colscari);
    
        % find index of correspond landslide
        landslidei = landslide(globalidscari);
        landslidei(landslidei == 0) = [];
    
        if ~isempty(landslidei)
            landslideid = mode(landslidei);
            [rowlandslidei,collandslidei] = find(landslide == landslideid(1));
            globalidlandslidei = sub2ind(size(landslide), rowlandslidei,collandslidei);
    
            rowup = min(rowlandslidei);
            rowdown = max(rowlandslidei);
            colleft = min(collandslidei);
            colright = max(collandslidei);
    
            % landslide index in local patch
            subrowlandslidei = rowlandslidei - rowup + 1;
            subcollandslidei = collandslidei - colleft + 1;
        
            % find index of correspond centerline
            centerlineid = centerline(globalidlandslidei);
            centerlineid(centerlineid == 0) = [];
            centerlineid = mode(centerlineid);
            if ~isempty(centerlineid)
                % calculate distance 2 centerline of landslide
                localarea = centerline(rowup:rowdown,colleft:colright);
                distances = bwdist(localarea == centerlineid(1));
                locallidlandslidei = sub2ind(size(localarea), subrowlandslidei,subcollandslidei);
                distanceslocalarea = distances(locallidlandslidei);
                dist2centerline(globalidlandslidei) = distanceslocalarea.*geoinfo.cellsize;
            end            
            % calculate distance 2 boundary of landslide 
            landslidei = zeros(size(landslide));
            landslidei(globalidlandslidei) = 1;
            se = strel('square', 5);
            landslidei = imdilate(landslidei, se);
            iddilate = find(landslidei == 1);
    
            boundaryid = boundary(iddilate);
            boundaryid(boundaryid == 0) = [];
            boundaryid = mode(boundaryid);
    
            localareaboundary = boundary(rowup:rowdown,colleft:colright);
            boundaryindex = find(ismember(localareaboundary,boundaryid));
            localareaboundary(boundaryindex) = boundaryid(1);
    
            distances = bwdist(localareaboundary == boundaryid(1));
            distanceslocalarea = distances(locallidlandslidei);
            dist2boundary(globalidlandslidei)  = distanceslocalarea.*geoinfo.cellsize;
        
            % calculate distance 2 crown
            localdtm = zeros(size(localarea));
            landslidedtm = DTM(globalidlandslidei);
            idcrown = find(landslidedtm == max(landslidedtm));
            localdtm(subrowlandslidei(idcrown(1)),subcollandslidei(idcrown(1))) = 1;
            distances = bwdist(localdtm == 1);
            distanceslocalarea = distances(locallidlandslidei);
            dist2crown(globalidlandslidei) = distanceslocalarea.*geoinfo.cellsize;
        
            % calculate fallheight 2 crown
            fallheight2crown(globalidlandslidei) = max(landslidedtm) - landslidedtm;
        
            % calculate fall height
            fallheight(globalidlandslidei) = max(landslidedtm) - min(landslidedtm);

        end
    end
    
    % derive high-order predictors
    % fallheight ratio
    highratio = fallheight2crown./fallheight;
    highratio(isnan(highratio)) = 0;
    highratio(highratio == -Inf) = 0;
    
    % length to width ratio
    distsemiaxis = dist2centerline + dist2boundary;
    length2width = distsemiaxis ./ dist2crown;
    length2width(isnan(length2width)) = 0;
    length2width(length2width == Inf) = 0;
    
    predictors = cat(3, highratio, length2width);
end
