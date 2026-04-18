import SwiftUI

struct OnboardingView: View {
    @Bindable var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                OnboardingHero()

                OnboardingPromiseCard()

                OnboardingWorkflowCard()

                OnboardingOfflineCard()

                Button {
                    state.onboardingStage = .privateAIPack
                } label: {
                    Text("Set Up Private AI Pack")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(24)
        }
        .background(Color.clerkGroupedBackground)
    }
}

private struct OnboardingHero: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Private Digital Clerk")
                .font(.system(size: 34, weight: .bold, design: .rounded))

            Text("A privacy-first workbench for advocates. Designed to keep case files on this device while supporting source-backed local review.")
                .font(.title3)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                OnboardingBadge(title: "Works locally on this device", systemImage: "lock.shield")
                OnboardingBadge(title: "Source-backed output", systemImage: "text.quote")
            }

            OnboardingBadge(title: "Public-law search requires approval", systemImage: "eye")
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.94, green: 0.97, blue: 0.99),
                    Color(red: 0.88, green: 0.93, blue: 0.97)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct OnboardingPromiseCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What the app is designed to do")
                .font(.headline)

            OnboardingBullet(text: "Keep case materials local to the device.")
            OnboardingBullet(text: "Separate case work from entitlement, billing, and model delivery traffic.")
            OnboardingBullet(text: "Require a visible query preview before any public-law search.")
            OnboardingBullet(text: "Treat every output as a draft for advocate review.")
        }
        .padding(22)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct OnboardingWorkflowCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How setup works")
                .font(.headline)

            Text("The initial install stays light. Your Private AI Pack is chosen after installation so the app can recommend the right local pack for this device.")
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 12) {
                WorkflowStep(number: "1", title: "Choose a pack", detail: "Shown with plain-language capability tiers only.")
                WorkflowStep(number: "2", title: "Review the recommendation", detail: "Storage, network, and Instant Mode are explained clearly.")
                WorkflowStep(number: "3", title: "Open the workbench", detail: "Capture and organization still remain available even before the full pack finishes.")
            }
        }
        .padding(22)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct OnboardingOfflineCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Offline behavior")
                .font(.headline)

            Text("Create cases, import files, review prior work, and run local workflows when the chosen pack is ready. Public-law search waits until connectivity returns.")
                .foregroundStyle(.secondary)
        }
        .padding(22)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct OnboardingBadge: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.82))
            .clipShape(Capsule())
    }
}

private struct OnboardingBullet: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "circle.fill")
                .font(.system(size: 7))
                .foregroundStyle(Color(red: 0.08, green: 0.33, blue: 0.55))
                .padding(.top, 6)

            Text(text)
                .foregroundStyle(.secondary)
        }
    }
}

private struct WorkflowStep: View {
    let number: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(number)
                .font(.headline)
                .frame(width: 30, height: 30)
                .background(Color(red: 0.08, green: 0.33, blue: 0.55))
                .foregroundStyle(.white)
                .clipShape(Circle())

            Text(title)
                .font(.subheadline.weight(.semibold))

            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
