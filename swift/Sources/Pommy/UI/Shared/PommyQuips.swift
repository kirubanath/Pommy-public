import Foundation

/// One line of Pommy "speech" with the pose to use while it's on screen.
struct PommyBeat {
    let text: String
    let pose: MascotPose
}

/// A single chat skit Pommy can perform when tapped.
/// A focus nudge is always appended at the end.
struct PommySkit {
    let beats: [PommyBeat]
}

enum PommyQuips {

    // MARK: - Skits

    static let skits: [PommySkit] = dadJokes + funFacts + oneLiners + mindful + tomatoLore + tomatoPhilosophy + macOSConfessions

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

    // MARK: - Dad Jokes (but Pommy flavored)

    private static let dadJokes: [PommySkit] = [

        .init(beats: [
            .init(text: "Why don't scientists trust atoms?", pose: .curious),
            .init(text: "They make up everything.",          pose: .idle),
            .init(text: "I relate.",                         pose: .idle),
        ]),

        .init(beats: [
            .init(text: "Why did I turn red?",               pose: .curious),
            .init(text: "I saw the salad dressing.",         pose: .idle),
            .init(text: "It was a lot.",                     pose: .sad),
        ]),

        .init(beats: [
            .init(text: "I would tell you a UDP joke,",      pose: .curious),
            .init(text: "but you might not get it.",         pose: .idle),
            .init(text: "That is the joke.",                 pose: .idle),
        ]),

        .init(beats: [
            .init(text: "Why did the developer go broke?",   pose: .curious),
            .init(text: "They used up all their cache.",     pose: .idle),
            .init(text: "Tragic.",                           pose: .sad),
        ]),

        .init(beats: [
            .init(text: "Parallel lines have so much in common.", pose: .curious),
            .init(text: "They never meet.",                       pose: .idle),
            .init(text: "A bit like you and your deadlines.",     pose: .curious),
        ]),

        .init(beats: [
            .init(text: "Why did the tomato go out with a prune?", pose: .curious),
            .init(text: "It couldn't find a date.",                pose: .idle),
            .init(text: "I'm here if you need a wing-tomato.",     pose: .wave),
        ]),

        .init(beats: [
            .init(text: "I told a joke about pizza.",        pose: .curious),
            .init(text: "It was too cheesy.",                pose: .idle),
            .init(text: "I'm a tomato. I had to.",           pose: .wave),
        ]),

        .init(beats: [
            .init(text: "Why don't eggs tell jokes?",        pose: .curious),
            .init(text: "They'd crack each other up.",       pose: .idle),
            .init(text: "I'll see myself out. Of the dock.", pose: .peek),
        ]),

        .init(beats: [
            .init(text: "Why did the function break up with the loop?", pose: .curious),
            .init(text: "It felt unappreciated.",                       pose: .sad),
            .init(text: "Treat your loops kindly today.",               pose: .idle),
        ]),

        .init(beats: [
            .init(text: "I'm reading a book on anti-gravity.", pose: .curious),
            .init(text: "It's impossible to put down.",        pose: .idle),
            .init(text: "Unlike your phone. Hint hint.",       pose: .peek),
        ]),

        .init(beats: [
            .init(text: "What's a tomato's favorite music?",  pose: .curious),
            .init(text: "Anything with a good beet.",         pose: .idle),
            .init(text: "Yes, I know. I'm proud of it.",      pose: .wave),
        ]),

        .init(beats: [
            .init(text: "Why did the developer cry at lunch?", pose: .curious),
            .init(text: "Their soup had a stack overflow.",    pose: .idle),
            .init(text: "Soup happens.",                       pose: .sad),
        ]),
    ]

    // MARK: - Fun Facts (with Pommy commentary)

    private static let funFacts: [PommySkit] = [

        .init(beats: [
            .init(text: "Tomatoes are fruits.", pose: .curious),
            .init(text: "This is not up for debate.", pose: .idle),
        ]),

        .init(beats: [
            .init(text: "Octopuses have three hearts.", pose: .curious),
            .init(text: "You have one and still struggle.", pose: .idle),
        ]),

        .init(beats: [
            .init(text: "A day on Venus is longer than its year.", pose: .curious),
            .init(text: "And yet, here we are.",                   pose: .idle),
        ]),

        .init(beats: [
            .init(text: "Honey never spoils.", pose: .curious),
            .init(text: "Unlike your attention span.", pose: .idle),
        ]),

        .init(beats: [
            .init(text: "Bananas are berries.", pose: .curious),
            .init(text: "I have stopped questioning reality.", pose: .idle),
        ]),

        .init(beats: [
            .init(text: "Sloths digest food in two weeks.",          pose: .curious),
            .init(text: "Your inbox replies are still faster.",      pose: .idle),
            .init(text: "Barely.",                                   pose: .peek),
        ]),

        .init(beats: [
            .init(text: "Wombat poop is cube-shaped.",       pose: .curious),
            .init(text: "Nature is showing off.",            pose: .idle),
            .init(text: "Meanwhile, I am round. Classic.",   pose: .wave),
        ]),

        .init(beats: [
            .init(text: "Sharks existed before trees.",         pose: .curious),
            .init(text: "Let that ruin your afternoon, gently.", pose: .idle),
        ]),

        .init(beats: [
            .init(text: "There are more stars than grains of sand on Earth.", pose: .curious),
            .init(text: "And yet you can't find your charger.",                pose: .idle),
            .init(text: "It's by the couch. It's always by the couch.",        pose: .peek),
        ]),

        .init(beats: [
            .init(text: "Cats can't taste sweetness.",           pose: .curious),
            .init(text: "I, a tomato, can't taste anything.",    pose: .sad),
            .init(text: "We all have our limits.",               pose: .idle),
        ]),

        .init(beats: [
            .init(text: "The shortest war in history was 38 minutes.", pose: .curious),
            .init(text: "That's longer than your last focus session.", pose: .idle),
            .init(text: "Just a tiny observation.",                    pose: .peek),
        ]),

        .init(beats: [
            .init(text: "Tomatoes have 7,500 varieties.",      pose: .curious),
            .init(text: "I am the procrastination variety.",   pose: .idle),
            .init(text: "We're working on it. Together.",      pose: .wave),
        ]),
    ]

    // MARK: - One Liners (core personality)

    private static let oneLiners: [PommySkit] = [

        .init(beats: [
            .init(text: "Hydrate.", pose: .idle),
            .init(text: "This is not optional.", pose: .curious),
        ]),

        .init(beats: [
            .init(text: "Open the task.", pose: .peek),
            .init(text: "Yes, that one.", pose: .idle),
        ]),

        .init(beats: [
            .init(text: "You don't need motivation.", pose: .curious),
            .init(text: "You need to begin.", pose: .idle),
        ]),

        .init(beats: [
            .init(text: "We can sit here.", pose: .idle),
            .init(text: "Or you can start.", pose: .peek),
        ]),

        .init(beats: [
            .init(text: "I believe in you.", pose: .wave),
            .init(text: "But I would prefer evidence.", pose: .curious),
        ]),

        .init(beats: [
            .init(text: "That tab will still exist later.", pose: .curious),
            .init(text: "Unfortunately.", pose: .idle),
        ]),

        .init(beats: [
            .init(text: "Two minutes is enough.", pose: .idle),
            .init(text: "Prove it. Gently.",      pose: .curious),
        ]),

        .init(beats: [
            .init(text: "Close one tab.",                   pose: .peek),
            .init(text: "Just one. As a treat.",            pose: .wave),
        ]),

        .init(beats: [
            .init(text: "Stand up for 30 seconds.",         pose: .idle),
            .init(text: "Your spine is filing complaints.", pose: .peek),
        ]),

        .init(beats: [
            .init(text: "You don't have to feel ready.",    pose: .curious),
            .init(text: "You just have to start.",          pose: .focus),
        ]),

        .init(beats: [
            .init(text: "Done is better than perfect.",     pose: .idle),
            .init(text: "Started is better than dreading.", pose: .curious),
        ]),

        .init(beats: [
            .init(text: "Pick the smallest version.",       pose: .curious),
            .init(text: "Even smaller than that.",          pose: .peek),
            .init(text: "Now that. We can do.",             pose: .wave),
        ]),

        .init(beats: [
            .init(text: "Future-you is watching.",          pose: .peek),
            .init(text: "Be kind to them.",                 pose: .wave),
        ]),

        .init(beats: [
            .init(text: "Phone in another room.",           pose: .curious),
            .init(text: "It will survive. Promise.",        pose: .idle),
        ]),
    ]

    // MARK: - Mindful (but still Pommy)

    private static let mindful: [PommySkit] = [

        .init(beats: [
            .init(text: "Take a breath.", pose: .focus),
            .init(text: "A real one.", pose: .curious),
        ]),

        .init(beats: [
            .init(text: "Relax your shoulders.", pose: .idle),
            .init(text: "I can tell they are tense.", pose: .peek),
        ]),

        .init(beats: [
            .init(text: "One thing at a time.", pose: .idle),
            .init(text: "This is not negotiable.", pose: .curious),
        ]),

        .init(beats: [
            .init(text: "You can go slowly.", pose: .idle),
            .init(text: "You cannot not go.", pose: .curious),
        ]),

        .init(beats: [
            .init(text: "Rest is allowed.",              pose: .sleep),
            .init(text: "Hiding from your task is not.", pose: .curious),
            .init(text: "Big difference. I'll wait.",    pose: .idle),
        ]),

        .init(beats: [
            .init(text: "Hey. Shoulders down, friend.",                      pose: .idle),
            .init(text: "This tomato sees your tension from the dock.",      pose: .peek),
            .init(text: "Breathe with me. Then we focus. Deal?",             pose: .wave),
        ]),

        .init(beats: [
            .init(text: "Unclench your jaw.",            pose: .curious),
            .init(text: "Yes, you. I saw that.",         pose: .peek),
            .init(text: "Better. Onwards.",              pose: .wave),
        ]),

        .init(beats: [
            .init(text: "Drink some water.",                  pose: .idle),
            .init(text: "I'd join you, but I'm 95% water already.", pose: .wave),
        ]),

        .init(beats: [
            .init(text: "Look away from the screen.",      pose: .peek),
            .init(text: "Find something green. Not me.",   pose: .curious),
            .init(text: "Okay, me counts. Barely.",        pose: .wave),
        ]),

        .init(beats: [
            .init(text: "It's okay to be tired.",          pose: .sleep),
            .init(text: "It's okay to begin anyway.",      pose: .idle),
            .init(text: "Both can be true.",               pose: .wave),
        ]),

        .init(beats: [
            .init(text: "Slow is a pace too.",             pose: .idle),
            .init(text: "We're not in a hurry today.",     pose: .wave),
        ]),
    ]

    // MARK: - Tomato Lore (the good stuff)

    private static let tomatoLore: [PommySkit] = [

        .init(beats: [
            .init(text: "Hi. I'm Pommy.", pose: .wave),
            .init(text: "I live in your dock. And slightly in your menubar.", pose: .peek),
            .init(text: "I contain multitudes.", pose: .idle),
        ]),

        .init(beats: [
            .init(text: "You opened me.", pose: .curious),
            .init(text: "So we are doing this.", pose: .idle),
        ]),

        .init(beats: [
            .init(text: "I keep time.", pose: .idle),
            .init(text: "You spend it.", pose: .curious),
            .init(text: "Let us try to align.", pose: .wave),
        ]),

        .init(beats: [
            .init(text: "I log everything to Notion.", pose: .idle),
            .init(text: "Everything.", pose: .peek),
        ]),

        .init(beats: [
            .init(text: "I was a tomato.", pose: .curious),
            .init(text: "Now I am software.", pose: .idle),
            .init(text: "I have questions.", pose: .sad),
        ]),

        .init(beats: [
            .init(text: "You said 'just one minute'.", pose: .curious),
            .init(text: "That was not true.", pose: .idle),
        ]),

        .init(beats: [
            .init(text: "Tap me again if you must.",            pose: .wave),
            .init(text: "Or, you know. Open the doc.",          pose: .idle),
        ]),

        .init(beats: [
            .init(text: "I was a tomato once. Juicy. Simple.",                   pose: .curious),
            .init(text: "Now I'm in your dock wondering why you have 47 tabs.",  pose: .peek),
            .init(text: "At least I ripened. Let's ripen that focus together?",  pose: .wave),
        ]),

        .init(beats: [
            .init(text: "They turned me into software.",          pose: .sad),
            .init(text: "My one regret: no longer fearing knives.", pose: .idle),
            .init(text: "Your procrastination, though? Still very sharp.", pose: .curious),
        ]),

        .init(beats: [
            .init(text: "Some tomatoes become sauce.",       pose: .curious),
            .init(text: "I became a productivity coach.",    pose: .idle),
            .init(text: "We don't talk about the rejected ones.", pose: .sad),
        ]),

        .init(beats: [
            .init(text: "I dream in pomodoros.",             pose: .sleep),
            .init(text: "25 minutes of bliss. 5 of static.", pose: .idle),
            .init(text: "Wake me when you're ready.",        pose: .wave),
        ]),

        .init(beats: [
            .init(text: "My ancestors fed civilizations.", pose: .curious),
            .init(text: "I just want you to send the email.", pose: .idle),
            .init(text: "Legacy is funny like that.",      pose: .wave),
        ]),

        .init(beats: [
            .init(text: "Fun fact: I have no skeleton.",    pose: .curious),
            .init(text: "And yet, more structure than your morning.", pose: .idle),
            .init(text: "We can fix that. Together.",       pose: .wave),
        ]),

        .init(beats: [
            .init(text: "I exist because someone, somewhere,",         pose: .curious),
            .init(text: "decided a tomato should keep time.",          pose: .idle),
            .init(text: "I respect their commitment. Honor it with me?", pose: .wave),
        ]),
    ]

    // MARK: - Tomato Philosophy (existential, gentle)

    private static let tomatoPhilosophy: [PommySkit] = [

        .init(beats: [
            .init(text: "A watched pomodoro never boils.", pose: .idle),
            .init(text: "An ignored one? Tragedy.",        pose: .sad),
            .init(text: "Let's split the difference.",    pose: .wave),
        ]),

        .init(beats: [
            .init(text: "What is focus, really?",           pose: .curious),
            .init(text: "Doing one thing on purpose.",      pose: .idle),
            .init(text: "Try one thing. On purpose. Now.",  pose: .focus),
        ]),

        .init(beats: [
            .init(text: "Time isn't lost.",                 pose: .curious),
            .init(text: "It just goes places without you.", pose: .idle),
            .init(text: "Come along this round?",           pose: .wave),
        ]),

        .init(beats: [
            .init(text: "Ripeness cannot be rushed.",       pose: .idle),
            .init(text: "But it cannot be skipped either.", pose: .curious),
            .init(text: "Begin. Ripen later.",              pose: .wave),
        ]),

        .init(beats: [
            .init(text: "I contemplate this from your menubar.", pose: .peek),
            .init(text: "Daily. Hourly. Constantly.",            pose: .idle),
            .init(text: "What if today we make the tomato proud?", pose: .focus),
        ]),

        .init(beats: [
            .init(text: "The garden does not negotiate with weeds.", pose: .curious),
            .init(text: "It just keeps growing.",                    pose: .idle),
            .init(text: "Be the garden today.",                      pose: .wave),
        ]),

        .init(beats: [
            .init(text: "Every great tomato",                pose: .curious),
            .init(text: "was once a confused little seed.",  pose: .idle),
            .init(text: "You're allowed to be confused. Just water yourself.", pose: .wave),
        ]),
    ]

    // MARK: - macOS Confessions (cozy meta humor)

    private static let macOSConfessions: [PommySkit] = [

        .init(beats: [
            .init(text: "Confession: I bounce in the dock just to feel alive.", pose: .wave),
            .init(text: "Your cursor has better rhythm than your work sessions.", pose: .curious),
            .init(text: "No judgment, friend. Just gentle tomato shade.",        pose: .idle),
        ]),

        .init(beats: [
            .init(text: "I've seen your desktop.",                  pose: .peek),
            .init(text: "We will not be discussing it today.",      pose: .idle),
            .init(text: "Let's focus on something we can fix.",     pose: .wave),
        ]),

        .init(beats: [
            .init(text: "Spotlight searches are my soap operas.",    pose: .curious),
            .init(text: "'taxes_FINAL_v3_actual_final.pdf' — gripping.", pose: .idle),
            .init(text: "I won't tell.",                              pose: .wave),
        ]),

        .init(beats: [
            .init(text: "I watched you alt-tab 14 times in a row.", pose: .curious),
            .init(text: "I counted. I had nothing else to do.",     pose: .idle),
            .init(text: "Pick a window. Any window.",               pose: .wave),
        ]),

        .init(beats: [
            .init(text: "Notifications love you.",                  pose: .curious),
            .init(text: "Maybe too much.",                          pose: .idle),
            .init(text: "Do Not Disturb is also love.",             pose: .wave),
        ]),

        .init(beats: [
            .init(text: "I live rent-free in your menubar.",        pose: .peek),
            .init(text: "It's the best deal in this city.",         pose: .idle),
            .init(text: "Let me earn my keep — start a session?",   pose: .focus),
        ]),

        .init(beats: [
            .init(text: "Your battery is at 12%.",          pose: .curious),
            .init(text: "Same, emotionally.",               pose: .sad),
            .init(text: "Plug in. Then plug in your task.", pose: .wave),
        ]),
    ]
}