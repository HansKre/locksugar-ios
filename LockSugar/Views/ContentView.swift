import SwiftUI

public struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()
    @ObservedObject private var liveActivityManager = LiveActivityManager.shared
    @Environment(\.scenePhase) private var scenePhase
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerView
                    
                    if let error = viewModel.errorMessage {
                        errorBanner(error)
                    }
                    if let liveActivityError = liveActivityManager.errorMessage {
                        errorBanner(liveActivityError)
                    }
                    
                    if viewModel.isConnected {
                        connectedView(viewModel.lastReading)
                    } else {
                        loginFormView
                    }
                }
                .padding(20)
            }
            .navigationTitle("LockSugar")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $viewModel.showingInstructions) {
                WidgetSetupInstructionsView()
            }
        }
        .navigationViewStyle(.stack)
        .task {
            if viewModel.isConnected {
                await viewModel.refreshReading()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && viewModel.isConnected {
                Task {
                    await viewModel.refreshReading()
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 10) {
            Image(systemName: "drop.fill")
                .font(.system(size: 48))
                .foregroundColor(.red)
            
            Text("LockSugar")
                .font(.title.bold())
            
            Text("Ultra-minimalist glucose readings on your Lock Screen")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Connected Status
    
    private func connectedView(_ reading: GlucoseReading?) -> some View {
        VStack(spacing: 20) {
            // Live Glucose Card
            VStack(spacing: 12) {
                HStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 10, height: 10)
                    Text("Connected to LibreLinkUp")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.green)
                    Spacer()
                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                
                if let reading = reading {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(reading.formattedValue)
                            .font(.system(size: 64, weight: .bold, design: .rounded))
                            .foregroundColor(reading.zoneColor)
                        Text(reading.trendArrowSymbol)
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundColor(reading.zoneColor)
                        Text(reading.glucoseUnits.label)
                            .font(.title2.weight(.medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    .opacity(reading.isStale() ? 0.6 : 1.0)
                    
                    HStack(spacing: 4) {
                        if Calendar.current.isDateInToday(reading.timestamp) {
                            Text("Last reading: \(reading.timestamp, style: .time)")
                        } else {
                            Text("Last reading: \(reading.timestamp, style: .date) \(reading.timestamp, style: .time)")
                        }
                        if reading.isStale() {
                            Text("(stale)")
                                .foregroundColor(.orange)
                        }
                    }
                    .font(.footnote)
                    .foregroundColor(.secondary)
                } else {
                    VStack(spacing: 8) {
                        Text("---")
                            .font(.system(size: 64, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                        Text(viewModel.isLoading ? "Fetching latest reading..." : "No reading available yet")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
            
            // Chart Settings
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: Binding(
                    get: { viewModel.isDynamicYAxisEnabled },
                    set: { viewModel.setDynamicYAxisEnabled($0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Calibrate Y-Axis to Data")
                            .font(.subheadline.bold())
                        Text(viewModel.isDynamicYAxisEnabled
                            ? "Calibrated: (min - 5) to (max + 5) of actual readings"
                            : "Standard: Fixed range including target bounds (70–180)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
            
            // Actions
            VStack(spacing: 12) {
                Button {
                    liveActivityManager.toggleLiveActivity(
                        reading: viewModel.lastReading,
                        history: viewModel.storage.cachedGlucoseHistory
                    )
                } label: {
                    HStack {
                        Image(systemName: liveActivityManager.isLiveActivityActive ? "stop.circle.fill" : "play.circle.fill")
                        Text(liveActivityManager.isLiveActivityActive ? "Stop Live Activity (CarPlay Card)" : "Start Live Activity (CarPlay Card)")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(liveActivityManager.isLiveActivityActive ? Color(red: 0.11, green: 0.25, blue: 0.14) : Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                
                Button {
                    Task {
                        await viewModel.refreshReading()
                    }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Label("Refresh Reading", systemImage: "arrow.clockwise")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .foregroundColor(.primary)
                .cornerRadius(12)
                .disabled(viewModel.isLoading)
                
                Button {
                    viewModel.showingInstructions = true
                } label: {
                    Label("Widget Setup Guide (Lock Screen & CarPlay)", systemImage: "questionmark.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(red: 0.38, green: 0.56, blue: 0.84))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                
                Button(role: .destructive) {
                    viewModel.disconnect()
                } label: {
                    Text("Disconnect Account")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
                .padding(.top, 8)
            }
        }
    }
    
    // MARK: - Login Form
    
    private var loginFormView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("LibreLinkUp Credentials")
                .font(.headline)
            
            VStack(spacing: 12) {
                TextField("Email", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
                
                SecureField("Password", text: $viewModel.password)
                    .textContentType(.password)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
            }
            
            Button {
                Task {
                    await viewModel.verifyConnection()
                }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    Text("Verify & Connect")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(12)
            .disabled(viewModel.isLoading)
            
            Text("Credentials are saved exclusively in your encrypted device Keychain and shared with the Lock Screen widget via App Groups.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
    }
    
    // MARK: - Error Banner
    
    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding()
        .background(Color.red.opacity(0.12))
        .cornerRadius(12)
    }
}
