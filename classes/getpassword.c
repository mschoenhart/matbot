#include "mex.h"
#include "windows.h"

void mexFunction(int nlhs,mxArray *plhs[],int nrhs,const mxArray *prhs[])
{
    int  i=0,j; 
    char c,str[32];
	char *outputstr;
	
    /* Set the console mode to no-echo, not-line-buffered input */
    DWORD  mode, count;
    HANDLE ih = GetStdHandle( STD_INPUT_HANDLE  );
    HANDLE oh = GetStdHandle( STD_OUTPUT_HANDLE );
	
	/* Check for proper number of input and output arguments */  
    if(nrhs>0) {
         mexErrMsgIdAndTxt("GETPASSWORD:ARRAYPRODUCT:NRHS",
                           "No input required!");
    }
    if(nlhs>1) {
         mexErrMsgIdAndTxt("GETPASSWORD:ARRAYPRODUCT:NLHS",
                           "Too many output arguments!");
    }
	
	/* Check for console */
	if (!GetConsoleMode(ih, &mode)) {
         mexErrMsgIdAndTxt("GETPASSWORD:CONSOLE",
                           "You must be connected to a console!");
    }
    SetConsoleMode(ih,mode & ~(ENABLE_ECHO_INPUT | ENABLE_LINE_INPUT));
	
    WriteConsoleA(oh,"Password:",9,&count,NULL);
    /* Get the password string */
    while (ReadConsoleA(ih,&c,1,&count,NULL) && (c!='\r') && (c!='\n')) {
     if (c=='\b') {
        if (i>0) {
            WriteConsoleA(oh,"\b \b",3,&count,NULL);
            i=i-1;
        }
     } else {
	    if (i<sizeof(str)) {
            WriteConsoleA(oh,"*",1,&count,NULL);
            str[i]=c;
		    i=i+1;
        }
     }
    }
    WriteConsoleA(oh,"\n",1,&count,NULL);
	
    /* Restore the console mode */
    SetConsoleMode(ih,mode);
	
    /* allocate memory for output string */
    outputstr=mxCalloc((mwSize) i,sizeof(char));
    for (j=0;j<i;j++) {
	    *(outputstr+j)=(mxChar) str[j];
	}
	/* set C-style string to MATLAB mexFunction output */
    plhs[0]=mxCreateString(outputstr);
	return;
}
