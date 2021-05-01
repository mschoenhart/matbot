%% MatLab Bet Bot

%% preprocessor
PROCESSTICKETSMIN=30;

switch (1)
    case 1
%matbot development
DEVELOPMENTFLAG =1;
WRITETICKETSFLAG=1;
EXECUTEPLACEBETS=0;
SENDMAILMINS    =0;
USERNUM         =1;
STRATEGIESTABNUM=1;
LOGFILENAME  ='matbot';
DATAFILENAME ='mbdata';
SCALGFILENAME='mscale';
    case 2
%matbot production
DEVELOPMENTFLAG =0;
WRITETICKETSFLAG=1;
EXECUTEPLACEBETS=1;
SENDMAILMINS    =12*60;
USERNUM         =1;
STRATEGIESTABNUM=1;
LOGFILENAME  ='mbot';
DATAFILENAME ='mbdata';
SCALGFILENAME='mscale';
end

%% logfile & datafile
timestamp=datestr(now,initvalues.timestamplogfile);
if DEVELOPMENTFLAG,
    workpath=initvalues.workpathdev;
    logfilepath=initvalues.logfilepathdev;
else
    workpath=initvalues.workpathprod; 
    logfilepath=initvalues.logfilepathprod;
end
logfile=fullfile(logfilepath,[LOGFILENAME,timestamp,'.log']);
datafile=fullfile(workpath,[DATAFILENAME,timestamp,'.mat']);
scalingfile=fullfile(workpath,[SCALGFILENAME,'.mat']);
cd(workpath);
diary(logfile);

%% mail setup
if SENDMAILMINS,
    subtxt=LOGFILENAME;
    if DEVELOPMENTFLAG,
        [mailaddress,mailpwd]=betmat.decrypt(initvalues.mailusertab,USERNUM);
        setupgmail(mailaddress,mailpwd);
    else
        mailaddress=betmat.decrypt(initvalues.mailusertab,USERNUM);
        pwd=getpassword;
        if strcmp(pwd,''),
            SENDMAILMINS=0;
        else
            setupgmail(mailaddress,pwd);
            sendmail(mailaddress,subtxt,'Happy boting!');
        end
    end
end

%% api
if DEVELOPMENTFLAG,
    [user,pwd]=betmat.decrypt(initvalues.usertab,USERNUM);
else
    user=betmat.decrypt(initvalues.usertab,USERNUM);
    pwd=getpassword;
end
betfairobj=betfair(user,pwd);

%% real time scheduler
rtobj=rtcontrol(betfairobj,datafile,scalingfile,STRATEGIESTABNUM);

%% environment
% keyboard virtual keys
VK_MENU=hex2dec('12'); % Alt Key
VK_LSHIFT=hex2dec('A0'); % Left Shift
VK_LCONTROL=hex2dec('A2'); % Left Control
% console
format('compact');

%% rt object data
rtobj.loadscaling; % load scaling data
rtobj.staticread;  % read new static data

%% account funds
accountstart=betfairobj.getaccountfunds;
if WRITETICKETSFLAG,
    rtobj.processtickets; % scale strategies
end

%% infinite loop - until user break (CTRL-C) or keystates
disptext=[];
loopcounter=1;
t1=tic; % time the loop
while ~(keystate(VK_LCONTROL) && keystate(VK_LSHIFT) && keystate(VK_MENU)), % keys currently pressed
    
    % measure looptime
    t2=tic;
    % save execution
    try
        % check api environment and try to reconnect if necessary
        if ~betfairobj.keepaliveandrelog(user,pwd),
            %disptext=[sprintf('API not available!\n'),disptext]; %#ok<AGROW>
            fprintf('API not accessible!\n');
        else
            % update ticket pnl and scaling before display
            if WRITETICKETSFLAG && (mod(loopcounter,PROCESSTICKETSMIN)==0), % empty scheduler or scheduled cycle reached
                rtobj.processtickets; % get pnl for tickets and scale strategies
            end
            % read and schedule static market data on lower refresh cycle
            if rtobj.getstaticread,  % empty scheduler or scheduled cycle reached
                rtobj.checkdata;     % check internal data integrity
                rtobj.staticread;    % read new static data
                rtobj.save(true);    % save checked static and dynamic data
            end
            % display status
            disptext=rtobj.dispaccount(toc(t1),accountstart);
            disp(disptext);rtobj.disp(false);%fprintf('\n');
            if ~rtobj.getstaticempty,
                % execute tickets
                if WRITETICKETSFLAG,
                    rtobj.dynamicwrite(EXECUTEPLACEBETS);
                end
                % read and write dynamic market data
                rtobj.dynamicread;
            end
        end
        % send email every x minutes
        if mod(loopcounter,SENDMAILMINS)==0,
            t3=tic;
            fprintf('Sending mail...');
            sendmail(mailaddress,[subtxt,'#',num2str(loopcounter)],disptext);
            fprintf('%.2fs\n',toc(t3));
        end
    catch exception
        % throw error as warning
        warning(exception.identifier,['iBot:ErrorHandler:',exception.identifier,':',exception.message,'!']);
        %error(exception.identifier,[exception.identifier,':',exception.message,'!']);
        % try to save
        try
            %rtobj.checkdata; % check internal data integrity
            rtobj.save; % save cleaned static and dynamic data
        catch exception2
            % throw error as warning
            warning(exception2.identifier,['iBot:ErrorHandler:Save:',exception2.identifier,':',exception2.message,'!']);
        end
    end

    % delay
    t2=toc(t2);
    pausetime=max(0,initvalues.delaytime-t2); % should not be negative
    fprintf('Loop %5.2fs/%5.2fs...\n',t2,pausetime);
    pause(pausetime);
    
    % counter & clear display
    loopcounter=loopcounter+1;
	clc;
end

%% save environment & quit
rtobj.checkdata;  % check internal data integrity
rtobj.save;       % save cleaned static and dynamic data
fprintf('ok!\n');
%if SENDMAILMINS,
%    sendmail(mailaddress,subtxt,'Happy ending!');
%end
diary off;
if ~DEVELOPMENTFLAG,
    clear classes;   % destroy objs and logout
    quit;
end
