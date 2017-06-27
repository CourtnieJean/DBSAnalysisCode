%% 6-22-2017 - Courtnie's Notes for pt 695e1 with David Caldwell's - script to look at stim spacing
% LALALALA
% requires getEpochSignal.m , subtitle.m , numSubplots.m , vline.m

%% initialize output and meta dir
% clear workspace
close all; clear all; clc


% load in the datafile of interest!
% have to have a value assigned to the file to have it wait to finish
% loading...mathworks bug

structureData = uiimport('-file');
Sing = structureData.Sing;
Stim = structureData.Stim;
%Stm0 = structureData.Stm0;
Eco1 = structureData.ECO1;
Eco2 = structureData.ECO2;
Eco3 = structureData.ECO3;
Eco4 = structureData.ECO4;

Wave.info = structureData.ECO1.info; 

%%
% ui box for input for stimulation channels
prompt = {'how many channels did we record from? e.g 48 ', 'what were the stimulation channels? e.g 28 29 ', 'how long before each stimulation do you want to look? in ms e.g. 1', 'how long after each stimulation do you want to look? in ms e.g 5'};
%Note: for the 6/21/17 patient 695e1, only one ECoG strip, so 1-8, and one DBS, so 33-36;
dlg_title = 'StimChans';
num_lines = 1;
defaultans = {'48','28 29','1','5'};
answer = inputdlg(prompt,dlg_title,num_lines,defaultans);
numChans = str2num(answer{1});
chans = str2num(answer{2});
preTime = str2num(answer{3});
postTime = str2num(answer{4});

%%
% first and second stimulation channel
stim_1 = chans(1);
stim_2 = chans(2);


% get sampling rates
fs_data = Wave.info.SamplingRateHz;
fs_stim = Stim.info.SamplingRateHz;

% stim data
stim = Stim.data;

% current data
sing = Sing.data;

% recording data
%data = [Eco1.data Eco2.data Eco3.data Eco4.data];
%in the case of this patient, only need Eco1(1-8) and Eco3(1-4 or 33-36),
%and the DBS data was mislabelled, such that DBS electrode 0 should be 3, 1
%should be 2, etc. By flipLR-ing the data, no further transpositions need
%to be kept in mind. 
data = [Eco1.data(:,1:8) fliplr(Eco3.data(:,1:4))];
%% plot stim channels if interested

prompt = {'plot intermediate figures that show stim voltage, currents, and delays? "y" or "n" '};
dlg_title = 'StimChans';
num_lines = 1;
defaultans = {'y'};
answer = inputdlg(prompt,dlg_title,num_lines,defaultans);
plotIt = answer(1);

if strcmp(plotIt,'y')
    figure;
    hold on;
    for i = 1:size(stim,2)
        
        t = (0:length(stim)-1)/fs_stim;
        subplot(2,2,i);
        plot(t*1e3,stim(:,i));
        title(sprintf('Channel %d',i));
        
        
    end
    
    
    xlabel('Time (ms)');
    ylabel('Amplitude (V)');
    
    subtitle('Stimulation Channels');
end

%% Sing looks like the wave to be delivered, with amplitude in uA


% build a burst table with the timing of stimuli
bursts = [];

% first channel of current
Sing1 = sing(:,1);
fs_sing = Sing.info.SamplingRateHz;

Sing1Mask = Sing1~=0;
dmode = diff([0 Sing1Mask' 0 ]);

dmode(end-1) = dmode(end);

bursts(2,:) = find(dmode==1);
bursts(3,:) = find(dmode==-1);

singEpoched = squeeze(getEpochSignal(Sing1,(bursts(2,:)-1),(bursts(3,:))+1));
t = (0:size(singEpoched,1)-1)/fs_sing;
t = t*1e3;

if strcmp(plotIt,'y')
    
    figure
    plot(t,singEpoched)
    xlabel('Time (ms)');
    ylabel('Current to be delivered (\muA)')
    title('Current to be delivered for all trials')
end


%% Plot stims with info from above, and find the delay!

stim1stChan = stim(:,1);
stim1Epoched = squeeze(getEpochSignal(stim1stChan,(bursts(2,:)-1),(bursts(3,:))+120));
t = (0:size(stim1Epoched,1)-1)/fs_stim;
t = t*1e3;

if strcmp(plotIt,'y')
    
    figure
    plot(t,stim1Epoched)
    xlabel('Time (ms)');
    ylabel('Voltage (V)');
    title('Finding the delay between current output and stim delivery')
    
end

% get the delay in stim times - looks to be 7 samples or so
delay = round(0.2867*fs_stim/1e3);


% plot the appropriately delayed signal
if strcmp(plotIt,'y')
    stimTimesBegin = bursts(2,:)-1+delay;
    stimTimesEnd = bursts(3,:)-1+delay+120;
    stim1Epoched = squeeze(getEpochSignal(stim1stChan,stimTimesBegin,stimTimesEnd));
    t = (0:size(stim1Epoched,1)-1)/fs_stim;
    t = t*1e3;
    figure
    plot(t,stim1Epoched)
    xlabel('Time (ms)');
    ylabel('Voltage (V)');
    title('Stim voltage monitoring with delay added in')
end



%% extract data

% try and account for delay for the stim times
stimTimes = bursts(2,:)-1+delay;

% DJC 7-7-2016, changed presamps and postsamps to be user defined
presamps = round(preTime/1000 * fs_data); % pre time in sec
postsamps = round(postTime/1000 * fs_data); % post time in sec,


% sampling rate conversion between stim and data
fac = fs_stim/fs_data;

% find times where stims start in terms of data sampling rate
sts = round(stimTimes / fac);


% looks like there's an additional 14 sample delay between the stimulation being set to
% be delivered....and the ECoG recording. which would be 2.3 ms?

%% Decided not to preclude this ECoG delay. So data chunking will start from stim output, and arrive whenever it arrives to the ECoG array.
%delay2 = 14;
%sts = round(stimTimes / fac) + delay2;


%% get the data epochs
%dataEpoched = squeeze(getEpochSignal(data,sts-presamps,sts+postsamps+1));

%The below version of dataEpoched has the chunking start with stimTimes,
%with no ECoG delay buffer or added buffer for visualization (which
%presamps is)
dataEpoched = squeeze(getEpochSignal(data,sts,sts+postsamps+1));

% set the time vector to be set by the pre and post samps
% t = (-presamps:postsamps)*1e3/fs_data;
t = (0:postsamps)*1e3/fs_data;


%% make the decision to scale it

% ui box for input
prompt = {'scale the y axis to the maximum stim pulse value? "y" or "n" '};
dlg_title = 'Scale';
num_lines = 1;
defaultans = {'n'};
answer = inputdlg(prompt,dlg_title,num_lines,defaultans);
scaling = answer{1};

if strcmp(scaling,'y')
    maxVal = max(dataEpoched(:));
    minVal = min(dataEpoched(:));
end


%% plot individual trials for each condition on a different graph

labels = max(singEpoched);
uniqueLabels = unique(labels);

% intialize counter for plotting
k = 1;

% make vector of stim channels
stimChans = [stim_1 stim_2];

% determine number of subplot
% subPlots = numSubplots(numChans);
% p = subPlots(1);
% q = subPlots(2);
p=3;
q=4;
% plot each condition separately e.g. 1000 uA, 2000 uA, and so on

for i=uniqueLabels
    figure;
    dataInterest = dataEpoched(:,:,labels==i);
    for j = 1:numChans
        subplot(p,q,j);
        plot(t,squeeze(dataInterest(:,j,:)));
        xlim([min(t) max(t)]);
        
        % change y axis scaling if necessary
        if strcmp(scaling,'y')
            ylim([minVal maxVal]);
        end
        
        % put a box around the stimulation channels of interest if need be
        if ismember(j,stimChans)
            ax = gca;
            ax.Box = 'on';
            ax.XColor = 'red';
            ax.YColor = 'red';
            ax.LineWidth = 2;
            title(num2str(j),'color','red');
            
        else
            title(num2str(j));
            
        end
        %vline(0);
        
    end
    
    % label axis
    xlabel('time in ms');
    ylabel('voltage in V');
    subtitle(['Individual traces - Current set to ',num2str(uniqueLabels(k)),' \muA']);
    
    
    % get cell of raw values, can use this to analyze later
    dataRaw{k} = dataInterest;
    
    % get averages to plot against each for later
    % cell function, can use this to analyze later
    dataAvgs{k} = mean(dataInterest,3);
    dataDevs{k} = std(dataInterest,0,3);
    
    
    %increment counter
    k = k + 1;
    
    
end
%%
% set 5 and 10 our our stim channels here to zero; chans(1) and chans(2)
dataEpoched(:,chans(1),:)=0;
dataEpoched(:,chans(2),:)=0;

%Per Larry's recommendation, time points (in ms) were hand-selected (HS) from the above subplot spread to
%determine a one-point "platueau value" for the max and min per stim pulse
%at each electrode. 
minmaxHS = floor([1.802 1.802 1.802 1.72 0 1.802 1.802 1.802 2.949 0 2.949 2.949; 2.785 2.785 2.785 2.785 0 2.785 2.785 2.785 1.884 0 1.884 1.884]/1e3*fs_data+1);


%pull the data at these indices from each epoch in each channel: should get
%a 2x12x20 result, with row 1 being min value and row 2 being max
handSelected = zeros(2,12,20);


for m = 1:2
    for c = 1:12
        for e = 1:20
            handSelected(m,c,e)= dataEpoched(minmaxHS(m,c),c,e);
        end
    end
end
%%Plotting to double check

for i=uniqueLabels
    figure;
    dataInterest = dataEpoched(:,:,labels==i);
    for j = 1:numChans
        subplot(p,q,j);
        hold on;
        plot(t,squeeze(dataInterest(:,j,:)));
        plot((minmaxHS(1,j)-1)*1e3/fs_data,squeeze(handSelected(1,j,:)),'*');
        plot((minmaxHS(2,j)-1)*1e3/fs_data,squeeze(handSelected(2,j,:)),'*');
        xlim([min(t) max(t)]);
        if j==1
            legend(z,'Location','westoutside')
        end

        % change y axis scaling if necessary
        if strcmp(scaling,'y')
            ylim([minVal maxVal]);
        end
        
        % put a box around the stimulation channels of interest if need be
        if ismember(j,stimChans)
            ax = gca;
            ax.Box = 'on';
            ax.XColor = 'red';
            ax.YColor = 'red';
            ax.LineWidth = 1;
            title(num2str(j),'color','red');
            
        else
            title(num2str(j));
            
        end
        
        
    end
    
    % label axis
    xlabel('time in ms');
    ylabel('voltage in V');
    subtitle(['Individual traces - Current set to ',num2str(uniqueLabels(k)),' \muA']); 
    %legend
    
    %increment counter
    k = k + 1;
end
%% 
figure;
for minmax = 1:2
    for ch = 1:8
        subplot(2,2,minmax)
        xlim([0 9]);
        y=abs(squeeze(handSelected(minmax,ch,:)));        
        for e = 1:20
            plot(ch,y(e),'y*');
            hold on;
        end        
    end
    vline(5,'r:','Stim');
    xlabel('ECoG Channels');
    ylabel('voltage in V');
    plot(squeeze(abs(mean(handSelected(minmax,1:8,:),3))));
    for ch = 9:12
        subplot(2,2,minmax+2)
        xlim([8 13]);
        y=abs(squeeze(handSelected(minmax,ch,:)));
        for e = 1:20
            plot(ch,y(e),'y*');
            hold on;
        end  
        plot(ch,mean(y),'k.');
    end
    vline(stim_2,'r:','Stim');
    xlabel('DBS Channels');
    ylabel('voltage in V');
    plot(9:12,squeeze(abs(mean(handSelected(minmax,9:12,:),3))));
end

% plot(10,mean(handSelected(1,1,:),3),'o');
% 
% plot(10,mean(handSelected(2,1,:),3),'o');




%% plot averages for 3 conditions on the same graph
% % In this case, there is only one condition (60uA max stim); 
% 
% k = 1;
% figure;
% for k = 1:length(dataAvgs)
%     
%     tempData = dataAvgs{k};
%     
%     for j = 1:numChans
%         s = subplot(p,q,j);
%         plot(t,squeeze(tempData(:,j)),'linewidth',2);
%         hold on;
%         xlim([min(t) max(t)]);
%         
%         
%         % change y axis scaling if necessary
%         
%         if strcmp(scaling,'y')
%             ylim([minVal maxVal]);
%         end
%         
%         
%         if ismember(j,stimChans)
%             ax = gca;
%             ax.Box = 'on';
%             ax.XColor = 'red';
%             ax.YColor = 'red';
%             ax.LineWidth = 2;
%             title(num2str(j),'color','red')
%             
%         else
%             title(num2str(j));
%             
%         end
%         
%         vline(0);
%         
%     end
%     gcf;
% end
% xlabel('time in ms');
% ylabel('voltage in V');
% subtitle(['Averages for all conditions']);
% legLabels = {[num2str(uniqueLabels(1))]};
% 
% k = 2;
% if length(uniqueLabels>1)
%     for i = uniqueLabels(2:end)
%         legLabels{end+1} = [num2str(uniqueLabels(k))];
%         k = k+1;
%     end
% end
% 
% legend(s,legLabels);
