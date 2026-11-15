import SwiftUI

struct ContentView: View {
    @StateObject private var level = LevelModel()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if !level.available {
                    ContentUnavailableView("Motion Unavailable", systemImage: "sensor", description: Text("Motion data is not available on this device."))
                } else if !level.hasReading {
                    ProgressView("Waiting for motion data")
                } else if verticalSizeClass == .compact {
                    HStack(spacing: 24) {
                        graphic
                        details.frame(width: 300)
                    }
                    .padding()
                } else {
                    VStack(spacing: 16) {
                        graphic
                        details
                    }
                    .padding()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar {
                Button("Settings", systemImage: "gearshape") { showingSettings = true }
            }
            .sheet(isPresented: $showingSettings) {
                NavigationStack {
                    Form {
                        Section("Level Feedback") {
                            Toggle("Sound", isOn: $level.soundEnabled)
                            Toggle("Haptics", isOn: $level.hapticEnabled)
                        }
                    }
                    .navigationTitle("Settings")
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showingSettings = false } } }
                }
            }
        }
        .onAppear { if scenePhase == .active { level.start() } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { level.start() } else { level.stop() }
        }
        .onChange(of: level.mode) { _, mode in
            AppDelegate.updateOrientation(mode: mode)
        }
        .onDisappear { level.stop() }
    }

    private var graphic: some View {
        BubbleView(x: level.x, y: level.y, flat: level.mode == .flat, vertical: verticalLevel, isLevel: level.isLevel)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityHidden(true)
    }

    private var details: some View {
        VStack(spacing: 12) {
            Text(level.mode.label).font(.headline)
            Text(level.isLevel ? "Level" : "Not level").font(.title2.bold())
            if level.mode == .flat {
                HStack(spacing: 32) {
                    reading("Left to right", level.x)
                    reading("Top to bottom", level.y)
                }
            } else {
                reading("Angle", level.x)
            }
            calibration
        }
    }

    private var calibration: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text("Optional. Rest the phone on a surface you know is level, then tap Calibrate to treat this position as zero for this orientation.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Calibrate") { level.calibrate() }
                        .disabled(!level.canCalibrate)
                    if level.calibrated {
                        Button("Reset") { level.resetCalibration() }
                    }
                    Spacer()
                    if level.calibrated {
                        Label("Calibrated", systemImage: "checkmark.circle")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        } label: {
            Text("Calibration").font(.caption.bold())
        }
    }

    private var verticalLevel: Bool {
        let sideEdge = level.mode == .left || level.mode == .right
        return level.mode != .flat && (sideEdge != (verticalSizeClass == .compact))
    }

    private func reading(_ label: String, _ value: Double) -> some View {
        VStack {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value, format: .number.sign(strategy: .always()).precision(.fractionLength(1)))
                .font(.title.monospacedDigit()) + Text("°").font(.title)
        }
        .accessibilityElement(children: .combine)
    }
}

struct BubbleView: View {
    let x: Double
    let y: Double
    let flat: Bool
    let vertical: Bool
    let isLevel: Bool

    var body: some View {
        GeometryReader { geometry in
            // The vial takes the full length of the available space; its thickness is capped so it stays a tube.
            let available = geometry.size
            let size: CGSize = flat
                ? CGSize(width: min(available.width, available.height), height: min(available.width, available.height))
                : (vertical
                    ? CGSize(width: min(available.width, available.height * 0.4), height: available.height)
                    : CGSize(width: available.width, height: min(available.height, available.width * 0.4)))
            let diameter = flat ? size.width * 0.2 : min(size.width, size.height) * 0.6
            let rangeX = (size.width - diameter) / 2
            let rangeY = (size.height - diameter) / 2
            // The ring is sized so the bubble lies fully inside it exactly when the reading is within tolerance.
            let ringDiameter = diameter + (flat || !vertical ? rangeX : rangeY) * LevelModel.toleranceDegrees / 7.5
            ZStack {
                RoundedRectangle(cornerRadius: flat ? size.width / 2 : min(size.width, size.height) / 2)
                    .fill(Color(uiColor: .secondarySystemBackground))
                RoundedRectangle(cornerRadius: flat ? size.width / 2 : min(size.width, size.height) / 2)
                    .strokeBorder(Color.secondary, lineWidth: 2)
                Circle().strokeBorder(Color.secondary, lineWidth: 2)
                    .frame(width: ringDiameter, height: ringDiameter)
                Circle()
                    .fill(isLevel ? Color.green : Color.accentColor)
                    .frame(width: diameter, height: diameter)
                    .offset(x: vertical ? 0 : min(max(x / 15, -1), 1) * rangeX,
                            y: flat ? min(max(-y / 15, -1), 1) * rangeY : (vertical ? min(max(x / 15, -1), 1) * rangeY : 0))
            }
            .frame(width: size.width, height: size.height)
            .position(x: available.width / 2, y: available.height / 2)
        }
    }
}
