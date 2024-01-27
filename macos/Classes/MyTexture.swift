//
//  TextRgba.swift
//  texture_rgba_renderer
//
//  Created by kingtous on 2023/2/17.
//

import Foundation
import FlutterMacOS
import CoreVideo

@objc public class MyTexture: NSObject, FlutterTexture {
    public var textureId: Int64 = -1
    private var buffer: CVPixelBuffer?
    private var width: Int = 0
    private var height: Int = 0
    private let queue = DispatchQueue(label: "libvncviewer_flutter_queue")
    
    public init(width:Int,height:Int) {
        self.width=width
        self.height=height
        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, dict as CFDictionary, &self.buffer)
    }
    
    
    // macOS only support 32BGRA currently.
    private let dict: [String: Any] = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferMetalCompatibilityKey as String: true,
        kCVPixelBufferOpenGLCompatibilityKey as String: true,
        // https://developer.apple.com/forums/thread/712709
        kCVPixelBufferBytesPerRowAlignmentKey as String: 64
    ]
    
    public func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        queue.sync {
            if (buffer == nil) {
                return nil
            }
            return Unmanaged.passRetained(buffer!)
        }
    }
    
    private func _markFrameAvaliable(buffer: UnsafePointer<UInt8>, len: Int, width: Int, height: Int, stride_align: Int) {
        CVPixelBufferLockBaseAddress(self.buffer!, [])
        let ptr = CVPixelBufferGetBaseAddress(self.buffer!)!
        memcpy(ptr, buffer, len)
        CVPixelBufferUnlockBaseAddress(self.buffer!, [])
    }
    
    @objc public func markFrameAvaliableRaw(buffer: UnsafePointer<UInt8>, len: Int, width: Int, height: Int, stride_align: Int){
        queue.sync {
            _markFrameAvaliable(buffer: buffer, len: len, width: width, height: height, stride_align: stride_align)
        }
    }
    
}
