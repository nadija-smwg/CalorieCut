import SwiftUI

struct OnboardingView: View {
    @Environment(AppStore.self) private var store
    @State private var draft = ProfileDraft()
    @State private var stage = 0
    var body: some View {
        NavigationStack {
            Group {
                if stage == 0 {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 30) {
                            Image(systemName: "leaf.circle.fill").font(.system(size: 90)).foregroundStyle(Palette.accent).padding(.top, 44).accessibilityHidden(true)
                            Text("A little awareness.\nA healthier rhythm.").font(.system(.largeTitle, design: .rounded, weight: .bold))
                            Text("Welcome to CalorieCut").font(.title3.weight(.medium))
                            Text("Log your meals, nourish your body, and follow your progress at a pace that works for you.").font(.body).foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 18) {
                                Label("Your diary stays on this iPhone", systemImage: "lock.shield")
                                Label("No account. Fully offline.", systemImage: "wifi.slash")
                                Label("Thoughtful daily reflections", systemImage: "sparkles")
                            }
                            Text("For adults 18+. Calorie and weight guidance is an estimate. If tracking feels stressful, pause and seek support. CalorieCut does not diagnose conditions or promise spot fat reduction.").font(.caption).foregroundStyle(.secondary)
                            Button("Get started") { withAnimation { stage = 1 } }.buttonStyle(.borderedProminent).controlSize(.large).accessibilityIdentifier("getStarted")
                        }.padding(28)
                    }.background(Palette.background)
                } else {
                    Form {
                        Section {
                            Text(stage == 1 ? "Make it yours" : "Find your daily rhythm").font(.title2.bold())
                            Text(stage == 1 ? "Example values are prefilled. Change them to fit you." : "Review your estimates and choose goals you can sustain.").foregroundStyle(.secondary)
                            ProgressView(value: Double(stage), total: 2).tint(Palette.accent)
                        }
                        if stage == 1 { ProfileFields(draft: $draft) } else { GoalFields(draft: $draft) }
                        Section {
                            Button(stage == 1 ? "Continue" : "Start my diary") {
                                if let error = draft.validation { store.errorMessage = error; return }
                                if stage == 1 { stage = 2 }
                                else if store.saveProfile(draft) { Haptics.success() }
                            }.fontWeight(.semibold).accessibilityIdentifier(stage == 1 ? "continueOnboarding" : "finishOnboarding")
                        }
                    }.keyboardDismissButton()
                }
            }.navigationTitle(stage == 0 ? "CalorieCut" : "\(stage) of 2").navigationBarTitleDisplayMode(.inline)
                .toolbar { if stage > 0 { ToolbarItem(placement: .topBarLeading) { Button("Back") { stage -= 1 } } } }
        }
    }
}
