% Partition data by randomly for training,
% validation and testing, respectively

function [imdsTrain, imdsVal, imdsTest, pxdsTrain, pxdsVal, pxdsTest] = partitionData(imdstrain, pxdstrain, imdstest, pxdstest, labelIDs)

    rng(0); 
    numFiles = numel(imdstrain.Files);
    shuffledIndices = randperm(numFiles);
    
    % Use 70% training data for training
    numTrain = round(0.7 * numFiles);
    trainingIdx = shuffledIndices(1:numTrain);
    
    % Use 30% training data for validation
    numVal = round(0.3 * numFiles);
    valIdx = shuffledIndices(numTrain+1:numTrain+numVal);
    
    % Use 100% testing data for testing
    numFilesTest = numel(imdstest.Files);
    testIdx = 1:numFilesTest;
    
    % Create image datastores for training and testing
    trainImages = imdstrain.Files(trainingIdx);
    valImages = imdstrain.Files(valIdx);
    testImages = imdstest.Files(testIdx);
    imdsTrain = imageDatastore(trainImages,'FileExtensions','.mat','ReadFcn',@matReader);
    imdsVal = imageDatastore(valImages,'FileExtensions','.mat','ReadFcn',@matReader);
    imdsTest = imageDatastore(testImages,'FileExtensions','.mat','ReadFcn',@matReader);
    
    % Create pixel label datastores for training and testing
    trainLabels = pxdstrain.Files(trainingIdx);
    valLabels = pxdstrain.Files(valIdx);
    testLabels = pxdstest.Files(testIdx);
    
    classes = pxdstrain.ClassNames;
    pxdsTrain = pixelLabelDatastore(trainLabels, classes, labelIDs);
    pxdsVal = pixelLabelDatastore(valLabels, classes, labelIDs);
    pxdsTest = pixelLabelDatastore(testLabels, classes, labelIDs);
    
end