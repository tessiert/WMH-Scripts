function random_head_pos_and_noise(DATADIR, sim_img_basename, SIGNAL, SNR)

% Function that calculates the local variance of an input image block-by-block
fun = @(block_struct) ...
   std2(block_struct.data).^2 * ones(size(block_struct.data));

% Initialize random number generatot based on system clock time
rng('shuffle');

% Construct image filenames
sim_fname = [DATADIR, '/', sim_img_basename, '.nii.gz'];

% Load files without applying header transformations
sim_nii = load_untouch_nii(sim_fname);

% Get image dimensions
DIM = size(sim_nii.img);

% First, introduce Rician noise into simulated image

% A value of zero for SNR means do not add any noise
if SNR ~= 0

  % Calculate the desired value of sigma from SIGNAL and SNR
  SIGMA = SIGNAL./(sqrt(2).*SNR);

  % Sample from gaussian distribution w stdev = SIGMA
  SIGMA_N = SIGMA.*randn(DIM);

  % Add the noise to the image to simulate the given SNR
  sim_nii.img = sqrt((sim_nii.img + SIGMA_N).^2 + SIGMA_N.^2);
  
end

% Next, add a randomly generated bias field to simulated image

% Generate bias field contribution coefficients normalized to one
%a = sqrt(rand(1))
%b = sqrt(1 - a.^2)

% Use random superposition of receiver and donor bias fields to generate
% new bias field
%BIAS = a.^2 .* receiver_nii.img + b.^2 .* donor_nii.img;

% Add bias to simualted image
%sim_nii.img = sim_nii.img + BIAS;

% Finally, randomly jitter head position for current visit, using baseline
% head position as a starting point

% Load the sform data from the Nifti header
sform = load([DATADIR, '/', 'cur_head_pos_data']);

% Reshape and take transform to get typical form of sform matrix
sform_mat = reshape(sform, 4, 4)';

% Extract rotation matrix (S) and translation vector (T)
S = sform_mat(1:3, 1:3);
T = sform_mat(1:3,4);

ANGLE = 15;

% Generate random x, y, z rotation angles between 0 and ANGLE degrees
angles = ANGLE.*rand(1,3);

a = angles(1);
b = angles(2);
c = angles(3);

% Create 3D rotation matrix (yaw, pitch, and roll) using random angles
R = [cosd(a)*cosd(b) cosd(a)*sind(b)*sind(c)-sind(a)*cosd(c) cosd(a)*sind(b)*cosd(c)+sind(a)*sind(c);
     sind(a)*cosd(b) sind(a)*sind(b)*sind(c)+cosd(a)*cosd(c) sind(a)*sind(b)*cosd(c)-cosd(a)*sind(c);
    -sind(b)                        cosd(b)*sind(c)                    cosd(b)*cosd(c)       ];

% Simulate rotated head position
S_NEW = R*S;

OFFSET = 15;

% Generate random values between -OFFSET and OFFSET
T_RAND = -OFFSET + 2*OFFSET.*rand(3, 1);

% Simulate translated head position (in mm)
T_NEW = T + T_RAND;

sform_mat(1:3, 1:3) = S_NEW;
sform_mat(1:3, 4) = T_NEW;

% Format output as 'fslorient' routine in calling bash script expects
out_sform = reshape(sform_mat', [], 16);

% Save jittered sform data
save([DATADIR, '/', 'cur_head_pos_data_updated'], 'out_sform', '-ascii');

% Save modified image
out_fname = [DATADIR, '/', sim_img_basename, '_noisy.nii.gz'];
save_untouch_nii(sim_nii, out_fname);

% Terminates matlab (needed when called from bash script)
quit;