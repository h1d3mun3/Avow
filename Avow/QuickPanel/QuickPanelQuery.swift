import Foundation

/// Parses the search text of the quick panel and the New Task sheet:
///
///     review notes @Avow #review #meeting +Work
///
/// The text before the first sigil is the task name. Each sigil starts a segment that runs to the
/// next sigil (so names may contain spaces): `@` names the project, `#` a facet for the task, `+` a
/// group for the project. A sigil only counts at the start or after whitespace, so `C++` or
/// `me@example.com` stay plain text. Factored out as plain value logic so it can be tested without
/// a running UI.
nonisolated struct QuickPanelQuery: Equatable {
    enum Sigil: Character {
        case project = "@"
        case facet = "#"
        case group = "+"
    }

    struct Segment: Equatable {
        let sigil: Sigil
        /// Trimmed text after the sigil, up to the next one.
        let text: String
    }

    /// Trimmed text before the first sigil (the whole text when there is none).
    let taskText: String
    let segments: [Segment]

    private let raw: String
    /// Character offset of the last segment's sigil in `raw`, for completion.
    private let lastSigilOffset: Int?

    init(_ raw: String) {
        let whitespace = CharacterSet.whitespacesAndNewlines
        var task = ""
        var segments: [Segment] = []
        var current: (sigil: Sigil, text: String)?
        var lastOffset: Int?
        var previous: Character?

        for (offset, character) in raw.enumerated() {
            if let sigil = Sigil(rawValue: character), previous == nil || previous!.isWhitespace {
                if let current {
                    segments.append(Segment(sigil: current.sigil, text: current.text.trimmingCharacters(in: whitespace)))
                }
                current = (sigil, "")
                lastOffset = offset
            } else if current != nil {
                current!.text.append(character)
            } else {
                task.append(character)
            }
            previous = character
        }
        if let current {
            segments.append(Segment(sigil: current.sigil, text: current.text.trimmingCharacters(in: whitespace)))
        }

        self.raw = raw
        self.taskText = task.trimmingCharacters(in: whitespace)
        self.segments = segments
        self.lastSigilOffset = lastOffset
    }

    /// The segment being typed — always the last one.
    var activeSegment: Segment? { segments.last }

    /// Text of the last `@` segment (a later one overrides an earlier one), nil when there is none.
    var projectText: String? { segments.last { $0.sigil == .project }?.text }

    /// True once the user has typed `@`, i.e. is choosing a project for a new task.
    var hasProjectClause: Bool { projectText != nil }

    /// The project name to create when none matches exactly: the text typed after `@`, if any.
    var newProjectName: String? {
        guard let projectText, !projectText.isEmpty else { return nil }
        return projectText
    }

    /// Whether `projectName` matches the text typed after `@` (everything matches an empty one).
    func matches(projectName: String) -> Bool {
        Self.matches(projectName, filter: projectText ?? "")
    }

    /// Whether `projectName` is exactly the typed project text, ignoring case.
    func isSameProjectName(_ projectName: String) -> Bool {
        guard let newProjectName else { return false }
        return Self.isSame(projectName, newProjectName)
    }

    /// Whether `taskName` is exactly the typed task name, ignoring case — creating it would only
    /// duplicate an existing task, so no "create" row is offered.
    func isSameTaskName(_ taskName: String) -> Bool {
        !taskText.isEmpty && Self.isSame(taskName, taskText)
    }

    /// The search text with the segment being typed replaced by `name` and a trailing space, ready
    /// for the next sigil (Tab completion). Unchanged when no sigil has been typed.
    func completed(with name: String) -> String {
        guard let lastSigilOffset, let sigil = activeSegment?.sigil else { return raw }
        return String(raw.prefix(lastSigilOffset)) + String(sigil.rawValue) + name + " "
    }

    // MARK: - Name matching

    /// Case-insensitive substring match; an empty filter matches everything.
    static func matches(_ name: String, filter: String) -> Bool {
        filter.isEmpty || name.localizedCaseInsensitiveContains(filter)
    }

    static func isSame(_ a: String, _ b: String) -> Bool {
        a.compare(b, options: .caseInsensitive) == .orderedSame
    }

    /// 0 for an exact match, 1 for a prefix match, 2 otherwise — for ordering suggestions.
    static func rank(_ name: String, filter: String) -> Int {
        if filter.isEmpty { return 2 }
        if isSame(name, filter) { return 0 }
        return name.range(of: filter, options: [.caseInsensitive, .anchored]) != nil ? 1 : 2
    }
}
