%% Class Betfair
% Access the Betfair Sports Exchange API

classdef (Sealed) betfair < hgsetget % reference class

%% constants
properties (Constant, ~Hidden)

    api_name         ='Betfair'
    api_ver          =6.0;
    api_freeproductId=82;
    locale           ='en';  % default language
    currencycode     ='EUR'; % default currency code
    
end
properties (Constant, ~Hidden)

% urls for wsdl endpoints
    endpoint_global        ='https://api.betfair.com/global/v3/BFGlobalService'
    endpoint_uk_exchange   ='https://api.betfair.com/exchange/v5/BFExchangeService'
    endpoint_aus_exchange  ='https://api-au.betfair.com/exchange/v5/BFExchangeService'
    
% public api
    betfair_api_global     ='http://www.betfair.com/publicapi/v3/BFGlobalService'
    betfair_api_uk_exchange='http://www.betfair.com/publicapi/v5/BFExchangeService'
    betfair_types          ='http://www.betfair.com/publicapi/types/exchange/v5/'

% api service objects
    globalService          =struct('endpoint',betfair.endpoint_global,'namespace',betfair.betfair_api_global);
    exchangeUK             =struct('endpoint',betfair.endpoint_uk_exchange,'namespace',betfair.betfair_api_uk_exchange);
    
end
%% properties
properties (Access=public, ~Hidden)

    sessionToken =[]  % default is logged out
    loginTime    =[]
    logoutTime   =[]
    proxySettings=[]
    
end
% dependent properties
properties (Dependent, SetAccess=protected, Hidden)
    
    APIRequestHeader
    
end
% dependent(get) functions
methods
function APIRequestHeader=get.APIRequestHeader(obj) 
    APIRequestHeader=struct('header',struct('clientStamp',0,'sessionToken',[]));
    APIRequestHeader.header.sessionToken=obj.sessionToken; % faster than init within struct
end
end

%% class internal methods
methods (Access=protected,Hidden)
function [response,errorcode]=callAPI(obj,apiURL,apifunstr,request)
%CallAPI Call function of the Betfair API and check for errors in response.

    %Create the message, make the call, and convert the response into a variable.
    soapMessage=betfair.createSoapMessageFast(apiURL.namespace,apifunstr,request);
    response=[];
    errorcode=[];
    try
        response=obj.callSoapServiceFast(apiURL.endpoint,apifunstr,soapMessage);
        response=parseSoapResponse(response); % call matlab function
    catch exception
        % throw error as warning
        %Error using ==> callSoapService at 148
        %SOAP Fault: INTERNAL_ERROR
        %MATLAB:callSoapService:Fault
        warning(exception.identifier,[exception.identifier,':',exception.message,'!']);
        errorcode=exception.message;
    end
    if isempty(errorcode),
        obj.sessionToken=response.header.sessionToken;
        %check response for API error
        if strcmpi(response.header.errorCode,'OK'),
            if any(strcmpi(fields(response),'errorCode')) && ~strcmpi(response.errorCode,'OK'), % if exists field response.errorCode, check for not 'ok'
               % if exists field response.errorCode, not equal 'ok', return error code, f.e. EVENT_SUSPENDED, EVENT_CLOSED, EVENT_INACTIVE
               %warning(['BETFAIR:' apifunstr],['BETFAIR:' apifunstr ':error header "' response.header.errorCode '" errorCode "' response.errorCode '"!']);
               errorcode=response.errorCode;
            end
        elseif strcmpi(response.header.errorCode,'EXCEEDED_THROTTLE'),
            errorcode=response.header.errorCode;
        else % severe error
            %errorcode=response.header.errorCode;
            error(['Betfair:' apifunstr],['Betfair:' apifunstr ':error "' response.header.errorCode '"!']);
        end
    end
end
function response=callSoapServiceFast(obj,endpoint,soapAction,message)
    %java
    import java.io.*;
    import java.net.*;
    import com.mathworks.mlwidgets.io.InterruptibleStreamCopier;
    %message
    m=java.lang.String(message).getBytes('UTF8');
    %connection
    endpoint=URL(endpoint);
    %proxy
    if isempty(obj.proxySettings)
        c=endpoint.openConnection();
    else
        c=endpoint.openConnection(obj.proxySettings);
    end
    c.setRequestProperty('Content-Type','text/xml; charset=utf-8');
    c.setRequestProperty('SOAPAction',soapAction);
    c.setRequestMethod('POST');
    c.setDoOutput(true);
    c.setDoInput(true);
    %send
    try
        s=c.getOutputStream;
        s.write(m);
        s.close;
    catch e
        error(e.message);
    end
    %receive
    try
        inputStream=c.getInputStream;
        byteArrayOutputStream=java.io.ByteArrayOutputStream;
        isc=InterruptibleStreamCopier.getInterruptibleStreamCopier;
        isc.copyStream(inputStream,byteArrayOutputStream);
        inputStream.close;
        byteArrayOutputStream.close;
    catch e
        error(e.message);
    end
    %convert to char
    response=char(byteArrayOutputStream.toString('UTF-8'));
end
end
methods (Static,Access=protected,Hidden)
function soapmsg=createSoapMessageFast(tns,methodname,values)
%CREATESOAPMESSAGE Create a SOAP message for the BETFAIR server.

%envelope
soapmsg=['<?xml version="1.0" encoding="utf-8"?><soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:bfex="',tns,'"><soapenv:Body><bfex:',methodname,'><request>'];
%body
soapmsg=[soapmsg,createxml(values)];
%tail
soapmsg=[soapmsg,'</request></bfex:',methodname,'></soapenv:Body></soapenv:Envelope>'];

    function xml=createxml(values)
        xml=[];
        names=fieldnames(values);
        vals=struct2cell(values);
        for i=1:numel(names),
            if ~isstruct(vals{i}),
                if isnumeric(vals{i}),
                    val=num2str(vals{i});
                else
                    val=char(vals{i});
                end
                xml=[xml,'<',names{i},'>',val,'</',names{i},'>']; %#ok<AGROW>
            else
                xml=[xml,'<',names{i},'>',createxml(vals{i}),'</',names{i},'>']; %#ok<AGROW>
            end
        end
    end
end
end

%% public methods
methods (Access=public)

%constructor
function obj=betfair(username,password,productId,loginflag)
%BETFAIR Constructor obj=betfair(username,password).

    if nargin>0, % necessary for matlab constructors
        
        MaxArg=4;
        narginchk(2,MaxArg);
        if nargin<MaxArg,
            loginflag=true;
            if nargin<MaxArg-1,
                productId=betfair.api_freeproductId;
            end
        end
        %set proxy settings
        com.mathworks.mlwidgets.html.HTMLPrefs.setProxySettings
        obj.proxySettings=com.mathworks.net.transport.MWTransportClientPropertiesFactory.create().getProxy();
        if loginflag,
            %login
            fprintf('Login to %s API v%3.1f ...',obj.api_name,obj.api_ver);
            tic;
            obj.login(username,password,productId);
            fprintf('%5.2f sec\n',toc);
        end
        %timezone
        %up=obj.viewprofile;
        %if strcmpi(up.timeZone,'GMT'),
        %    obj.timezoneadj=0;
        %else
        % calibrate to local timezone
        %import java.util.Calendar;
        %z=Calendar.getInstance.getTimeZone;
        %obj.timezoneadj=datenum(0,0,0,(z.getRawOffset+z.getDSTSavings)./3.6e6,0,0); % local timezone offset + daylight savings in ms
        %api seems to deliver daylight saving in time
        %obj.timezoneadj=datenum(0,0,0,(z.getRawOffset)./3.6e6,0,0); % local timezone offset + daylight savings in ms
        %end

    end

end
%destructor
function delete(obj)
    if ~isempty(obj.loginTime),
        try
            obj.logout;
        catch %#ok<CTCH>
            warning('BETFAIR:DESTRUCTOR','BETFAIR:DESTRUCTOR - unable to logout!')
        end;
    end
end

%methods
function disp(obj)
%DISPLAY Display BETFAIR object.

    if ~isempty(obj.loginTime),
        fprintf('Logged in@%s\n',datestr(obj.loginTime));
        if ~isempty(obj.logoutTime),
            fprintf('Logged out@%s\n',datestr(obj.logoutTime));
        end
    else
        fprintf('Status: Not Logged in\n');
    end

end

%% general methods
function login(obj,username,password,productId)
%LOGIN Login to BETFAIR API.

    narginchk(3,4); % including obj
    if nargin<4,
        productId=betfair.api_freeproductId;
    end
    request=struct('username',username,'password',password,'productId',productId, ...
                    'vendorSoftwareId',0,'locationId',0,'ipAddress',0);
    response=obj.callAPI(obj.globalService,'login',request);
    if ~isstruct(response),
        obj.loginTime=[];
    else
        obj.loginTime=obj.timestampstr2datenum(response.header.timestamp);
    end
end
function logout(obj)
%LOGOUT Logout of BETFAIR API session.

    response=obj.callAPI(obj.globalService,'logout',obj.APIRequestHeader);
    if ~isstruct(response),
        obj.logoutTime=[];
    else
        obj.logoutTime=obj.timestampstr2datenum(response.header.timestamp);
    end
    obj.sessionToken=[];
    
end
function okflag=keepalive(obj)
%KEEPALIVE heartbeat the BETFAIR API session.

    response=obj.callAPI(obj.globalService,'keepAlive',obj.APIRequestHeader);
    okflag=~isempty(response);
end
function okflag=keepaliveandrelog(obj,username,password)
%KEEPALIVEANDRELOG Keep alive the connection to the API.
    
    okflag=false;
    try
        okflag=obj.keepalive; % keep alive the api
    catch ME
        if strcmp(ME.identifier,'Betfair:keepAlive'),
            fprintf('ReLogin to %s API v%3.1f ...',obj.api_name,obj.api_ver);
            t=tic;
            try
                obj.login(username,password); % login again
                fprintf('%5.2f sec\n',toc(t));
                okflag=true;
            catch ME
                fprintf('%5.2f sec - %s!\n',toc(t),ME.message); % close tic
            end
        else
            fprintf('%s!\n',ME.message);
            %rethrow(ME);
        end
    end
    
end 
function apitime=getapitime(obj) % all times are returned in GMT
    %obj.keepalive;
    response=obj.callAPI(obj.globalService,'keepAlive',obj.APIRequestHeader);
    if ~isstruct(response),
        apitime=[];
    else
        % return time
        apitime=obj.timestampstr2datenum(response.header.timestamp);
    end
end

%events
function eventtypes=getactiveeventtypes(obj)
%GetActiveEventTypes Returns an array of eventTypeItems.
    
    narginchk(1,1); % including obj
    request=obj.APIRequestHeader;
    request.locale=betfair.locale;
    response=obj.callAPI(obj.globalService,'getActiveEventTypes',request);
    
    if isempty(response),
        eventtypes=[];
    else
        eventtypes=[{response.eventTypeItems.EventType.id}' {response.eventTypeItems.EventType.name}'];
    end
 
end
function eventtypes=getalleventtypes(obj)
%GetAllEventTypes Returns an array of eventTypeItems.
    
    narginchk(1,1); % including obj
    request=obj.APIRequestHeader;
    request.locale=betfair.locale;
    response=obj.callAPI(obj.globalService,'getAllEventTypes',request);
    
    if isempty(response),
        eventtypes=[];
    else
        eventtypes=[{response.eventTypeItems.EventType.id}' {response.eventTypeItems.EventType.name}'];
    end
 
end

%markets
function marketdata=getallmarkets(obj,fromdate,todate,eventtypeids)
%GETALLMARKETS Get a cell-array of eventTypeItems.
    
    MinArg=1; % obj + 1
    MaxArg=4;
    narginchk(MinArg,MaxArg); % including obj
    
    request=obj.APIRequestHeader;
    request.locale=betfair.locale;
    if nargin>MinArg,
        request.fromDate=betfair.datenum2timestampstr(datenum(fromdate)); % 1st Element of Array
        if nargin>MinArg+1,
            request.toDate=betfair.datenum2timestampstr(datenum(todate));
            if nargin>MinArg+2,
                request.eventTypeIds.int=eventtypeids;
            end
        end
    end
    response=obj.callAPI(obj.exchangeUK,'getAllMarkets',request);

    if isempty(response) || strcmp(response.marketData,''),
        marketdata=[];
    else
        %marketdata is compressed
        marketdata=response.marketData;
        if ~isempty(marketdata),
            if marketdata(1)==':',
                marketdata=marketdata(2:end);
            end
            % structures
            struct_fields={'marketID','marketName','marketType','marketStatus',...
                'eventDate','menuPath','eventHierarchy','betDelay','exchangeID',...
                'ISO3CountryCode','lastRefresh','numberRunners','numberWinners',...
                'totalAmountMatched','BSPMarket','TurningInPlay','lastRefreshDateStr',...
                'eventDateStr'};
            % find market by delimiter ':','~' but not '\:','\~'
            idxfield=regexp(marketdata,'(?<!\\)[~:]','split');
            n=length(struct_fields)-2; % 2 fields are created
            idxfield=reshape(idxfield,n,length(idxfield)./n);
            idxfield(end+1,:)=arrayfun(@(x) betfair.timestamp2datestr(x),idxfield(11,:),'UniformOutput',false);
            idxfield(end+1,:)=arrayfun(@(x) betfair.timestamp2datestr(x),idxfield(5,:),'UniformOutput',false);
            marketdata=cell2struct(idxfield,struct_fields,1);
        end
    end
    
end
function [marketdata,errorcode]=getmarket(obj,marketid)
%GETMARKET Get a cell-array of static market data.
    
    narginchk(2,2); % including obj
    
    request=obj.APIRequestHeader;
    request.marketId=marketid;
    request.locale=betfair.locale;
    response=obj.callAPI(obj.exchangeUK,'getMarket',request);

    marketdata=[];
    errorcode=[];
    if ~isempty(response),
        if ~strcmpi(response.errorCode,'OK'),
            errorcode=response.errorCode;
        elseif strcmpi(response.market.marketStatus,'CLOSED'),
            marketdata=response.market.marketStatus;
        elseif ~strcmp(response.market.runners,''),
            marketdata={response.market.runners.Runner.name;
                        response.market.runners.Runner.selectionId}';
            marketdata(:,2)=cellfun(@(x) {num2str(x)},marketdata(:,2));
        end
    end
end
function [marketdata,errorcode]=getmarketinfo(obj,marketid)
%GETMARKET Get a cell-array of static market data.
    
    narginchk(2,2); % including obj
    
    request=obj.APIRequestHeader;
    request.marketId=marketid;
    request.locale=betfair.locale;
    response=obj.callAPI(obj.exchangeUK,'getMarketInfo',request);

    marketdata=[];
    errorcode=[];
    if ~isempty(response),
        if ~strcmpi(response.errorCode,'OK'),
            errorcode=response.errorCode;
        else
            marketdata=response.marketLite;
        end
    end
end

%prices
function [marketprices,marketpricesbest3,selectionid,amountmatched,timestamp,ipdelay,lastpricematched,SPprice]=getmarketprices(obj,marketid)
%GETMARKETPRICES Get a cell-array of marketprices.
    
    narginchk(2,2); % including obj
    
    request=obj.APIRequestHeader;
    request.marketId=marketid;
    request.currencyCode=betfair.currencycode;
    [response,errorcode]=obj.callAPI(obj.exchangeUK,'getMarketPricesCompressed',request);

    %getMarketPricesCompressed CLOSED,SUSPENDED,INACTIVE show up in status
    %getCompleteMarketPricesCompressed EVENT_CLOSED,EVENT_SUSPENDED,EVENT_INACTIVE show up as secondary error
    marketprices=[];
    marketpricesbest3=[];
    selectionid=[];
    amountmatched=[];
    timestamp=[];
    ipdelay=[];
    lastpricematched=[];
    SPprice=[];
    if ~isempty(errorcode), % check for secondary error
        marketprices=errorcode;
    elseif ~isempty(response),
        timestamp=obj.timestampstr2datenum(response.header.timestamp);
        % process structure of marketprices
        %struct_marketPricesRunnerPrices= struct('price',[],'backAmount',[],'layAmount',[],'totalBSPBackAmount',[],'totalBSPLayAmount',[]);
        idxmarket=regexp(response.marketPrices,'(?<!\\):','split'); % find market by delimiter ':' but not '\:'
        % analyze market status
        marketinfo=regexp(idxmarket{1},'(?<!\\)\~','split');
        if ~strcmpi(marketinfo(3),'ACTIVE'),
            marketprices=['EVENT_',marketinfo{3}];
        else % analyze prices
            ipdelay=str2double(marketinfo{4});
            n=length(idxmarket)-1; % first market is market id and delay info
            % structure memory pre-allocation
            marketprices=NaN(4,n);
            marketpricesbest3=repmat({NaN(4,3)},n,1);
            selectionid=cell(1,n);
            amountmatched=NaN(1,n);
            lastpricematched=NaN(1,n);
            SPprice=NaN(3,n);
            orderidx=NaN(1,n); % table for missing order index information
            % loop over runner information
            for i=1:n,
                % runner information fields
                idxrunnerinfo=regexp(idxmarket{i+1},'(?<!\\)\|','split'); % runner information pipe delimiter
                idx=regexp(idxrunnerinfo{1},'(?<!\\)~','split');  % info fields have ~ delimiter
                orderidx(i)=str2double(idx(2)); % item order, '' or empty gives NaN
                selectionid(i)=idx(1);
                amountmatched(i)=str2double(idx(3));
                lastpricematched(i)=str2double(idx(4));
                SPprice(1,i)=str2double(idx(10)); % actual SP price
                SPprice(2,i)=str2double(idx(9)); % near SP price
                SPprice(3,i)=str2double(idx(8)); % far SP price
                % runner prices
                % best back prices
                if ~isempty(idxrunnerinfo{2}),
                    if idxrunnerinfo{2}(end)=='~',
                        idxrunnerinfo{2}=idxrunnerinfo{2}(1:end-1); % delete delimiter at end
                    end
                    idx=regexp(idxrunnerinfo{2},'(?<!\\)~','split');  % prices have ~ delimiter
                    idx=reshape(idx,2,length(idx)./2);
                    idx=str2double(idx(:,1:2:end));
                    marketprices(1,i)=idx(1,1);
                    marketprices(3,i)=idx(2,1); % back amount available
                    cols=1:size(idx,2);
                    marketpricesbest3{i}(1,cols)=idx(1,cols);
                    marketpricesbest3{i}(3,cols)=idx(2,cols);
                end
                % best lay prices
                if ~isempty(idxrunnerinfo{3}),
                    if idxrunnerinfo{3}(end)=='~',
                        idxrunnerinfo{3}=idxrunnerinfo{3}(1:end-1); % delete delimiter at end
                    end
                    idx=regexp(idxrunnerinfo{3},'(?<!\\)~','split');  % prices have ~ delimiter
                    idx=reshape(idx,2,length(idx)./2);
                    idx=str2double(idx(:,1:2:end));
                    marketprices(2,i)=idx(1,1);
                    marketprices(4,i)=idx(2,1); % lay amount available
                    cols=1:size(idx,2);
                    marketpricesbest3{i}(2,cols)=idx(1,cols);
                    marketpricesbest3{i}(4,cols)=idx(2,cols);
                end
            end
            % check for correct order in quotes
            if ~all(diff(orderidx)==1), % is not sorted or NaNs
                idx=isnan(orderidx);
                if any(idx),
                    if sum(idx)==1,
                        fprintf('BETFAIR:GETMARKETPRICES:Order index reconstructed!\n');
                    else
                        % 2 missing orderindices - should never happen
                        fprintf('BETFAIR:GETMARKETPRICES:Order index cannot be reconstructed!\n');
                    end
                    %orderidx(idx)=setdiff(1:length(orderidx),orderidx);
                    orderidxtab=true(1,length(orderidx));
                    for i=find(~idx),
                        orderidxtab(orderidx(i))=false;
                    end
                    orderidx(idx)=find(orderidxtab);
                end                
                % re-sort according to orderindex
                [~,idx]=sort(orderidx); % start index with 1 and re-sort, NaN at end
                marketprices=marketprices(:,idx);
                marketpricesbest3=marketpricesbest3(idx);
                selectionid=selectionid(idx);
                amountmatched=amountmatched(idx);
                lastpricematched=lastpricematched(:,idx);
                SPprice=SPprice(:,idx);
            end
            if all(isnan(SPprice(:))),
                SPprice=[];
            end
        end
    end
    
end
function [marketpricescomplete,marketprices,selectionid,amountmatched,timestamp,ipdelay]=getcompletemarketprices(obj,marketid)
%GETCOMPLETEMARKETPRICES Get a cell-array of marketprices and ladder.
    
    narginchk(2,2); % including obj
    
    request=obj.APIRequestHeader;
    request.marketId=marketid;
    request.currencyCode=betfair.currencycode;
    [response,errorcode]=obj.callAPI(obj.exchangeUK,'getCompleteMarketPricesCompressed',request);

    %getMarketPricesCompressed CLOSED,SUSPENDED,INACTIVE show up in status
    %getCompleteMarketPricesCompressed EVENT_CLOSED,EVENT_SUSPENDED,EVENT_INACTIVE show up as secondary error
    marketpricescomplete=[];
    marketprices=[];
    selectionid=[];
    amountmatched=[];
    timestamp=[];
    ipdelay=[];
    if ~isempty(errorcode), % check for secondary error, f.e. EVENT_CLOSED,EVENT_SUSPENDED,EVENT_INACTIVE
        marketpricescomplete=errorcode;
    elseif ~isempty(response),
        timestamp=obj.timestampstr2datenum(response.header.timestamp);
        % process structure of marketprices
        %struct_marketPricesRunnerPrices= struct('price',[],'backAmount',[],'layAmount',[],'totalBSPBackAmount',[],'totalBSPLayAmount',[]);
        idxmarket=regexp(response.completeMarketPrices,'(?<!\\):','split'); % find market by delimiter ':' but not '\:'
        % analyze market status
        marketinfo=regexp(idxmarket{1},'(?<!\\)\~','split');
        ipdelay=str2double(marketinfo{2});
        % analyze prices
        n=length(idxmarket)-1; % first market is market id and delay info
        % structure memory pre-allocation
        marketprices=NaN(4,n);
        marketpricescomplete=cell(n,1);
        selectionid=cell(1,n);
        amountmatched=NaN(1,n);
        orderidx=NaN(1,n); % table for missing order index information
        % loop over runner information
        for i=1:n,
            % runner information fields
            idxrunnerinfo=regexp(idxmarket{i+1},'(?<!\\)\|','split'); % runner information pipe delimiter
            idx=regexp(idxrunnerinfo{1},'(?<!\\)~','split');  % info fields have ~ delimiter
            orderidx(i)=str2double(idx(2)); % item order
            selectionid(i)=idx(1);
            amountmatched(i)=str2double(idx(3));
            % runner prices
            if ~isempty(idxrunnerinfo{2}),
                if idxrunnerinfo{2}(end)=='~',
                    idxrunnerinfo{2}=idxrunnerinfo{2}(1:end-1); % delete delimiter at end
                end
                idx=regexp(idxrunnerinfo{2},'(?<!\\)~','split');  % prices have ~ delimiter
                idx=str2double(reshape(idx,5,length(idx)./5))';
                % complete prices
                marketpricescomplete(i,1)={idx(:,1:3)};
                % best back price
                [c,pos]=max(idx(logical(idx(:,2)),1)); 
                if ~isempty(c),
                    marketprices(1,i)=c;
                    marketprices(3,i)=idx(pos,2); % back amount available
                else
                    pos=0; % start for lay amount is 1
                end
                % best lay price
                c=min(idx(logical(idx(:,3)),1)); 
                if ~isempty(c),
                    marketprices(2,i)=c;
                    marketprices(4,i)=idx(pos+1,3); % lay amount available
                end
            end
        end
        % check for correct order in quotes
        if ~all(diff(orderidx)==1), % is not sorted or NaNs
            idx=isnan(orderidx);
            if any(idx),
                if sum(idx)==1,
                    fprintf('BETFAIR:GETMARKETPRICES:Order index reconstructed!\n');
                else
                    % 2 missing orderindices - should never happen
                    fprintf('BETFAIR:GETMARKETPRICES:Order index cannot be reconstructed!\n');
                end
                orderidxtab=true(1,length(orderidx));
                for i=find(~idx),
                    orderidxtab(orderidx(i))=false;
                end
                orderidx(idx)=find(orderidxtab);
            end                
            % re-sort according to orderindex
            [~,idx]=sort(orderidx); % start index with 1 and re-sort, NaN at end
            marketpricescomplete=marketpricescomplete(idx);
            marketprices=marketprices(:,idx);
            selectionid=selectionid(idx);
            amountmatched=amountmatched(idx);
        end
    end
end

%bets and PnL
function [betresults,timestamp]=placebets(obj,marketid,selectionid,bettype,limitprice,betsize)
%PLACE BETS Place multiple bets on a single market.
%Example     betfairobj.placebets('104588301','47999','B',2.2,2)
%Conditions  size >= 2 EUR    
%            price must fullfill increment intervall
%Results
%    averagePriceMatched: 2.20
%                  betId: '17786663671'
%             resultCode: 'OK'
%            sizeMatched: 0.40
%                success: 1
%Error
%    averagePriceMatched: 0
%                  betId: '0'
%             resultCode: 'INVALID_SIZE' %'INVALID_INCREMENT'
%            sizeMatched: 0
%                success: 0
%Error
%back quote higher than best in book
%    averagePriceMatched: 0
%                  betId: '17944469661'
%             resultCode: 'OK'
%            sizeMatched: 0
%                success: 1

    narginchk(6,6); % including obj

    request=obj.APIRequestHeader;
    request.bets.PlaceBets=struct('asianLineId',0, ...
        'betType',bettype,'betCategoryType','E', ...
        'betPersistenceType','NONE','marketId',marketid,'price',limitprice, ...
        'selectionId',selectionid,'size',betsize,'bspLiability',0);
   
    [response,errorcode]=obj.callAPI(obj.exchangeUK,'placeBets',request);
    if ~isstruct(response),
        timestamp=[];
    else
        timestamp=obj.timestampstr2datenum(response.header.timestamp);
    end
    betresults=[];
    if ~isempty(errorcode), % check for secondary
        betresults=errorcode;
    elseif ~isempty(response),
        betresults=response.betResults.PlaceBetsResult;
    end    
end
function [betresults,timestamp]=placebetsim(~,~,~,~,price,betsize)
%PLACE BET SIMULATOR Place simulated bets on a single market.
    
    narginchk(6,6); % including obj
    betresults=struct('betId',num2str(fix(rand*10^9)+10^10), ...
                      'resultCode','OK', ...
                      'sizeMatched',betsize,...%fix(rand*betsize)+1, ...
                      'averagePriceMatched',betfair.increments(price.*(1-rand./100)), ...
                      'success',1);
    timestamp=now;
end
function betresults=getbet(obj,betid)
%GET BET Get a single bet from a settled market.

    narginchk(2,2); % including obj
    
    request=obj.APIRequestHeader;
    request.betId=betid;
    request.locale=betfair.locale;

    [response,errorcode]=obj.callAPI(obj.exchangeUK,'getBet',request);

    betresults=[];
    if ~isempty(errorcode), % check for secondary
        betresults=errorcode;
    elseif ~isempty(response),
        betresults=response.bet;
    end    
end
function betresults=getmubets(obj,betstatus,marketid)
%GET MATCHED AND UNMATCHED BETS from a single market.

    narginchk(1,3); % including obj
    if nargin<2,
        betstatus='MU';
    end
    request=obj.APIRequestHeader;
    request.betStatus=betstatus;
    if nargin>2,
        request.marketId=marketid;
    end
    request.orderBy='NONE';%'MATCHED_DATE';
    request.sortOrder='ASC';
    request.recordCount=200;
    request.startRecord=0;
    [response,errorcode]=obj.callAPI(obj.exchangeUK,'getMUBets',request);

    betresults=[];
    if ~isempty(errorcode), % check for secondary
        betresults=errorcode;
    elseif ~isempty(response),
        betresults=response.bets.MUBet;
    end    
end
function betresults=cancelbets(obj,betid)
%CANCEL BETS Cancel unmatched bets.
%Results
%            betId: '17944528739'
%       resultCode: 'REMAINING_CANCELLED'
%    sizeCancelled: 2
%      sizeMatched: 0
%          success: 1
%Error
%            betId: '17944469661'
%       resultCode: 'TAKEN_OR_LAPSED'
%    sizeCancelled: 0
%      sizeMatched: 0
%          success: 0

    narginchk(2,2); % including obj
    
    request=obj.APIRequestHeader;
    request.bets.CancelBets.betId=betid;
    [response,errorcode]=obj.callAPI(obj.exchangeUK,'cancelBets',request);

    betresults=[];
    if ~isempty(errorcode), % check for secondary
        betresults=errorcode;
    elseif ~isempty(response),
        betresults=response.betResults.CancelBetsResult;
    end    
end
function betresults=cancelbetsbymarket(obj,marketid) % not available in free API
%CANCEL BETS BY MARKET Cancel all unmatched bets placed on one or more markets.
%Results
%Error

    narginchk(2,2); % including obj
    
    request=obj.APIRequestHeader;
    request.markets.int=marketid;
    [response,errorcode]=obj.callAPI(obj.exchangeUK,'cancelBetsByMarket',request);

    betresults=[];
    if ~isempty(errorcode), % check for secondary
        betresults=errorcode;
    elseif ~isempty(response),
        betresults=response.results.CancelBetsResult;
    end    
end
function [betresults,unmatchedbets]=cancelbetsall(obj,marketid)
%CANCEL BETS ALL Cancel all unmatched bets (of a market).

    narginchk(1,2); % including obj
    
    if nargin<2,
        unmatchedbets=obj.getmubets('U'); % get all markets
    else
        unmatchedbets=obj.getmubets('U',marketid);
    end
    
    betresults=[];
    if ~strcmpi(unmatchedbets,'NO_RESULTS'),
        betresults=obj.cancelbets(unmatchedbets(1).betId); % create structure
        for i=2:numel(unmatchedbets), % loop thru structure
            betresults(i)=obj.cancelbets(unmatchedbets(i).betId);
        end    
    end

end
function marketpnl=getmarketprofitandloss(obj,marketid)
%GETMARKETPROFITANDLOSS Get Market Profit and Loss.
    
    narginchk(2,2); % including obj
    
    request=obj.APIRequestHeader;
    request.marketId=marketid;
    request.locale=betfair.locale;
    request.includeBSPBets=0;%'FALSE';
    [response,errorcode]=obj.callAPI(obj.exchangeUK,'getMarketProfitAndLoss',request);

    marketpnl=[];
    if ~isempty(errorcode), % check for secondary
        marketpnl=errorcode;
    elseif ~isempty(response),
        marketpnl=response;
    end    
end
function [exptotal,expback,explay]=getmatchedbetexposures(obj)
%GET MATCHED BET EXPOSURES

    narginchk(1,1); % including obj
    
    [~,~,exptotal]=getaccountfunds(obj);
    expback=0;
    explay=0;
    mbets=obj.getmubets('M'); % get all matched bets
    if isstruct(mbets),% && ~(ischar(mbets) && strcmpi(mbets,'NO_RESULTS')),
        % calc exposures
        idx=cat(1,mbets.betType)=='B';
        expback=betmat.nansum(cat(1,mbets(idx).size)); % back exposure
        explay=exptotal-expback;
    end
end

%account management
function [balance,availbalance,exposure,accountresults]=getaccountfunds(obj)
%GETACCOUNTFUNDS

    narginchk(1,1); % including obj
    
    request=obj.APIRequestHeader;
    [response,errorcode]=obj.callAPI(obj.exchangeUK,'getAccountFunds',request);

    balance=NaN;
    availbalance=NaN;
    exposure=NaN;
    accountresults=[];
    if ~isempty(errorcode), % check for secondary
        accountresults=errorcode;
    elseif ~isempty(response),
        balance=response.balance;
        availbalance=response.availBalance;
        exposure=abs(response.exposure);
        accountresults=rmfield(response,'header');
    end    
end
function userprofile=viewprofile(obj)
%GetActiveEventTypes Returns an array of eventTypeItems.
    
    narginchk(1,1); % including obj
    
    request=obj.APIRequestHeader;
    response=obj.callAPI(obj.globalService,'viewProfile',request);
    
    if isempty(response),
        userprofile=[];
    else
        userprofile=rmfield(response,{'header','errorCode','minorErrorCode'});
    end
 
end

end % methods

%% class external static methods
methods (Static, Access=public)

%date and time methods
function dn=timestampstr2datenum(ts)
    dn=datenum(ts,'yyyy-mm-ddTHH:MM:SS.FFF');
end
function ts=datenum2timestampstr(n)
    ts=datestr(n,'yyyy-mm-ddTHH:MM:SS.FFFZ');
end
function dn=timestampstr2datenum2(ts)
    dn=datenum(ts,'yyyy-mm-dd HH:MM:SS.FFF');
end
function ts=datenum2timestampstr2(n)
    ts=datestr(n,'yyyy-mm-dd HH:MM:SS.FFF');
end
function str=timestamp2datestr(ts)
%TIMESTAMP2STR Convert timestamp to date string format.

ts=str2double(char(ts));
str=datestr(ts./(24000*60*60)+datenum(1970,1,1),'yyyy-mm-dd HH:MM:SS.FFF');
%import java.sql.Timestamp;
%str=char(java.sql.Timestamp(ts)); % java uses daylight saving and location
end
function ts=datestr2timestamp(str)
%STR2TIMESTAMP Convert date string to timestamp.

ts=(datenum(str)-datenum(1970,1,1)).*(24000*60*60);
%import java.sql.Timestamp;
%ts=java.sql.Timestamp.valueOf(str); % java uses daylight saving and location
%ts=num2str(ts.getTime);
end
function dn=timestamp2datenum(ts)
%TIMESTAMP2DATENUM Convert timestamp to matlab serial date number.

    dn=datenum(betfair.timestamp2datestr(ts),'yyyy-mm-dd HH:MM:SS.FFF');
end
function ts=datenum2timestamp(dn)
%DATENUM2TIMESTAMP Convert matlab serial date number to timestamp.

    ts=betfair.datestr2timestamp(datestr(dn,'yyyy-mm-dd HH:MM:SS.FFF'));
end

%exchange api support methods
function [eventids,eventnames]=geteventid(eventtypes,searchstr)
%GETEVENTID from event list.    
    if isempty(eventtypes),
        eventids=[];
    else
        idx=logical(cellfun(@(x) ~isempty(x),regexpi(eventtypes(:,2),searchstr)));
        eventids=cell2mat(eventtypes(idx,1));
        eventnames=eventtypes(idx,2);
    end
end
function bfprice=increments(price)
    %for asian handicap and total goal markets
    %inc=[1.01:0.01:1000];
    %for odds markets
    %http://help.betfair.com/contents/itemId/i65767327/index.en.html
    inc=[1.01:.01:2, 2.02:.02:3, 3.05:.05:4, 4.1:.1:6, 6.2:.2:10, 10.5:.5:20, 21:1:30, 32:2:50, 55:5:100, 110:10:1000];
    idx=find(inc<=price,1,'last');
    if isempty(idx),
        idx=1;
    end
    bfprice=inc(idx);
end

end % static methods
end % classdef
