% data filepath
filedtm = '..\..\..\data\SaiKung\dtm\dtm.mat';
filescar = '..\..\..\data\SaiKung\scar\scar.tif';
filelandslide = '..\..\..\data\SaiKung\landslide\landslide.tif';
filecenterline = '..\..\..\data\SaiKung\centerline\centerline.tif';
filetrainregion = '..\..\..\data\SaiKung\trainregion\trainregion.tif';

% generate predictors
predictors = generatePredictors(filedtm, filescar, filelandslide, filecenterline);

% train and test predictor split
trainregion = imread(filetrainregion);
[rowtra,coltra] = find(trainregion == trainregion(1));

train_predictors = predictors(:,1:max(coltra),:);
test_predictors = predictors(:,max(coltra)+1:end,:);

% train and test ground truth split
scar = importdata(filescar);
scar(scar == scar(1)) = 2;
scar(scar ~= scar(1)) = 1;
train_labels = uint8(scar(:,1:max(coltra)));
test_labels = uint8(scar(:,max(coltra)+1:end));

% read landslide
landslide = importdata(filelandslide);
test_landslide = landslide(:,max(coltra)+1:end);

%% Model training
classNames = [ "Scars", "NoScars"]; 
cmap = jet(numel(classNames));

% Save the training data as a MAT file and the training labels as a PNG file.
save('train_predictors.mat','train_predictors');
imwrite(train_labels,'train_labels.png');

% Begin by storing the training images from 'train_data.mat' in an imageDatastore. 
imds = imageDatastore('train_predictors.mat','FileExtensions','.mat','ReadFcn',@matReader);

% Create a pixelLabelDatastore (Computer Vision Toolbox) to store the label patches .
pixelLabelIds = 1:2;
pxds = pixelLabelDatastore('train_labels.png',classNames,pixelLabelIds);

% Create a randomPatchExtractionDatastore from the image datastore and the pixel label datastore.
dsTrain = randomPatchExtractionDatastore(imds,pxds,[512,512],'PatchesPerImage',160);

% build network
inputTileSize = [512, 512, 2]; 
lgraph = createUnet(inputTileSize);
analyzeNetwork(lgraph);
disp(lgraph.Layers)

% model parameter setting
initialLearningRate = 0.05;
maxEpochs = 30;
minibatchSize = 4;
l2reg = 0.0001;

options = trainingOptions('sgdm',...
    'InitialLearnRate',initialLearningRate, ...
    'Momentum',0.9,...
    'L2Regularization',l2reg,...
    'MaxEpochs',maxEpochs,...
    'MiniBatchSize',minibatchSize,...
    'LearnRateSchedule','piecewise',...    
    'Shuffle','every-epoch',...
    'GradientThresholdMethod','l2norm',...
    'GradientThreshold',0.05, ...
    'Plots','training-progress', ...
    'VerboseFrequency',20);

% model training
[net,~] = trainNetwork(dsTrain,lgraph,options);

% save trained network
save train net

%% Model test
% use function, segmentImage, to the data set. 
predictPatchSize = [512 512];
scar_pred = segmentImage(test_predictors,net,predictPatchSize);

% mask non-landslide area
idnonlandslide = find(test_landslide == landslide(1));
test_labels(idnonlandslide) = 2;
scar_pred(idnonlandslide) = 2;

% delete predictions in the low area of a landslide
load(filedtm,'DTM');

% pad scar predictions in test region to total study area
train_area = ones(size(train_labels)).*2;
scar_pred = cat(2,train_area,scar_pred);

%
scar_pred_u = ones(size(scar_pred)).*2;
landslidei = unique(landslide);
for i = 2:length(unique(landslide))
    % match predicted scar with landslide
    idslide = find(landslide == landslidei(i));

    % find correspond predicted scar
    scari = zeros(size(landslide));
    scari(idslide) = scar_pred(idslide);
    scari(scari == 2) = 0;
    scari = bwlabel(scari);

    % find separated scars in the same landslide
    scarpieces = unique(scari);
    scarpieces(scarpieces == 0) = [];

    %
    if ~isempty(scarpieces)
        dtmpiece = zeros(length(scarpieces),1);

        % calculate mean elevation of each scar piece in the same landslide
        for j = 1:length(scarpieces)
            idpiece = find(scari == scarpieces(j));
            dtmpiece(j) = mean(DTM(idpiece));
        end
    
        % delete scar piece in the low area
        idpiecemax = find(dtmpiece == max(dtmpiece));
        scari(scari ~= scarpieces(idpiecemax(1))) = 0;
        scari(scari == scarpieces(idpiecemax(1))) = 1;
    
        % reserve highest scar
        idhighscar = find(scari == 1);
        scar_pred_u(idhighscar) = 1;
    
        % finetune results
        landslideonlyi = zeros(size(landslide,1), size(landslide,2));
        landslideonlyi(idslide) = 1;
        idnolandslide = find(landslideonlyi == 0);
    
        dtmi = DTM;
        dtmi(idnolandslide) = -9999;

        highscarele = DTM(idhighscar);
        minele = min(highscarele);
        idhigher = find(dtmi >= minele(1));
        scar_pred_u(idhigher) = 1;
    end
end

% evaluation metrix
scar_pred_test = scar_pred_u(:,size(train_area,2)+1:end);
[rowtest,coltest] = size(scar_pred_test);
pred = uint8(reshape(scar_pred_test,[rowtest*coltest,1]));

obs = uint8(reshape(test_labels,[rowtest*coltest,1]));

[C_matrix,~] = confusionmat(obs,pred);
TP = C_matrix(1,1); FP = C_matrix(2,1); 
FN = C_matrix(1,2); TN = C_matrix(2,2);
Accuracy = (TP+TN)/(TP+TN+FP+FN);
Precision = TP/(TP+FP);
Recall = TP/(TP+FN);
F1 = 2*Precision*Recall/(Precision+Recall);
IoU = TP/(TP+FP+FN);
Dice = 2*TP/(2*TP+FP+FN);

% write predictions
currDir = [pwd, '\'];
resDir = [currDir, 'results\'];
if ~exist(resDir, 'dir'), mkdir(resDir); end

[~,R] = geotiffread(filescar);
info = geotiffinfo(filescar);
scar_premap = 'results\scar_pred_unet.tif';
geotiffwrite(scar_premap, scar_pred_u, R,  ...
    'GeoKeyDirectoryTag', info.GeoTIFFTags.GeoKeyDirectoryTag);