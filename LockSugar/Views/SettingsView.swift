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
                    footer: Text("Choose which app opens when you tap the Lock Screen widget. Since Abbott does not register a custom URL scheme for FreeStyle Libre 3, the Direct option links directly to the App Store page with the Open button.")
                ) {
                    Picker("Tap Action", selection: Binding(
                        get: { viewModel.widgetTapAction },
                        set: { viewModel.setWidgetTapAction($0) }
                    )) {
                        ForEach(SharedStorage.WidgetTapActionOption.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
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
                Section(header: Text("Connected Bluetooth Headphones")) {
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
