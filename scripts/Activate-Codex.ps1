param([Parameter(Mandatory=$true)][string]$AppUserModelId,[string]$Arguments='')
$ErrorActionPreference='Stop'
if($AppUserModelId -ne 'OpenAI.Codex_2p2nqsd0c76g0!App'){throw 'Unexpected application identity.'}
if($Arguments -ne '' -and $Arguments -ne '--remote-debugging-address=127.0.0.1 --remote-debugging-port=9340'){throw 'Unexpected application arguments.'}
if(-not ('XLink.AppActivation' -as [type])){
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace XLink {
 [ComImport, Guid("2E941141-7F97-4756-BA1D-9DECDE894A3D"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
 interface IApplicationActivationManager {
  [PreserveSig] int ActivateApplication([MarshalAs(UnmanagedType.LPWStr)] string appId,[MarshalAs(UnmanagedType.LPWStr)] string arguments,uint options,out uint processId);
  [PreserveSig] int ActivateForFile([MarshalAs(UnmanagedType.LPWStr)] string appId,IntPtr items,[MarshalAs(UnmanagedType.LPWStr)] string verb,out uint processId);
  [PreserveSig] int ActivateForProtocol([MarshalAs(UnmanagedType.LPWStr)] string appId,IntPtr items,out uint processId);
 }
 public static class AppActivation {
  public static uint Launch(string appId,string arguments) {
   var instance=Activator.CreateInstance(Type.GetTypeFromCLSID(new Guid("45BA127D-10A8-46EA-8AB7-56EA9078943C")));
   try {uint processId;int result=((IApplicationActivationManager)instance).ActivateApplication(appId,arguments,2,out processId);Marshal.ThrowExceptionForHR(result);return processId;}
   finally {Marshal.ReleaseComObject(instance);}
  }
 }
}
'@
}
[XLink.AppActivation]::Launch($AppUserModelId,$Arguments)
