import Foundation

/// The pet's current activity. Pure value type shared by the behavior machine
/// and the animation layer.
public enum PetState: String, Sendable, CaseIterable {
    case idle
    case walk
    case run
    case sleep
    case drink
    case play
    case react
    case follow
    case laugh
    case jump
    case roll
    case woolball
    case cheer
    case love

    /// The animation that visually represents this state.
    public var animation: PetAnimation {
        switch self {
        case .idle: return .idle
        case .walk: return .walk
        case .run: return .run
        case .sleep: return .sleep
        case .drink: return .drink
        case .play: return .play
        case .react: return .react
        case .follow: return .follow
        case .laugh: return .laugh
        case .jump: return .jump
        case .roll: return .roll
        case .woolball: return .play // plays with the wool ball using the play sprites
        case .cheer: return .jump    // cheer reuses the jump sprites (bouncy confetti)
        case .love: return .love
        }
    }
}
