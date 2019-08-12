function image_data_final_Complex = MRF_recon()
% This script requires MiRT toolbox,
% https://web.eecs.umich.edu/~fessler/code/
% some variables: dim1: size of original raw data
%dim2: size of concatenated raw data
%dim3: size of ktrajectory data
%dim4: size of concatenated raw data after cutting rewinders


%% This stage takes in a .dat raw data file and outputs .mat file.
acquired_raw_data = dat2mat_nonCart();%extract .dat information
 %the second dim of acquired data is acquired points, 4th dim is partition number
dim1 = size(acquired_raw_data);
acquired_points = dim1(2);
acquired_raw_data_con = zeros(dim1(1)*dim1(4),dim1(2),dim1(3));%preallocate concatenated raw data
for n1 = 1:dim1(2)
    for n2 = 1:dim1(3)
        acquired_raw_data_con(:,n1,n2) = [acquired_raw_data(:,n1,n2,1);...
            acquired_raw_data(:,n1,n2,2)];%concatenate second partition with first partition
    end
end
dim2 = size(acquired_raw_data_con);

%% Stage 2, load spiral data
[baseFileName,folder] = uigetfile('*.mat','Pick the trajectory file');
fullFileName = fullfile(folder, baseFileName);
load(fullFileName)
dim3 = size(traj);
kshots = dim3(2);
% check if acquired raw data has rewinders
if dim2(1)>dim3(1) %if concatenated raw data is longer than trajectory file, cut the rewinders in the end
    acquired_raw_data_con = acquired_raw_data_con(1:dim3(1),:,:); %cut the rewinders
    % the raw data should have same length as trajectory data, the data
    % acquired at rewinder is useless
end

non_zero_loc = find(ind(1,:));
trunc = non_zero_loc(1)+1;
acquired_raw_data_con = circshift(acquired_raw_data_con,-trunc); %remove the offset at beginning
acquired_raw_data_con(end-trunc+1:end, :,:) = 0; % add same length of zeros at end
dim4 = size(acquired_raw_data_con);
ktraj = repmat(traj,[1,ceil(acquired_points/kshots),1]);
ktraj = ktraj(:,1:acquired_points,:);%repmat spiral data, check first spiral and 49 spiral


%% Stage 3, multiply dcf with raw data 
acquired_raw_data_final = zeros(dim4);
acquired_raw_data_con2 = acquired_raw_data_con;

dcf_repmat = repmat(reshape(dcf,dim3(1:2)),[1 ceil(acquired_points/kshots)]);
dcf_repmat = dcf_repmat(:,1:acquired_points);
for n3 = 1:dim2(3)
    acquired_raw_data_final(:,:,n3) = acquired_raw_data_con2(:,:,n3).*dcf_repmat;
    %multiplying with dcf for each channel
end

%% Stage 4, sliding windows
Jd = [5,5]; Nd = [256,256]; Kd =Nd.*2;
image_data_final = zeros(Nd(1),Nd(2),dim2(3),acquired_points);
image_data_final_Complex = zeros(Nd(1),Nd(2),acquired_points);
% setting up parameters for nufft

tic

for n4 = 1:acquired_points%total # of images generated by sliding windows
    kshot_win = floor(kshots.*0.5);
    disp (n4)
    SelectedRange = (n4-kshot_win-1):(n4+kshot_win-2);
    SelectedRange = SelectedRange(SelectedRange > 0 & SelectedRange <= acquired_points);
    
    ktraj_temp = ktraj(:,SelectedRange,:); %recounstruct using full 48 spirals or partial spirals
    ktraj_temp = reshape(ktraj_temp,[],2).*1e-3; %multiply by 1e3 for phantom data from Sravan, but 1e-3 for my data
    om = squeeze(ktraj_temp.*2.*pi);
    st = nufft_init(om, Nd, Jd, Kd, Nd/2, 'minmax:kb');
    
    for n5 = 1:dim2(3)
        acquired_raw_data_temp = acquired_raw_data_final(:,SelectedRange,n5);
        acquired_raw_data_temp = reshape(acquired_raw_data_temp,[],1);
        image_data_final(:,:,n5,n4) = nufft_adj(acquired_raw_data_temp,st);
    end  
    sens = Complex_Chan_Combining(image_data_final(:,:,:,n4));
    imtemp2 = squeeze(sum(bsxfun(@times,conj(sens),image_data_final(:,:,:,n4)),3));
    
    figure;
    imagesc(abs(imtemp2));xlabel(num2str(n4));
    caxis auto;
    axis equal tight; drawnow;
    colormap gray;
    
    image_data_final_Complex(:, :, n4) = imtemp2;
end
end
