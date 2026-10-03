import Foundation
@main struct OnboardingProgressTests {
    static func main() {
        precondition(OnboardingProgress.stepCount == 7)
        for step in 0...4 { precondition(OnboardingProgress.resumedStep(saved: step, schema: 2) == step) }
        for step in 5...9 { precondition(OnboardingProgress.resumedStep(saved: step, schema: 2) == 4) }
        precondition(OnboardingProgress.resumedStep(saved: -1, schema: 2) == 0)
        precondition(OnboardingProgress.resumedStep(saved: 4, schema: 0) == 3)
        for step in [3, 5, 6, 7] { precondition(OnboardingProgress.resumedStep(saved: step, schema: 0) == 4) }
        print("PASS: onboarding migration, bounds and fresh evidence on resume")
    }
}
