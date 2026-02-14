import AppKit

enum CheckinState: String, CaseIterable {
    case focused
    case wandering
    case resting

    var label: String {
        switch self {
        case .focused:
            return "集中"
        case .wandering:
            return "ぼんやり"
        case .resting:
            return "休憩中"
        }
    }

    var feedbackMessage: String {
        switch self {
        case .focused:
            return "いい感じ！その調子で進めていこう。"
        case .wandering:
            return "少しぼんやり気味かも。次の5分だけやることを決めよう。"
        case .resting:
            return "休憩は大事。戻る時間を決めておこう。"
        }
    }

    static func from(rawValue: String?) -> CheckinState {
        guard let rawValue else { return .focused }
        switch rawValue {
        case CheckinState.focused.rawValue:
            return .focused
        case CheckinState.wandering.rawValue:
            return .wandering
        case CheckinState.resting.rawValue, "break":
            return .resting
        default:
            return .focused
        }
    }
}
