import AppKit
import MetalKit
import ScreenCaptureKit
import Carbon

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var preview: MTKView!
    var previewRenderer: GlassRenderer!
    var overlay: NSWindow?
    var overlayView: MTKView?
    var overlayRenderer: GlassRenderer!
    var sensor = LidSensor()
    var statusItem: NSStatusItem!
    var angleLabel: NSTextField!
    var infoLabel: NSTextField!
    var slider: NSSlider!
    var threshold: NSSlider!
    var thresholdLabel: NSTextField!
    var blurSlider: NSSlider!
    var blurValueLabel: NSTextField!
    var enableButton: NSButton!
    var sourceControl: NSSegmentedControl!
    var lastAngle: Double?
    var enabled = false
    var blockedUntilOpen = false
    var sleeping = false
    var capturePending = false
    var captureGeneration = 0
    var capturingScreen = false
    var desktopReady = false
    var recovering = false
    var overlayGeneration = 0
    var lastSensorTime = CACurrentMediaTime()
    var healthTimer: Timer?
    var artwork: CGImage!
    var liveDesktop: LiveDesktop?
    var demoTimer: Timer?
    var overlayStarted: Date?
    var hotKey: EventHotKeyRef?
    var localMonitor: Any?
    var notificationTokens: [NSObjectProtocol] = []

    var startAngle: Double { threshold?.doubleValue ?? 85 }
    func progress(for angle: Double) -> Float { Float(min(1,max(0,(startAngle-angle)/(startAngle-12)))) }
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let device = MTLCreateSystemDefaultDevice() else { fail("Metal is unavailable on this Mac."); return }
        do {
            previewRenderer = try GlassRenderer(device:device)
            overlayRenderer = try GlassRenderer(device:device)
            overlayRenderer.keepsDisplayClockRunning=true
            artwork = makeArtwork()
            try previewRenderer.setImage(artwork); try overlayRenderer.setImage(artwork)
        } catch { fail("Graphics initialization failed: \(error.localizedDescription)"); return }
        if CommandLine.arguments.contains("--render-check") {
            do {
                let path = CommandLine.arguments.last!
                for (name,p): (String,Float) in [("open",0),("half",0.45),("near-closed",0.82),("closed",1)] {
                    try previewRenderer.renderPNG(at:URL(fileURLWithPath:path).appendingPathComponent("\(name).png"),progress:p)
                }
                print("Metal render: 4 frames completed")
                NSApp.terminate(nil); return
            } catch { print("Render failure: \(error)"); exit(1) }
        }
        if let iconURL=Bundle.main.url(forResource:"AppIcon",withExtension:"icns"),let icon=NSImage(contentsOf:iconURL) { NSApp.applicationIconImage=icon }
        makeMenu(); makeWindow(device:device); registerEscape()
        sensor.onAngle = { [weak self] angle in self?.receive(angle) }
        sensor.start()
        let health=Timer(timeInterval:0.25,repeats:true) { [weak self] _ in
            guard let self,self.enabled else { return }
            if CACurrentMediaTime()-self.lastSensorTime>0.6 {
                self.blockedUntilOpen=true; self.hideOverlay()
                self.infoLabel.stringValue="Sensor disconnected. Desktop restored. Open the lid fully to retry."
            }
        }
        RunLoop.main.add(health,forMode:.common); healthTimer=health
        let center=NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification,NSWorkspace.screensDidSleepNotification,NSWorkspace.sessionDidResignActiveNotification] {
            notificationTokens.append(center.addObserver(forName:name,object:nil,queue:.main) { [weak self] _ in
                self?.sleeping=true; self?.blockedUntilOpen=true; self?.hideOverlay()
                self?.demoTimer?.invalidate(); self?.demoTimer=nil
            })
        }
        for name in [NSWorkspace.didWakeNotification,NSWorkspace.screensDidWakeNotification,NSWorkspace.sessionDidBecomeActiveNotification] {
            notificationTokens.append(center.addObserver(forName:name,object:nil,queue:.main) { [weak self] _ in
                self?.sleeping=false; self?.blockedUntilOpen=true; self?.hideOverlay(); self?.sensor.start()
            })
        }
        notificationTokens.append(NotificationCenter.default.addObserver(forName:NSApplication.didChangeScreenParametersNotification,object:nil,queue:.main) { [weak self] _ in
            self?.hideOverlay(); self?.overlay=nil; self?.overlayView=nil
        })
        for name in ["com.apple.screenIsLocked", "com.apple.screenIsUnlocked"] {
            notificationTokens.append(DistributedNotificationCenter.default().addObserver(forName:Notification.Name(name),object:nil,queue:.main) { [weak self] n in
                self?.sleeping = n.name.rawValue == "com.apple.screenIsLocked"
                self?.blockedUntilOpen=true; self?.hideOverlay()
                self?.demoTimer?.invalidate(); self?.demoTimer=nil
            })
        }
        if CommandLine.arguments.contains("--live-stream-check") { runLiveStreamCheck(); return }
        if CommandLine.arguments.contains("--self-test") { runSelfTest(); return }
        if CommandLine.arguments.contains("--lifecycle-check") { runLifecycleCheck(); return }
        if CommandLine.arguments.contains("--cadence-check") { runCadenceCheck(); return }
        if CommandLine.arguments.contains("--performance-check") { runPerformanceCheck(); return }
        showWindow()
    }
    func fail(_ message:String) { let a=NSAlert(); a.messageText=message; a.runModal(); NSApp.terminate(nil) }
    func label(_ text:String, size:CGFloat=13, weight:NSFont.Weight = .regular) -> NSTextField {
        let l=NSTextField(labelWithString:text); l.font = .systemFont(ofSize:size,weight:weight); return l
    }
    func button(_ text:String, _ action:Selector) -> NSButton { let b=NSButton(title:text,target:self,action:action); b.bezelStyle = .rounded; return b }
    func row(_ views:[NSView]) -> NSStackView { let s=NSStackView(views:views); s.orientation = .horizontal; s.spacing=12; s.alignment = .centerY; return s }
    func makeWindow(device:MTLDevice) {
        window=NSWindow(contentRect:NSRect(x:0,y:0,width:420,height:760),styleMask:[.titled,.closable,.miniaturizable],backing:.buffered,defer:false)
        window.title="HingeGlass"; window.titlebarAppearsTransparent=true; window.isReleasedWhenClosed=false
        window.backgroundColor = .windowBackgroundColor
        let root=NSStackView(); root.orientation = .vertical; root.alignment = .leading; root.spacing=14
        root.translatesAutoresizingMaskIntoConstraints=false
        window.contentView!.addSubview(root)
        NSLayoutConstraint.activate([root.topAnchor.constraint(equalTo:window.contentView!.topAnchor,constant:18),root.leadingAnchor.constraint(equalTo:window.contentView!.leadingAnchor,constant:24),root.trailingAnchor.constraint(equalTo:window.contentView!.trailingAnchor,constant:-24)])
        func add(_ view:NSView) {
            root.addArrangedSubview(view)
            view.widthAnchor.constraint(equalTo:root.widthAnchor).isActive=true
        }
        func divider() { let line=NSBox(); line.boxType = .separator; add(line) }
        let title=label("HingeGlass",size:23,weight:.semibold)
        let subtitle=label("A little motion. A softer view.",size:12); subtitle.textColor = .secondaryLabelColor
        let heading=NSStackView(views:[title,subtitle]); heading.orientation = .vertical; heading.alignment = .leading; heading.spacing=4
        let spacer=NSView(); spacer.setContentHuggingPriority(.defaultLow,for:.horizontal)
        enableButton=button("Enable",#selector(toggleEnabled)); enableButton.controlSize = .large
        enableButton.bezelColor = .controlAccentColor
        add(row([heading,spacer,enableButton]))

        let sensorCaption=label("LID ANGLE",size:11,weight:.medium); sensorCaption.textColor = .secondaryLabelColor
        angleLabel=label("—°",size:48,weight:.light)
        angleLabel.font = .monospacedDigitSystemFont(ofSize:48,weight:.light)
        let sensorGroup=NSStackView(views:[sensorCaption,angleLabel]); sensorGroup.orientation = .vertical; sensorGroup.alignment = .leading; sensorGroup.spacing=2
        add(sensorGroup)
        divider()
        let savedAngle=UserDefaults.standard.object(forKey:"referenceAngle") as? Double ?? 110
        threshold=NSSlider(value:min(140,max(60,savedAngle)),minValue:60,maxValue:140,target:self,action:#selector(thresholdChanged))
        threshold.isContinuous=true; threshold.setAccessibilityLabel("Lid angle that starts the effect")
        thresholdLabel=label("Below \(Int(startAngle))°",size:12); thresholdLabel.textColor = .secondaryLabelColor
        let thresholdSpacer=NSView(); thresholdSpacer.setContentHuggingPriority(.defaultLow,for:.horizontal)
        add(row([label("Start angle",weight:.medium),thresholdSpacer,thresholdLabel])); add(threshold)
        previewRenderer.referenceAngle=Float(startAngle); overlayRenderer.referenceAngle=Float(startAngle)
        let savedBlur=UserDefaults.standard.object(forKey:"maximumBlur") as? Double ?? 68
        blurSlider=NSSlider(value:min(80,max(1,savedBlur)),minValue:1,maxValue:80,target:self,action:#selector(blurChanged))
        blurSlider.isContinuous=true; blurSlider.setAccessibilityLabel("Maximum blur")
        blurValueLabel=label("\(Int(blurSlider.doubleValue))",size:12); blurValueLabel.textColor = .secondaryLabelColor
        let blurSpacer=NSView(); blurSpacer.setContentHuggingPriority(.defaultLow,for:.horizontal)
        add(row([label("Maximum blur",weight:.medium),blurSpacer,blurValueLabel])); add(blurSlider)
        previewRenderer.maximumBlur=blurSlider.doubleValue; overlayRenderer.maximumBlur=blurSlider.doubleValue
        divider()

        sourceControl=NSSegmentedControl(labels:["Landscape","Desktop"],trackingMode:.selectOne,target:self,action:#selector(changeSource)); sourceControl.selectedSegment=0
        let sourceSpacer=NSView(); sourceSpacer.setContentHuggingPriority(.defaultLow,for:.horizontal)
        add(row([label("Scene",weight:.medium),sourceSpacer,sourceControl,button("Image…",#selector(chooseImage))]))
        preview=makeMetalView(device:device,renderer:previewRenderer)
        preview.wantsLayer=true; preview.layer?.cornerRadius=12; preview.layer?.masksToBounds=true
        add(preview); preview.heightAnchor.constraint(equalToConstant:170).isActive=true
        slider=NSSlider(value:0,minValue:0,maxValue:1,target:self,action:#selector(scrub)); slider.isContinuous=true; slider.setAccessibilityLabel("Preview lid closure")
        slider.setContentHuggingPriority(.defaultLow,for:.horizontal)
        add(row([slider,button("Play",#selector(playDemo)),button("Try full screen",#selector(fullScreenDemo))]))
        divider()
        infoLabel=NSTextField(wrappingLabelWithString:"Choose a scene, then enable the lid effect.")
        infoLabel.font = .systemFont(ofSize:11); infoLabel.textColor = .secondaryLabelColor
        add(infoLabel); infoLabel.heightAnchor.constraint(equalToConstant:60).isActive=true
        let footerSpacer=NSView(); footerSpacer.setContentHuggingPriority(.defaultLow,for:.horizontal)
        add(row([button("Permissions…",#selector(openScreenSettings)),footerSpacer,button("Restore",#selector(emergencyStop))]))
        let hint=label("⌃⌥⌘ Esc to restore  ·  Built-in display only",size:10); hint.textColor = .tertiaryLabelColor
        add(hint)
        window.center()
    }
    func makeMetalView(device:MTLDevice, renderer:GlassRenderer) -> MTKView {
        let v=MTKView(frame:.zero,device:device); v.colorPixelFormat = .bgra8Unorm; v.colorspace=CGColorSpace(name:CGColorSpace.sRGB)
        v.clearColor=MTLClearColorMake(0,0,0,1); v.delegate=renderer
        v.preferredFramesPerSecond=60
        v.isPaused=true; v.enableSetNeedsDisplay=false; v.framebufferOnly=false
        return v
    }
    func makeMenu() {
        let main=NSMenu(); let appItem=NSMenuItem(); let appMenu=NSMenu()
        let about=NSMenuItem(title:"About HingeGlass",action:#selector(showAbout),keyEquivalent:"")
        about.target=self; appMenu.addItem(about); appMenu.addItem(.separator())
        let quit=NSMenuItem(title:"Quit HingeGlass",action:#selector(quitApp),keyEquivalent:"q"); quit.target=self
        appMenu.addItem(quit); appItem.submenu=appMenu; main.addItem(appItem); NSApp.mainMenu=main
        statusItem=NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength)
        statusItem.button?.title="◩"
        let menu=NSMenu()
        for (title,action) in [("Open HingeGlass",#selector(showWindow)),("Pause and Restore",#selector(emergencyStop)),("Quit HingeGlass",#selector(quitApp))] {
            let i=NSMenuItem(title:title,action:action,keyEquivalent:""); i.target=self; menu.addItem(i)
        }
        statusItem.menu=menu
    }
    @objc func showAbout() {
        var options: [NSApplication.AboutPanelOptionKey: Any] = [:]
        if let url=Bundle.main.url(forResource:"AppIcon",withExtension:"icns"),let icon=NSImage(contentsOf:url) { options[.applicationIcon]=icon }
        NSApp.orderFrontStandardAboutPanel(options: options)
    }
    func registerEscape() {
        let callback:EventHandlerUPP = { _,_,userData in
            guard let userData else { return noErr }
            Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue().emergencyStop(); return noErr
        }
        var type=EventTypeSpec(eventClass:OSType(kEventClassKeyboard),eventKind:UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(),callback,1,&type,Unmanaged.passUnretained(self).toOpaque(),nil)
        let id=EventHotKeyID(signature:0x48474C53,id:1)
        RegisterEventHotKey(UInt32(kVK_Escape),UInt32(controlKey|optionKey|cmdKey),id,GetApplicationEventTarget(),0,&hotKey)
        localMonitor=NSEvent.addLocalMonitorForEvents(matching:.keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.emergencyStop(); return nil }; return event
        }
    }
    @objc func showWindow() { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true); preview.draw() }
    @objc func quitApp() { NSApp.terminate(nil) }
    @objc func scrub() { demoTimer?.invalidate(); demoTimer=nil; previewRenderer.progress=Float(slider.doubleValue); preview.draw() }
    @objc func playDemo() {
        demoTimer?.invalidate(); let begin=Date()
        let t=Timer(timeInterval:1.0/60,repeats:true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            let elapsed=Date().timeIntervalSince(begin)
            if elapsed>=4 { timer.invalidate(); self.demoTimer=nil; self.slider.doubleValue=0; self.previewRenderer.progress=0; self.preview.draw(); return }
            let p=(1-cos(elapsed/4*2*Double.pi))*0.5
            self.slider.doubleValue=p; self.previewRenderer.progress=Float(p); self.preview.draw()
        }
        RunLoop.main.add(t,forMode:.common); demoTimer=t
    }
    @objc func fullScreenDemo() {
        emergencyStop()
        if capturingScreen {
            startLiveDesktop(forDemo:true) { [weak self] in self?.startFullScreenDemo() }
        } else { startFullScreenDemo() }
    }
    func startFullScreenDemo() {
        let began=CACurrentMediaTime()
        infoLabel.stringValue="Previewing for 5 seconds. Press ⌃⌥⌘ Esc to stop."
        let timer=Timer(timeInterval:1.0/60,repeats:true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            let t=CACurrentMediaTime()-began
            if t>=5 {
                timer.invalidate(); self.demoTimer=nil
                self.recovering=true
                let generation=self.overlayGeneration
                self.overlayRenderer.onSettled = { [weak self] in
                    guard let self,self.recovering,self.overlayGeneration==generation else { return }
                    self.hideOverlay(); self.infoLabel.stringValue="Preview complete. Enable to follow the lid."
                }
                if let v=self.overlayView { self.overlayRenderer.follow(0,in:v) }
                return
            }
            self.showOverlay(Float(0.72*pow(sin(t/5*Double.pi),2)))
        }
        RunLoop.main.add(timer,forMode:.common); demoTimer=timer
    }
    @objc func blurChanged() {
        blurValueLabel.stringValue="\(Int(blurSlider.doubleValue))"
        previewRenderer.maximumBlur=blurSlider.doubleValue; overlayRenderer.maximumBlur=blurSlider.doubleValue
        UserDefaults.standard.set(blurSlider.doubleValue,forKey:"maximumBlur")
        preview.draw()
    }
    @objc func thresholdChanged() {
        thresholdLabel.stringValue="Below \(Int(startAngle))°"
        previewRenderer.referenceAngle=Float(startAngle); overlayRenderer.referenceAngle=Float(startAngle)
        preview.draw(); hideOverlay(); blockedUntilOpen=true
        UserDefaults.standard.set(startAngle,forKey:"referenceAngle")
    }
    @objc func emergencyStop() {
        enabled=false; hideOverlay(); demoTimer?.invalidate(); demoTimer=nil
        slider.doubleValue=0; previewRenderer.progress=0; preview.draw()
        enableButton.title="Enable"; statusItem.button?.title="◩"
        infoLabel.stringValue="Paused. Your desktop is restored."
    }
    @objc func toggleEnabled() {
        if enabled { emergencyStop(); return }
        demoTimer?.invalidate(); demoTimer=nil; hideOverlay()
        guard lastAngle != nil else { infoLabel.stringValue="Lid sensor unavailable. Preview is still available."; return }
        guard !capturingScreen || desktopReady else { requestCapture(); return }
        enabled=true; blockedUntilOpen=true
        enableButton.title="Pause"; statusItem.button?.title="◩ ON"
        infoLabel.stringValue="Enabled. Open past \(Int(startAngle+3))°, then slowly close the lid."
    }
    func receive(_ angle:Double?) {
        lastSensorTime=CACurrentMediaTime()
        lastAngle=angle
        guard let angle else { angleLabel.stringValue="—°"; blockedUntilOpen=true; hideOverlay(); return }
        let caption="\(Int(angle))°"
        if angleLabel.stringValue != caption { angleLabel.stringValue=caption }
        guard enabled, !sleeping else { return }
        if angle>startAngle+3 { blockedUntilOpen=false }
        guard !blockedUntilOpen else { hideOverlay(); return }
        let p=progress(for:angle)
        if p<=0 {
            if overlay?.isVisible == true {
                if !recovering, let view=overlayView {
                    recovering=true; let generation=overlayGeneration
                    overlayRenderer.onSettled = { [weak self] in
                        guard let self,self.recovering,self.overlayGeneration==generation else { return }
                        self.hideOverlay()
                    }
                    overlayRenderer.follow(0,in:view)
                }
            } else if capturePending { hideOverlay() }
            return
        }
        recovering=false
        if capturingScreen {
            if liveDesktop == nil { if !capturePending { startLiveDesktop() }; return }
            if capturePending { return }
        }
        showOverlay(p)
    }
    func builtInScreen() -> NSScreen? {
        NSScreen.screens.first { s in
            guard let n=s.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return false }
            return CGDisplayIsBuiltin(n.uint32Value) != 0
        }
    }
    func showOverlay(_ p:Float) {
        guard !sleeping else { return }
        guard let screen=builtInScreen() else { return }
        if overlay == nil {
            let w=NSWindow(contentRect:screen.frame,styleMask:.borderless,backing:.buffered,defer:false)
            w.isReleasedWhenClosed=false; w.backgroundColor = .black; w.isOpaque=true
            w.ignoresMouseEvents=true; w.hasShadow=false
            w.level=NSWindow.Level(rawValue:Int(CGWindowLevelForKey(.statusWindow))+1)
            w.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary,.ignoresCycle]
            let v=makeMetalView(device:overlayRenderer.device,renderer:overlayRenderer)
            w.contentView=v; overlay=w; overlayView=v
        }
        window.level=NSWindow.Level(rawValue:Int(CGWindowLevelForKey(.statusWindow))+2)
        if overlay?.isVisible != true {
            overlayGeneration += 1
            let generation=overlayGeneration
            overlay?.alphaValue=0
            overlay?.setFrame(screen.frame,display:true)
            overlay?.orderFrontRegardless(); overlayStarted=Date()
            overlayRenderer.onPresented = { [weak self] in
                guard let self,self.overlayGeneration==generation,self.overlay?.isVisible == true else { return }
                self.overlay?.alphaValue=1
            }
            // A missing drawable must never reveal a black or stale frame.
            DispatchQueue.main.asyncAfter(deadline:.now()+0.6) { [weak self] in
                guard let self,self.overlayGeneration==generation,self.overlay?.isVisible == true,self.overlay?.alphaValue==0 else { return }
                self.blockedUntilOpen=true; self.hideOverlay()
                self.infoLabel.stringValue="Display not ready. Desktop restored; pause and retry."
            }
        }
        if let view=overlayView {
            let fps=60
            if view.preferredFramesPerSecond != fps { view.preferredFramesPerSecond=fps }
            overlayRenderer.follow(p,in:view)
        }
    }
    func hideOverlay() {
        window?.level = .normal
        overlayGeneration += 1; recovering=false
        overlay?.alphaValue=0
        overlay?.orderOut(nil); overlayStarted=nil
        overlayRenderer?.stopFollowing(in:overlayView)
        liveDesktop?.stop(); liveDesktop=nil
        overlayRenderer?.frameSource=nil
        overlayRenderer?.stillImage=previewRenderer?.stillImage
        captureGeneration += 1; capturePending=false
    }
    @objc func changeSource() {
        emergencyStop()
        if sourceControl.selectedSegment == 1 { requestCapture() }
        else { capturingScreen=false; enableButton.isEnabled=true; setImages(artwork); infoLabel.stringValue="Landscape needs no recording permission. Enable to follow the lid." }
    }
    @objc func openScreenSettings() {
        emergencyStop()
        NSWorkspace.shared.open(URL(string:"x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
    }
    func requestCapture() {
        // Use the actual ScreenCaptureKit result, not an unrelated preflight.
        capturingScreen=true; desktopReady=false; enableButton.isEnabled=false
        sourceControl.selectedSegment=1
        infoLabel.stringValue="Connecting to your desktop…"
        captureDesktopPreview()
    }
    func startLiveDesktop(forDemo:Bool=false, completion:(() -> Void)?=nil) {
        guard !capturePending,let screen=builtInScreen(),let number=screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return }
        capturePending=true; captureGeneration += 1
        let ticket=captureGeneration
        func failed(_ message:String) {
            guard self.captureGeneration==ticket else { return }
            self.emergencyStop(); self.infoLabel.stringValue=message
        }
        Task { @MainActor in
            do {
                let content=try await SCShareableContent.excludingDesktopWindows(false,onScreenWindowsOnly:false)
                guard ticket==self.captureGeneration else { return }
                guard let display=content.displays.first(where:{$0.displayID==number.uint32Value}),
                      let own=content.applications.first(where:{$0.processID==ProcessInfo.processInfo.processIdentifier}) else {
                    failed("Could not separate the desktop and panel."); return
                }
                let filter=SCContentFilter(display:display,excludingApplications:[own],exceptingWindows:[])
                if #available(macOS 14.2, *) { filter.includeMenuBar=true }
                let config=SCStreamConfiguration()
                config.width=Int(screen.frame.width*screen.backingScaleFactor)
                config.height=Int(screen.frame.height*screen.backingScaleFactor)
                config.minimumFrameInterval=CMTime(value:1,timescale:60)
                config.queueDepth=3; config.pixelFormat=kCVPixelFormatType_32BGRA
                config.showsCursor=false; config.capturesAudio=false
                let live=try LiveDesktop(device:self.overlayRenderer.device)
                self.liveDesktop=live
                self.overlayRenderer.frameSource = { [weak live] in live?.frame() }
                live.onFailure = { message in failed(message) }
                live.onReady = { [weak self] in
                    guard let self,self.captureGeneration==ticket,!self.sleeping else { return }
                    self.capturePending=false
                    if forDemo { completion?() }
                    else if self.enabled,!self.blockedUntilOpen,let angle=self.lastAngle,self.progress(for:angle)>0 {
                        self.showOverlay(self.progress(for:angle))
                    } else { self.hideOverlay() }
                }
                try await live.start(filter:filter,configuration:config)
                guard ticket==self.captureGeneration else { live.stop(); return }
                DispatchQueue.main.asyncAfter(deadline:.now()+3) { [weak self] in
                    if let self,self.captureGeneration==ticket,self.capturePending { failed("No live desktop frames arrived. Check Permissions and retry.") }
                }
            } catch { failed("Live desktop unavailable (code \((error as NSError).code)). Check Permissions and retry.") }
        }
    }
    func captureDesktopPreview() {
        guard !capturePending, let screen=builtInScreen(), let number=screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return }
        capturePending=true; captureGeneration += 1; let generation=captureGeneration
        Task { @MainActor in
            do {
                let content=try await SCShareableContent.excludingDesktopWindows(false,onScreenWindowsOnly:false)
                guard let display=content.displays.first(where:{$0.displayID==number.uint32Value}) else { throw NSError(domain:"Built-in display unavailable",code:1) }
                // The control panel is a separate, clear foreground layer.
                // Exclude all our windows so neither it nor its preview is baked
                // into the transformed background, including the first capture.
                guard let ownApp=content.applications.first(where: { $0.processID == ProcessInfo.processInfo.processIdentifier }) else {
                    throw NSError(domain:"Unable to separate the panel. Reconnect Desktop.",code:1)
                }
                let filter=SCContentFilter(display:display,excludingApplications:[ownApp],exceptingWindows:[])
                if #available(macOS 14.2, *) { filter.includeMenuBar=true }
                let config=SCStreamConfiguration(); config.width=Int(screen.frame.width*screen.backingScaleFactor); config.height=Int(screen.frame.height*screen.backingScaleFactor)
                config.showsCursor=false; config.captureResolution = .best
                let image=try await SCScreenshotManager.captureImage(contentFilter:filter,configuration:config)
                guard generation==captureGeneration else { return }
                capturePending=false
                desktopReady=true; enableButton.isEnabled=true
                guard setImages(image) else { desktopReady=false; enableButton.isEnabled=false; return }
                infoLabel.stringValue="Desktop connected. Preview or enable the live effect."
            } catch {
                guard generation==captureGeneration else { return }
                capturePending=false; hideOverlay(); enabled=false; desktopReady=false; enableButton.isEnabled=false; enableButton.title="Enable"
                statusItem.button?.title="◩"; infoLabel.stringValue="Desktop unavailable (code \((error as NSError).code)). Check Permissions, reopen the app, then select Desktop."
            }
        }
    }
    @discardableResult func setImages(_ image:CGImage) -> Bool {
        do { try previewRenderer.setImage(image); overlayRenderer.stillImage=previewRenderer.stillImage; preview.draw(); return true }
        catch { infoLabel.stringValue="Image could not be loaded: \(error.localizedDescription)"; return false }
    }
    @objc func chooseImage() {
        emergencyStop()
        let panel=NSOpenPanel(); panel.allowedContentTypes=[.png,.jpeg,.heic,.tiff]; panel.canChooseDirectories=false
        panel.beginSheetModal(for:window) { [weak self] result in
            guard let self,result == .OK,let url=panel.url,let image=NSImage(contentsOf:url),let cg=image.cgImage(forProposedRect:nil,context:nil,hints:nil) else { return }
            self.emergencyStop(); self.capturingScreen=false; self.sourceControl.selectedSegment=0
            self.enableButton.isEnabled=true
            self.artwork=cg; self.setImages(cg); self.infoLabel.stringValue="Custom image loaded for this session."
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification:Notification) {
        sensor.stop(); healthTimer?.invalidate(); demoTimer?.invalidate(); hideOverlay()
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        for t in notificationTokens { NSWorkspace.shared.notificationCenter.removeObserver(t); NotificationCenter.default.removeObserver(t); DistributedNotificationCenter.default().removeObserver(t) }
    }
    func runLiveStreamCheck() {
        sensor.stop(); window.orderOut(nil)
        overlayRenderer.measuring=true; capturingScreen=true
        startLiveDesktop(forDemo:true) { [weak self] in
            guard let self else { return }
            self.startFullScreenDemo()
            DispatchQueue.main.asyncAfter(deadline:.now()+3) {
                let frames=self.liveDesktop?.frameCount() ?? 0
                let rendered=self.overlayRenderer.frameTimes.count
                let visible=self.overlay?.alphaValue == 1
                self.emergencyStop()
                print("captured complete desktop frames: \(frames)")
                print("rendered frames: \(rendered)")
                print("first frame visible: \(visible)")
                let stopped=self.liveDesktop == nil && self.overlayRenderer.frameSource == nil && self.overlayView?.isPaused == true
                print("capture and renderer stopped: \(stopped)")
                if frames<1 || rendered<30 || !visible || !stopped { exit(1) }
                print("PASS: real desktop stream reaches Metal and stops cleanly; terminal permission context only")
                NSApp.terminate(nil)
            }
        }
        DispatchQueue.main.asyncAfter(deadline:.now()+8) { [weak self] in
            print("FAIL: live stream timeout: \(self?.infoLabel.stringValue ?? "unknown")"); exit(1)
        }
    }
    func runSelfTest() {
        sensor.stop()
        var count=0
        func check(_ condition:Bool,_ name:String) {
            if !condition { print("FAIL: \(name)"); exit(1) }
            count += 1; print("PASS: \(name)")
        }
        check(lastAngle != nil,"physical HID sensor returns an angle")
        check(progress(for:129)==0 && progress(for:12)==1,"angle endpoints")
        check(progress(for:60)>0 && progress(for:60)<progress(for:30),"closing progress is monotonic")
        enabled=true; blockedUntilOpen=true; receive(60)
        check(overlay?.isVisible != true,"arming while closed waits for opening")
        receive(129); receive(60)
        check(overlay?.isVisible == true,"closing shows built-in display overlay")
        check(overlay?.ignoresMouseEvents == true,"overlay does not intercept clicks")
        receive(150)
        RunLoop.main.run(until:Date(timeIntervalSinceNow:0.3))
        check(overlay?.isVisible == false,"opening removes overlay")
        receive(60); overlayStarted=Date(timeIntervalSinceNow:-13); receive(60)
        check(overlay?.isVisible == true,"healthy partial closure is not forcibly dismissed")
        receive(nil)
        check(overlay?.isVisible == false && blockedUntilOpen,"missing sensor input fails open")
        receive(150); receive(60)
        NSWorkspace.shared.notificationCenter.post(name:NSWorkspace.screensDidSleepNotification,object:nil)
        check(sleeping && overlay?.isVisible == false,"screen sleep hides overlay")
        sleeping=false; blockedUntilOpen=false; receive(60); emergencyStop()
        check(!enabled && overlay?.isVisible == false && slider.doubleValue==0,"emergency stop clears effect and preview")
        check(!capturingScreen && liveDesktop == nil,"default artwork path does not request or use screen capture")
        print("\(count) checks passed. Physical hand-driven motion and permission-granted capture remain manual checks.")
        NSApp.terminate(nil)
    }
    func runLifecycleCheck() {
        sensor.stop(); window.orderOut(nil)
        var failed=false
        func check(_ condition:Bool,_ name:String) { print("\(condition ? "PASS" : "FAIL"): \(name)"); if !condition { failed=true } }
        enabled=true; blockedUntilOpen=false
        receive(startAngle-25)
        check(overlay?.alphaValue == 0,"first frame hidden until ready")
        RunLoop.main.run(until:Date(timeIntervalSinceNow:0.18))
        let statusLevel=Int(CGWindowLevelForKey(.statusWindow))
        let entries=CGWindowListCopyWindowInfo(.optionAll,kCGNullWindowID) as? [[String:Any]] ?? []
        let own=entries.first { ($0[kCGWindowNumber as String] as? Int)==overlay?.windowNumber }
        check((own?[kCGWindowLayer as String] as? Int ?? -1)>statusLevel,"WindowServer places overlay above menu status items")
        check(overlay?.frame == builtInScreen()?.frame,"overlay covers full display including menu area")
        check(window.level.rawValue > (overlay?.level.rawValue ?? Int.max),"settings panel stays above the effect")
        check(overlay?.isVisible == true && overlay?.alphaValue == 1,"prepared Metal frame becomes visible")
        overlayStarted=Date(timeIntervalSinceNow:-13)
        receive(startAngle-25)
        check(overlay?.isVisible == true,"healthy stationary hold stays active")
        receive(startAngle+5)
        check(recovering,"opening completes the final frame before removal")
        RunLoop.main.run(until:Date(timeIntervalSinceNow:0.3))
        check(overlay?.isVisible == false,"opening removes the layer after settling")
        receive(startAngle-35)
        RunLoop.main.run(until:Date(timeIntervalSinceNow:0.12))
        receive(startAngle+5); receive(startAngle-20)
        RunLoop.main.run(until:Date(timeIntervalSinceNow:0.25))
        check(overlay?.isVisible == true && !recovering,"reversing direction cancels pending recovery")
        emergencyStop()
        RunLoop.main.run(until:Date(timeIntervalSinceNow:0.15))
        check(overlay?.isVisible == false && overlayView?.isPaused == true,"late frames cannot revive a stopped overlay")
        check(window.level == .normal,"stopping restores normal settings window level")
        if failed { exit(1) }
        NSApp.terminate(nil)
    }
    func runCadenceCheck() {
        sensor.stop(); window.orderOut(nil)
        enabled=true; blockedUntilOpen=false; threshold.doubleValue=85
        overlayRenderer.measuring=true
        let began=CACurrentMediaTime()
        let timer=Timer(timeInterval:1.0/30,repeats:true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            let elapsed=CACurrentMediaTime()-began
            if elapsed>=4 {
                timer.invalidate(); self.hideOverlay()
                self.overlayRenderer.reportPerformance()
                let gaps=zip(self.overlayRenderer.frameTimes.dropFirst(),self.overlayRenderer.frameTimes).map { $0-$1 }
                let passes=(gaps.max() ?? 1)<0.05
                print(passes ? "PASS: slow quantized input keeps a continuous display clock" : "FAIL: slow quantized input interrupts display clock")
                NSApp.terminate(nil); return
            }
            self.receive(80-floor(elapsed*2))
        }
        RunLoop.main.add(timer,forMode:.common)
    }
    func runPerformanceCheck() {
        sensor.stop(); window.orderOut(nil)
        enabled=true; blockedUntilOpen=false; threshold.doubleValue=85
        overlayRenderer.referenceAngle=85
        overlayRenderer.measuring=true
        let began=CACurrentMediaTime()
        let timer=Timer(timeInterval:1.0/30,repeats:true) { [weak self] timer in
            guard let self else { return }
            let elapsed=CACurrentMediaTime()-began
            if elapsed>=4 {
                timer.invalidate()
                DispatchQueue.main.asyncAfter(deadline:.now()+0.35) {
                    let paused=self.overlayView?.isPaused == true
                    let count=self.overlayRenderer.frameTimes.count
                    DispatchQueue.main.asyncAfter(deadline:.now()+0.15) {
                        let settled = !paused && self.overlayRenderer.frameTimes.count>count
                        self.hideOverlay()
                        self.overlayRenderer.reportPerformance()
                        print(settled ? "PASS: active overlay keeps rendering" : "FAIL: active display clock stopped")
                        print(self.overlayView?.isPaused == true ? "PASS: hidden overlay is paused" : "FAIL: hidden overlay keeps rendering")
                        if !settled { exit(1) }
                        NSApp.terminate(nil)
                    }
                }
                return
            }
            // Replay quantized, 30 Hz lid input through the real fullscreen path.
            self.receive((84-elapsed*13).rounded())
        }
        RunLoop.main.add(timer,forMode:.common)
    }
}

let app=NSApplication.shared
let delegate=AppDelegate()
app.delegate=delegate
app.setActivationPolicy(.regular)
app.run()
