%  matReader reads custom MAT files

% Copyright 2017 The MathWorks, Inc.
function data = matReader(filename)

    d = load(filename);
    f = fields(d);
    data = d.(f{1})(:,:,:);