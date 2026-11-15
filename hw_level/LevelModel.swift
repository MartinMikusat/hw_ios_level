import SwiftUI
import CoreMotion
import AVFAudio
import UIKit

enum LevelMode: String {
    case flat, top, bottom, left, right

    var label: String {
        switch self {
        case .flat: return "Flat surface"
        case .top, .bottom, .left, .right: return "Sideways"
        }
    }
}

@MainActor
final class LevelModel: ObservableObject {
    @Published private(set) var mode: LevelMode = .flat
    @Published private(set) var x = 0.0
    @Published private(set) var y = 0.0
    @Published private(set) var available = true
    @Published private(set) var calibrated = false
    @AppStorage("soundEnabled") var soundEnabled = true
    @AppStorage("hapticEnabled") var hapticEnabled = true

    private let motion = CMMotionManager()
    private let sound = LevelSound()
    private var rawX = 0.0
    private var rawY = 0.0
    private var wasLevel = false
    @Published private(set) var hasReading = false
    private let defaults = UserDefaults.standard

    var isLevel: Bool { abs(x) <= 0.5 && (mode != .flat || abs(y) <= 0.5) }
    var canCalibrate: Bool { available && hasReading }

    func start() {
        UIApplication.shared.isIdleTimerDisabled = true
        guard !motion.isDeviceMotionActive else { return }
        guard motion.isDeviceMotionAvailable else { available = false; return }
        motion.deviceMotionUpdateInterval = 1.0 / 30.0
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, error in
            Task { @MainActor in
                guard let self else { return }
                guard error == nil, let data else {
                    self.available = false
                    self.hasReading = false
                    self.motion.stopDeviceMotionUpdates()
                    return
                }
                self.update(data.gravity)
            }
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
        UIApplication.shared.isIdleTimerDisabled = false
        hasReading = false
        wasLevel = false
    }

    func calibrate() {
        guard canCalibrate else { return }
        defaults.set([rawX, rawY], forKey: key)
        applyCalibration()
        wasLevel = isLevel
    }

    func resetCalibration() {
        defaults.removeObject(forKey: key)
        applyCalibration()
        wasLevel = isLevel
    }

    private var key: String { "calibration.\(mode.rawValue)" }

    private func update(_ gravity: CMAcceleration) {
        let gx = gravity.x, gy = gravity.y, gz = gravity.z
        let next: LevelMode
        let planar = hypot(gx, gy)
        if mode == .flat ? abs(gz) > 0.70 : abs(gz) > 0.80 {
            next = .flat
        } else if abs(gx) > abs(gy) {
            next = gx > 0 ? .left : .right
        } else {
            next = gy > 0 ? .top : .bottom
        }
        if next != mode { mode = next; wasLevel = false }
        if next == .flat {
            rawX = atan2(gx, abs(gz)) * 180 / .pi
            rawY = atan2(gy, abs(gz)) * 180 / .pi
        } else if planar > 0 {
            switch next {
            case .left: rawX = atan2(gy, gx) * 180 / .pi
            case .right: rawX = atan2(-gy, -gx) * 180 / .pi
            case .top: rawX = atan2(-gx, gy) * 180 / .pi
            case .bottom: rawX = atan2(gx, -gy) * 180 / .pi
            case .flat: break
            }
            rawY = 0
        }
        available = true
        hasReading = true
        applyCalibration()
        if isLevel && !wasLevel {
            if hapticEnabled { UINotificationFeedbackGenerator().notificationOccurred(.success) }
            if soundEnabled { sound.play() }
        }
        wasLevel = isLevel
    }

    private func applyCalibration() {
        let offsets = defaults.array(forKey: key) as? [Double]
        calibrated = offsets?.count == 2
        x = rawX - (offsets?.first ?? 0)
        y = rawY - (offsets?.last ?? 0)
    }
}

private final class LevelSound {
    private let queue = DispatchQueue(label: "com.halwayland.hw-level.sound", qos: .userInitiated)
    private var player: AVAudioPlayer?

    func play() {
        queue.async {
            guard let url = Bundle.main.url(forResource: "level", withExtension: "wav") else {
                NSLog("Level sound file is missing")
                return
            }
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
                try AVAudioSession.sharedInstance().setActive(true)
                if self.player == nil { self.player = try AVAudioPlayer(contentsOf: url) }
                self.player?.currentTime = 0
                self.player?.play()
            } catch {
                NSLog("Level sound failed: %@", error.localizedDescription)
            }
        }
    }
}
