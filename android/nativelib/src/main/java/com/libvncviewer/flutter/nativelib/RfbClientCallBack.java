package com.libvncviewer.flutter.nativelib;

public interface RfbClientCallBack {
    public void onError(long clientId,int code,String msg);
    public void onClosed(long clientId);

    public void onConnectSuccess(long clientId,int width,int height);

    public void imageData(long clientId,byte[] datas,int width,int height);

    public void imageResize(long clientId,int width,int height);
}
