%  matReader reads custom MAT files
%
%  IMAGE = matReader(FILENAME) returns the channels of the
%  Multispectral image saved in FILENAME.

% Copyright 2017 The MathWorks, Inc.
function data = matReader(filename)

    d = load(filename);
    f = fields(d);
    data = d.(f{1})(:,:,:);
