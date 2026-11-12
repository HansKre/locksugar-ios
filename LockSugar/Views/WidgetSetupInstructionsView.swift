import SwiftUI

public struct WidgetSetupInstructionsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: SetupTab = .lockScreen
    
    public enum SetupTab: String, CaseIterable, Identifiable {
        case lockScreen = "Lock Screen"
        case carPlay = "CarPlay"
        case trendArrows = "Trend Arrows"
        
        public var id: String { rawValue }
    }
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Segmented Selector
                    Picker("Guide", selection: $selectedTab) {
                        ForEach(SetupTab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.top, 4)
                    
                    switch selectedTab {
                    case .lockScreen:
                        lockScreenInstructions
                    case .carPlay:
                        carPlayInstructions
                    case .trendArrows:
                        trendArrowInstructions
                    }
                }
                .padding(20)
            }
            .navigationTitle("Guide & Reference")
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
                Text("Display your live glucose, trend arrow, and delta on your car's Dashboard.")
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
    
    // MARK: - Trend Arrows Instructions & Reference
    
    private var trendArrowInstructions: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Abbott Trend Arrow Definitions")
                    .font(.title2.bold())
                Text("Official rate-of-change thresholds and clinical projections from Abbott FreeStyle Libre.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 5 Trend Arrow Cards
            VStack(spacing: 12) {
                ForEach(TrendArrowDefinition.allDefinitions) { item in
                    arrowCard(for: item)
                }
            }
            
            // Velocity vs. Delta Deep-Dive Callout
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.title3)
                    Text("Trend Arrow vs. Delta Value")
                        .font(.headline)
                }
                
                Text("Why can the arrow be flat (→) even when the delta shows +5?")
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                        Text("**Trend Arrow**: Measures **instantaneous velocity** (rate of change per minute over recent minutes), calculated by Abbott's sensor algorithm.")
                    }
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                        Text("**Delta Value**: Measures the **discrete difference** between your latest reading and the immediately preceding reading.")
                    }
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                        Text("**Why they differ**: A change of +5 mg/dL over a 15-minute gap is only ~0.33 mg/dL/min. Because it is well below Abbott's 1.0 mg/dL/min threshold, the sensor algorithm classifies it as **changing slowly (→)**.")
                    }
                }
                .font(.footnote)
                .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color.accentColor.opacity(0.08))
            .cornerRadius(12)
        }
    }
    
    private func arrowCard(for item: TrendArrowDefinition) -> some View {
        HStack(alignment: .top, spacing: 14) {
            // Big Arrow Symbol Badge
            ZStack {
                Circle()
                    .fill(arrowColor(for: item.id).opacity(0.15))
                    .frame(width: 48, height: 48)
                Text(item.symbol)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(arrowColor(for: item.id))
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title)
                        .font(.headline)
                    Spacer()
                    Text(item.fifteenMinuteChange)
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 8) {
                    Text(item.rateMgPerDl)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(arrowColor(for: item.id).opacity(0.12))
                        .foregroundColor(arrowColor(for: item.id))
                        .cornerRadius(6)
                    
                    Text(item.rateMmolPerL)
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)
                }
                
                Text(item.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func arrowColor(for id: Int) -> Color {
        switch id {
        case 5: return .red
        case 4: return .orange
        case 3: return .green
        case 2: return .orange
        case 1: return .red
        default: return .primary
        }
    }
}
