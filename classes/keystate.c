/* calls GetAsyncKeyState of windows api */
#include "mex.h"
#include "windows.h"
void mexFunction(
      int nlhs, mxArray *plhs[],
      int nrhs, const mxArray *prhs[])
{
   int KeyCode;
   int KeyState;

   if(nrhs!=1) {
      mexErrMsgIdAndTxt("KEYSTATE:ARRAYPRODUCT:NRHS",
            "Virtual Key required");
   }
   if(nlhs>2) {
      mexErrMsgIdAndTxt("KEYSTATE:ARRAYPRODUCT:NLHS",
            "2 or less output arguments");
   }
   
   KeyCode=(int)mxGetScalar(prhs[0]);
   KeyState=GetAsyncKeyState(KeyCode);

   /* key is currently pressed */
   if ((KeyState & 0x8000)!=0)
   {
      plhs[0]=mxCreateDoubleScalar(1);
   }
   else
   {
      plhs[0]=mxCreateDoubleScalar(0);
   }

   /* key was hit since last call */
   if(nlhs==2)
   {
      if ((KeyState & 0x1)!=0)
      {
         plhs[1]=mxCreateDoubleScalar(1);
      }
      else
      {
         plhs[1]=mxCreateDoubleScalar(0);
      }
   }
}
