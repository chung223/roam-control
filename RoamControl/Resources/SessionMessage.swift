import Foundation

/// Translates text for display without changing the text the code reasons about.
///
/// Failure text is produced in English by the native bridge and the session
/// code, and that English is load-bearing in three places: `FailureStage`
/// classifies telemetry by matching it exactly, the session coordinator decides
/// whether a failure is recoverable by matching it, and `scripts/` asserts on
/// it. Translating at the source would break all three at once and silently.
///
/// So the English stays as the internal identity and is translated only on the
/// way to the screen. A message with no entry in the String Catalog falls back
/// to itself, which is the English text, so an untranslated message is shown
/// rather than lost.
enum SessionMessage {
    static func localized(_ message: String) -> String {
        String(localized: String.LocalizationValue(message))
    }

    static func localized(_ message: String?) -> String? {
        message.map(localized)
    }
}

extension String {
    /// For text held in a computed property rather than written inline.
    ///
    /// `Text("literal")` localises itself through `LocalizedStringKey`, but
    /// `Text(aString)` takes the verbatim overload and would show English.
    /// Calling this where the English is written keeps the lookup next to the
    /// text instead of at every call site.
    static func appText(_ key: String.LocalizationValue) -> String {
        String(localized: key)
    }
}
