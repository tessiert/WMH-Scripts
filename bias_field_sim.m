clear all;
close all;

DDIR = '/export/research/analysis/human/grosenberg/vci_20223/analysis/sim_data_test/test/'

fname1 = [DDIR, 'M87101013_20130424_t1n_brain_bias.nii.gz'];
fname2 = [DDIR, 'M87125399_20151007_t1n_brain_bias.nii.gz'];
out_fname = [DDIR, 'test_bias.nii.gz'];

nii1 = load_untouch_nii(fname1);
nii2 = load_untouch_nii(fname2);
out_nii = load_untouch_nii(out_fname);

x_ind = 1:192;
y_ind = 1:256;
z_ind = 1:256;

x_dim = size(x_ind);
y_dim = size(y_ind);
z_dim = size(z_ind);

num_x = x_dim(2);
num_y = y_dim(2);
num_z = z_dim(2);

bias = zeros(num_x, num_y, num_z);

for m = 1:num_z
                
    z_norm_1(m) = norm(nii1.img(:,:,m));
    z_norm_2(m) = norm(nii2.img(:,:,m));
    
    cur_z_norm = mean([z_norm_1(m), z_norm_2(m)]);
    
    % Create a vector of 10 coefficients - each between -1 and 1, 
    %then subsequently normalized to cur_z_norm - of a 2D cubic polynomial basis (x^m*y^n; m,n <= 3)
    c = cur_z_norm.*normr(1 - 2.*rand(1, 10));
    
    for l = 1:num_y
        
        for k = 1:num_x
            
            bias(k,l,m) = c(1) + c(2)*k + c(3)*l + c(4)*k^2 + c(5)*k*l + c(6)*l^2 + c(7)*k^3 + c(8)*k^2*l + c(9)*k*l^2 + c(10)*l^3;
            
        end        
    end
end

out_nii.img = bias;

save_untouch_nii(out_nii, out_fname);

