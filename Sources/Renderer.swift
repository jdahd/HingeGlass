import AppKit
import MetalKit
import CoreImage

// Adapted from Ruixiang Huang's Macbook_Duo_Effect (MIT).
// See ThirdPartyNotices/Macbook_Duo_Effect.txt for attribution and license.
struct ReferenceState {
    var width: Double = 1
    var darkness: Double = 0
    var radius: Double = 0
    static func target(progress:Float, reference:Float, maximum:Double) -> ReferenceState {
        let threshold=Double(reference)
        let angle=max(0,threshold-Double(progress)*(threshold-12))
        guard angle<threshold,threshold>0 else { return ReferenceState() }
        let delta=min(75,threshold-angle)*Double.pi/180
        let depth=1/(cos(delta)+0.2*sin(delta))
        let width=max(0.08,1-depth*sin(delta)/2.5)
        let fraction=min(1,max(0,1-angle/threshold))
        let amount=fraction*fraction*(3-2*fraction)
        return ReferenceState(width:width,darkness:amount,radius:maximum*amount)
    }
    mutating func advance(to target:ReferenceState,dt:Double) {
        guard target.radius>0 else { self=ReferenceState(); return }
        let blend=1-exp(-max(0,dt)/0.045)
        width += (target.width-width)*blend
        darkness += (target.darkness-darkness)*blend
        radius += (target.radius-radius)*blend
    }
}

final class GlassRenderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    let queue: MTLCommandQueue
    let context: CIContext
    let colorSpace=CGColorSpace(name:CGColorSpace.sRGB)!
    var stillImage: CIImage?
    var frameSource: (() -> DesktopFrame?)?
    private let inFlight=DispatchSemaphore(value:2)
    var progress: Float = 0
    var maximumBlur: Double = 68
    var referenceAngle: Float = 114
    private var motion=ReferenceState()
    private var animatedTarget: Float?
    private var previousFrameTime: Double?
    var keepsDisplayClockRunning=false
    var onPresented:(() -> Void)?
    var onSettled:(() -> Void)?
    var measuring=false
    var frameTimes=[Double]()
    var frameProgress=[Float]()
    var submissionMS=[Double]()
    var gpuMS=[Double]()

    init(device:MTLDevice) throws {
        self.device=device
        guard let queue=device.makeCommandQueue() else { throw NSError(domain:"Metal queue",code:1) }
        self.queue=queue
        context=CIContext(mtlCommandQueue:queue,options:[.cacheIntermediates:false])
        super.init()
    }
    func setImage(_ image:CGImage) throws { stillImage=CIImage(cgImage:image) }
    func follow(_ target:Float,in view:MTKView) {
        animatedTarget=min(1,max(0,target))
        if view.isPaused { previousFrameTime=nil; view.isPaused=false }
    }
    func stopFollowing(in view:MTKView?) {
        view?.isPaused=true; animatedTarget=nil; previousFrameTime=nil
        motion=ReferenceState(); progress=0; onPresented=nil; onSettled=nil
    }
    func processed(_ input:CIImage,state:ReferenceState,bounds:CGRect) -> CIImage {
        let image=input.transformed(by:CGAffineTransform(scaleX:bounds.width/input.extent.width,y:bounds.height/input.extent.height))
        let width=bounds.width,height=bounds.height
        let inset=width*(1-state.width)/2
        let projected=image.applyingFilter("CIPerspectiveTransform",parameters:[
            "inputTopLeft":CIVector(x:inset,y:height),
            "inputTopRight":CIVector(x:width-inset,y:height),
            "inputBottomLeft":CIVector(x:0,y:0),
            "inputBottomRight":CIVector(x:width,y:0)
        ]).composited(over:CIImage(color:.black).cropped(to:bounds)).cropped(to:bounds)
        let gradient=CIFilter(name:"CILinearGradient",parameters:[
            "inputPoint0":CIVector(x:width/2,y:0),"inputPoint1":CIVector(x:width/2,y:height),
            "inputColor0":CIColor(red:0.05,green:0.05,blue:0.05),"inputColor1":CIColor.white
        ])!.outputImage!.cropped(to:bounds)
        let light=1-state.darkness
        return projected.clampedToExtent()
            .applyingFilter("CIMaskedVariableBlur",parameters:[kCIInputRadiusKey:state.radius,"inputMask":gradient])
            .cropped(to:bounds)
            .applyingFilter("CIColorMatrix",parameters:[
                "inputRVector":CIVector(x:light,y:0,z:0,w:0),
                "inputGVector":CIVector(x:0,y:light,z:0,w:0),
                "inputBVector":CIVector(x:0,y:0,z:light,w:0)])
    }
    func draw(in view:MTKView) {
        guard inFlight.wait(timeout:.now()) == .success else { return }
        let budget=inFlight,liveFrame=frameSource?()
        guard let input=liveFrame.map({CIImage(cvPixelBuffer:$0.buffer)}) ?? (frameSource == nil ? stillImage:nil),
              let drawable=view.currentDrawable,let command=queue.makeCommandBuffer() else { budget.signal(); return }
        let began=CACurrentMediaTime()
        let dt=min(0.1,began-(previousFrameTime ?? began-1.0/60)); previousFrameTime=began
        let target=animatedTarget ?? progress
        let desired=ReferenceState.target(progress:target,reference:referenceAngle,maximum:maximumBlur)
        if animatedTarget != nil {
            motion.advance(to:desired,dt:dt)
            if target==0 { progress=0 } else { progress += (target-progress)*Float(1-exp(-dt/0.045)) }
            if abs(target-progress)<0.00015 { progress=target }
        } else { motion=desired }
        var pixels=motion
        let scale=view.drawableSize.height/max(1,view.bounds.height)
        pixels.radius *= Double(scale)
        let bounds=CGRect(origin:.zero,size:view.drawableSize)
        autoreleasepool {
            let output=processed(input,state:pixels,bounds:bounds)
            context.render(output,to:drawable.texture,commandBuffer:command,bounds:bounds,colorSpace:colorSpace)
        }
        if measuring { frameTimes.append(began); frameProgress.append(progress) }
        let first=onPresented; onPresented=nil
        let settled=animatedTarget == progress ? onSettled:nil
        if settled != nil { onSettled=nil }
        if first != nil || settled != nil {
            drawable.addPresentedHandler { _ in DispatchQueue.main.async { first?(); settled?() } }
        }
        let collect=measuring
        command.addCompletedHandler { [weak self,liveFrame,budget] result in
            withExtendedLifetime(liveFrame) { _ = budget.signal() }
            if collect {
                let ms=(result.gpuEndTime-result.gpuStartTime)*1000
                DispatchQueue.main.async { self?.gpuMS.append(ms) }
            }
        }
        command.present(drawable); command.commit()
        if measuring { submissionMS.append((CACurrentMediaTime()-began)*1000) }
        if !keepsDisplayClockRunning,animatedTarget == progress { view.isPaused=true }
    }
    func reportPerformance() {
        func stats(_ a:[Double]) -> String {
            let s=a.sorted(); guard !s.isEmpty else { return "no samples" }
            return String(format:"median %.3f, p95 %.3f, max %.3f",s[s.count/2],s[min(s.count-1,Int(Double(s.count)*0.95))],s.last!)
        }
        let intervals=zip(frameTimes.dropFirst(),frameTimes).map { ($0-$1)*1000 }
        let steps=zip(frameProgress.dropFirst(),frameProgress).map { Double(abs($0-$1)) }
        print("frames: \(frameTimes.count)")
        print("frame interval ms: \(stats(intervals))")
        print("main-thread submission ms: \(stats(submissionMS))")
        print("GPU ms: \(stats(gpuMS))")
        print("progress step: \(stats(steps))")
    }
    func mtkView(_ view:MTKView,drawableSizeWillChange size:CGSize) {}
    func renderPNG(at url:URL,progress:Float) throws {
        guard let input=stillImage else { throw NSError(domain:"Missing image",code:1) }
        let state=ReferenceState.target(progress:progress,reference:referenceAngle,maximum:maximumBlur)
        let output=processed(input,state:state,bounds:CGRect(x:0,y:0,width:960,height:600))
        try context.writePNGRepresentation(of:output,to:url,format:.RGBA8,colorSpace:colorSpace)
    }
}

func makeArtwork() -> CGImage {
    let context = CGContext(data:nil,width:1600,height:1000,bitsPerComponent:8,bytesPerRow:1600*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext:context,flipped:false)
    NSGradient(colors:[NSColor(calibratedRed:0.15,green:0.30,blue:0.46,alpha:1),NSColor(calibratedRed:0.83,green:0.69,blue:0.56,alpha:1)])!.draw(in:NSRect(x:0,y:0,width:1600,height:1000),angle:-90)
    NSColor(calibratedRed:1,green:0.91,blue:0.70,alpha:1).setFill()
    NSBezierPath(ovalIn:NSRect(x:1090,y:615,width:140,height:140)).fill()
    let colors:[NSColor]=[.init(calibratedRed:0.35,green:0.42,blue:0.46,alpha:1),.init(calibratedRed:0.22,green:0.33,blue:0.38,alpha:1),.init(calibratedRed:0.12,green:0.24,blue:0.28,alpha:1),.init(calibratedRed:0.06,green:0.15,blue:0.19,alpha:1)]
    for layer in 0..<4 {
        let path=NSBezierPath(); path.move(to:NSPoint(x:0,y:0))
        for x in stride(from:0,through:1600,by:8) {
            let xf=Double(x), l=Double(layer)
            let y=380-l*76+sin(xf/270+l*1.7)*(72-l*7)+sin(xf/107+l)*16
            path.line(to:NSPoint(x:xf,y:y))
        }
        path.line(to:NSPoint(x:1600,y:0)); path.close(); colors[layer].setFill(); path.fill()
    }
    let attrs:[NSAttributedString.Key:Any]=[.font:NSFont.systemFont(ofSize:22,weight:.medium),.foregroundColor:NSColor.white.withAlphaComponent(0.60)]
    NSString(string:"HINGE / GLASS").draw(at:NSPoint(x:90,y:850),withAttributes:attrs)
    NSGraphicsContext.restoreGraphicsState()
    return context.makeImage()!
}
