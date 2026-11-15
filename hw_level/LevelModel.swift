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
    @AppStorage("repeatSound") var repeatSound = true
    @AppStorage("hapticEnabled") var hapticEnabled = true

    private let motion = CMMotionManager()
    private let sound = LevelSound()
    private var rawX = 0.0
    private var rawY = 0.0
    private let haptics = UINotificationFeedbackGenerator()
    private var entryArmed = true
    private var lastPingTime = 0.0
    @Published private(set) var hasReading = false
    private let defaults = UserDefaults.standard

    static let toleranceDegrees = 0.5
    static let feedbackRearmDegrees = 1.0
    static let pingInterval = 1.0

    var isLevel: Bool { (mode == .flat ? hypot(x, y) : abs(x)) <= Self.toleranceDegrees }
    var canCalibrate: Bool { available && hasReading }

    func start() {
        UIApplication.shared.isIdleTimerDisabled = true
        guard !motion.isDeviceMotionActive else { return }
        guard motion.isDeviceMotionAvailable else { available = false; return }
        sound.prepare()
        haptics.prepare()
        // CoreMotion clamps this to the hardware maximum (100 Hz on iPhone).
        motion.deviceMotionUpdateInterval = 1.0 / 120.0
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
        entryArmed = true
    }

    func calibrate() {
        guard canCalibrate else { return }
        defaults.set([rawX, rawY], forKey: key)
        applyCalibration()
        entryArmed = !isLevel
    }

    func resetCalibration() {
        defaults.removeObject(forKey: key)
        applyCalibration()
        entryArmed = !isLevel
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
        if next != mode { mode = next; entryArmed = true }
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
        updateFeedback()
    }

    // Entry feedback fires once per approach: it re-arms only after the reading leaves the wider re-arm band,
    // so jitter around the tolerance edge cannot retrigger it. With repeating sound, the sound also pings
    // while level, so silence tells a user who cannot see the screen that the level is lost.
    private func updateFeedback() {
        let deviation = mode == .flat ? hypot(x, y) : abs(x)
        if deviation > Self.feedbackRearmDegrees { entryArmed = true }
        guard isLevel else { return }
        let entered = entryArmed
        entryArmed = false
        if entered && hapticEnabled {
            haptics.notificationOccurred(.success)
            haptics.prepare()
        }
        guard soundEnabled else { return }
        let now = CACurrentMediaTime()
        if repeatSound ? now - lastPingTime >= Self.pingInterval : entered {
            lastPingTime = now
            sound.play()
        }
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

    func prepare() {
        queue.async {
            guard let url = Bundle.main.url(forResource: "level", withExtension: "wav") else {
                NSLog("Level sound file is missing")
                return
            }
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
                try AVAudioSession.sharedInstance().setActive(true)
                if self.player == nil { self.player = try AVAudioPlayer(contentsOf: url) }
                self.player?.prepareToPlay()
            } catch {
                NSLog("Level sound failed: %@", error.localizedDescription)
            }
        }
    }

    // A playing sound is never restarted: cutting the waveform mid-cycle produces a click.
    func play() {
        queue.async {
            guard let player = self.player, !player.isPlaying else { return }
            if !player.play() {
                // An interruption can deactivate the session; reactivate and retry once.
                try? AVAudioSession.sharedInstance().setActive(true)
                player.play()
            }
        }
    }
}
