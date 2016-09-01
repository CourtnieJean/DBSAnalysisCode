%% DJC - 8-29-2016 - DBS analysis script
% This is to extract the neural data

%% initialize output and meta dir
% clear workspace - be in the directory with all scripts necessary
close all; clear all; clc

SIDS = {'bb908'};

%% load in subject

sid = SIDS{1};
% load in tank
if (strcmp(sid, 'bb908'))
    
    structureData = uiimport('-file');
   Sing = structureData.Sing;
    Stim = structureData.Stim;
    Valu = structureData.Valu;
    Cond = structureData.Cond;
    DBSs = structureData.DBSs;
    ECOG = structureData.ECOG;
    
    dbsElectrodes = DBSs.data;
    dbs_fs = DBSs.info.SamplingRateHz;
    
    ECOGelectrodes = ECOG.data;
    ECOG_fs = ECOG.info.SamplingRateHz;
    
    stimBox = Stim.data;
    stim_fs = Stim.info.SamplingRateHz;
    
    stimProgrammed = Sing.data;
    
    stimSampDeliver = Cond.data(:,1);
    condition = Cond.data(:,2);
    ttlPulse = Cond.data(:,3);
    cond_fs = Cond.info.SamplingRateHz;
    
    
end

%% decide what to plot

% ui box for input
prompt = {'Plot stimulation monitor and current to be delivered (time series?) y or n ',...
    'Plot time series of DBS and ECoG electrodes? y or n','Plot Specific channels or conditions of interest? y or n'...
    'Plot histogram of DBS and ECoG electrodes? y or n'};
dlg_title = 'Channel of Interest';
num_lines = 1;
defaultans = {'n','n','y','y'};
answer = inputdlg(prompt,dlg_title,num_lines,defaultans);

plotStim = answer{1};
plotTime = answer{2};
plotCond = answer{3};
plotHist = answer{4};
%% plot stim
%
if strcmp(plotStim,'y')
    figure
    hold on
    for i = 1:size(stimBox,2)
        
        t = (0:length(stimBox)-1)/stim_fs;
        subplot(2,2,i)
        plot(t*1e3,stimBox(:,i))
        title(sprintf('Channel %d',i))
        
        
    end
    
    
    xlabel('Time (ms)')
    ylabel('Amplitude (V)')
    
    subtitle('Stimulation Channels')
end

%% Sing is wave to be delivered

% build a burst table with the timing of stimuli from the stim file
bursts = [];

Sing1 = stimProgrammed(:,1);


% trying something like A_BuildStimTables from BetaStim


stimMask = stimSampDeliver~=0;


% sample length of train - 500 ms
sampsEnd = floor(0.5*stim_fs);

bursts(2,:) = find(stimMask==1);
bursts(3,:) = bursts(2,:) + repmat(sampsEnd,size(bursts(2,:)));

stims = squeeze(getEpochSignal(Sing1,(bursts(2,:)-1),(bursts(3,:))+1));
t = (0:size(stims,1)-1)/stim_fs;
t = t*1e3;
if strcmp(plotStim,'y')
    
    figure
    % for first subject, stim_epcohed 1 seems to be off by a sample
    plot(t,stims(:,2:end))
    xlabel('Time (ms)');
    ylabel('Voltage to be delivered')
    title('Voltage to be delivered')
    
    %delay loks to be 0.2867 ms from below.
    
end
%% Plot stims with info from above

stim1 = stimBox(:,1);
stim1Epoched = squeeze(getEpochSignal(stim1,(bursts(2,:)-1),(bursts(3,:))+1));
t = (0:size(stim1Epoched,1)-1)/stim_fs;
t = t*1e3;

if strcmp(plotStim,'y')
    
    figure
    plot(t,stim1Epoched)
    xlabel('Time (ms');
    ylabel('Voltage (V)');
    title('Finding the delay between current output and stim delivery')
    
    hold on
    
    plot(t,stims)
    
    % get the delay in stim times
end

delay = floor(0.1434*stim_fs/1e3);

if strcmp(plotStim,'y')
    
    % plot the appropriately delayed signal
    figure
    stimTimesBegin = bursts(2,:)-1+delay;
    stimTimesEnd = bursts(3,:)+1+delay;
    stim1Epoched = squeeze(getEpochSignal(stim1,stimTimesBegin,stimTimesEnd));
    t = (0:size(stim1Epoched,1)-1)/stim_fs;
    t = t*1e3;
    figure
    plot(t,stim1Epoched(:,2:end))
    hold on
    plot(t,stims(:,2:end))
    xlabel('Time (ms');
    ylabel('Voltage (V)');
    title('Stim voltage monitoring with delay added in')
    
end

%% extract data - NO NEED FOR THIS SINCE DATA IS SAMPLED HIGH HERE
%
% try and account for delay for the stim times
stimTimes = bursts(2,:)-1+delay;


prompt = {'time to look before stimulation (seconds) (If wanting to do stimulation pulse analysis, set to 0)','Time to look after stimulation signal (seconds) (If wanting to do stimulation pulse analysis, set to 0.495) '};
dlg_title = 'How much to analyze';
num_lines = 1;
defaultans = {'0.1','2'};
answer = inputdlg(prompt,dlg_title,num_lines,defaultans);

pre = str2num(answer{1});
post  = str2num(answer{2});

% DJC 7-7-2016, changed presamps and post samps to 1 second
presamps = floor(pre * stim_fs); % pre time in sec
postsamps = floor(post * stim_fs); % post time in sec, % modified DJC to look at up to 300 ms after

%% get the data epochs


dataEpochedECOG = squeeze(getEpochSignal(ECOGelectrodes,stimTimes-presamps,stimTimes+postsamps));
dataEpochedDBS = squeeze(getEpochSignal(dbsElectrodes,stimTimes-presamps,stimTimes+postsamps));

% mean subtract

ECoG_ave = mean(dataEpochedECOG,1);
DBS_ave = mean(dataEpochedDBS,1);

dataEpochedECOG = dataEpochedECOG - repmat(ECoG_ave,size(dataEpochedECOG,1),1,1);
dataEpochedDBS = dataEpochedDBS - repmat(DBS_ave,size(dataEpochedECOG,1),1,1);


% set the time vector to be set by the pre and post samps
t = (-presamps:postsamps-1)*1e3/ECOG_fs;

% get conditions

ucondition = unique(condition);
ucondition = ucondition(2:end);

ECoG_sep = {};
DBS_sep = {};

for i = 1:length(ucondition)
    
    ECoG_sep{i} = dataEpochedECOG(:,:,condition(stimTimes)==ucondition(i));
    DBS_sep{i} = dataEpochedDBS(:,:,condition(stimTimes)==ucondition(i));
    
end


%% plot ECoG Electrodes

if strcmp(plotTime,'y')
    
    for i = 1:length(ucondition)
        
        figure
        ECoG_temp = ECoG_sep{i};
        
        for j = 1:16
            
            subplot(4,4,j);
            plot(t,squeeze(ECoG_temp(:,j,:)));
            title(['Channel ' num2str(j)]);
        end
        
        xlabel('time (ms)')
        ylabel('voltage (V)')
        
        subtitle(['ECoG Electrodes, Condition ' num2str(i)]);
        
    end
    
    
    
    %% plot DBS Electrodes
    
    for i = 1:length(ucondition)
        
        figure
        DBS_temp = DBS_sep{i};
        
        for j = 1:8
            
            subplot(4,2,j);
            plot(t,squeeze(DBS_temp(:,j,:)));
            title(['Channel ' num2str(j)]);
        end
        
        xlabel('time (ms)')
        ylabel('voltage (V)')
        
        subtitle(['DBS Electrodes, Condition ' num2str(i)]);
        
    end
    
end
%% plot channel of interest

if strcmp(plotCond,'y')
    % ui box for input
    prompt = {'ECoG Channel of interest?','DBS Channel of interest','Condition of Interest?'};
    dlg_title = 'Channel of Interest';
    num_lines = 1;
    defaultans = {'16','8','4'};
    answer = inputdlg(prompt,dlg_title,num_lines,defaultans);
    
    ecog_chanInt = str2num(answer{1});
    DBS_chanInt = str2num(answer{2});
    cond_int = str2num(answer{3});
    
    ECoG_temp = ECoG_sep{cond_int};
    DBS_temp = DBS_sep{cond_int};
    
    figure
    plot(t,squeeze(ECoG_temp(:,ecog_chanInt,:)))
    
    xlabel('time (ms)')
    ylabel('voltage (V)')
    title(['ECoG Channel ', num2str(ecog_chanInt), ' for Condition ', num2str(cond_int)]);
    
    
    figure
    plot(t,squeeze(DBS_temp(:,DBS_chanInt,:)))
    
    
    xlabel('time (ms)')
    ylabel('voltage (V)')
    title(['DBS Channel ', num2str(DBS_chanInt), ' for Condition ', num2str(cond_int)]);
    
    
    %% look at averages for condition of interest
    
    DBS_aveCond  = squeeze(mean(DBS_temp,3));
    ECoG_aveCond = squeeze(mean(ECoG_temp,3));
    
    figure
    plot(t,DBS_aveCond);
    xlabel('time (ms)')
    ylabel('voltage (V)')
    title(['Average DBS recording across channels for condition ', num2str(cond_int)])
    
    figure
    plot(t,ECoG_aveCond);
    xlabel('time (ms)')
    ylabel('voltage (V)')
    title(['Average ECoG recording across channels for condition ', num2str(cond_int)])
    
end

%% get average peaks of waveform

DBS_peak_pos = {};
ECoG_peak_pos = {};

DBS_peak_neg = {};
ECoG_peak_neg = {};

factor = -1;
ECoG_neg = cellfun(@(x) x*factor,ECoG_sep,'un',0);
DBS_neg = cellfun(@(x) x*factor,DBS_sep,'un',0);

for i = 1:length(ucondition)
    
    dbs_condP = DBS_sep{i};
    dbs_condN = DBS_neg{i};
    ECoG_condP = ECoG_sep{i};
    ECoG_condN = ECoG_neg{i};
    
    
    for j = 1:size(dbs_condP,2)
        dbs_stackP = squeeze(dbs_condP(:,j,:));
        dbs_stackP = dbs_stackP(:);
        [DBS_peakFind_pos,~] = findpeaks(dbs_stackP,dbs_fs,'MinPeakDistance',0.005);
        DBS_peak_pos{i}{j} = DBS_peakFind_pos;
        
        dbs_stackN = squeeze(dbs_condN(:,j,:));
        dbs_stackN = dbs_stackN(:);
        [DBS_peakFind_neg,~] = findpeaks(dbs_stackN,dbs_fs,'MinPeakDistance',0.005);
        DBS_peak_neg{i}{j} = DBS_peakFind_neg;
        
    end
    
    for j = 1:size(ECoG_condP,2)
        
        ECoG_stackP = squeeze(ECoG_condP(:,j,:));
        ECoG_stackP = ECoG_stackP(:);
        [ECoG_peakFind_pos,~] = findpeaks(ECoG_stackP,dbs_fs,'MinPeakDistance',0.005);
        ECoG_peak_pos{i}{j} = ECoG_peakFind_pos;
        
        ECoG_stackN = squeeze(ECoG_condN(:,j,:));
        ECoG_stackN = ECoG_stackN(:);
        [ECoG_peakFind_neg,~] = findpeaks(ECoG_stackN,dbs_fs,'MinPeakDistance',0.005);
        ECoG_peak_neg{i}{j} = ECoG_peakFind_neg;
    end
    
end

%% Plot it

if strcmp(plotHist,'y')
    for i = 1:length(ucondition)
        
        % DBS
        dbsTotP(i) = figure;
        hold on
        dbsIndP(i) = figure;
        hold on
        legT = {};
        legI = {'Positive Peak','Negative Peak'};
        
        for j=1:size(dbs_condP,2)
            figure(dbsIndP(i));
            subplot(4,2,j)
            hold on
            histogram(DBS_peak_pos{i}{j})
            histogram(DBS_peak_neg{i}{j})
            
            
            title(['Electrode ' num2str(j)])
            
            figure(dbsTotP(i));
            ax1(i) = subplot(2,1,1);
            hold on
            histogram(DBS_peak_pos{i}{j})
            legT{end+1} = ['Electrode ' num2str(j)];
            xlabel('Voltage (V)')
            title('Positive Peak')
            
            ax2(i) = subplot(2,1,2);
            hold on
            histogram(DBS_peak_neg{i}{j})
            xlabel('Voltage (V)')
            title('Negative Peak')
            
        end
        
        figure(dbsIndP(i));
        legend(legI)
        xlabel('Voltage (V)')
        subtitle(['DBS stim pulses for Condition ', num2str(i)])
        
        
        figure(dbsTotP(i));
        legend(legT)
        subtitle(['DBS stim pulses for Condition ', num2str(i)])
        
        %     linkaxes([ax1(i) ax2(i)],'x')
        
        % ECoG
        
        ecogTotP(i) = figure;
        hold on
        ecogIndP(i) = figure;
        hold on
        legT = {};
        legI = {'Positive Peak','Negative Peak'};
        
        for j=1:size(ECoG_condP,2)
            figure(ecogIndP(i));
            subplot(4,4,j)
            hold on
            histogram(ECoG_peak_pos{i}{j})
            histogram(ECoG_peak_neg{i}{j})
            
            
            title(['Electrode ' num2str(j)])
            
            figure(ecogTotP(i));
            ax3(i) = subplot(2,1,1);
            hold on
            histogram(ECoG_peak_pos{i}{j})
            legT{end+1} = ['Electrode ' num2str(j)];
            xlabel('Voltage (V)')
            title('Positive Peak')
            
            ax4(i) = subplot(2,1,2);
            hold on
            histogram(ECoG_peak_neg{i}{j})
            xlabel('Voltage (V)')
            title('Negative Peak')
            
        end
        
        figure(ecogIndP(i));
        legend(legI)
        xlabel('Voltage (V)')
        subtitle(['ECoG stim pulses for Condition ', num2str(i)])
        
        
        figure(ecogTotP(i));
        legend(legT)
        subtitle(['ECoG stim pulses for Condition ', num2str(i)])
        
        %     linkaxes([ax3(i) ax4(i)],'x')
        
    end
    
end


