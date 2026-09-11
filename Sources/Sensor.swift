import Foundation
import IOKit.hid

// Discovered from this machine's HID element descriptors; no third-party code.
final class LidSensor {
    private var manager: IOHIDManager?
    private var device: IOHIDDevice?
    private var element: IOHIDElement?
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "local.jux.hingeglass.sensor", qos: .userInitiated)
    private var generation = 0
    private let deliveryLock = NSLock()
    private var deliveryPending = false
    private var latestAngle: Double?
    var onAngle: ((Double?) -> Void)?

    // Lifecycle and callbacks run on main; all HID work belongs to this queue.
    func start() {
        stop()
        queue.sync { connect() }
        let initial = queue.sync { readAngle() }
        onAngle?(initial)
        let ticket=generation
        let t=DispatchSource.makeTimerSource(queue:queue)
        t.schedule(deadline:.now()+1.0/60,repeating:1.0/60,leeway:.milliseconds(1))
        t.setEventHandler { [weak self] in
            guard let self else { return }
            let angle=self.readAngle()
            self.deliveryLock.lock()
            self.latestAngle=angle
            let shouldDeliver = !self.deliveryPending
            self.deliveryPending=true
            self.deliveryLock.unlock()
            guard shouldDeliver else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self,self.generation==ticket else { return }
                self.deliveryLock.lock()
                let latest=self.latestAngle
                self.deliveryPending=false
                self.deliveryLock.unlock()
                self.onAngle?(latest)
            }
        }
        timer=t; t.resume()
    }
    private func connect() {
        let m = IOHIDManagerCreate(kCFAllocatorDefault, 0)
        IOHIDManagerSetDeviceMatching(m, [kIOHIDPrimaryUsagePageKey: 32, kIOHIDPrimaryUsageKey: 138] as CFDictionary)
        guard IOHIDManagerOpen(m, 0) == kIOReturnSuccess else { return }
        manager = m
        for d in (IOHIDManagerCopyDevices(m) as? Set<IOHIDDevice>) ?? [] {
            let elements = (IOHIDDeviceCopyMatchingElements(d, nil, 0) as? [IOHIDElement]) ?? []
            if let e = elements.first(where: { IOHIDElementGetUsagePage($0) == 32 && IOHIDElementGetUsage($0) == 1151 && IOHIDElementGetLogicalMax($0) == 360 }), IOHIDDeviceOpen(d, 0) == kIOReturnSuccess {
                device = d; element = e; break
            }
        }
    }
    private func readAngle() -> Double? {
        guard let d = device else { return nil }
        // Live comparison showed the element cache updates about once per second
        // on this Mac; the feature report changes about every 100 ms while moving.
        // Read-only report 1: little-endian integer degrees following report ID.
        var report = [UInt8](repeating: 0, count: 8)
        report[0] = 1
        var count = report.count
        let result = IOHIDDeviceGetReport(d, kIOHIDReportTypeFeature, 1, &report, &count)
        guard result == kIOReturnSuccess, count >= 3, report[0] == 1 else { return nil }
        let angle = Int(report[1]) | (Int(report[2]) << 8)
        return (0...180).contains(angle) ? Double(angle) : nil
    }

    func stop() {
        generation += 1
        timer?.cancel(); timer = nil
        queue.sync {
            if let d = device { IOHIDDeviceClose(d, 0) }
            if let m = manager { IOHIDManagerClose(m, 0) }
            device=nil; element=nil; manager=nil
        }
        deliveryLock.lock(); deliveryPending=false; latestAngle=nil; deliveryLock.unlock()
    }
    deinit { timer?.cancel() }
}
