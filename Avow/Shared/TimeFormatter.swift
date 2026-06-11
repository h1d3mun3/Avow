import Foundation

extension TimeInterval {
    /// Formats as "H:MM:SS" for timer display.
    var timerFormatted: String {
        let total = Int(self)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }

    /// Short format for summaries: "12:30" (hours:minutes only).
    var shortFormatted: String {
        let total = Int(self)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        return String(format: "%d:%02d", hours, minutes)
    }
}
