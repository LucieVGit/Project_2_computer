function run_embodiment_task()
% RUN_EMBODIMENT_TASK  Perspective-taking task (6/9) with different embodiments.
% Requires Psychtoolbox-3.
%
% STIMULI: put images in ./stimuli/ named <embodiment>_<digit>.png, e.g.
%   robot_humanoid_6.png robot_humanoid_9.png
%   robot_nonhumanoid_6.png robot_nonhumanoid_9.png
% The digit in the filename = the digit AS SEEN BY THE PARTICIPANT.
%   Perspective "You"   -> correct answer = flipped digit (6<->9)
%   Perspective "Other" -> correct answer = displayed digit
%
% KEYS: response  f = 6 , j = 9  (stick labels "6" and "9" on them)
%       catch     f = humanoid , j = non-humanoid
%       ESC aborts.

%% ---------------- PARAMETERS ----------------
scriptDir      = fileparts(mfilename('fullpath'));
stimuliDir     = fullfile(scriptDir, 'stimuli');
P.stimDir      = scriptDir;
if isfolder(stimuliDir)
    P.stimDir = stimuliDir;
end
P.fixDur       = 0.750;
P.cueDur       = 0.750;
P.blankDur     = 0.750;
P.maxRT        = 3.0;    % time-out
P.isi          = 0.500;
P.catchTimeout = 3.0;
P.confTimeout  = 3.0;
P.nCatch       = 5;
P.nRepPerPersp = 5;      % 5 "You" + 5 "Other" per embodiment
P.removeOnResp = true;   % stimulus disappears at response
P.trainFeedback= true;   % feedback in training only

P.embodiments = {'robot_humanoid','robot_nonhumanoid'};
P.category    = {'humanoid','nonhumanoid'};
P.trainFaces  = P.embodiments;

P.keyResp  = {'f','j'};         % -> digits 6, 9
P.respDig  = [6 9];
P.keyCatch = {'f','j'};         % -> humanoid, non-humanoid
P.catchCat = {'humanoid','nonhumanoid'};
P.keyConf  = {'1','2','3','4','5','6','7','8','9','0'};
P.confVal  = [1:9 10];

P.txt.training = ['TRAINING\n\nA fixation cross will appear, then the word "You" or "Other".\n' ...
    '"You": report the number as YOU see it.\n"Other": report the number as the OTHER (the character) sees it.\n\n' ...
    'Press F for 6, J for 9, as fast as you can while staying accurate.\n' ...
    'After each answer, rate your confidence from 1 (not confident) to 10 (very confident).\n\n' ...
    'Press SPACE to start the training.'];
P.txt.main = ['MAIN EXPERIMENT\n\nSame task. Look carefully at the character each time:\n' ...
    'sometimes you will be asked whether it was a humanoid or non-humanoid robot\n(F = humanoid, J = non-humanoid).\n\n' ...
    'After each answer, rate your confidence from 1 (not confident) to 10 (very confident).\n\n' ...
    'Press SPACE to start.'];
P.txt.end  = 'Thank you, the experiment is over!';

%% ---------------- SUBJECT INFO ----------------
subj = input('Participant ID: ', 's');
if ~exist('data','dir'), mkdir('data'); end
timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmm'));
outFile = fullfile('data', sprintf('sub-%s_%s.csv', subj, timestamp));
rng('shuffle');

%% ---------------- BUILD TRIAL LISTS ----------------
trainTrials = buildTraining(P);
mainTrials  = buildMain(P);

% catch trials: 5 random main trials followed by a catch question
catchIdx = sort(randperm(numel(mainTrials), P.nCatch));
for i = 1:numel(mainTrials), mainTrials(i).catch = ismember(i, catchIdx); end

%% ---------------- PTB SETUP ----------------
KbName('UnifyKeyNames');
Screen('Preference','SkipSyncTests',1);
escKey = KbName('ESCAPE'); spaceKey = KbName('space');
results = [];
try
    ListenChar(2); HideCursor;
    screen = max(Screen('Screens'));
    [win, rect] = Screen('OpenWindow', screen, [0 0 0]);
    Screen('TextFont', win, 'Arial'); Screen('TextSize', win, 36);
    Priority(MaxPriority(win));
    [xc, yc] = RectCenter(rect);

    % preload textures
    names = [P.embodiments, P.trainFaces];
    tex = struct();
    for n = 1:numel(names)
        for d = [6 9]
            f = dir(fullfile(P.stimDir, sprintf('%s_%d.*', names{n}, d)));
            assert(~isempty(f), 'Missing image: %s_%d.*', names{n}, d);
            img = imread(fullfile(P.stimDir, f(1).name));
            tex.(sprintf('%s_%d', names{n}, d)) = Screen('MakeTexture', win, img);
        end
    end

    ctx = struct('win',win,'xc',xc,'yc',yc,'rect',rect,'tex',tex,'esc',escKey);

    % ---- TRAINING ----
    showText(ctx, P.txt.training, spaceKey);
    for i = 1:numel(trainTrials)
        r = runTrial(ctx, P, trainTrials(i), true);
        results = [results; packResult(subj, 'training', i, trainTrials(i), r)]; %#ok<AGROW>
    end

    % ---- MAIN ----
    showText(ctx, P.txt.main, spaceKey);
    for i = 1:numel(mainTrials)
        r = runTrial(ctx, P, mainTrials(i), false);
        if mainTrials(i).catch
            c = runCatch(ctx, P, mainTrials(i));
            r.catchResp = c.resp; r.catchCorrect = c.correct;
            r.catchRT = c.rt; r.catchConfidence = c.confidence;
        end
        results = [results; packResult(subj, 'main', i, mainTrials(i), r)]; %#ok<AGROW>
        % inter-stimulus interval
        Screen('Flip', win); WaitSecs(P.isi);
    end

    showText(ctx, P.txt.end, [], 2);
    cleanup();
catch ME
    cleanup();
    if ~isempty(results), writetable(struct2table(results), outFile); end
    rethrow(ME);
end
writetable(struct2table(results), outFile);
fprintf('Data saved to %s\n', outFile);
end

%% =====================================================================
function trials = buildTraining(P)
% 2 robot types x 4 repetitions = 8 trials (2 You + 2 Other per type)
trials = struct('emb',{},'cat',{},'persp',{},'digit',{},'catch',{});
for f = 1:numel(P.trainFaces)
    persp = [repmat({'You'},1,2), repmat({'Other'},1,2)];
    digit = [6 9 6 9];
    for k = 1:4
        trials(end+1) = struct('emb',P.trainFaces{f},'cat',P.category{f}, ...
            'persp',persp{k},'digit',digit(k),'catch',false); %#ok<AGROW>
    end
end
trials = trials(randperm(numel(trials)));
end

function trials = buildMain(P)
% 2 embodiments x (5 You + 5 Other) = 20 trials.
% Digit counterbalanced within embodiment: 5 sixes / 5 nines across the 10 trials
trials = struct('emb',{},'cat',{},'persp',{},'digit',{},'catch',{});
for e = 1:numel(P.embodiments)
    if rand < .5, dYou = [6 6 6 9 9]; dOth = [6 6 9 9 9];
    else,         dYou = [6 6 9 9 9]; dOth = [6 6 6 9 9]; end
    for k = 1:P.nRepPerPersp
        trials(end+1) = struct('emb',P.embodiments{e},'cat',P.category{e}, ...
            'persp','You','digit',dYou(k),'catch',false); %#ok<AGROW>
        trials(end+1) = struct('emb',P.embodiments{e},'cat',P.category{e}, ...
            'persp','Other','digit',dOth(k),'catch',false); %#ok<AGROW>
    end
end
trials = trials(randperm(numel(trials)));
end

%% =====================================================================
function r = runTrial(ctx, P, tr, isTraining)
win = ctx.win;
r = struct('resp',NaN,'rt',NaN,'correct',NaN,'timeout',false, ...
           'confidence',NaN, ...
           'catchResp','','catchCorrect',NaN,'catchRT',NaN, ...
           'catchConfidence',NaN);

if strcmp(tr.persp,'You')
    correctDigit = 15 - tr.digit;
else
    correctDigit = tr.digit;
end

KbReleaseWait;

% 1. fixation (750 ms)
DrawFormattedText(win,'+','center','center',[255 255 255]);
Screen('Flip', win); WaitSecs(P.fixDur);

% 2. cue "You"/"Other" (750 ms)
DrawFormattedText(win, tr.persp, 'center','center',[255 255 255]);
Screen('Flip', win); WaitSecs(P.cueDur);

% 3. blank (750 ms)
Screen('Flip', win); WaitSecs(P.blankDur);

% 4. stimulus, response window = 3 s
t = ctx.tex.(sprintf('%s_%d', tr.emb, tr.digit));
Screen('DrawTexture', win, t);
t0 = Screen('Flip', win);
while GetSecs - t0 < P.maxRT
    [down, secs, kc] = KbCheck;
    if down
        if kc(ctx.esc), error('Aborted by experimenter.'); end
        for k = 1:2
            if kc(KbName(P.keyResp{k}))
                r.resp = P.respDig(k); r.rt = secs - t0;
                r.correct = double(r.resp == correctDigit);
                break;
            end
        end
        if ~isnan(r.resp), break; end
    end
end
if isnan(r.resp), r.timeout = true; r.correct = 0; end
if ~isnan(r.resp)
    r.confidence = getConfidence(ctx, P);
end

% remove stimulus (or keep it until 3 s elapsed)
if P.removeOnResp
    Screen('Flip', win);
else
    WaitSecs(max(0, P.maxRT - (GetSecs - t0))); Screen('Flip', win);
end

% training feedback
if isTraining && P.trainFeedback
    if r.timeout
        msg = 'Too slow!';
    elseif r.correct
        msg = 'Correct';
    else
        msg = 'Incorrect';
    end
    DrawFormattedText(win, msg, 'center','center',[255 255 255]);
    Screen('Flip', win); WaitSecs(1);
    Screen('Flip', win); WaitSecs(P.isi);
end
r.correctDigit = correctDigit;
end

%% =====================================================================
function c = runCatch(ctx, P, tr)
win = ctx.win;
c = struct('resp','','correct',NaN,'rt',NaN,'confidence',NaN);
KbReleaseWait;
DrawFormattedText(win, 'What appeared on the screen?', 'center', ctx.yc-60, [255 255 255]);
DrawFormattedText(win, 'humanoid (F)      non-humanoid (J)', 'center', ctx.yc+40, [255 255 255]);
t0 = Screen('Flip', win);
while GetSecs - t0 < P.catchTimeout
    [down, secs, kc] = KbCheck;
    if down
        if kc(ctx.esc), error('Aborted by experimenter.'); end
        for k = 1:numel(P.keyCatch)
            if kc(KbName(P.keyCatch{k}))
                c.resp = P.catchCat{k}; c.rt = secs - t0;
                c.correct = double(strcmp(c.resp, tr.cat));
                break;
            end
        end
        if ~isempty(c.resp), break; end
    end
end
if isempty(c.resp), c.resp = 'timeout'; c.correct = 0; end
if ~strcmp(c.resp, 'timeout')
    c.confidence = getConfidence(ctx, P);
end
Screen('Flip', win);
end

function confidence = getConfidence(ctx, P)
confidence = NaN;
KbReleaseWait;
ShowCursor;

win = ctx.win;
oldTextSize = Screen('TextSize', win);
n = numel(P.confVal);
gap = 12;
boxW = 70;
boxH = 70;
totalW = n * boxW + (n - 1) * gap;
x0 = ctx.xc - totalW / 2;
y0 = ctx.yc - boxH / 2;
boxes = zeros(n, 4);
for k = 1:n
    boxes(k,:) = [x0 + (k-1)*(boxW+gap), y0, x0 + (k-1)*(boxW+gap) + boxW, y0 + boxH];
end

Screen('TextSize', win, 36);
DrawFormattedText(win, 'How confident are you?', 'center', y0-100, [255 255 255]);
DrawFormattedText(win, '1 = not confident', x0, y0+boxH+45, [255 255 255]);
DrawFormattedText(win, '10 = very confident', x0+totalW-220, y0+boxH+45, [255 255 255]);
for k = 1:n
    Screen('FrameRect', win, [255 255 255], boxes(k,:), 3);
    DrawFormattedText(win, num2str(P.confVal(k)), 'center', 'center', [255 255 255], [], [], [], [], [], boxes(k,:));
end
t0 = Screen('Flip', win);
while GetSecs - t0 < P.confTimeout
    [down, ~, kc] = KbCheck;
    if down && kc(ctx.esc), error('Aborted by experimenter.'); end

    [mx, my, buttons] = GetMouse(win);
    for k = 1:n
        hovered = mx >= boxes(k,1) && mx <= boxes(k,3) && my >= boxes(k,2) && my <= boxes(k,4);
        if hovered && any(buttons)
            confidence = P.confVal(k);
            break;
        end
    end
    if ~isnan(confidence), break; end
    WaitSecs(0.01);
end
KbReleaseWait;

while true
    [~, ~, buttons] = GetMouse(win);
    if ~any(buttons), break; end
    WaitSecs(0.01);
end

Screen('TextSize', win, oldTextSize);
Screen('Flip', win);
HideCursor;
end

%% =====================================================================
function showText(ctx, txt, key, dur)
DrawFormattedText(ctx.win, txt, 'center','center',[255 255 255], 70, [], [], 1.4);
Screen('Flip', ctx.win);
if nargin >= 4 && ~isempty(dur), WaitSecs(dur); return; end
KbReleaseWait;
while true
    [down, ~, kc] = KbCheck;
    if down && kc(ctx.esc), error('Aborted by experimenter.'); end
    if down && kc(key), break; end
end
KbReleaseWait;
end

function s = packResult(subj, block, idx, tr, r)
s = struct('subject',subj,'block',block,'trial',idx,'embodiment',tr.emb, ...
    'category',tr.cat,'perspective',tr.persp,'shownDigit',tr.digit, ...
    'correctDigit',r.correctDigit,'response',r.resp,'rt',r.rt, ...
    'correct',r.correct,'timeout',r.timeout,'confidence',r.confidence, ...
    'isCatch',tr.catch,'catchResp',{r.catchResp}, ...
    'catchCorrect',r.catchCorrect,'catchRT',r.catchRT, ...
    'catchConfidence',r.catchConfidence);
end

function cleanup()
Priority(0); ListenChar(0); ShowCursor; sca;
end
