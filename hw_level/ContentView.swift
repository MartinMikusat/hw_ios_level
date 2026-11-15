import SwiftUI

struct ContentView: View {
    @StateObject private var level = LevelModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if !level.available {
                        ContentUnavailableView("Motion Unavailable", systemImage: "sensor", description: Text("Motion data is not available on this device."))
                    } else if !level.hasReading {
                        ProgressView("Waiting for motion data")
                    } else {
                        Text(level.mode.label).font(.headline)
                        BubbleView(x: level.x, y: level.y, flat: level.mode == .flat, isLevel: level.isLevel)
                            .frame(maxWidth: 280)
                            .aspectRatio(level.mode == .flat ? 1 : 2.4, contentMode: .fit)
                            .accessibilityHidden(true)
                        Text(level.isLevel ? "Level" : "Not level")
                            .font(.title2.bold())
                        if level.mode == .flat {
                            HStack(spacing: 32) {
                                reading("Left to right", level.x)
                                reading("Top to bottom", level.y)
                            }
                        } else {
                            reading("Angle", level.x)
                        }
                        if level.calibrated {
                            Label("Calibrated", systemImage: "checkmark.circle")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Button("Calibrate") { level.calibrate() }
                            .buttonStyle(.borderedProminent)
                            .disabled(!level.canCalibrate)
                        if level.calibrated {
                            Button("Reset Calibration") { level.resetCalibration() }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
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
        .onDisappear { level.stop() }
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
    let isLevel: Bool

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let diameter = min(size.width, size.height) * 0.2
            let rangeX = (size.width - diameter) / 2
            let rangeY = (size.height - diameter) / 2
            ZStack {
                RoundedRectangle(cornerRadius: flat ? size.width / 2 : size.height / 2)
                    .fill(Color(uiColor: .secondarySystemBackground))
                RoundedRectangle(cornerRadius: flat ? size.width / 2 : size.height / 2)
                    .strokeBorder(Color.secondary, lineWidth: 2)
                Circle().strokeBorder(Color.secondary, lineWidth: 2)
                    .frame(width: diameter * 1.4, height: diameter * 1.4)
                Circle()
                    .fill(isLevel ? Color.green : Color.accentColor)
                    .frame(width: diameter, height: diameter)
                    .offset(x: min(max(x / 15, -1), 1) * rangeX,
                            y: flat ? min(max(-y / 15, -1), 1) * rangeY : 0)
            }
        }
    }
}
