%% Class BackTest

classdef (~Sealed) backt < hgsetget % reference class

%% properties    
properties (Constant, GetAccess=public) % Constants

    dbtimeformat  ='yyyy-mm-dd HH:MM:SS';
    cminute       =datenum(0,0,0,0,1,0);  % const for 1 minute eq. 1/24/60
    markettypes   ={'Match Odds','Correct Score','Half Time/Full time','Half Time'};
    mainmarkettype=1;
    htftconversion=[1,3,2;7,9,8;4,6,5];
    
    startscoretime=[-30,  0]; % between mins relative to starttime
    htscoretime   =[ 45, 55];
    ftscoretime   =[100,inf]; 
    
    defaultevent  ='Soccer';
    
     % dynamic data structure
    DMARKETID =1; 
    DAPITIME  =2;
    DQUOTES   =5;
   
end
properties (SetAccess=public, GetAccess=public, ~Hidden)
       
    dbname         % name of historic database
    dbtype         % database type
    dbconn         % connection object
    
end 

%% methods
methods

%% Constructor/Destructor
function obj=backt(dbname,dbtype)
%BACKT Constructor.
 
% input parameter handling
if nargin>0,
    
    maxarg=2;
    narginchk(maxarg,maxarg);
    
    % init internal data structure
    obj.dbname=dbname;
    obj.dbtype=dbtype;
    % try to connect to db
    switch lower(dbtype)
        case 'msaccess'
            % MS Access
            connurl=['jdbc:odbc:Driver={Microsoft Access Driver (*.mdb, *.accdb)};DBQ=' dbname ];
            obj.dbconn=database('','','','sun.jdbc.odbc.JdbcOdbcDriver',connurl);
            if ~isempty(obj.dbconn.Message),
                error(obj.dbconn.Message);
            end
        case 'mysql'
            % MySQL
            obj.dbconn=database('',dbname,dbname,'sun.jdbc.odbc.JdbcOdbcDriver','jdbc:odbc:Driver={MySQL ODBC 5.1 Driver}');
            if  ~isempty(obj.dbconn.Message),
                error(obj.dbconn.Message);
            end
            exec(obj.dbconn,['use ',dbname]);
        otherwise
            error('BACKT:CONSTRUCTOR:Unknown Database!');
    end
    
end

end % constructor
function delete(obj)                 % destructor

    close(obj.dbconn); % close database connection

end
%% Display
function disp(obj) % display function
%DISP Display formatted object contents.
     
    if ~isempty(obj.dbconn),
        fprintf('Connected to %s@%s\n\n',obj.dbname,obj.dbtype);
        stats=obj.dbstats;
        fprintf('Markets:  %d\nTicks:    %d\nTicks/M.:%5.1f\n\n',stats(1),stats(2),stats(2)./stats(1));
    end
    
end
%% Database Maintenance
function stats=dbstats(obj)

    maxarg=1;
    narginchk(maxarg,maxarg);

    stats=zeros(1,2);

    %market stats
    curs=exec(obj.dbconn,'SELECT count(*) FROM markets');
    curs=fetch(curs);
    stats(1)=curs.Data{1};

    %tick stats
    curs=exec(obj.dbconn,'SELECT count(*) FROM ticks');
    curs=fetch(curs);
    stats(2)=curs.Data{1};

end
function stats=marketcount(obj,markettype)
    maxarg=2;
    narginchk(maxarg,maxarg);
    
    % count markettype
    curs=exec(obj.dbconn,strcat('SELECT count(*) FROM markets WHERE marketType=''',markettype,''''));
    curs=fetch(curs);
    stats=curs.Data{1};

end
function dbintegritycheck(obj)
    
    % start with ticks and markets - fallout in lost joins at end
    countsql('Ticks - content checks', ...
             'SELECT count(*) FROM ticks WHERE quotes=''EXCEEDED_THROTTLE'' or quotes=''INVALID_MARKET''');
    countsql('Markets - w just 1 tick', ...
             'SELECT COUNT(ticks.marketid) FROM ticks WHERE ticks.marketid IN (SELECT ticks.marketID FROM ticks GROUP BY ticks.marketid HAVING Count(ticks.marketID)=1)');
    countsql('Markets - w just text ticks', ...
             'SELECT COUNT(ticks.marketid) FROM ticks WHERE ticks.marketid IN (SELECT ticks.marketID FROM ticks GROUP BY ticks.marketid HAVING Count(ticks.marketID)=1)');
    countsql('Markets - w/o joins to ticks', ...
             'SELECT COUNT(markets.marketid) FROM markets WHERE markets.marketID NOT IN (SELECT ticks.marketid FROM ticks)');
    countsql('Ticks - w/o joins to markets', ...
             'SELECT COUNT(ticks.marketid) FROM ticks WHERE ticks.marketID NOT IN (SELECT markets.marketid FROM markets)');
    countsql('Markets - w/o main market', ...
             'SELECT count(marketid) FROM markets WHERE marketName NOT IN (SELECT DISTINCT marketName FROM markets WHERE marketType=''Match Odds'')');
    
    %nested function
    function countsql(text,sql)
        fprintf([text,' - ']);
        tic;
        curs=exec(obj.dbconn,sql);
        curs=fetch(curs);
        num=curs.Data{1};
        if num==0,
            fprintf('ok\n');
        else
            fprintf('%d errors!\n',curs.Data{1});
        end
        toc;
    end    
end
%% Database Handling
function y=getdbtable(obj,table,colnames)
        
    maxarg=3;
    narginchk(maxarg,maxarg);
    
    curs=exec(obj.dbconn,strcat({'SELECT DISTINCT '},colnames,{' FROM '},table));
    curs=fetch(curs);
    y=curs.Data;
    
end
%% Events
function y=geteventtypes(obj)
        
    maxarg=1;
    narginchk(maxarg,maxarg);
    
    y=obj.getdbtable('markets','eventtype');
    
end
%% Markets
function y=getmarkettypes(obj)
        
    maxarg=1;
    narginchk(maxarg,maxarg);
    
    y=obj.getdbtable('markets','markettype');
    
end
function y=getmarketnames(obj)
        
    maxarg=1;
    narginchk(maxarg,maxarg);
    
    y=obj.getdbtable('markets','marketname');
    
end
function y=getmarketinfo(obj,marketid,colnames)
        
    minarg=2;
    maxarg=3;
    narginchk(minarg,maxarg);
    
    if nargin<3, % colnames not defined
        colnames='*';
    end
    curs=exec(obj.dbconn,strcat({'SELECT '},colnames,' FROM markets WHERE marketid=''',marketid,''''));
    curs=fetch(curs);
    y=curs.Data;
    
end
function y=getrelatedmarkets(obj,marketid,markettype)
        
    maxarg=3;
    narginchk(maxarg,maxarg);
    
    curs=exec(obj.dbconn,strcat({'SELECT marketid FROM markets WHERE markettype='''},markettype,''' AND marketname=(SELECT marketname FROM markets m WHERE m.marketid=''',marketid,''' AND m.starttime=markets.starttime)'));
    curs=fetch(curs);
    y=curs.Data;
    
end
function starttime=getmarketstarttime(obj,marketid)

    maxarg=2;
    narginchk(maxarg,maxarg);
    
    starttime=datenum(obj.getmarketinfo(marketid,'starttime'),obj.dbtimeformat); 
    
end
function y=getmarkets(obj,eventtype,markettype,marketfilter)
        
    minarg=3;
    maxarg=4;
    narginchk(minarg,maxarg);
    
    sqlstr=strcat('SELECT marketid FROM markets WHERE eventtype=''',eventtype,''' and markettype=''',markettype,'''');
    if (nargin>2) && ~isempty(marketfilter),
        sqlstr=strcat(sqlstr,{' AND ('},marketfilter,')');
    end
    curs=exec(obj.dbconn,sqlstr);
    curs=fetch(curs);
    y=curs.Data;
    
end
function [y,n]=getrandmarkets(obj,num,eventtype,markettype,marketfilter)
      
    minarg=1;
    maxarg=5;
    narginchk(minarg,maxarg);
    
    if nargin<5,
        marketfilter=[];
        if nargin<4, % markettype not defined
            markettype=obj.markettypes(obj.mainmarkettype);
            if nargin<3,
                eventtype=obj.defaulteventtype;
                if nargin<2, % num not defined
                    num=1;
                end
            end
        end
    end
    y=obj.getmarkets(eventtype,markettype,marketfilter);
    
    n=size(y,1);
    idx=fix(rand(num,1)*n)+1;
    y=y(idx);
    
end
%% Ticks
function [y,starttime]=getticks(obj,marketid,timefrom,timeto)
    
    minarg=2;
    maxarg=4;
    narginchk(minarg,maxarg);
    
    curs=exec(obj.dbconn,strcat('SELECT * FROM ticks WHERE marketid=''',marketid,''''));
    curs=fetch(curs);
    
    %return values
    starttime=[];
    if ~strcmp(curs.Data,'No Data'),
        y=curs.Data;
    else    
        y=[];
    end
    
    if nargin>2, % relative timed ticks timefrom
        
        if nargin<4, % timeto not defined
            timeto=inf;
        end
        
        % get starttime
        starttime=datenum(obj.getmarketinfo(marketid,'starttime'),obj.dbtimeformat);
 
        % select ticks within time
        idx=obj.ticktime(y(:,2),starttime+timefrom*obj.cminute,starttime+timeto*obj.cminute);
        
        %return values
        y=y(idx,:);
    end
    
end
function [y,n,starttime]=getrandticks(obj,marketid,num,timefrom,timeto)
    
    minarg=2;
    maxarg=5;
    narginchk(minarg,maxarg);
        
    if nargin<5, % timeto not defined
        timeto=inf;
        if nargin<4, % timefrom not defined
            timefrom=-inf;
            if nargin<3, % num not defined
                num=1;
            end
        end
    end
    [y,starttime]=obj.getmarketticks(marketid,timefrom,timeto);
    n=size(y,1);
    idx=fix(rand(num,1)*n)+1;
    y=y(idx,:);
end
%% States
function [states,quotes]=calcstate(obj,mticks)
    
    maxarg=2;
    narginchk(maxarg,maxarg);
    
    markettype=obj.getmarketinfo(mticks(1,1),'markettype');
    switch lower(markettype{:})
        case 'match odds'
            [states,quotes]=obj.calcstatemodds(mticks);
        case 'correct score'
            [states,quotes]=obj.calcstatecorrectscore(mticks);
        case 'half time/full time'
            [states,quotes]=obj.calcstatehtft(mticks);
        otherwise
            error('BACKT:CALCSTATE:Unknown Markettype!');
    end
end
function [states,quotes]=calcstatemodds(obj,mticks)
    
    maxarg=2;
    narginchk(maxarg,maxarg);
    
    % return values
    states=[];
    quotes=[];
    
    % get starttime
    starttime=obj.getmarketstarttime(mticks(1,1));

    % find correct startq
    idx=obj.cleanquotes(mticks,starttime,obj.startscoretime(1),obj.startscoretime(2));
    if ~isempty(idx),
        quotes{1}=eval(mticks{idx(end),obj.DQUOTES}); % quote closest to starttime
        % find correct endq 
        idx=obj.cleanquotes(mticks,starttime,obj.ftscoretime(1),obj.ftscoretime(2));
        if ~isempty(idx),
            quotes{2}=eval(mticks{idx(end),obj.DQUOTES}); % quote closest to endtime
            % calc score
            states=betmat.quotestate(quotes{2},quotes{1});
        end
    end
    
end
function [states,quotes]=calcstatemoddsht(obj,mticks)
    
    maxarg=2;
    narginchk(maxarg,maxarg);
    
    % return values
    states=[];
    quotes=[];
    
    % get starttime
    starttime=obj.getmarketstarttime(mticks(1,1));

    % find correct startq
    idx=obj.cleanquotes(mticks,starttime,obj.startscoretime(1),obj.startscoretime(2));
    if ~isempty(idx),
        quotes{1}=eval(mticks{idx(end),obj.DQUOTES}); % quote closest to starttime
        % find correct endq 
        idx=obj.cleanquotes(mticks,starttime,obj.htscoretime(1),obj.htscoretime(2));
        if ~isempty(idx),
            quotes{2}=eval(mticks{idx(end),obj.DQUOTES}); % quote closest to httime
            % calc score
            states=betmat.quotestate(quotes{2},quotes{1});
        end
    end
    
end
function [states,quotes]=calcstatecorrectscore(obj,mticks)
    
    maxarg=2;
    narginchk(maxarg,maxarg);
    
    % return values
    states=[];
    quotes=[];
    
    % get starttime
    starttime=obj.getmarketstarttime(mticks(1,1));
    % find correct startq
    idx=obj.cleanquotes(mticks,starttime,obj.startscoretime(1),obj.startscoretime(2));
    if ~isempty(idx),
        quotes{1}=eval(mticks{idx(end),obj.DQUOTES}); % quote closest to starttime
        % find correct endq 
        idx=obj.cleanquotes(mticks,starttime,obj.ftscoretime(1),obj.ftscoretime(2));
        if ~isempty(idx),
            quotes{2}=eval(mticks{idx(end),obj.DQUOTES}); % quote closest to endtime
            % calc score
            states=betmat.quotestate(quotes{2},quotes{1});
        end
    end
    
end
function [states,quotes]=calcstatehtft(obj,mticks,doublecheckflag)
    
    narginchk(2,3);

    if nargin<3,
        doublecheckflag=false;
    end
    
    % return values
    states=[];
    quotes=[];
    % find match odds market id and ticks
    htftid=mticks(1,1);
    moid=getrelatedmarkets(obj,htftid,obj.markettypes(1));
    mticks=obj.getticks(moid);
    if ~isempty(mticks),
        statesft=obj.calcstatemodds(mticks);
        if doublecheckflag,
            % calculate ht from modds ticks
            statesht2=obj.calcstatemoddsht(mticks);
            states2=obj.htftconversion(statesht2,statesft);
        end
        if ~isempty(statesft), % find ht quote
            % find correct ht quote
            htid=getrelatedmarkets(obj,htftid,obj.markettypes(4));
            mticks=obj.getticks(htid);
            if ~isempty(mticks),
                % get starttime
                starttime=obj.getmarketstarttime(htftid);
                % find correct startq
                idx=obj.cleanquotes(mticks,starttime,obj.startscoretime(1),obj.startscoretime(2));
                if ~isempty(idx),
                    quotes{1}=eval(mticks{idx(end),obj.DQUOTES}); % quote closest to starttime
                     % find correct htq 
                    idx=obj.cleanquotes(mticks,starttime,obj.htscoretime(1),obj.htscoretime(2));
                    if ~isempty(idx),
                        quotes{2}=eval(mticks{idx(end),obj.DQUOTES}); % quote closest to htendtime
                        % calc score
                        statesht=betmat.quotestate(quotes{2},quotes{1});
                        if ~isempty(statesht),
                            % combine ft and ht to correct htft state
                            states=obj.htftconversion(statesht,statesft);
                        end
                    end
                end
            end
        end
    end
    % if doublecheck, combine states, states2
    if doublecheckflag && (isempty(states) || isempty(states2) || (states~=states2)),
        states=[];
    end

end

end % methods

%% static methods
methods (Static)

%% tick handling    
function idx=ticktime(mticktime,timefrom,timeto)
% select ticks within time frame
   
    idx=datenum(mticktime,backt.dbtimeformat);
    idx=(idx>=timefrom) & (idx<=timeto);

end
function idx=cleanquotes(mticks,starttime,timefrom,timeto,layflag)
% correct quote within time    

    if nargin<5,
        layflag=false;
    end
    timefrom=starttime+timefrom.*backt.cminute;
    timeto  =starttime+timeto.*backt.cminute;
    idx=find(backt.ticktime(mticks(:,2),timefrom,timeto)); % quotes within time
    if ~isempty(idx),
        idx=idx(cellfun(@(x) x(1)=='[',mticks(idx,backt.DQUOTES)));    % quotes w/o text
        if ~isempty(idx),
            if layflag,
                idx=idx(cellfun(@(x) isempty(strfind(x{1},'NaN')) && isempty(strfind(x{2},'NaN')),regexp(mticks(idx,backt.DQUOTES),';','split'))); % backq and layq w/o NaN
            else
                idx=idx(cellfun(@(x) isempty(x),strfind(strtok(mticks(idx,backt.DQUOTES),';'),'NaN'))); % backq w/o NaN 
            end
        end
    end
end
function [quote,idx]=randquote(mticks,starttime,timefrom,timeto,layflag)
% random quote within time    

    idx=backt.cleanquotes(mticks,starttime,timefrom,timeto,layflag);
    if ~isempty(idx),
        n=length(idx);
        idx=idx(fix(rand*n)+1);
        quote=eval(mticks{idx,backt.DQUOTES});
    else
        quote=[];
    end
end

end % static methods
            
end % classdef
