function add_rician_noise(DATADIR, sim_img_basename, SIGNAL, SNR)

% Initialize random number generator based on system clock time
rng('shuffle');

% Construct image filenames
sim_fname = [DATADIR, '/', sim_img_basename, '.nii.gz'];

% Load files without applying header transformations
sim_nii = load_untouch_nii(sim_fname);

% Get image dimensions
DIM = size(sim_nii.img);

% Introduce Rician noise into simulated image

% A value of zero for SNR means do not add any noise
if SNR ~= 0

  % Calculate the desired value of sigma from SIGNAL and SNR
  SIGMA = SIGNAL./(sqrt(2).*SNR);

  % Sample from gaussian distribution w stdev = SIGMA
  SIGMA_N = SIGMA.*randn(DIM);

  % Add the noise to the image to simulate the given SNR
  sim_nii.img = sqrt((sim_nii.img + SIGMA_N).^2 + SIGMA_N.^2);
  
end

% Save modified image
out_fname = [DATADIR, '/', sim_img_basename, '_SNR_', int2str(SNR), '.nii.gz'];
save_untouch_nii(sim_nii, out_fname);

% Terminates matlab (needed when called from bash script)
quit;