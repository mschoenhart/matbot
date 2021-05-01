%% Class Initial Values

classdef (~Sealed) initvalues

properties (Constant=true, GetAccess=public) 

  %% Environment    
  workpathdev     ='d:\data\projects\matbots\dev';      % Client
  logfilepathdev  ='d:\data\projects\matbots\dev';      % Client
  workpathprod    ='c:\users\xxx\dropbox\betbase\data'; % Server
  logfilepathprod ='c:\projects\bots\data';             % Server
  timestamplogfile='yyyy-mm-ddTHH-MM';
  
  %% API
  usertab  ={1,'xxx',2,char([0,0,0]);
             2,'xxx',2,char([0,0,0])};
  delaytime=60; % sec, for main loop
  
  %% Mail
  mailusertab={2,char([0,0,0]),...
               2,char([0,0,0]);...
               2,char([0,0,0]),...
               2,char([0,0,0])};
  
  %% collect data
  % Database
  databasename  ='betbase';
  databasetype  ='mysql';

end 

end
