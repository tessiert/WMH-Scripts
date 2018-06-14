function noise_free_prob(DATADIR, neighbor_map_basename, target_map_basename, output_basename)

% Construct image filenames
neighbors_fname = [DATADIR, '/', neighbor_map_basename, '.nii.gz'];
targets_fname = [DATADIR, '/', target_map_basename, '.nii.gz'];

% Load files without applying header transformations
neighbors_nii = load_untouch_nii(neighbors_fname);
targets_nii = load_untouch_nii(targets_fname);

% Get the dimensions of the input images
dim=size(targets_nii.img);

% Create a blank image template
blank_img=[zeros(dim)];

% Make an nii structure containing the blank image
make_nii(blank_img, [1 1 1], [0 0 0]);

% Copy all info into new structure
corrected_nii=neighbors_nii;

% Blank out the image
corrected_nii.img=blank_img;

corrected_nii.fileprefix=[DATADIR, '/', output_basename];

corrected_nii.untouch=0;

% Find the linear indices of the voxels of interest (i.e. those that have
% nonzero entries)
target_ind=find(targets_nii.img);

% Find the number of target voxels
num_targets = length(target_ind);

% Find the 2D matrices of subscript indices for each target voxel
[X_Targ, Y_Targ, Z_Targ] = ind2sub(dim, target_ind);

% Find the linear indices of the neighbors of each target voxel.
% Each row is a list of the indices of (up to) 26 neighboring voxels
[Neighbor_Ind, R, num_neighbors] = neighborND(target_ind, dim);

% Find the 2D matrices of subscripts for each neighboring point
% Each row is a list of the X(YZ) indices of (up to) 26 neighboring voxels
[X_Neighbor, Y_Neighbor, Z_Neighbor] = ind2sub(dim, Neighbor_Ind);

% For each voxel whose classification has changed since the last visit
for m = 1:num_targets
    
    neighbor_total = 0;
    neighbor_count = 0;
    
    % For each potential neighbor
    for n = 1:26
   
        % Find the coordinates of the current neighbor to be considered
        cur_x = X_Neighbor(m, n);
        cur_y = Y_Neighbor(m, n);
        cur_z = Z_Neighbor(m, n);
        
        % If the WMH score (probability or z-scores) of the current neighboring voxel exists,
        % i.e. it survived the cuts applied in the main calling script
        if neighbors_nii.img(cur_x, cur_y, cur_z) > 0
        
            % Add current value to running total of neighboring values
            neighbor_total = neighbor_total + neighbors_nii.img(cur_x, cur_y, cur_z);
            
            % Keep track of # of neighbors contributing to total for
            % averaging
            neighbor_count = neighbor_count + 1;
            
        end
        
    end
 
    % If a particular voxel had no 'noise-free' neighbors
    if neighbor_count == 0
        
        % Retain the starting value at that voxel
        corrected_nii.img(X_Targ(m), Y_Targ(m), Z_Targ(m)) = targets_nii.img(X_Targ(m), Y_Targ(m), Z_Targ(m));
        
    else
        
        % Use the average of the voxel's neighbors
        corrected_nii.img(X_Targ(m), Y_Targ(m), Z_Targ(m)) = neighbor_total/neighbor_count;
        
    end
     
end

% Save modified image
out_fname = [DATADIR, '/', output_basename, '.nii.gz'];
save_nii(corrected_nii, out_fname);

% Terminates matlab (needed when called from bash script)
quit;