%% Class Trading Strategies

classdef (~Sealed) tstrat < hgsetget % reference class

properties (Constant=true, GetAccess=public) 

%% development    
%markettype,name,num arguments,tstrat function to call
stratdefs={ ...
    {[],'BuyHld.1/n',         1,@tstrat.tstrat_eqw};
};

end 

%% static methods
methods (Static)

%% misc
function y=stratidx(markettype)
    y=cellfun(@(x) isempty(x{1}) || strcmp(x(1),markettype),tstrat.stratdefs);
end
function y=stratnum(markettype)
    y=sum(tstrat.stratidx(markettype));
end
function y=stratname(markettype)
    y=cellfun(@(x) x(2),tstrat.stratdefs(tstrat.stratidx(markettype)));
end
function y=eventsbot
    y=cellfun(@(x) x(1),tstrat.stratdefsbot);
end
function y=marketsbot
    y=cellfun(@(x) x(2),tstrat.stratdefsbot);
end

%% Trading Strategies General
function w=tstrat_eqw(qstart)
% Benchmark - equal weighting 1/n
    w=ones(1,size(qstart,2));
end

%% Trading Strategies Match Odds
%% Trading Strategies Correct Score
%% Trading Strategies Half time/Full time

end

end
