import Foundation

@main
struct RemoteDisplayNameTests {
    static func main() throws {
        let suite = "vRemote.tests.remote-name.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let key = RemoteDisplayName.key

        precondition(defaults.object(forKey: key) == nil)
        precondition(RemoteDisplayName.alias(in: defaults).isEmpty)
        precondition(RemoteDisplayName.displayName(in: defaults) == RemoteDisplayName.defaultName,
                     "new and upgraded installs retain the model name")
        defaults.set("untouched", forKey: "unrelated.preference")

        for name in ["客厅遥控器", "My Remote", "🎤 👨‍👩‍👧‍👦", "ريموت", "e\u{301}", String(repeating: "🎤", count: 64)] {
            try RemoteDisplayName.set(" \t\n" + name + "\n\u{3000}", in: defaults)
            precondition(defaults.string(forKey: key) == name, "save trims outer whitespace only")
            precondition(RemoteDisplayName.displayName(in: defaults) == name)
            precondition(RemoteDisplayName.displayName(in: UserDefaults(suiteName: suite)!) == name,
                         "saved names survive a fresh preference reader")
        }
        for empty in ["", "  ", "\r\n\t\u{3000}"] {
            try RemoteDisplayName.set("Existing name", in: defaults)
            try RemoteDisplayName.set(empty, in: defaults)
            precondition(defaults.object(forKey: key) == nil, "empty input removes override")
            precondition(RemoteDisplayName.displayName(in: defaults) == RemoteDisplayName.defaultName)
        }

        let invalid = [String(repeating: "a", count: 65), "Line\nBreak", "Tab\tName",
                       "Null\0Name", "Delete\u{7F}Name", "Line\u{2028}Separator",
                       "Paragraph\u{2029}Separator", "Hidden\u{202E}Override", "Hidden\u{2066}Isolate",
                       "e" + String(repeating: "\u{301}", count: 4096)]
        try RemoteDisplayName.set("Keep this", in: defaults)
        for value in invalid {
            do { try RemoteDisplayName.set(value, in: defaults); preconditionFailure("invalid name accepted") }
            catch is RemoteDisplayName.ValidationError { }
            precondition(defaults.string(forKey: key) == "Keep this", "invalid save is non-mutating")
        }
        let invalidStoredValues: [Any] = [true, 42, Data(), ["unexpected"], "bad\nname", String(repeating: "a", count: 65)]
        for value in invalidStoredValues {
            defaults.set(value, forKey: key)
            precondition(RemoteDisplayName.displayName(in: defaults) == RemoteDisplayName.defaultName,
                         "invalid stored preferences fall back safely without changing identity")
        }
        try RemoteDisplayName.set("Office remote", in: defaults)
        RemoteDisplayName.reset(in: defaults)
        RemoteDisplayName.reset(in: defaults)
        precondition(defaults.object(forKey: key) == nil)
        precondition(RemoteDisplayName.displayName(in: defaults) == RemoteDisplayName.defaultName)
        precondition(defaults.string(forKey: "unrelated.preference") == "untouched")
        print("PASS: remote display name default, trim, Unicode, bounds, persistence, invalid input and reset")
    }
}
