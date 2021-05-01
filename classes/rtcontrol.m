%% Class RealTimeControl
% Controls TradingStrategies and APIs

classdef (~Sealed) rtcontrol < hgsetget % reference class

%% properties    
properties (Constant, GetAccess=public) % Constants

    %disp
    dispmaxlines=10;
    
    %save
    timestampfile    ='yyyy-mm-ddTHH-MM';
    savedatathreshold=250;
    
    %execution
    executionmaxspread       =0.05;
	executionminquotelimit   =0.05;
    mainminamountmatched     =5000; % GBP
    minamountmatched         =500;  % EUR
    %marketminselectionamountmatched=100; % EUR
    minbetsize               =2;    % EUR
    maxbetsizediff           =0.1;  % EUR
    maxplacebetsize          =20;   % EUR sanity check
    
    %static
    staticreadcycle=datenum(0,0,0,1,0,0);  % read new static markets every 60 minutes eq. 1/24
    staticstartread=datenum(0,0,0,-4,0,0); % read new static markets from t-x hours, be<=dynamicstartread
    staticendread  =datenum(0,0,1);        % read new static markets up to x-days ahead
    
    %dynamic
    dynamicstartread  =datenum(0,0,0,-3,0,0); % start reading markets x hours before starttime
    dynamicendread    =inf; % datenum(0,0,0, 6,0,0); % read markets until closed or x hours after starttime

    % production strats
    NANOK              =0;
    NANBACKQUOTES      =1;
    NANBACKLAYQUOTES   =2;
    STRATFUNQUOTES     =1;
    STRATFUNTICKETS    =2;
    STRATFUNQUOTESNAMES=3;
    
    strategiestab={
    {
    %'SoMo_Lq<1.3',  'Soccer','Match Odds',                 datenum(0,0,0,0,-15,0),datenum(0,0,0,3,0,0),   2,rtcontrol.NANBACKLAYQUOTES,rtcontrol.STRATFUNQUOTES,@rtcontrol.layqle13;
    ...
    %virtual
    %'vSoMo_Trend',   'Soccer','Match Odds',                datenum(0,0,0,0,-15,0),datenum(0,0,0,3, 0,0), 2,rtcontrol.NANBACKQUOTES,   rtcontrol.STRATFUNQUOTES, @rtcontrol.somotrend;
    %'vSoMo_Trend',   'Soccer','Match Odds',                datenum(0,0,0,0,-15,0),datenum(0,0,0,3, 0,0), 1,rtcontrol.NANBACKLAYQUOTES,rtcontrol.STRATFUNTICKETS,@rtcontrol.vcashout;
    ...
    %traded and virtual
    ...
    %traded cashout
    ...
    %traded
    },...
    {
    }
    };

    %event/static filter handle/minamount/main market/markets to read
    emreadtab={
           {'Soccer',[],rtcontrol.mainminamountmatched,{'Match Odds'}, ...
                     {'Match Odds','Correct Score','Over/Under 2.5 goals','Total Goals',...
                      'Half Time','Half Time Score','Next Goal',...  % live markets
                      'Half Time/Full Time','First Goal Odds'}; ...  % non-live
            'Horse Racing',@rtcontrol.staticfilter_horseracing,rtcontrol.minamountmatched,{'Win Only'},...
                           {'Win Only','To Be Placed'};              % live markets
            'Tennis',[],rtcontrol.minamountmatched,{'Match Odds'},{'Match Odds'};            % live markets
            'Basketball',[],rtcontrol.minamountmatched,{'Match Odds'},{'Match Odds'};        % live markets
            'Snooker',[],rtcontrol.minamountmatched,{'Match Odds'},{'Match Odds'};           % live markets
            'Ice Hockey',[],rtcontrol.minamountmatched,{'Regular Time Match Odds'},{'Regular Time Match Odds'}; % live markets
            'American Football',[],rtcontrol.minamountmatched,{'Match Odds'},{'Match Odds'}; % live markets
            'Australian Rules',[],rtcontrol.minamountmatched,{'Match Odds'},{'Match Odds'};  % live markets
           }%,...
           %{'Soccer',[],rtcontrol.mainminamountmatched,{'Match Odds'}, ...
           %          {'Match Odds','Correct Score','Half Time Score',... % live markets
           %           'Half Time/Full Time'};  % non-live
           %};
    };
    emsuspendedread={'Half Time/Full Time','First Goal Odds','Win Only','To Be Placed'}; % non-live markets f. suspended end
    
end
properties (Constant, Hidden)
       
    % display
    scheduleheader={'MarketID','StartTime','StartReading','EventType','MarketType','MarketName'};
    ticketheader  ={'MarketID','SelectionID','StartReading','EndReading','Size','BetType','Runner'};

    % emread data structure
    EMREVENT     =1;
    EMRFUNCHANDLE=2;
    EMRMINAMOUNT =3;
    EMRMAINMARKET=4;
    EMRMARKETS   =5;
    
    % scaling data structure
    SCSTRATNAME    =1;
    SCBETSIZE      =2;
    SCTOTALSIZE    =3;
    SCTOTALPNLPOS  =4;
    SCTOTALPNLNEG  =5;
    SCTRADESPOS    =6;
    SCTRADESNEG    =7;
    SCTOTALPRICEPOS=8; % for avg price calcs
    SCTOTALPRICENEG=9; % for avg price calcs
    
    % static data structure
    MARKETID     =1; % 1-6 static db structure
    STARTTIME    =2;
    EVENTTYPE    =3;
    MARKETTYPE   =4;
    MARKETNAME   =5;
    ORDERIDX     =6;
    STARTREAD    =7;  % 7-13 fields for internal use
    ENDREAD      =8;  % time
    READSTATE    =9;  % false ... end reading if event is closed
    READPREFER   =10; % prefer market if exceeded throttle last time
    WRITESTATE   =11; % true ... ticket will be written
    ORDERIDXFLAG =12; % order of runnernames
    RUNNERNAMES  =13; % q-ordered runnernames
    TIMESTAMP    =14; % creation timestamp
    
    % dynamic data structure
    DMARKETID    =1; % all to database
    DAPITIME     =2;
    DIPDELAY     =3;
    DQUOTES      =4;
    DAMATCHED    =5;
    DLPMATCHED   =6;
    DSPPRICE     =7;
    
    % ticket data structure
    TBETID       =1; % all to database
    TMARKETID    =2; 
    TSELECTIONID =3;
    TRUNNERNAME  =4;
    TBETTYPE     =5;
    TBETSIZE     =6;
    TBETPRICE    =7;
    TSTRATNAME   =8;
    TBETPNL      =9;
    TTIMESTAMP   =10;
    TTYPEVIRTUAL ='virtual';
    
    % strategy data structure
    SNAME      =1;
    SEVENTTYPE =2;
    SMARKETTYPE=3;
    SSTARTREAD =4;
    SENDREAD   =5;
    SBETSIZE   =6;
    SOVERROUND =7;
    SNANCHECK  =8;
    SFUNCARGS  =9;
    SNAMECHKFUNCHANDLE=10;
    SFUNCHANDLE=11;

end 
properties (SetAccess=public, GetAccess=public, ~Hidden)
       
    apiobj            % API for data transfer
    datafilename      % filename to save market data
    scalingfilename   % filename to save scaling data
    stratscaling      % strategy scaling
    strategies        % strategy definitions
    emread            % events/markets to read
    disptextticketpnl % text for ticket pnl, s. processtickets
    
    staticdata     % market data
    dynamicdata
    ticketdata     % ticket Data
    pnlstart       % pnl delta calc
    
    eventidsread
    staticreadnext % next time for static read
    
    accountmin % for dispaccount
    accountmax
    
    ttttime % stats execution
    tttnum
    bestqok
    bestqerror
    bestqfunds
    bestqnum
    slippage
    slipnum
end 

%% methods
methods

%% Constructor/Destructor
function obj=rtcontrol(apiobj,datafilename,scalingfilename,strategiestabnum)
%RTCONTROL Constructor.
 
% input parameter handling
if nargin>0,
    
    maxarg=4;
    narginchk(maxarg,maxarg);
    
    % init internal data structure
    obj.datafilename=datafilename;
    obj.apiobj=apiobj;
    obj.scalingfilename=scalingfilename;
    obj.strategies=obj.strategiestab{strategiestabnum};
    obj.emread=obj.emreadtab{1};%strategiestabnum};
    obj.accountmin=ones(1,3).*inf;
    obj.accountmax=ones(1,3).*-inf;
    obj.ttttime=zeros(1,3);
    obj.tttnum=zeros(1,3);
    obj.bestqok=0;
    obj.bestqerror=0;
    obj.bestqfunds=0;
    obj.bestqnum=0;
    obj.slippage=zeros(1,2);
    obj.slipnum=zeros(1,2);
    
    % strategy data and scaling
    stratnames=unique(obj.strategies(:,obj.SNAME));
    idx=cellfun(@(x) find(strcmp(obj.strategies,x),1,'first'),stratnames); %first row contains size
    obj.stratscaling=[stratnames,obj.strategies(idx,obj.SBETSIZE),repmat({0},numel(idx),7)];
    % pnl delta calc
    obj.pnlstart=zeros(size(obj.stratscaling,1),1);
    % disp text init
    obj.disptextticketpnl=[];
    % get eventid from event list
    alleventtypes=obj.apiobj.getalleventtypes; % use all instead of active events, they can get active later in time
    n=size(obj.emread,1);
    obj.eventidsread=NaN(n,1);
    for i=1:n,
        [idx,eventnames]=obj.apiobj.geteventid(alleventtypes,obj.emread(i,obj.EMREVENT)); % find id
        obj.eventidsread(i)=idx(1); % first appearance
        fprintf('%s\n',eventnames{1});
    end
    if any(isnan(obj.eventidsread)),
        error('RTCONTROL:CONSTRUCTOR','RTCONTROL:CONSTRUCTOR:EventId not found!');
    end
end

end % constructor
%function delete(obj)       % destructor                                     
%RTCONTROL Destructor.
%end

%% general
function disp(obj,noshow) % display function
%DISP Display formatted object contents.
     
    % display
    t=obj.apiobj.getapitime;
    if isempty(t), % did not get proper time from api
        fprintf('RTCONTROL:DISP:Empty t!\n');
        return;
    end
    fprintf('Local DateTime: %s\n',datestr(now));
    fprintf('API   DateTime: %s\n',datestr(t));
    if ~isempty(obj.staticreadnext),
        fprintf('Next static read in %s\n',datestr(obj.staticreadnext-t,'HH:MM'));
    end
    if nargin>1 && ~noshow,
        return;
    end
    if isempty(obj.staticdata),
        fprintf('No static data available!\n');
    else
        % show only events that are currently to read
        idx=find(cat(1,obj.staticdata{:,obj.READSTATE}) & ...      % readstate is true
                 (t>=cat(1,obj.staticdata{:,obj.STARTREAD})) & ... % time >= startread
                 (t<=cat(1,obj.staticdata{:,obj.ENDREAD})));       % time <= endread
        if ~isempty(idx),
            %schedule header
            fprintf('%-10s %-15s %-15s %-10s %-20s %-s\n',obj.scheduleheader{:});
            %data
            for j=1:min(obj.dispmaxlines,numel(idx)),
                fprintf('%-10s %-15s %-15s %-10s %-20s %-s\n', ...
                        obj.staticdata{idx(j),obj.MARKETID}, ...
                        datestrfinite(obj.staticdata{idx(j),obj.STARTTIME}), ...
                        datestrfinite(obj.staticdata{idx(j),obj.STARTREAD}), ...
                        ...%datestrfinite(obj.staticdata{idx(j),obj.ENDREAD}), ...
                        obj.staticdata{idx(j),obj.EVENTTYPE}, ...
                        obj.staticdata{idx(j),obj.MARKETTYPE}, ...
                        obj.staticdata{idx(j),obj.MARKETNAME} ...
                       );
            end
            fprintf('%d market(s) to read\n',numel(idx));
        end
    end
    
    %nested function
    function s=datestrfinite(x)
        if isfinite(x) && x,
            s=datestr(x,'dd-mm-yy HH:MM');
        else
            s='-';
        end
    end
end
function load(obj,filename)
%LOAD Load static and dynamic market data, if file exists.

    narginchk(1,2);
    if nargin<2,
        filename=obj.datafilename;
    end
    if exist(filename,'file'),
        s=load(filename);
        obj.staticdata=s.staticdata;
        obj.dynamicdata=s.dynamicdata;
        obj.ticketdata=s.ticketdata;
    else
        fprintf('RTCONTROL:LOAD:File not found!\n');
    end
end
function loadscaling(obj,filename)
%LOAD Load strategy scaling data.

    narginchk(1,2);
    if nargin<2,
        filename=obj.scalingfilename;
    end
    if exist(filename,'file'),
        s=load(filename);
        % set scaling to loaded values or add new row
        for i=1:size(s.stratscaling,1),
            idx=strcmp(obj.stratscaling(:,obj.SCSTRATNAME),s.stratscaling(i,obj.SCSTRATNAME));
            if ~any(idx),
                obj.stratscaling=[obj.stratscaling;s.stratscaling(i,:)]; % new row
            else
            %    betsize=s.stratscaling{i,obj.SCBETSIZE}(1);
            %    betparams=obj.stratscaling{idx,obj.SCBETSIZE};
            %    if (numel(betparams)==1) ||...
            %       ( (betsize>=betparams(2)) && (betsize<=betparams(3)) ), % check for min,max
            %        obj.stratscaling{idx,obj.SCBETSIZE}(1)=betsize;
            %    else
            %        fprintf('Saved betsize out of range!\n');
            %    end
                obj.stratscaling(idx,3:end)=s.stratscaling(i,3:end); % rest of data
            end
        end    
        %calc pnl delta
        obj.pnlstart=sum(cell2mat(obj.stratscaling(:,[obj.SCTOTALPNLPOS,obj.SCTOTALPNLNEG])),2);
    end
end
function save(obj,outdatedflag)
%SAVE Save static and dynamic data.
% Check integrity before save.

    narginchk(1,2);
    if nargin<2,
        outdatedflag=false;
    end
    staticdata=obj.staticdata;     %#ok<PROP,NASGU>
    dynamicdata=obj.dynamicdata;   %#ok<PROP,NASGU>
    ticketdata=obj.ticketdata;     %#ok<PROP,NASGU>
    stratscaling=obj.stratscaling; %#ok<PROP,NASGU>
    
    % datafile
    if exist(obj.datafilename,'file'),
        copyfile(obj.datafilename,[obj.datafilename,'_backup']);
    end
    save(obj.datafilename,'staticdata','dynamicdata','ticketdata');
    
    % scalingfile
    if exist(obj.scalingfilename,'file'),
        copyfile(obj.scalingfilename,[obj.scalingfilename,'_backup']);
    end
    save(obj.scalingfilename,'stratscaling');
    
    % save already closed markets,ticks,tickets and delete from memory
    if outdatedflag && ~isempty(obj.staticdata),
        % find closed static markets - readstate==false
        idx=~cat(1,obj.staticdata{:,obj.READSTATE});
        if sum(idx)>obj.savedatathreshold,
            staticdata=obj.staticdata(idx,obj.MARKETID:obj.ORDERIDX); %#ok<PROP,NASGU>
            % check for joins in dynamic data
            if ~isempty(obj.dynamicdata),
                dynamicjoinidx=ismember(obj.dynamicdata(:,obj.DMARKETID),obj.staticdata(idx,obj.MARKETID));
                if any(dynamicjoinidx),
                    dynamicdata=obj.dynamicdata(dynamicjoinidx,obj.DMARKETID:obj.DSPPRICE); %#ok<PROP,NASGU>
                end
            else
                dynamicjoinidx=[];
            end
            % check for settled tickets
            if ~isempty(obj.ticketdata),
                ticketjoinidx=~isnan(cat(1,obj.ticketdata{:,obj.TBETPNL}));
                if any(ticketjoinidx),
                    ticketdata=obj.ticketdata(ticketjoinidx,obj.TBETID:obj.TTIMESTAMP); %#ok<PROP,NASGU>
                end
            else
                ticketjoinidx=[];
            end    
            % save outdated data to different file
            timestamp=datestr(now,obj.timestampfile);
            save([obj.datafilename,'_',timestamp,'.mat'],'staticdata','dynamicdata','ticketdata');

            % delete outdated data, only if saved
            obj.staticdata=obj.staticdata(~idx,:);
            obj.dynamicdata=obj.dynamicdata(~dynamicjoinidx,:);
            obj.ticketdata=obj.ticketdata(~ticketjoinidx,:);
        end
    end
end
function checkdata(obj)
%CHECK internal DATA integrity.

    % check static and 1:n join dynamic market data
    if ~isempty(obj.staticdata),
        % check uniqueness of marketid
        if size(obj.staticdata,1)~=numel(unique(obj.staticdata(:,obj.MARKETID))),
            fprintf('RTCONTROL:STATICCHECK:MarketId not unique!\n');
        end
        if ~isempty(obj.dynamicdata),
            % find closed static markets w/o joins to dynamic data
            idx=find(~cat(1,obj.staticdata{:,obj.READSTATE}));
            if ~isempty(idx),
                % check for join in dynamic data
                joinidx=~ismember(obj.staticdata(idx,obj.MARKETID),obj.dynamicdata(:,obj.DMARKETID));
                if any(joinidx),
                    %delete outdated static data w/o joins in dynamic data
                    obj.staticdata(idx(joinidx),:)=[];
                    fprintf('RTCONTROL:STATICCHECK:%d outdated unjoined static market(s) deleted.\n',sum(joinidx));
                end
            end
            % check dynamic data and 1:n join to static market data
            joinidx=~ismember(obj.dynamicdata(:,obj.DMARKETID),obj.staticdata(:,obj.MARKETID));
            if any(joinidx),
                %delete dynamic data w/o joins in static data
                obj.dynamicdata(joinidx,:)=[];
                fprintf('RTCONTROL:DYNAMICCHECK:%d unjoined dynamic market(s) deleted!\n',sum(joinidx));
            end
        end
    end
end

%% tickets and pnl
function processtickets(obj)
    
    if ~isempty(obj.ticketdata),
        % loop thru tickets and update stratscaling
        idx=find(~strcmp(obj.ticketdata(:,obj.TBETID),'') & ~strcmp(obj.ticketdata(:,obj.TBETID),obj.TTYPEVIRTUAL) &... % not empty betid or virtual
                 isnan(cat(1,obj.ticketdata{:,obj.TBETPNL}))); % empty pnl
        for i=1:numel(idx),
            idxi=idx(i); %speed up indexing
            betresults=obj.apiobj.getbet(obj.ticketdata{idxi,obj.TBETID});
            if ~isempty(betresults),
                if ~isstruct(betresults),
                    fprintf('RTCONTROL:PROCESSTICKETS:%s!\n',betresults);
					if ischar(betresults) && strcmp(betresults,'BET_ID_INVALID'),
                        disp(obj.ticketdata{idxi,obj.TBETID});
                        %prevent ticket from being checked again
					    obj.ticketdata{idxi,obj.TBETPNL}=0; % betbase ticket reader checks for NaNs and 0
					end
                elseif betresults.betStatus=='S', % process only settled bets
                    obj.ticketdata{idxi,obj.TBETPNL}=betresults.profitAndLoss;
                    % set per strategy data
                    stratidx=strcmp(obj.stratscaling(:,obj.SCSTRATNAME),obj.ticketdata(idxi,obj.TSTRATNAME));
                    if ~any(stratidx),
                        fprintf('RTCONTROL:PROCESSTICKETS:Strategy not found!\n');
                        continue; % next ticket
                    end
                    % set strategy scaling if params given
                    betparams=obj.stratscaling{stratidx,obj.SCBETSIZE};
                    if numel(betparams)>1,
                        if betresults.profitAndLoss>=0, % gains will increase size
                            obj.stratscaling{stratidx,obj.SCBETSIZE}(1)=min(betparams(1)+betparams(4),betparams(3));
                        else
                            obj.stratscaling{stratidx,obj.SCBETSIZE}(1)=max(betparams(1)+betparams(5),betparams(2));
                        end
                    end
                    obj.stratscaling{stratidx,obj.SCTOTALSIZE}=obj.stratscaling{stratidx,obj.SCTOTALSIZE}+obj.ticketdata{idxi,obj.TBETSIZE};
                    if betresults.profitAndLoss>=0,
                        obj.stratscaling{stratidx,obj.SCTOTALPNLPOS}=obj.stratscaling{stratidx,obj.SCTOTALPNLPOS}+betresults.profitAndLoss;
                        obj.stratscaling{stratidx,obj.SCTRADESPOS}=obj.stratscaling{stratidx,obj.SCTRADESPOS}+1;
                        obj.stratscaling{stratidx,obj.SCTOTALPRICEPOS}=obj.stratscaling{stratidx,obj.SCTOTALPRICEPOS}+obj.ticketdata{idxi,obj.TBETPRICE};
                    else
                        obj.stratscaling{stratidx,obj.SCTOTALPNLNEG}=obj.stratscaling{stratidx,obj.SCTOTALPNLNEG}+betresults.profitAndLoss;
                        obj.stratscaling{stratidx,obj.SCTRADESNEG}=obj.stratscaling{stratidx,obj.SCTRADESNEG}+1;
                        obj.stratscaling{stratidx,obj.SCTOTALPRICENEG}=obj.stratscaling{stratidx,obj.SCTOTALPRICENEG}+obj.ticketdata{idxi,obj.TBETPRICE};
                    end
                end
            end
        end
    end
    % calc new pnl and stats
    % traded tickets
    txt=[];
    %idx=find(cat(1,obj.stratscaling{:,obj.SCTOTALSIZE})>0);
    idx=find(cat(1,obj.stratscaling{1:numel(unique(obj.strategies(:,obj.SNAME))),obj.SCTOTALSIZE})>0);
    if ~isempty(idx),
        n=numel(idx);
        roi=NaN(n,1); % to sort for
        txttab=cell(n,1);
        for i=1:n,
            idxi=idx(i);
            totalpnl=obj.stratscaling{idxi,obj.SCTOTALPNLPOS}+obj.stratscaling{idxi,obj.SCTOTALPNLNEG};
            roi(i)=totalpnl./obj.stratscaling{idxi,obj.SCTOTALSIZE};
            totaltrades=obj.stratscaling{idxi,obj.SCTRADESPOS}+obj.stratscaling{idxi,obj.SCTRADESNEG};
            hitrate=obj.stratscaling{idxi,obj.SCTRADESPOS}./totaltrades;
            [bmean,bstd]=betmat.binomstat(totaltrades,totaltrades./(obj.stratscaling{idxi,obj.SCTOTALPRICEPOS}+obj.stratscaling{idxi,obj.SCTOTALPRICENEG})); % n,p=1/avg(q)=1/(q/t)=t/q
            %[bmeanpos,bstdpos]=betmat.binomstat(obj.stratscaling{idxi,obj.SCTRADESPOS},...
            %                                    obj.stratscaling{idxi,obj.SCTRADESPOS}./obj.stratscaling{idxi,obj.SCTOTALPRICEPOS}); % n,p=1/avg(q)=1/(q/t)=t/q
            %[bmeanneg,bstdneg]=betmat.binomstat(obj.stratscaling{idxi,obj.SCTRADESNEG},...
            %                                    obj.stratscaling{idxi,obj.SCTRADESNEG}./obj.stratscaling{idxi,obj.SCTOTALPRICENEG}); % n,p=1/avg(q)=1/(q/t)=t/q
            txttab(i)={sprintf('%-14s%6.1f%%%6.1f%5.1f%4d(%3d/%3d)%4.1f%6.1f%%%6.2f/%6.2f%6.1f±%3.1f\n',...
                               obj.stratscaling{idxi,obj.SCSTRATNAME}(1:min(end,14)),...
                               100.*roi(i),totalpnl,totalpnl-obj.pnlstart(idxi),... %100.*(totalpnl./accountstart) PnL%%
                               sum(cat(1,obj.stratscaling{idxi,[obj.SCTRADESPOS,obj.SCTRADESNEG]})),...
                               obj.stratscaling{idxi,obj.SCTRADESPOS},obj.stratscaling{idxi,obj.SCTRADESNEG},...
                               obj.stratscaling{idxi,obj.SCBETSIZE}(1),100.*hitrate,...
                               obj.stratscaling{idxi,obj.SCTOTALPNLPOS}./obj.stratscaling{idxi,obj.SCTRADESPOS}.*hitrate,...
                               obj.stratscaling{idxi,obj.SCTOTALPNLNEG}./obj.stratscaling{idxi,obj.SCTRADESNEG}.*(1-hitrate),...
                               bmean,bstd)};
        end
        [~,sidx]=sort(roi,'descend');
        sidx=sidx(~isnan(roi(sidx)));
        if ~isempty(sidx),
            pnltotal=sum(cat(1,obj.stratscaling{idx,[obj.SCTOTALPNLPOS,obj.SCTOTALPNLNEG]}));
            pnlstartsum=sum(obj.pnlstart(idx));
            betsize=sum(cat(1,obj.stratscaling{idx,[obj.SCTOTALSIZE]}));
            tradespos=sum(cat(1,obj.stratscaling{idx,obj.SCTRADESPOS}));
            tradesneg=sum(cat(1,obj.stratscaling{idx,obj.SCTRADESNEG}));
            txt=[txt,sprintf('\nTotal          %6.1f%%%6.1f%5.1f%5d(%5d/%5d)\n',...
                             100.*(pnltotal./sum(betsize)),pnltotal,pnltotal-pnlstartsum,... %100.*(pnltotal./accountstart) PnL%%
                             tradespos+tradesneg,tradespos,tradesneg)];
            txt=[txt,sprintf('-------------------------------------------------------------------------------\n')];
            txt=[txt,sprintf('Strategy         ROI%%   PnL PnLd       Trades Size HitR%%      wAvgPnL  Binomial\n')];
            txt=[txt,sprintf('-------------------------------------------------------------------------------\n')];
            for i=1:numel(sidx),
                txt=cat(2,txt,txttab{sidx(i)});
            end
        end
    end
    obj.disptextticketpnl=txt;
end
function txt=dispaccount(obj,time,accountstart)
    
    %get account data
    [accountfundstotal,accountfunds,exposure]=obj.apiobj.getaccountfunds;
    %pnl
    pnl=accountfundstotal-accountstart;
    pnlperc=100.*betmat.discreturn([accountstart,accountfundstotal]);
    days=time./(60*60*24); % secs to days
    %min,max
    obj.accountmin(1)=min(obj.accountmin(1),accountfundstotal);
    obj.accountmax(1)=max(obj.accountmax(1),accountfundstotal);
    obj.accountmin(2)=min(obj.accountmin(2),pnl);
    obj.accountmax(2)=max(obj.accountmax(2),pnl);
    obj.accountmin(3)=min(obj.accountmin(3),pnlperc);
    obj.accountmax(3)=max(obj.accountmax(3),pnlperc);
    %disp
    txt=[sprintf('%.0f/%.0f/%.0f(%.1fd)\nAccount: %7.2f\nExposure:%7.2f\nTotal:  %8.2f(%7.2f/%7.2f)\nPnL:     %7.2f(%7.2f/%7.2f)\nPnL%%:     %6.2f%%(%6.2f%%/%6.2f%%)\nTTR:%.1fms TTDB:%.1fms TTW:%.1fms\nbQok/e/o #/f:%.2f%%/%.2f%%/%.2f%% %d/%d\nSlpB/L:%.2f%%/%.2f%% %d/%d',...
                 obj.accountmin(2)./days,pnl./days,obj.accountmax(2)./days,days,...
                 accountfunds,exposure,accountfundstotal,obj.accountmin(1),obj.accountmax(1),...
                 pnl,obj.accountmin(2),obj.accountmax(2),...
                 pnlperc,obj.accountmin(3),obj.accountmax(3),...
                 1000.*obj.ttttime./obj.tttnum,...%size=1,3
                 100.*[obj.bestqok,obj.bestqerror,obj.bestqnum-obj.bestqfunds-obj.bestqok-obj.bestqerror]./(obj.bestqnum-obj.bestqfunds),obj.bestqnum-obj.bestqfunds,obj.bestqfunds,...%size=1,3
                 100.*obj.slippage./obj.slipnum,obj.slipnum),obj.disptextticketpnl]; %size=1,2
    if ~isempty(obj.ticketdata),
        % open tickets & exposure from open tickets
        idx=~strcmp(obj.ticketdata(:,obj.TBETID),'') & ~strcmp(obj.ticketdata(:,obj.TBETID),obj.TTYPEVIRTUAL) &... % not empty betid and not virtual
            isnan(cat(1,obj.ticketdata{:,obj.TBETPNL})); % but empty pnl
        if any(idx), % any open tickets
            % open tickets/strategy
            stratnames=unique(obj.ticketdata(idx,obj.TSTRATNAME));
            n=numel(stratnames);
            opentab=NaN(n,2); % open tickets
            for stratnum=1:n,
                idxopen=find(idx & strcmp(obj.ticketdata(:,obj.TSTRATNAME),stratnames(stratnum))); % strategyname
                if ~isempty(idxopen),
                    idxb=cat(1,obj.ticketdata{idxopen,obj.TBETTYPE})=='B';
                    opentab(stratnum,:)=[numel(idxopen),sum(cat(1,obj.ticketdata{idxopen(idxb),obj.TBETSIZE}))+... %num,backexp
                                         abs(sum((1-cat(1,obj.ticketdata{idxopen(~idxb),obj.TBETPRICE})).*cat(1,obj.ticketdata{idxopen(~idxb),obj.TBETSIZE})))]; % layexp
                end
            end
            [~,sidx]=sortrows(opentab,[-1 -2]);
            sidx=sidx(~isnan(opentab(sidx,1)));
            if ~isempty(sidx),
                txt=[txt,sprintf('\nTotal          %6d   %6.1f\n',betmat.nansum(opentab,1))];
		        txt=[txt,sprintf('------------------------------\n')];
                txt=[txt,sprintf('Strategy       OpenT# Exposure\n')];
                txt=[txt,sprintf('------------------------------\n')];
                for i=1:numel(sidx),
                    stratnum=sidx(i);
                    txt=cat(2,txt,sprintf('%-15s%6d   %6.1f\n',stratnames{stratnum},opentab(stratnum,1),opentab(stratnum,2)));
                end
            end
        end
    end
end

%% static scheduler functions
function staticread(obj)
    
    t=obj.apiobj.getapitime;
    if isempty(t), % did not get proper time from api
        fprintf('RTCONTROL:STATICREAD:Empty t!\n');
        return;
    end
    starttime=t+obj.staticstartread;
    endtime=t+obj.staticendread;
    for eventnum=1:numel(obj.eventidsread),
        % read static market data
        fprintf('Loading %s-markets from %s to %s ...',obj.emread{eventnum,obj.EMREVENT},datestr(starttime),datestr(endtime));
        tic;
        marketdata=obj.apiobj.getallmarkets(starttime,endtime,obj.eventidsread(eventnum));
        fprintf('%5.2f sec\n',toc);
        % filter market data
        if isempty(marketdata),
            fprintf('No markets found.\n');
        else
            % select & add active markets to scheduler
            if isempty(obj.emread{eventnum,obj.EMRFUNCHANDLE}), % use standard filter
                marketdata=staticfilter(obj.emread{eventnum,obj.EMREVENT},marketdata,obj.emread{eventnum,obj.EMRMAINMARKET},obj.emread{eventnum,obj.EMRMARKETS},obj.emread{eventnum,obj.EMRMINAMOUNT});
            else % use special filter
                marketdata=feval(obj.emread{eventnum,obj.EMRFUNCHANDLE},...
                                 obj.emread{eventnum,obj.EMREVENT},marketdata,obj.emread{eventnum,obj.EMRMAINMARKET},obj.emread{eventnum,obj.EMRMARKETS},obj.emread{eventnum,obj.EMRMINAMOUNT});
            end
            if numel(marketdata)>0,
                % total amount matched / market
                fprintf('Total Amount Matched(GBP)        StartTime          Market Type Market Name\n');
                num=str2double({marketdata.totalAmountMatched}');
                [~,idx]=sort(num,'descend');
                for i=1:numel(idx), 
                    if num(idx(i))>0,
                        fprintf('%25.0f %10s %20s %s\n',num(idx(i)),marketdata(idx(i)).eventDateStr(1:end-5),marketdata(idx(i)).marketName,marketdata(idx(i)).menuPathStr);
                    end
                end
                %bar(str2num(char({marketdata(idx).totalAmountMatched}')))
                % insert static data into scheduler
                n=numel(marketdata);
                starttimes=betfair.timestampstr2datenum2({marketdata.eventDateStr});
                staticinsert({marketdata.marketID}',num2cell(starttimes),repmat(obj.emread(eventnum,obj.EMREVENT),n,1),... % marketid,starttime,eventtype
                             {marketdata.marketName}',{marketdata.menuPathStr}',cell(n,1),...                        % markettype,marketname,orderindex
                             num2cell(starttimes+obj.dynamicstartread),num2cell(starttimes+obj.dynamicendread),...   % startread,endread
                             repmat({true},n,1),repmat({false},n,1),repmat({true(1,size(obj.strategies,1))},n,1),... % readstate,readprefer,writestates
                             repmat({true},n,1),cell(n,1),repmat({t},n,1));                                          % orderidxflag,runnernames,timestamp
            end
        end
    end
    % set time for next static read cycle
    obj.staticreadnext=t+obj.staticreadcycle;
    
% nested functions
function staticinsert(marketid,starttime,eventtype,markettype,marketname,orderidx,startread,endread,readstate,preferedread,ticketwritestates,orderidxflag,runnernames,timestamp)
% STATICINSERT Insert markets to scheduler.

    % check for new markets and new starttime
    idxnew=true(size(marketid)); % all data is added
    if ~isempty(obj.staticdata),
        [~,idxa,idxb]=intersect(obj.staticdata(:,obj.MARKETID),marketid);
        if ~isempty(idxb),
            idxnew(idxb)=false; % add all but intersections
            % check if starttime has changed
            idxchg=cat(1,obj.staticdata{idxa,obj.STARTTIME})~=cat(1,starttime{idxb});
            if any(idxchg),  % if starttime has changed
                obj.staticdata(idxa(idxchg),obj.STARTTIME)=starttime(idxb(idxchg)); % chg starttime
                obj.staticdata(idxa(idxchg),obj.STARTREAD)=startread(idxb(idxchg)); % chg startreadtime
                obj.staticdata(idxa(idxchg),obj.ENDREAD)=endread(idxb(idxchg)); % chg endreadtime
                fprintf('Starttime has changed for %d market(s).\n',sum(idxchg));
                %disp([obj.staticdata(idxa(idxchg),obj.MARKETID),cellstr(datestr(cat(1,obj.staticdata{idxa(idxchg),obj.STARTTIME})))]);
                %disp(obj.staticdata(idxa(idxchg),obj.MARKETNAME));
            end
        end
    end
    if any(idxnew), % new data to add
        obj.staticdata=[ obj.staticdata;
                         marketid(idxnew),starttime(idxnew),eventtype(idxnew),... 
                         markettype(idxnew),marketname(idxnew),orderidx(idxnew),... 
                         startread(idxnew),endread(idxnew),...
                         readstate(idxnew),preferedread(idxnew),ticketwritestates(idxnew),...
                         orderidxflag(idxnew),runnernames(idxnew),timestamp(idxnew) ];
        fprintf('%d new market(s) added.\n',sum(idxnew));
        % sort
        obj.staticdata=sortrows(obj.staticdata,[obj.STARTREAD,obj.MARKETNAME,obj.MARKETTYPE]);
    end
end
function y=staticfilter(eventtype,marketdata,mainmarket,markets2read,minamountmatched)
%MARKETFILTER Filter market data.

% select only active, inplay markets
idxactive=strcmpi({marketdata.marketStatus}','ACTIVE');
idxminamount=str2double({marketdata.totalAmountMatched}')>=minamountmatched;
idxinplay=strcmpi({marketdata.TurningInPlay}','Y');
idxmain=strcmpi({marketdata.marketName}',mainmarket);
idx=idxmain & idxminamount & idxinplay & idxactive;
fprintf('Active Markets:   %5d\nInplay Markets:   %5d\nMain Markets:     %5d\n', ...
        sum(idxactive),sum(idxinplay),sum(idx));
% find related markets for each mainmarket
if numel(markets2read)>1,
    idx=ismember({marketdata.menuPath}',{marketdata(idx).menuPath}') & ... % games with name of filtered markets
        ismember({marketdata.marketName}',markets2read); % markettypes of markets2read
end
%idx=idx | cellfun(@(x) ~isempty(strfind(x,'Winner 2010')),{marketdata.marketName}'); %  && isempty(strfind(x,'Accumulators'))
marketdata=marketdata(idx);
if any(idx),
    % filter market names
    for ii=1:numel(marketdata), 
        mname=regexp(marketdata(ii).menuPath,'\\|/','split');
        if numel(mname)<=1,
            fprintf('Staticfilter:No delimiter in marketname!\n');
            marketdata(ii).menuPathStr=marketdata(ii).menuPath;
        else
            mname=strtrim(strcat(mname(~cellfun(@(x) isempty(x) || strncmpi(x,'Fixtures',8) || strncmpi(x,eventtype,length(eventtype)),mname)),'/'));
            mname=cat(2,mname{:});
            marketdata(ii).menuPathStr=mname(1:end-1);
        end
    end;
    % sort data by menuPath and marketName
    [~,sidx]=sortrows([{marketdata.menuPath}',{marketdata.marketName}'],[1 2]);
    marketdata=marketdata(sidx);
end
fprintf('Reading Markets:  %5d\n',numel(marketdata));
y=marketdata;
end
end
function y=getstaticread(obj)
    t=obj.apiobj.getapitime;
    y=isempty(obj.staticdata) || isempty(obj.staticreadnext) || isempty(t) || (t>=obj.staticreadnext);
end
function y=getstaticempty(obj)
    y=isempty(obj.staticdata);
end

%% dynamic scheduler functions
function [savedataflag,trademarketflag]=checkquotes(obj,q,idx,selectionids,ipdelay)
%Check quotes for saving and trading.

    savedataflag=false;
    trademarketflag=false;
    if isempty(q), % empty quotes
        fprintf(' -empty q!');
    elseif ~isnumeric(q), % not numeric quotes
        if ~ischar(q),
            fprintf(' -q not numeric nor char!');
        else
            fprintf(' -%s',q);
            if strcmpi(q,'EVENT_CLOSED'),
                obj.staticdata{idx,obj.READSTATE}=false;  % end reading if event closed before ENDREAD
                obj.staticdata{idx,obj.WRITESTATE}=false(1,size(obj.strategies,1)); % end writing if event closed before ENDREAD
                savedataflag=true; % save quotes
            elseif strcmpi(q,'EVENT_SUSPENDED') &&...
                   any(strcmpi(obj.emsuspendedread,obj.staticdata{idx,obj.MARKETTYPE})) &&... % is a non-live market
                   (isempty(ipdelay) || (ipdelay~=0)),    % market already in IP-mode or ended vs. (t>obj.staticdata{idx(i),obj.STARTTIME}) % after starttime
                obj.staticdata{idx,obj.READSTATE}=false;  % end reading if event suspended before ENDREAD  
                obj.staticdata{idx,obj.WRITESTATE}=false(1,size(obj.strategies,1)); % end writing if event closed before ENDREAD
            elseif strcmpi(q,'EXCEEDED_THROTTLE'),
                obj.staticdata{idx,obj.READPREFER}=true;  % load balancer - read first in next cycle
                pause(.1);
            else
                savedataflag=true; % save quotes
            end
        end
    else % numeric quotes
        savedataflag=true; % save quotes
        %check orderidx by comparing selectionids
        if obj.staticdata{idx,obj.ORDERIDXFLAG}, % implies that selectionids not empty, only when q == numeric
            fprintf(' -mkt');
            runnerselections=obj.apiobj.getmarket(obj.staticdata{idx,obj.MARKETID}); % get runner names
            if isempty(runnerselections),
                fprintf(':no');
            elseif ischar(runnerselections) && strcmpi(runnerselections,'CLOSED'),
                obj.staticdata{idx,obj.READSTATE}=false; % end reading if event closed before ENDREAD
                obj.staticdata{idx,obj.WRITESTATE}=false(1,size(obj.strategies,1)); % end writing if event closed before ENDREAD
                fprintf(':cls');
            elseif ~isempty(setdiff(selectionids,runnerselections(:,2))),
                obj.staticdata(idx,obj.ORDERIDX)={'selids not eq!'};
                fprintf(':selids not eq!');
            else
                % check correct order of runnernames with selectionids
                if ~all(strcmp(selectionids',runnerselections(:,2))),
                    orderidx=cellfun(@(x) find(strcmp(runnerselections(:,2),x)),selectionids);
                    runnerselections=runnerselections(orderidx,:); % order of q-selectionids
                    fprintf(':ord');
                else
                    orderidx='ok';
                end
                obj.staticdata(idx,obj.RUNNERNAMES)={runnerselections(:,1)};
                obj.staticdata(idx,obj.ORDERIDX)={orderidx};
                obj.staticdata(idx,obj.ORDERIDXFLAG)={false};
            end
        else
            trademarketflag=true; % trading market is possible
        end
    end
end
function dynamicread(obj)
%Read quotes for static markets.

    fprintf('Reading');
    t=obj.apiobj.getapitime;
    if isempty(t), % did not get proper time from api
        fprintf('RTCONTROL:DYNAMICREAD:Empty t!\n');
        return;
    end
    %get scheduled markets from static data
    idx=find(cat(1,obj.staticdata{:,obj.READSTATE}) &...     % readstate is true
            (t>=cat(1,obj.staticdata{:,obj.STARTREAD})) &... % time >= startread
            (t<=cat(1,obj.staticdata{:,obj.ENDREAD})));      % time <= endread
    if isempty(idx),
        nextmarket=min(cat(1,obj.staticdata{t<=cat(1,obj.staticdata{:,obj.STARTREAD}),obj.STARTREAD}))-t;
        fprintf(' -in %s\n',datestr(nextmarket,'HH:MM'));
    else
        % load balancer
        pridx=cat(1,obj.staticdata{idx,obj.READPREFER});
        if any(pridx), % prefered read because of exceeded throttle
            fprintf(' -preferred');
            [~,sidx]=sort(pridx,'descend');
            obj.staticdata(idx(pridx),obj.READPREFER)={false}; % clear flag
            idx=idx(sidx); % preferred markets to front
        end
        fprintf('\n');
        % loop thru markets
        for i=1:numel(idx),
            idxi=idx(i); %speed up indexing
            % read quotes
            fprintf('%s-%s-%s',obj.staticdata{idxi,obj.EVENTTYPE},obj.staticdata{idxi,obj.MARKETNAME},obj.staticdata{idxi,obj.MARKETTYPE});
            marketid=obj.staticdata{idxi,obj.MARKETID};
            ttr=tic;
            [q,~,selectionids,amountsmatched,t,ipdelay,lastpricematched,spprice]=obj.apiobj.getmarketprices(marketid); % read quotes and update time
            obj.ttttime(1)=obj.ttttime(1)+toc(ttr);
            obj.tttnum(1)=obj.tttnum(1)+1;
            if obj.checkquotes(q,idxi,selectionids,ipdelay), % insert dynamic data
                obj.ttttime(2)=obj.ttttime(2)+toc(ttr);
                obj.tttnum(2)=obj.tttnum(2)+1;
                if isempty(t), % no time -> no index for db
                    fprintf(' -empty t!');
                else
                    obj.dynamicdata=[obj.dynamicdata;
                        marketid,{t},{ipdelay},{q},{amountsmatched},{lastpricematched},{spprice}]; % market id, api time, quotes or text, amounts, spprice
                end
            end
            fprintf('\n');
        end
    end
end
function dynamicwrite(obj,placebetsflag)
%Write and execute bets for static markets.
    
    % check ticket writing
    fprintf('Writing\n');
    ticketnum=size(obj.ticketdata,1); % ticket counter
    for stratnum=1:size(obj.strategies,1),
        fprintf('%s',obj.strategies{stratnum,obj.SNAME});
        % find relevant markets
        t=obj.apiobj.getapitime;
        if isempty(t), % did not get proper time from api
            fprintf('\nRTCONTROL:DYNAMICWRITE:Empty t!\n');
            continue; % next strategy
        end
        idx=find(cellfun(@(x) x(stratnum),obj.staticdata(:,obj.WRITESTATE)) &...                            % writestate of strategy x per market
                 strcmpi(obj.staticdata(:,obj.EVENTTYPE),obj.strategies(stratnum,obj.SEVENTTYPE)) &...      % eventtype
                 strcmpi(obj.staticdata(:,obj.MARKETTYPE),obj.strategies(stratnum,obj.SMARKETTYPE)) &...    % markettype
                 ((t-obj.strategies{stratnum,obj.SSTARTREAD})>=cat(1,obj.staticdata{:,obj.STARTTIME})) &... % time >= startread
                 ((t-obj.strategies{stratnum,obj.SENDREAD})<=cat(1,obj.staticdata{:,obj.STARTTIME})));      % time <= endread
        if isempty(idx),
            stratstartread=obj.strategies{stratnum,obj.SSTARTREAD};
            nextmarketidx=strcmpi(obj.staticdata(:,obj.EVENTTYPE),obj.strategies{stratnum,obj.SEVENTTYPE}) &...   % eventtype
                          strcmpi(obj.staticdata(:,obj.MARKETTYPE),obj.strategies{stratnum,obj.SMARKETTYPE}) &... % markettype
                          ((t-stratstartread)<=cat(1,obj.staticdata{:,obj.STARTTIME}));                           % time <= startread
            nextmarket=min(cat(1,obj.staticdata{nextmarketidx,obj.STARTTIME}))+stratstartread-t;
            if ~isempty(nextmarket),
                fprintf(' -in %s\n',datestr(nextmarket,'HH:MM'));
            else
                fprintf(' -no\n');
            end
            continue; % next strategy
        end
        % loop thru markets
        for i=1:numel(idx),
            idxi=idx(i); % speed up indexing
            % check for name
            if ~isempty(obj.strategies{stratnum,obj.SNAMECHKFUNCHANDLE}),
                flag=feval(obj.strategies{stratnum,obj.SNAMECHKFUNCHANDLE},obj.staticdata{idxi,obj.MARKETNAME});
                if isempty(flag) || ~flag,
                    continue; % next market
                end
            end
            % read quotes
            marketid=obj.staticdata{idxi,obj.MARKETID};
            ttw=tic;
            [q,~,selectionids,amountsmatched,t,ipdelay,lastpricematched,spprice]=obj.apiobj.getmarketprices(marketid); % read quotes and update time
            [savedataflag,trademarketflag]=obj.checkquotes(q,idxi,selectionids,ipdelay);
            if trademarketflag,
                % quote quality checks
                if any(isnan(amountsmatched)),
                    fprintf(' -NaNamnts!\n');
                elseif betmat.nansum(amountsmatched)<obj.minamountmatched,
                    fprintf(' -amnts<\n');
                elseif (obj.strategies{stratnum,obj.SNANCHECK}~=rtcontrol.NANOK) && any(any(isnan(q(1:obj.strategies{stratnum,obj.SNANCHECK},:)))),
                    fprintf(' -NaNq');
                elseif betmat.bookvalflag(q,obj.strategies{stratnum,obj.SOVERROUND},obj.strategies{stratnum,obj.SNANCHECK}),
                    fprintf(' -ovrrnd>');
                else
                    % calc strategy weights
                    w=0; % init with 0
                    switch obj.strategies{stratnum,obj.SFUNCARGS}
                        case rtcontrol.STRATFUNQUOTES
                            [w,tickettype]=feval(obj.strategies{stratnum,obj.SFUNCHANDLE},q);
                        case rtcontrol.STRATFUNQUOTESNAMES
                            [w,tickettype]=feval(obj.strategies{stratnum,obj.SFUNCHANDLE},q,obj.staticdata{idxi,obj.MARKETNAME});
                        case rtcontrol.STRATFUNTICKETS
                            if ~isempty(obj.ticketdata),
                                tidx=strcmp(obj.ticketdata(:,obj.TMARKETID),marketid) & strcmp(obj.ticketdata(:,obj.TSTRATNAME),obj.strategies(stratnum,obj.SNAME)); % already exists executed ticket incl. virtual bets
                                if any(tidx), % already exists executed bets for market
                                    [w,tickettype]=feval(obj.strategies{stratnum,obj.SFUNCHANDLE},q,selectionids,obj.ticketdata(tidx,:));
                                end
                            end
                    end
                    if any(w),
                        fprintf('\n%s-%s-%s\n',obj.staticdata{idxi,obj.EVENTTYPE},obj.staticdata{idxi,obj.MARKETNAME},obj.staticdata{idxi,obj.MARKETTYPE});
                        % scale w to bet size, if cashout, betsize=1
                        w=w.*obj.strategies{stratnum,obj.SBETSIZE};
                        % execute bet(s) and write tickets
                        for k=find(w),
                            % betsize
                            betsize=abs(w(k));
                            if betsize>obj.maxplacebetsize,
                               fprintf(' -maxsize>!\n'); 
                               continue; % next w
                            end
                            % bettype,betprice
                            if w(k)>0,
                                bettype={'B'};
                                betprice=q(1,k);
                                qscaling=1-obj.executionminquotelimit;
                                qvol=q(3,k);
                            else
                                bettype={'L'};
                                betprice=q(2,k);
                                qscaling=1+obj.executionminquotelimit;
                                qvol=q(4,k);
                            end
                            if ~isfinite(betprice) || (betprice<=1) || (betprice>=1000),
                                fprintf(' -q<>Inf!');
                                disp(betprice);
                                continue; % next quote
                            end
                            if qvol<betsize,
                                fprintf(' -qvol<');
                                continue; % next quote
                            end
                            obj.ttttime(3)=obj.ttttime(3)+toc(ttw); % time to write
                            obj.tttnum(3)=obj.tttnum(3)+1;
                            %fprintf('%s\n%s:%s %s - Ovrnd %.2f/%.2f/%.2f(%.2f) - %s %.2f@Limit %.2f(Price %.2f, Vol %.2f)\n', ...
                            %        obj.ticketdata{idx(i),obj.TSTRATNAME},marketid,selectionid,obj.ticketdata{idx(i),obj.TRUNNERNAME}, ...
                            %        betmat.bookval3(q3,1,backandlaycheck),betmat.bookval3(q3,2,backandlaycheck),betmat.bookval3(q3,3,backandlaycheck),...
                            %        betmat.bookval(q(backandlaycheck,:).*qscaling),...
                            %        bettype,betsize,betprice,q(1,selidx),q(3,selidx));
                            if placebetsflag,
                                if strcmp(tickettype,obj.TTYPEVIRTUAL), % virtual ticket
                                    betresults.resultCode='OK';
                                    betresults.betId=obj.TTYPEVIRTUAL;
                                    betresults.sizeMatched=betsize;
                                    betresults.averagePriceMatched=betprice;
                                    pbtimestamp=now;
                                    placetype=false;
                                else % real ticket
	                                [betresults,pbtimestamp]=obj.apiobj.placebets(marketid,selectionids(k),bettype,betfair.increments(betprice.*qscaling),betsize);
                                    obj.bestqnum=obj.bestqnum+1;
                                    placetype=true;
                                end
                            else % simulated ticket
                                [betresults,pbtimestamp]=obj.apiobj.placebetsim(marketid,selectionids(k),bettype,betprice,betsize);
                                placetype=false;
                            end
                            disp(betresults);
                            if ~isstruct(betresults),
                                if ischar(betresults),
                                    fprintf('betresults:%s!\n',betresults);
                                else
                                    fprintf('betresults neither struct nor char!\n');
                                end
                                obj.bestqerror=obj.bestqerror+1;
                            elseif placetype && strcmpi(betresults.resultCode,'EXPOSURE_OR_AVAILABLE_BALANCE_EXCEEDED'), %EXCEEDED_THROTTLE???
                                obj.bestqfunds=obj.bestqfunds+1;
                            elseif ~strcmpi(betresults.resultCode,'OK'),
                                %BET_IN_PROGRESS,UNKNOWN_ERROR,EXPOSURE_OR_AVAILABLE_BALANCE_EXCEEDED
                                fprintf('betresults:%s!\n',betresults.resultCode);
                                obj.bestqerror=obj.bestqerror+1;
                            elseif ~strcmp(betresults.betId,'0'), % bet was matched
                                if betresults.sizeMatched==betsize, % bet matched in correct size
                                    ticketinsert;
                                elseif betresults.sizeMatched==0, % did not get best quote at all
                                    cancelresults=obj.apiobj.cancelbets(betresults.betId); %cancel unmatched part of bet
                                    if cancelresults.success==0, % cancelresults.resultCode==REMAINING_CANCELLED
                                        if strcmpi(cancelresults.resultCode,'TAKEN_OR_LAPSED'), % got quote while cancelbets
                                            ticketinsert;
                                        else    
                                            fprintf('cancelresults!\n');
                                            disp(cancelresults);
                                        end
                                    end
                                else % bets matched in different size
                                    sizediff=abs(betsize-betresults.sizeMatched);
                                    if sizediff<rtcontrol.maxbetsizediff,
                                        fprintf('betresults size diff<eps!\n');
                                    else    
                                        fprintf('betresults size diff:%5.2f',sizediff);
                                        if betresults.sizeMatched<betsize,
                                            cancelresults=obj.apiobj.cancelbets(betresults.betId); %cancel unmatched part of bet
                                            if cancelresults.success==1,
                                                fprintf('-%s!',cancelresults.resultCode);
                                            else
                                                fprintf('-cancelresults!\n');
                                                disp(cancelresults);
                                            end
                                        end
                                        %if diffbetsize<obj.minbetsize,
                                        %    fprintf('too small!\n');
                                        %else
                                        %insert new ticket with differing size
                                        %elseif betresults.sizeMatched>betsize,
                                        %fprintf('placeBets - size matched>betsize - size diff:%5.2f\n',betresults.sizeMatched-betsize);
                                    end
                                    ticketinsert;
                                end
                            end
                        end
                    end
                end
            end
            if savedataflag, % insert dynamic data
                if isempty(t), % no time -> no index for db
                    fprintf(' -empty t!');
                else
                    obj.dynamicdata=[obj.dynamicdata;
                        marketid,{t},{ipdelay},{q},{amountsmatched},{lastpricematched},{spprice}]; % market id, api time, quotes or text, amounts, spprice
                end
            end
        end
        fprintf('\n');
    end
    ticketnum=size(obj.ticketdata,1)-ticketnum;
    if ticketnum>0,
        fprintf('%d ticket(s).\n',ticketnum);
    end
    
%nested functions
    function ticketinsert
        obj.ticketdata=[obj.ticketdata; % create ticket
                        betresults.betId,marketid,selectionids(k),obj.staticdata{idxi,obj.RUNNERNAMES}(k),... % betid,marketid,selectionid,runnernames
                        bettype,betresults.sizeMatched,betresults.averagePriceMatched,obj.strategies(stratnum,obj.SNAME), ... % bettype,sizematched,pricematched,strategyname
                        {NaN},pbtimestamp]; % PNL,exectimestamp
        obj.staticdata{idxi,obj.WRITESTATE}(stratnum)=false; % tickets for strat x written
        if placetype && betresults.averagePriceMatched>0, %calc slippage and bestq
            if bettype{1}=='B',
                obj.slippage(1)=obj.slippage(1)+betprice./betresults.averagePriceMatched-1;
                obj.slipnum(1)=obj.slipnum(1)+1;
            else
                obj.slippage(2)=obj.slippage(2)+1-betprice./betresults.averagePriceMatched;
                obj.slipnum(2)=obj.slipnum(2)+1;
            end
            obj.bestqok=obj.bestqok+1;
        end
    end
end

end % methods

%% class static methods
methods (Static, Access=public)

%% filter
function y=staticfilter_horseracing(eventtype,marketdata,mainmarket,markets2read,minamountmatched)
%MARKETFILTER Filter market data.

% select only active, inplay markets
idxactive=strcmpi({marketdata.marketStatus}','ACTIVE');
idxminamount=str2double({marketdata.totalAmountMatched}')>=minamountmatched;
idxinplay=strcmpi({marketdata.TurningInPlay}','Y');
idxmain=strcmp({marketdata.numberWinners}','1'); % win only markets
idx=idxmain & idxinplay & idxactive & idxminamount;
fprintf('Active Markets:   %5d\nInplay Markets:   %5d\nMain Markets:     %5d\n', ...
        sum(idxactive),sum(idxinplay),sum(idx));
% assign new name to mainmarkets
idxf=find(idx);
for i=1:numel(idxf),
    marketdata(idxf(i)).marketName=mainmarket{1};
end
% find related place markets for each mainmarket
idx=ismember({marketdata.menuPath}',{marketdata(idx).menuPath}') & ... % games with name of filtered markets
    ismember({marketdata.marketName}',markets2read);                   % markettypes of markets2read excl. mainmarket
marketdata=marketdata(idx);
if any(idx),
    % filter market names
    for ii=1:numel(marketdata),
        mname=regexp(marketdata(ii).menuPath,'\\|/','split');
        if numel(mname)<=1,
            fprintf('Staticfilter:No delimiter in marketname!\n');
            marketdata(ii).menuPathStr=marketdata(ii).menuPath;
        else
            mname=strtrim(strcat(mname(~cellfun(@(x) isempty(x) || strncmpi(x,'Fixtures',8) || strncmpi(x,eventtype,length(eventtype)),mname)),'\'));
            mname=cat(2,mname{:});
            marketdata(ii).menuPathStr=mname(1:end-1);
        end
    end;
    % sort data by menuPath and marketName
    [~,sidx]=sortrows([{marketdata.menuPath}',{marketdata.marketName}'],[1 2]);
    marketdata=marketdata(sidx);
end
fprintf('Reading Markets:  %5d\n',numel(marketdata));
y=marketdata;
end

%% tickets
function [exposure,exposurev,betpnl]=ticketexposure(tickets,idx)
%TICKETEXPOSURE calc exposures from tickets.

    if nargin<2,
        idx=[rtcontrol.TBETID,rtcontrol.TSELECTIONID,rtcontrol.TBETTYPE,...
             rtcontrol.TBETSIZE,rtcontrol.TBETPRICE,rtcontrol.TBETPNL];
    end
    selectionids=unique(tickets(:,idx(2)));
    n=length(selectionids)+1; % possible state of loss
    exposurev=zeros(1,n);
    exposure=zeros(1,n);
    betpnl=zeros(1,n);
    for i=1:size(tickets,1),
        orderidx=strcmp(selectionids,tickets(i,idx(2)));
        q=zeros(1,n);
        w=zeros(1,n);
        q(orderidx)=tickets{i,idx(5)};
        if tickets{i,idx(3)}=='L',
            w(orderidx)=-tickets{i,idx(4)};
        else
            w(orderidx)=tickets{i,idx(4)};
        end
        pnlsum=betmat.pnlsum(q,w);
        exposure=exposure+pnlsum;
        if strcmp(tickets(i,idx(1)),rtcontrol.TTYPEVIRTUAL),
            exposurev=exposurev+pnlsum;
        else
            betpnl(orderidx)=tickets{i,idx(6)};
        end
    end
end


% namechecks
function flag=internationals(marketname)
    flag=regexp(lower(marketname),'internationals','once')==1;
end
function flag=friendlies(marketname)
    flag=regexp(lower(marketname),'friendlies','once')==1;
end
function flag=csnamelist(marketname)
    %{
    mnamelist=lower({'English Soccer','Scottish Soccer','Spanish Soccer','German Soccer',...
               'Dutch Soccer','French Soccer','Portuguese Soccer','Italian Soccer',...
               'Russian Soccer','Greek Soccer','Austrian Soccer','Polish Soccer',...
               'Swiss Soccer','Belgian Soccer','Cypriot Soccer','Ukrainian Soccer',...
               'Turkish Soccer','Brazilian Soccer','Argentinian Soccer',...
               'UEFA Champions League','UEFA Europa League'});
    %}
    mnamelist=lower({'English Soccer','Spanish Soccer','German Soccer',...
               'Dutch Soccer','French Soccer','Portuguese Soccer','Italian Soccer',...
               'Scottish Soccer','austrian bundesliga',...
               'UEFA Champions League','UEFA Europa League'});
    flag=any(cell2mat(regexp(lower(marketname),mnamelist)));
end
function flag=csteamnamelist(marketname)
    mnamelist=lower({'REAL MADRID',...
                     ...%Netherlands 1
                     'PSV','AZ ALKMAAR','TWENTE','AJAX','FEYENOORD','Groningen','Roda JC','De Graafschap','Breda',...
                     'Excelsior','NEC Nijmegen','Heracles','Sparta Rotterdam','Heerenveen','Willem II'
                   });
    flag=any(cell2mat(regexp(lower(marketname),mnamelist)));
end
function flag=htftnamelistS(marketname)
    mnamelist=lower({'Spanish Soccer/Primera Division'});
    flag=any(cell2mat(regexp(lower(marketname),mnamelist)));
end
function flag=htftnamelistD(marketname)
    mnamelist=lower({'Dutch Soccer/Eredivisie'});
    flag=any(cell2mat(regexp(lower(marketname),mnamelist)));
end
function flag=htftnamelistFEIG(marketname)
    mnamelist=lower({'French Soccer/Ligue 1 Orange','English Soccer/Barclays Premier League',...
                     'Italian Soccer/Serie A','German Soccer/Bundesliga 1'});
    flag=any(cell2mat(regexp(lower(marketname),mnamelist)));
end
%% trading strategies
% general
function [weights,tickettype]=bqle(x,quotes)
    tickettype=[];
    weights=quotes(1,:)<=x;
end
% cashout
function [weights,tickettype,pnl]=cashout(quotes,selectionids,tickets,profittarget,stoploss)
    tickettype=[];
    weights=zeros(1,size(quotes,2));
    q=zeros(1,size(quotes,2));
    w=zeros(1,size(quotes,2));
    pnl=NaN;
    if nargin<4,
        profittarget=0.5;
        stoploss=-0.2;
    end
    for i=1:size(tickets,1),
        orderidx=strcmp(selectionids,tickets{i,rtcontrol.TSELECTIONID});
        if ~any(orderidx),
            fprintf('CASHOUT:QUOTES:Selection not found!\n');
            return;
        end
        if tickets{i,rtcontrol.TBETTYPE}=='L',
            weight=-tickets{i,rtcontrol.TBETSIZE};
        else
            weight=tickets{i,rtcontrol.TBETSIZE};
        end
        q(orderidx)=q(orderidx)+tickets{i,rtcontrol.TBETPRICE}.*weight; % weighted average
        w(orderidx)=w(orderidx)+weight;
    end
    if any(w) && all(isfinite(w)),
        q=q./w; % caution - negative quotes possible
        q(~w)=0; % division by 0 gives NaN
        if any(q) && all(isfinite(q)),
            % trading PnL - pays at least the back/lay spread
            [pnl,cashoutw]=betmat.pnlcashoutquotes(q,w,quotes);
            if any(abs(cashoutw(cashoutw~=0))<rtcontrol.minbetsize), % check for minbetsize
                fprintf('CASHOUT:CASHOUTW:Size<minBetSize!\n');
                return;
            end
            maxloss=min(betmat.pnlsum(q,w)); % max neg exposure
            if all(isfinite(cashoutw)) &&...% no Infs and NaNs in weights
               min(pnl)>maxloss, % sanity check - don't lose more than set
                roi=min(pnl)./abs(maxloss);
                if (roi<stoploss) || (roi>profittarget), %#ok<BDSCI>
                    %fprintf('%d:%5.2f:ROI:%5.1f%% - ',betsize,min(pnl),100.*roi);
                    weights=cashoutw;
                end
            end
        end
    end
end
% exposure
function [weights,tickettype]=maxexp(quotes)
    tickettype=[];
    weights=zeros(1,size(quotes,2));
    %w=[0 0 1;0 1 0;0 1 1;1 0 0;1 0 1;1 1 0];
    w=[0 1 1;1 0 1;1 1 0];
    exposure=zeros(size(w,1),1);
    for i=1:size(w,1),
        exposure(i)=sum(betmat.pnlsum(quotes(1,:),w(i,:)./quotes(1,:)));
    end;
    if any(exposure>0),
        [~,pos]=max(exposure);
        w=w(pos,:)./quotes(1,:);
        weights=w./min(w(logical(w))).*rtcontrol.minbetsize;
        weights=betmat.roundxdec(weights,2);
        %w=w(pos,:)./quotes(1,:).*30;
        %if all(w(logical(w))>=rtcontrol.minbetsize),
        %    weights=w;
        %else
        %    disp(w);
        %end
    end
end
% tennis
% soccer
function [weights,tickettype]=eqw(quotes)
    tickettype=[];
    weights=ones(1,size(quotes,2));
end
% virtual
function [weights,tickettype]=vcashoutexposure(quotes,selectionids,tickets)
    tickettype=rtcontrol.TTYPEVIRTUAL;
    weights=zeros(1,size(quotes,2));
    exposure=zeros(1,size(quotes,2));
    for i=1:size(tickets,1),
        orderidx=strcmp(selectionids,tickets{i,rtcontrol.TSELECTIONID});
        if ~any(orderidx),
            fprintf('VCASHOUT:EXPOSURE:Selection not found! - ');
        else
            q=zeros(1,size(quotes,2));
            w=zeros(1,size(quotes,2));
            q(orderidx)=tickets{i,rtcontrol.TBETPRICE};
            if tickets{i,rtcontrol.TBETTYPE}=='L',
                w(orderidx)=-tickets{i,rtcontrol.TBETSIZE};
            else
                w(orderidx)=tickets{i,rtcontrol.TBETSIZE};
            end
            exposure=exposure+betmat.pnlsum(q,w);
        end
    end
    if any(exposure),
        % trading PnL - pays at least the back/lay spread
        [pnl,cashoutw]=betmat.pnlcashoutexposure(exposure,quotes);
        betsize=sum(cat(1,tickets{:,rtcontrol.TBETSIZE}));
        roi=min(pnl)./betsize;
        if (roi<-0.2) || (roi>0.5), %#ok<BDSCI>
            fprintf('%d:%5.2f:ROI:%5.1f%% - ',betsize,min(pnl),100.*roi);
            weights=cashoutw;
            weights(isnan(weights))=0; % no NaNs in weight
        end
    end
end
function [weights,tickettype]=vcashout(quotes,selectionids,tickets)
    tickettype=rtcontrol.TTYPEVIRTUAL;
    weights=rtcontrol.cashout(quotes,selectionids,tickets);
end
function [weights,tickettype]=veqw(quotes)
    tickettype=rtcontrol.TTYPEVIRTUAL;
    weights=rtcontrol.eqw(quotes);
end
end % static methods

end % classdef
