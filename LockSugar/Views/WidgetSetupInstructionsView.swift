import SwiftUI

public struct WidgetSetupInstructionsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: SetupTab = .lockScreen
    
    public enum SetupTab: String, CaseIterable, Identifiable {
        case lockScreen = "Lock Screen"
        case carPlay = "Apple CarPlay"
        
        public var id: String { rawValue }
    }
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Segmented Selector
                    Picker("Widget Setup", selection: $selectedTab) {
                        ForEach(SetupTab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.top, 4)
                    
                    if selectedTab == .lockScreen {
                        lockScreenInstructions
                    } else {
                        carPlayInstructions
                    }
                }
                .padding(20)
            }
            .navigationTitle("Widget Setup Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Lock Screen Instructions
    
    private var lockScreenInstructions: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Add to Lock Screen")
                    .font(.title2.bold())
                Text("Keep your blood glucose reading visible at a glance every time you wake your iPhone.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 14) {
                instructionStep(
                    number: 1,
                    icon: "hand.tap.fill",
                    title: "Long press your Lock Screen",
                    description: "Touch and hold an empty area on your Lock Screen until the Customize button appears."
                )
                
                instructionStep(
                    number: 2,
                    icon: "slider.horizontal.3",
                    title: "Tap Customize",
                    description: "Select the Lock Screen page on the left."
                )
                
                instructionStep(
                    number: 3,
                    icon: "plus.circle.fill",
                    title: "Tap Widget Area",
                    description: "Tap the accessory area above the clock (Inline) or below the clock (Circular / Rectangular)."
                )
                
                instructionStep(
                    number: 4,
                    icon: "drop.fill",
                    title: "Select LockSugar",
                    description: "Find LockSugar in the widget gallery and tap or drag your preferred accessory slot."
                )
                
                instructionStep(
                    number: 5,
                    icon: "checkmark.circle.fill",
                    title: "Save & Exit",
                    description: "Tap Done in the top-right corner to activate your glucose display."
                )
            }
        }
    }
    
    // MARK: - CarPlay Instructions
    
    private var carPlayInstructions: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Add to Apple CarPlay")
                    .font(.title2.bold())
                Text("Display your live glucose, trend arrow, delta, and target gauge on your car's Dashboard.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 14) {
                instructionStep(
                    number: 1,
                    icon: "cable.connector",
                    title: "Connect to your Vehicle",
                    description: "Connect your iPhone to your car via USB cable or wireless CarPlay."
                )
                
                instructionStep(
                    number: 2,
                    icon: "gearshape.fill",
                    title: "Open CarPlay Settings",
                    description: "On your iPhone, go to Settings > General > CarPlay and tap your car name."
                )
                
                instructionStep(
                    number: 3,
                    icon: "plus.circle.fill",
                    title: "Add LockSugar Widget",
                    description: "Tap Customize (or Widgets). Find LockSugar under More Apps and tap the green '+' button."
                )
                
                instructionStep(
                    number: 4,
                    icon: "rectangle.3.group.fill",
                    title: "Open CarPlay Dashboard",
                    description: "On your car head unit, tap the Dashboard split-screen icon to see LockSugar alongside Maps."
                )
            }
        }
    }
    
    private func instructionStep(number: Int, icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                    .font(.system(size: 18, weight: .bold))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}
