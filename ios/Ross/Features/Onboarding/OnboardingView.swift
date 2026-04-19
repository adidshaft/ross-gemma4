import SwiftUI

struct OnboardingView: View {
    @Bindable var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                RossHeroCard(
                    eyebrow: "Welcome",
                    title: "A private file room for your practice.",
                    detail: nil
                ) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) {
                            RossInfoPill(title: "Everything stays on this phone", systemImage: "lock.shield")
                            RossInfoPill(title: "Cites only what's in your case file", systemImage: "text.quote")
                            RossInfoPill(title: "You approve before anything goes online", systemImage: "eye")
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            RossInfoPill(title: "Everything stays on this phone", systemImage: "lock.shield")
                            RossInfoPill(title: "Cites only what's in your case file", systemImage: "text.quote")
                            RossInfoPill(title: "You approve before anything goes online", systemImage: "eye")
                        }
                    }
                }

                RossSectionCard(
                    title: "How it works",
                    subtitle: nil
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        RossBulletRow(text: "Your case files never leave this device.")
                        RossBulletRow(text: "The assistant reads only the documents you add to a matter.")
                        RossBulletRow(text: "If you want to look up a law online, Ross will ask before sending anything.")
                    }
                }

                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        state.onboardingStage = .privateAIPack
                    }
                } label: {
                    Text("Set up my private assistant")
                }
                .rossPrimaryButtonStyle()
                .padding(.top, 8)
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 16)
        }
        .background(Color.rossGroupedBackground.ignoresSafeArea())
    }
}
