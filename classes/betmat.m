%% Class BetMaths

classdef (~Sealed) betmat < hgsetget % reference class

%% Constants
properties (Constant, GetAccess=public)
    
    % market states
    ftoddstr  ={'1','2','X'};
    htftoddstr={'1/1','1/X','1/2','X/1','X/X','X/2','2/1','2/X','2/2'};
    
end

%% static methods
methods (Static)

%% misc
function y=nansum(x,dim)
    x(isnan(x))=0;
    if nargin==1 % let sum figure out which dimension to work along
        y=sum(x);
    else         % work along the explicitly given dimension
        y=sum(x,dim);
    end
end
function y=nancumsum(x)
    x(isnan(x))=0;
    y=cumsum(x);
end
function [y,count,sidx]=uniquefast(x)
    [x,sidx]=sort(x);
    idx=diff(x)~=0;
    count=diff([0,find(idx),length(idx)+1]);
    idx=[true,idx];
    y=x(idx);
    sidx=sidx(idx);
end
function y=roundxdec(x,e)
    if nargin<2,
        e=2;
    end
    e=10.^e;
    y=round(x.*e)./e;
end
function y=discreturn(x)
%DISCRETE RETURN.
    y=x(2)./x(1)-1;
end
%% pnl
function y=pnlmat(q,w)
    %as inline function
    %payoffm=@(q,w) bsxfun(@minus,diag(q(:).*w(:)),w(:)); % payoff matrix w>0 .. back, w<0 .. lay
    y=bsxfun(@minus,diag(q(:).*w(:)),w(:));
end
function y=pnlsum(q,w)
    %as inline function
    %pnlm=@(q,w) nansum(bsxfun(@minus,diag(q(:).*w(:)),w(:)),2); % pnl of payoff matrix per state
    y=betmat.nansum(bsxfun(@minus,diag(q(:).*w(:)),w(:)),1);
end
function y=pnltrade(qbuy,qsell,w)
    y=sum((qbuy./qsell-1).*w); 
end
function [y,cashoutw]=pnlcashoutquotes(qbuy,w,qsell) % dutching
    qmix=betmat.quotemix(qsell(1,:),qsell(2,:),-w); % lay is closed w back
    cashoutw=betmat.roundxdec(-w.*qbuy./qmix);
    y=betmat.pnlsum(qbuy,w)+betmat.pnlsum(qmix,cashoutw);
end
function [y,cashoutw]=pnlcashoutexposure(exposure,qsell)
    qmix=betmat.quotemix(qsell(1,:),qsell(2,:),-exposure); % lay is closed w back
    cashoutw=betmat.roundxdec(-exposure./qmix,2);
    y=exposure+betmat.pnlsum(qmix,cashoutw);
end
%% quotes
function q=quotemix(qback,qlay,w)
    q=qback;
    q(w<0)=qlay(w<0);
end
function q=quotenans(q)
% Correct lay quotes for NaNs and zeros
    %q(1,(q(1,:)==0) | isnan(q(1,:)))=1;
    q(2,(q(2,:)==0) | isnan(q(2,:)))=1000;
end
function state=quotestate(qend,qstart)
% Estimate state from quotes

    qback=qend(1,:);
    state=qstate(qback); % min of backquote is most reliable
    if isempty(state) || ( qback(state)>qstart(1,state) ), % end quote is higher
        %qend=betmat.quotenans(qend);
        qlay=qend(2,:); % back quote not reliable, try lay quote
        state=qstate(qlay); 
        if ~isempty(state) && ( qlay(state)>qstart(2,state) ), % end quote is higher
            state=[];
        end
    end
    
    % nested function
    function state=qstate(quote)
        % find unique minimum
        [quniq,count,sidx]=betmat.uniquefast(quote);
        idx=find(count==1); % any unique quote
        if ~isempty(idx), % min of unique quotes
            [~,pos]=min(quniq(idx));
            state=sidx(idx(pos));
        else
            state=[];
        end
    end
end
%% statistics
function y=bookval(q)
% BOOK'S VALUE Overround vs Overbroke.
    y=sum(1./q);
end
function y=bookvalflag(q,ovrround,backlaycheck)
    y=betmat.bookval(q(1,:))>ovrround;
    if backlaycheck==2,
        y=y || (betmat.bookval(q(2,:))<(2*fix(ovrround)-ovrround)); % if ovrrnd==inf, x<NaN->false
    end
end
function y=bookval3(q3,num,backlaycheck)
% BOOK'S VALUE Overround vs Overbroke.
    y=betmat.bookval(cellfun(@(x) x(backlaycheck,num),q3));
end
function y=herfindahl(q)
% Herfindahl-Hirschman-Index
    y=1./q;      % get p
    %y=y./sum(y); % normalize
    %y=sum(y.^2); % HHI
    y=sum(bsxfun(@rdivide,y,betmat.nansum(y,2)).^2,2); % matrix
end
function [m,s]=binomstat(n,p)
% BINOMSTAT Mean and standard deviation of the binomial distribution.
m=n.*p;
s=sqrt(n.*p.*(1-p));
end
%% movg avg
function y=movsum(v,t)
    y=filter(ones(1,t),1,v);
end
function y=movavgexp(v,t)
    
    %y=tsmovavg(v,'e',t,1); % matlab function: Uses simple moving average as start value!!!
    %x=movavg(v,300,300,'e'); % matlab function
    
    emalpha=2./(t+1);  % emadays to ema-alpha
    y=zeros(size(v));
    y(1)=v(1);
    for i=2:size(v,1),
        y(i)=v(i).*emalpha+y(i-1).*(1-emalpha);
    end

end
%% ratios
function [maxdd,avgdd,meddd]=maxdd(ret)
% MAXDD Calculates Maximum Drawdown, Average Drawdown, Median Drawdown.

    % argin
    if nargin~=1,
        help betmat.maxdd; % function help
        return;
    end
    % mdd calculations
    num=size(ret);
    ddv=zeros(num(1),1);
    maxdd=zeros(1,num(2));
    avgdd=zeros(1,num(2));
    meddd=zeros(1,num(2));
    for j=1:num(2),
        
        cumret=betmat.nancumsum(ret(:,j));
        for i=1:num(1),
            ddv(i)=cumret(i)-max(cumret(1:i));
        end;
        % return values
        ddv=ddv(ddv<=0);
        maxdd(j)=min(ddv);
        avgdd(j)=mean(ddv);
        meddd(j)=median(ddv);
  
    end
end
function omega=omega(x,thresholds)
% Omega: SHADWICK, William F., and Con KEATING, 2002. A Universal
% Performance Measure. The Journal of Performance Measurement, 6(3).          
    
    if nargin<2,
        thresholds=0;
        %thresholds=linspace(min(x),max(x),100);
    end
    n=size(x,2);
    omega=zeros(1,n);
    for i=1:n,
        cdf=ksdensity(x(:,i),thresholds,'function','cdf'); % calc probability densities
        omega(i)=(1-cdf)./cdf; % ratio of upper area to lower area
    end
end
%% cryptographic functions
function y=encrypt1(data)
    %find key
    data=uint8(data);
    key=uint8(1);
    i=uint8(0);
    while (key~=i) && (i<=254),
        i=i+1;
        xdata=bitxor(data,i);
        key=xdata(1);
        for j=2:length(xdata),
            key=bitxor(key,xdata(j));
        end
    end    
    %encrypt
    y=char(bitxor(uint8(data),key));
end
function y=encrypt2(data)
    %find key
    data=uint8(data);
    n=numel(data);
    key=uint16(1);
    i=uint16(0);
    while (key~=(i-1)) && (i<=65535),
        RandStream.setGlobalStream(RandStream('mt19937ar','seed',i)); %seed can be uint32
        xdata=bitxor(data,uint8(rand(1,n).*256));
        key=xdata(1);
        for j=2:length(xdata),
            key=bitxor(key,xdata(j));
        end
        disp(i);
        i=i+1;
    end    
    %encrypt
    y=char(xdata);
end
function y=decrypt1(data)
    %find key
    data=uint8(data);
    key=data(1);
    for j=2:length(data),
        key=bitxor(key,data(j));
    end
    %decrypt
    y=char(bitxor(uint8(data),key));
end
function y=decrypt2(data)
    %find key
    data=uint8(data);
    key=data(1);
    for j=2:length(data),
        key=bitxor(key,data(j));
    end
    %decrypt
    RandStream.setGlobalStream(RandStream('mt19937ar','seed',key));
    y=char(bitxor(uint8(data),uint8(rand(1,numel(data)).*256)));
end
function [user,pwd]=decrypt(data,num)
    if nargin<2,
        num=1;
    end
    user=[];
    pwd=[];
    if data{num,1}==1,
        user=betmat.decrypt1(data{num,2});
    elseif data{num,1}==2,
        user=betmat.decrypt2(data{num,2});
    end
    if data{num,3}==1,
        pwd=betmat.decrypt1(data{num,4});
    elseif data{num,3}==2,
        pwd=betmat.decrypt2(data{num,4});
    end
end

end % static methods
            
end % classdef
