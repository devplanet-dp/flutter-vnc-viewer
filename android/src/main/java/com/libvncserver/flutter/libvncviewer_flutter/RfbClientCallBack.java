package com.libvncserver.flutter.libvncviewer_flutter;

public interface RfbClientCallBack {
    public void onError(long clientId,int code,String msg);
    public void onClosed(long clientId);

    public void onConnectSuccess(long clientId,int width,int height);

    public void onFrameUpdate(long clientId,byte[] datas,int width,int height);

    public void imageResize(long clientId,int width,int height);
}
