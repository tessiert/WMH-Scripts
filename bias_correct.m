clear all;

close all;

dirData = '/home/trace/MRN/data/';

basename = 'M87145150_V1_flair_t2_no_skull';

in_fname = [dirData, basename, '.nii.gz'];

out_fname = [dirData, basename, '_matlab_bias_correct'];

bias_fname = [dirData, basename, '_matlab_bias_field'];

% Load file without applying header transformations
nii = load_untouch_nii(in_fname);

xyz_dim = size(nii.img);

% Define grid of x,y,z values
x = 1:xyz_dim(1);
y = 1:xyz_dim(2);
z = 1:xyz_dim(3);
[X,Y,Z] = meshgrid(x,y,z);

% Define basis functions for f = c0 + cy*y + cx*x + cz*z
% Note: y and x are handled in reverse order because of weird way meshgrid works
f0 = ones(size(X));
f1 = Y;
f2 = X;
f3 = Z;

% Write as a matrix equation
A = [f0(:),f1(:),f2(:),f3(:)];
B = nii.img(:);

% Solve for coefficients
coefs = A\B;

% Calculate bias field
bias = A*coefs;

% Subtract bias field
nii.img = B/bias;

% Zero background
nii.img(nii.img<0) = 0;

% Save bias corrected image
save_untouch_nii(nii, out_fname);

% Also save bias field
nii.img = bias;
save_untouch_nii(nii, bias_fname);