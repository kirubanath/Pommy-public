import Foundation

/// One line of Pommy "speech" with the pose to use while it's on screen.
struct PommyBeat: Codable {
    let text: String
    let pose: MascotPose
}

/// A single chat skit Pommy can perform when tapped.
/// A focus nudge is always appended at the end.
struct PommySkit: Codable {
    let beats: [PommyBeat]
}

enum PommyQuips {

    // MARK: - Skits

    static var skits: [PommySkit] = {
        guard let url = Bundle.main.url(forResource: "quips", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([PommySkit].self, from: data)
        else { return [] }
        return decoded
    }()

    // MARK: - Final beats

    static let focusNudges: [PommyBeat] = [
        .init(text: "Alright. Tiny session?",                       pose: .focus),
        .init(text: "Start when you're ready. Soonish.",            pose: .peek),
        .init(text: "We both know what would feel good now.",       pose: .idle),
        .init(text: "Go. I'll log it for you.",                     pose: .wave),
        .init(text: "One small session. Just one.",                 pose: .focus),
        .init(text: "I'm rooting for you, quietly, from the dock.", pose: .wave),
        .init(text: "You opened me. Let's make it count.",          pose: .peek),
        .init(text: "Begin. I'll be right here.",                   pose: .focus),
        .init(text: "I'll be here. Cheering. Not judging.",         pose: .peek),
        .init(text: "This was your idea, friend.",                  pose: .idle),
        .init(text: "Progress sounds nice, doesn't it?",            pose: .curious),
        .init(text: "Shall we grow a little focus together?",       pose: .focus),
        .init(text: "This tomato believes in you. One tap, one task?", pose: .curious),
        .init(text: "I've got all day. Your goals don't. Let's sync?", pose: .peek),
        .init(text: "Two minutes. That's all I'm asking.",          pose: .wave),
        .init(text: "You. Me. The timer. Let's go.",                pose: .focus),
        .init(text: "Future-you will high-five present-you.",       pose: .celebrate),
        .init(text: "Small step. Big tomato pride.",                pose: .wave),
    ]

    // MARK: - Picker

    static func randomConversation() -> [PommyBeat] {
        var convo = (skits.randomElement() ?? PommySkit(beats: [])).beats
        if let nudge = focusNudges.randomElement() {
            convo.append(nudge)
        }
        return convo
    }
}