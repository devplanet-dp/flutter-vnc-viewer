package com.libvncviewer.flutter.nativelib;

import android.view.Surface;

public class VncClient{

    // Used to load the 'nativelib' library on application startup.
    static {
        System.loadLibrary("nativelib");
    }

    public native long rfbInitClient(String hostName, int port, String password, Surface surface, RfbClientCallBack clientCallBack);

    public native void startRfbClient(long clientId);

    public native void sendPointer(long clientId, int x, int y, int mask);

    public native void closeRfbClient(long clientId);

}