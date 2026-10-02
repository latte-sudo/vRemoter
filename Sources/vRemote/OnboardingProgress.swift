import Foundation

/// Seven-step navigation. Transport/recognition evidence intentionally never
/// survives relaunch: resume later stages at the real speech trial instead.
enum OnboardingProgress {
    static let schemaVersion = 2
    static let stepCount = 7
    static let trialStep = 4
    static let schemaKey = "chromecast.onboarding.schemaVersion"
    static let stepKey = "chromecast.onboarding.step"

    static func resumedStep(saved: Int, schema: Int) -> Int {
        let normalized: Int
        if schema < schemaVersion {
            // Previous native flow: welcome, connect, permission, audio, tool,
            // trial, keys, done. Do not accidentally skip the changed steps.
            switch saved {
            case 1, 2: normalized = saved
            case 4: normalized = 3
            case 3, 5...7: normalized = trialStep
            default: normalized = 0
            }
        } else { normalized = min(max(saved, 0), stepCount - 1) }
        return min(normalized, trialStep)
    }

    static func resumedStep(in defaults: UserDefaults = .standard) -> Int {
        resumedStep(saved: defaults.integer(forKey: stepKey), schema: defaults.integer(forKey: schemaKey))
    }

    static func save(step: Int, in defaults: UserDefaults = .standard) {
        defaults.set(schemaVersion, forKey: schemaKey)
        defaults.set(min(max(step, 0), stepCount - 1), forKey: stepKey)
    }
}
