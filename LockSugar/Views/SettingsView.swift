import SwiftUI

public struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel
    @ObservedObject private var batteryMonitor = BluetoothBatteryMonitor.shared
    @Environment(\.dismiss) private var dismiss
    
    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationView {
            Form {
                // MARK: - Lock Screen Widget Options
                Section(
                    header: Text("Lock Screen Widget"),
                    footer: Text("When enabled, the battery percentage of your connected Bluetooth headphones appears in the Lock Screen widget.")
                ) {
                    Toggle(isOn: Binding(
                        get: { viewModel.showHeadphoneBattery },
                        set: { viewModel.setShowHeadphoneBattery($0) }
                    )) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Show Headphone Battery")
                                    .font(.body)
                                Text("Only displayed while headphones are connected")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } icon: {
                            Image(systemName: "headphones")
                                .foregroundColor(.accentColor)
                        }
                    }
                    
                    Toggle(isOn: Binding(
                        get: { viewModel.isDynamicYAxisEnabled },
                        set: { viewModel.setDynamicYAxisEnabled($0) }
                    )) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Calibrate Y-Axis to Data")
                                    .font(.body)
                                Text("Calibrate Y-axis range to actual readings")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } icon: {
                            Image(systemName: "chart.xyaxis.line")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                
                // MARK: - Widget Tap Action
                Section(
                    header: Text("Widget Tap Action"),
                    footer: Text("On the 50% rectangular Lock Screen widget, the left 50% triggers your Insulin Timer shortcut and the right 50% triggers the Libre 3 action configured below. Circular and inline widgets open Libre 3 directly.")
                ) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Lock Screen 50% Widget Split", systemImage: "rectangle.split.2x1")
                            .font(.subheadline.bold())
                            .foregroundColor(.accentColor)
                        Text("• Left 50%: Triggers Apple Shortcut \"\(viewModel.insulinShortcutName)\".\n• Right 50%: Triggers the Libre 3 action below.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 2)
                    
                    HStack {
                        Text("Insulin Shortcut:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextField("Insulin Timer starten", text: Binding(
                            get: { viewModel.insulinShortcutName },
                            set: { viewModel.setInsulinShortcutName($0) }
                        ))
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                    }
                    
                    Picker("Right Tap Action", selection: Binding(
                        get: { viewModel.widgetTapAction },
                        set: { viewModel.setWidgetTapAction($0) }
                    )) {
                        ForEach(SharedStorage.WidgetTapActionOption.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    
                    if viewModel.widgetTapAction == .libre3Direct {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Direct Scheme (freestylelibre3://)", systemImage: "bolt.fill")
                                .font(.subheadline.bold())
                                .foregroundColor(.accentColor)
                            Text("Attempts to launch the FreeStyle Libre 3 app directly. If direct opening is not supported on your iOS version, LockSugar automatically falls back to the \"Libre 3\" shortcut or App Store.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    if viewModel.widgetTapAction == .custom {
                        HStack {
                            Text("URL:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextField("e.g. freestylelibre3://", text: Binding(
                                get: { viewModel.widgetTapCustomURL },
                                set: { viewModel.setWidgetTapCustomURL($0) }
                            ))
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                        }
                    }
                    
                    if viewModel.widgetTapAction == .libre3Shortcut {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Apple Shortcut Setup", systemImage: "info.circle")
                                .font(.subheadline.bold())
                                .foregroundColor(.accentColor)
                            Text("In Apple's Shortcuts app, create a shortcut named \"Libre 3\" with the action: \"Open App → FreeStyle Libre 3\". Tapping the widget will immediately launch that shortcut.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // MARK: - Bluetooth Headphone Status
                Section(
                    header: Text("Connected Bluetooth Headphones"),
                    footer: Text("Apple's iOS sandbox only exposes battery percentage for Bluetooth Low Energy (BLE) devices supporting GATT Battery Service. Classic Bluetooth audio devices (such as Shokz OpenRun) send battery via internal Hands-Free Profile commands reserved for iOS system widgets.")
                ) {
                    let info = batteryMonitor.currentInfo ?? viewModel.headphoneInfo
                    let isConnected = info?.isConnected == true
                    
                    HStack(spacing: 12) {
                        Circle()
                            .fill(isConnected ? Color.green : Color.secondary.opacity(0.4))
                            .frame(width: 10, height: 10)
                        
                        Image(systemName: "headphones")
                            .foregroundColor(isConnected ? .primary : .secondary)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(isConnected ? (info?.deviceName ?? "Bluetooth Headphone") : "No headphones connected")
                                .font(.body.weight(isConnected ? .semibold : .regular))
                                .foregroundColor(isConnected ? .primary : .secondary)
                            
                            if isConnected, let pct = info?.formattedPercentage {
                                Text("Battery: \(pct)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            } else if isConnected {
                                Text("Connected (audio active)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if isConnected, let pct = info?.formattedPercentage {
                            Text(pct)
                                .font(.headline.bold())
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    if isConnected {
                        Button(action: { batteryMonitor.scanNow() }) {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .rotationEffect(.degrees(batteryMonitor.isScanning ? 360 : 0))
                                    .animation(batteryMonitor.isScanning ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: batteryMonitor.isScanning)
                                Text(batteryMonitor.isScanning ? "Scanning for battery..." : "Scan for Battery")
                                    .font(.subheadline)
                            }
                        }
                        .disabled(batteryMonitor.isScanning)
                        
                        HStack {
                            Text("Battery Level:")
                                .font(.subheadline)
                            Spacer()
                            Picker("Battery Level", selection: Binding(
                                get: { info?.batteryLevel ?? 0 },
                                set: { batteryMonitor.setBatteryLevel(level: $0 > 0 ? $0 : nil) }
                            )) {
                                Text(info?.batteryLevel == nil ? "Auto (No % shown)" : "Clear").tag(0)
                                ForEach([100, 90, 80, 70, 60, 50, 40, 30, 20, 10], id: \.self) { val in
                                    Text("\(val)%").tag(val)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                }
                
                // MARK: - Bluetooth Diagnostics
                Section(
                    header: Text("Bluetooth Diagnostics"),
                    footer: Text("Live debug output from CoreBluetooth and audio hardware probes. Tap 'Copy Logs' to copy the logs and share them.")
                ) {
                    HStack {
                        Button(action: {
                            batteryMonitor.scanNow()
                        }) {
                            Label(batteryMonitor.isScanning ? "Scanning..." : "Scan", systemImage: "arrow.clockwise")
                        }
                        .disabled(batteryMonitor.isScanning)
                        
                        Spacer()
                        
                        Button(action: {
                            #if canImport(UIKit)
                            UIPasteboard.general.string = batteryMonitor.logsAsText
                            #endif
                        }) {
                            Label("Copy Logs", systemImage: "doc.on.doc")
                        }
                        .disabled(batteryMonitor.diagnosticLogs.isEmpty)
                        
                        Spacer()
                        
                        Button(role: .destructive, action: {
                            batteryMonitor.clearLogs()
                        }) {
                            Label("Clear", systemImage: "trash")
                        }
                    }
                    .buttonStyle(.borderless)
                    
                    if batteryMonitor.diagnosticLogs.isEmpty {
                        Text("No logs yet. Tap 'Scan' to start discovery.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ScrollView {
                            Text(batteryMonitor.logsAsText)
                                .font(.system(size: 10, weight: .regular, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(4)
                        }
                        .frame(maxHeight: 220)
                        .background(Color(UIColor.tertiarySystemBackground))
                        .cornerRadius(6)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}
