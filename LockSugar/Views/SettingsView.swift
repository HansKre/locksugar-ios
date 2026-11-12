import SwiftUI

public struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel
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
                    footer: Text("Calibrating the Y-axis zooms the vertical scale to recent readings. Longer time windows compress the horizontal axis, matching the steepness of the FreeStyle Libre curve.")
                ) {
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
                    
                    Picker(selection: Binding(
                        get: { viewModel.chartHistoryDurationHours },
                        set: { viewModel.setChartHistoryDurationHours($0) }
                    )) {
                        Text("2 Hours").tag(2.0)
                        Text("3 Hours (Default)").tag(3.0)
                        Text("4 Hours").tag(4.0)
                        Text("6 Hours").tag(6.0)
                        Text("12 Hours").tag(12.0)
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Chart Time Window")
                                    .font(.body)
                                Text("Visible duration on widget chart")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } icon: {
                            Image(systemName: "clock.arrow.circlepath")
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
