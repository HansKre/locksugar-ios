import SwiftUI

public struct WidgetSetupInstructionsView: View {
    @Environment(\.dismiss) private var dismiss
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Add LockSugar to Lock Screen")
                            .font(.title2.bold())
                        Text("Follow these simple steps to keep your blood glucose reading visible at a glance.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)
                    
                    // Steps List
                    VStack(spacing: 16) {
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
                .padding(20)
            }
            .navigationTitle("How to Lock Screen Widget")
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
