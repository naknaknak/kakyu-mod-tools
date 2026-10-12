using System;
using System.Runtime.InteropServices;

namespace Kakyu.ContentTools
{
    [ComImport]
    [Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
    internal class MMDeviceEnumeratorComObject
    {
    }

    [ComImport]
    [Guid("A95664D2-9614-4F35-A746-DE8DB63617E6")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IMMDeviceEnumerator
    {
        int EnumAudioEndpoints(int dataFlow, int stateMask, out object devices);
        int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice endpoint);
        int GetDevice(string id, out IMMDevice device);
        int RegisterEndpointNotificationCallback(IntPtr client);
        int UnregisterEndpointNotificationCallback(IntPtr client);
    }

    [ComImport]
    [Guid("D666063F-1587-4E43-81F1-B948E807363F")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IMMDevice
    {
        int Activate(
            ref Guid interfaceId,
            int classContext,
            IntPtr activationParameters,
            [MarshalAs(UnmanagedType.IUnknown)] out object instance
        );

        int OpenPropertyStore(int access, out IntPtr properties);
        int GetId(out string id);
        int GetState(out int state);
    }

    [ComImport]
    [Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IAudioSessionManager2
    {
        int GetAudioSessionControl(
            ref Guid sessionId,
            uint streamFlags,
            out IAudioSessionControl control
        );

        int GetSimpleAudioVolume(ref Guid sessionId, uint streamFlags, out IntPtr volume);
        int GetSessionEnumerator(out IAudioSessionEnumerator sessionEnumerator);
        int RegisterSessionNotification(IntPtr notification);
        int UnregisterSessionNotification(IntPtr notification);
        int RegisterDuckNotification(string sessionId, IntPtr notification);
        int UnregisterDuckNotification(IntPtr notification);
    }

    [ComImport]
    [Guid("E2F5BB11-0570-40CA-ACDD-3AA01277DEE8")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IAudioSessionEnumerator
    {
        int GetCount(out int count);
        int GetSession(int index, out IAudioSessionControl control);
    }

    [ComImport]
    [Guid("F4B1A599-7266-4319-A8CA-E70ACB11E8CD")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IAudioSessionControl
    {
        int GetState(out int state);
        int GetDisplayName(out string name);
        int SetDisplayName(string name, ref Guid eventContext);
        int GetIconPath(out string path);
        int SetIconPath(string path, ref Guid eventContext);
        int GetGroupingParam(out Guid groupingId);
        int SetGroupingParam(ref Guid groupingId, ref Guid eventContext);
        int RegisterAudioSessionNotification(IntPtr client);
        int UnregisterAudioSessionNotification(IntPtr client);
    }

    [ComImport]
    [Guid("BFB7FF88-7239-4FC9-8FA2-07C950BE9C6D")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IAudioSessionControl2
    {
        int GetState(out int state);
        int GetDisplayName(out string name);
        int SetDisplayName(string name, ref Guid eventContext);
        int GetIconPath(out string path);
        int SetIconPath(string path, ref Guid eventContext);
        int GetGroupingParam(out Guid groupingId);
        int SetGroupingParam(ref Guid groupingId, ref Guid eventContext);
        int RegisterAudioSessionNotification(IntPtr client);
        int UnregisterAudioSessionNotification(IntPtr client);
        int GetSessionIdentifier(out string id);
        int GetSessionInstanceIdentifier(out string id);
        int GetProcessId(out uint processId);
        int IsSystemSoundsSession();
        int SetDuckingPreference(bool optOut);
    }

    [ComImport]
    [Guid("C02216F6-8C67-4B5B-9D00-D008E73E0064")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IAudioMeterInformation
    {
        int GetPeakValue(out float peak);
        int GetMeteringChannelCount(out int count);
        int GetChannelsPeakValues(int count, [Out] float[] peaks);
        int QueryHardwareSupport(out int mask);
    }

    public static class WindowsAudioSessionMeter
    {
        private const int RenderDataFlow = 0;
        private const int MultimediaRole = 1;
        private const int ClassContextAll = 23;

        private static readonly IAudioSessionManager2 SessionManager = CreateSessionManager();

        // Returns -1 when the process has no session and -2 on a meter failure.
        public static float ReadPeak(uint processId)
        {
            IAudioSessionEnumerator enumerator;
            if (SessionManager.GetSessionEnumerator(out enumerator) != 0)
            {
                return -2.0f;
            }

            int count;
            if (enumerator.GetCount(out count) != 0)
            {
                return -2.0f;
            }

            for (int index = 0; index < count; index++)
            {
                IAudioSessionControl control;
                if (enumerator.GetSession(index, out control) != 0)
                {
                    continue;
                }

                var control2 = control as IAudioSessionControl2;
                var meter = control as IAudioMeterInformation;
                if (control2 == null || meter == null)
                {
                    continue;
                }

                uint candidateProcessId;
                if (control2.GetProcessId(out candidateProcessId) != 0 ||
                    candidateProcessId != processId)
                {
                    continue;
                }

                float peak;
                return meter.GetPeakValue(out peak) == 0 ? peak : -2.0f;
            }

            return -1.0f;
        }

        private static IAudioSessionManager2 CreateSessionManager()
        {
            var deviceEnumerator = (IMMDeviceEnumerator)new MMDeviceEnumeratorComObject();
            IMMDevice device;
            Marshal.ThrowExceptionForHR(
                deviceEnumerator.GetDefaultAudioEndpoint(
                    RenderDataFlow,
                    MultimediaRole,
                    out device
                )
            );

            var interfaceId = typeof(IAudioSessionManager2).GUID;
            object manager;
            Marshal.ThrowExceptionForHR(
                device.Activate(
                    ref interfaceId,
                    ClassContextAll,
                    IntPtr.Zero,
                    out manager
                )
            );
            return (IAudioSessionManager2)manager;
        }
    }
}
