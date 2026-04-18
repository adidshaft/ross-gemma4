import SwiftUI

struct OnboardingView: View {
    @Bindable var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                RossHeroCard(
                    eyebrow: "Private workbench",
                    title: "A calm legal file room built for advocates.",
                    detail: "Ross is designed to keep case files on this device while setup stays brief, readable, and honest about what becomes available when the Private AI Pack is ready."
                ) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) {
                            RossInfoPill(title: "Works locally", systemImage: "lock.shield")
                            RossInfoPill(title: "Source-backed", systemImage: "text.quote")
                            RossInfoPill(title: "Approval required", systemImage: "eye")
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            RossInfoPill(title: "Works locally on this device", systemImage: "lock.shield")
                            RossInfoPill(title: "Source-backed output", systemImage: "text.quote")
                            RossInfoPill(title: "Public-law search needs approval", systemImage: "eye")
                        }
                    }
                }

                RossSectionCard(
                    title: "What the first run is designed to protect",
                    subtitle: "The app stays lightweight at install time, then explains where every network boundary begins."
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        RossBulletRow(text: "Case materials remain in the private workbench rather than being mixed into entitlement or billing traffic.")
                        RossBulletRow(text: "Local drafting stays framed as a draft for advocate review, with source chips or a clear “Not found in the case file” path.")
                        RossBulletRow(text: "Public-law search is previewed first so only a sanitized, user-approved query can cross the boundary.")
                    }
                }

                RossSectionCard(
                    title: "Setup in three short steps",
                    subtitle: "The recommendation is phrased in capability language, not model jargon."
                ) {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 20) {
                            RossStepTile(
                                number: "1",
                                title: "Review device fit",
                                detail: "Storage, network posture, and an honest recommendation are shown up front."
                            )
                            RossStepTile(
                                number: "2",
                                title: "Choose work tier",
                                detail: "Quick Start, Case Associate, and Senior Drafting Support stay outcome-focused."
                            )
                            RossStepTile(
                                number: "3",
                                title: "Open workbench",
                                detail: "Capture, organization, and review remain usable while larger delivery continues."
                            )
                        }

                        VStack(alignment: .leading, spacing: 20) {
                            RossStepTile(
                                number: "1",
                                title: "Review the device fit",
                                detail: "Storage, network posture, and an honest recommendation are shown up front."
                            )
                            RossStepTile(
                                number: "2",
                                title: "Choose the work tier",
                                detail: "Quick Start, Case Associate, and Senior Drafting Support stay outcome-focused."
                            )
                            RossStepTile(
                                number: "3",
                                title: "Open the workbench",
                                detail: "Capture, organization, and review remain usable while larger delivery continues."
                            )
                        }
                    }
                }

                RossSectionCard(
                    title: "Available immediately",
                    subtitle: "Even before the largest pack finishes, the workbench remains useful."
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        RossBulletRow(text: "Create matters, import bundles, and review existing documents.")
                        RossBulletRow(text: "Capture papers for later filing into the case workspace.")
                        RossBulletRow(text: "Stage local-first workflows while the recommended pack finishes in the background.")
                    }
                }

                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        state.onboardingStage = .privateAIPack
                    }
                } label: {
                    Text("Continue to Private AI Pack")
                }
                .rossPrimaryButtonStyle()
                .padding(.top, 8)

                Text("Setup copy stays focused on outcome, storage, and privacy posture. Technical model details remain tucked away in settings.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            .padding(24)
        }
        .background(Color.rossGroupedBackground.ignoresSafeArea())
    }
}
