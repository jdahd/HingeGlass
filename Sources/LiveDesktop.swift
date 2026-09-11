import AppKit
import ScreenCaptureKit
import Metal
import CoreVideo

// Hold both the pixel buffer and its Metal wrapper until GPU work completes.
final class DesktopFrame {
    let buffer: CVPixelBuffer
    let wrapper: CVMetalTexture
    let texture: MTLTexture
    init(buffer: CVPixelBuffer, wrapper: CVMetalTexture, texture: MTLTexture) {
        self.buffer=buffer; self.wrapper=wrapper; self.texture=texture
    }
}

final class LiveDesktop: NSObject, SCStreamOutput, SCStreamDelegate {
    private let queue=DispatchQueue(label:"local.jux.hingeglass.desktop",qos:.userInteractive)
    private let lock=NSLock()
    private var latest: DesktopFrame?
    private var stopped=false
    private var delivered=false
    private var received=0
    private var cache: CVMetalTextureCache!
    private var stream: SCStream?
    var onReady: (() -> Void)?
    var onFailure: ((String) -> Void)?

    init(device: MTLDevice) throws {
        super.init()
        guard CVMetalTextureCacheCreate(kCFAllocatorDefault,nil,device,nil,&cache)==kCVReturnSuccess else {
            throw NSError(domain:"Desktop texture cache unavailable",code:1)
        }
    }
    func start(filter: SCContentFilter, configuration: SCStreamConfiguration) async throws {
        let capture=SCStream(filter:filter,configuration:configuration,delegate:self)
        stream=capture
        try capture.addStreamOutput(self,type:.screen,sampleHandlerQueue:queue)
        try await capture.startCapture()
    }
    func frame() -> DesktopFrame? {
        lock.lock(); defer { lock.unlock() }
        return stopped ? nil : latest
    }
    func frameCount() -> Int { lock.lock(); defer { lock.unlock() }; return received }
    func stop() {
        lock.lock(); stopped=true; latest=nil; lock.unlock()
        onReady=nil; onFailure=nil
        if let capture=stream { stream=nil; Task { try? await capture.stopCapture() } }
    }
    func stream(_ stream:SCStream, didStopWithError error:Error) {
        fail("Desktop stream stopped (code \((error as NSError).code)).")
    }
    private func fail(_ message:String) {
        lock.lock(); let active = !stopped; lock.unlock()
        if active { DispatchQueue.main.async { [weak self] in self?.onFailure?(message) } }
    }
    func stream(_ stream:SCStream,didOutputSampleBuffer sampleBuffer:CMSampleBuffer,of type:SCStreamOutputType) {
        guard type == .screen,sampleBuffer.isValid,
              let info=CMSampleBufferGetSampleAttachmentsArray(sampleBuffer,createIfNecessary:false) as? [[SCStreamFrameInfo:Any]],
              let raw=info.first?[.status] as? Int, let status=SCFrameStatus(rawValue:raw) else { return }
        if status == .blank || status == .suspended || status == .stopped {
            fail("Desktop capture paused. The effect has been removed."); return
        }
        guard status == .complete,let buffer=sampleBuffer.imageBuffer else { return }
        var wrapper: CVMetalTexture?
        let result=CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,cache,buffer,nil,.bgra8Unorm,CVPixelBufferGetWidth(buffer),CVPixelBufferGetHeight(buffer),0,&wrapper)
        guard result == kCVReturnSuccess,let wrapper,let texture=CVMetalTextureGetTexture(wrapper) else {
            fail("Desktop frame could not be displayed."); return
        }
        let frame=DesktopFrame(buffer:buffer,wrapper:wrapper,texture:texture)
        lock.lock()
        guard !stopped else { lock.unlock(); return }
        latest=frame; received += 1
        let first = !delivered; delivered=true
        lock.unlock()
        if first { DispatchQueue.main.async { [weak self] in self?.onReady?() } }
    }
}
