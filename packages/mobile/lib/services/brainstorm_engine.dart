/// 80 lateral thinking techniques for creative ideation
class BrainstormEngine {
  static final List<String> techniques = [
    "INVERSION: Reverse the flow. Flip the assumption. What if we did the opposite?",
    "ANALOGY: What does this resemble from biology? Physics? Games? Music? Military?",
    "CONSTRAINT_REMOVAL: Unlimited budget/time/users. Then scale back to reality.",
    "COMBINATION: Merge with unrelated concept. AI + farming? Code + cooking?",
    "EXTREME: Most extreme version? Simplest? Most complex? Fastest? Slowest?",
    "FIRST_PRINCIPLES: Strip ALL assumptions. What's the fundamental problem?",
    "USER_OBSESSION: What makes users cry with joy? Their deepest unspoken frustration?",
    "FUTURE_BACK: Fast-forward 5 years. What exists then? Work backwards to today.",
    "RANDOM_STIMULUS: Open dictionary on random word. How does it connect?",
    "PROVOCATION: Make absurd statement. 'Code writes itself.' Extract useful kernel.",
    "SCAMPER: Substitute, Combine, Adapt, Modify, Put to use, Eliminate, Reverse.",
    "SIX_HATS: White(facts), Red(emotions), Black(risks), Yellow(benefits), Green(creativity), Blue(process).",
    "TRIZ: 40 inventive principles. Segmentation, asymmetry, merging, universality.",
    "BIOMIMICRY: How does nature solve this? Ants? Bees? Neural nets? Evolution?",
    "CONTRADICTION: Identify contradiction (want X and not-X). Resolve, don't compromise.",
    "BLUE_OCEAN: Eliminate, Reduce, Raise, Create. Remove what industry takes for granted.",
    "JOBS_TO_BE_DONE: What 'job' is user hiring product for? Not features — the progress.",
    "PRETOTYPE: What's the FAKEST version testing the core assumption? Fake before build.",
    "MORPHOLOGICAL_BOX: List dimensions. Combine different values from each. All permutations.",
    "WORST_IDEA: Generate the worst possible solutions. Invert them for brilliance.",
    "METAPHOR: What's the perfect metaphor for this problem? Build from there.",
    "CHILD_VIEW: How would a 5-year-old describe the solution? Radical simplicity.",
    "ALIEN_VIEW: An alien sees this for the first time. What do they notice?",
    "HISTORICAL: How was this solved 100 years ago? 1000? What can we borrow?",
    "QUANTITY_FIRST: Generate 50 ideas in 5 minutes. No filtering. Then pick best 3.",
    "CONSTRAINT_INJECTION: Add a severe constraint. Now solve within it.",
    "ROLE_PLAY: You're the CEO/customer/competitor/hacker. What would you do?",
    "TREND_SURFING: What trends could make this irrelevant? How to ride them instead?",
    "FAILURE_MODE: List all ways this could fail catastrophically. Build safeguards.",
    "SYNESTHESIA: If this problem had a color/taste/sound/smell, what would it be?",
    "MINIMAL_VIABLE: What's the smallest thing that delivers 80% of the value?",
    "MAXIMAL_DREAM: Unlimited everything. What does the dream solution look like?",
    "ECOSYSTEM_VIEW: Who else is affected? Suppliers, regulators, families, environment?",
    "TIME_TRAVEL: Send the solution back 20 years. What parts would they understand?",
    "REVERSE_ENGINEER: Start from the desired outcome. Work backwards step by step.",
    "PARADOX_EMBRACE: The problem IS the solution. How can the obstacle become the path?",
    "DISCIPLINE_HOP: How would a mathematician/sociologist/artist/biologist solve this?",
    "EMOTION_MAP: Map user emotions through the journey. Where's delight? Frustration?",
    "SYSTEM_DYNAMICS: What feedback loops exist? What has second-order effects?",
    "BOUNDARY_BLUR: Remove the boundary between product and service, digital and physical.",
    "HIERARCHY_FLIP: Bottom-up instead of top-down. Decentralized instead of centralized.",
    "SELF_HEALING: What if the solution could detect and fix its own problems?",
    "GAMIFICATION: Turn it into a game. Points, levels, achievements, leaderboards.",
    "STORYTELLING: Craft the narrative. What's the hero's journey of the user?",
    "ZERO_TO_ONE: What's something that doesn't exist yet but SHOULD? Build it.",
    "PARETO_PRINCIPLE: 20% of effort gives 80% of value. Identify and amplify that 20%.",
    "SUNK_COST_IGNORE: Forget everything already invested. What's the right move NOW?",
    "PARALLEL_WORLDS: In a world where this does NOT exist, how do people solve it?",
    "CALM_TECHNOLOGY: What if the solution required ZERO attention from the user?",
    "DISINTERMEDIATION: Remove ALL middlemen. Connect directly. What happens?",
    "SUBSCRIPTION_SHIFT: What if this was a subscription? One-time? Pay-per-use? Free?",
    "PLATFORM_THINK: Don't solve the problem. Build a platform for others to solve it.",
    "NETWORK_EFFECT: How does each new user make it better for ALL users?",
    "UNCANNY_VALLEY: Push beyond comfortable. Where does it get unsettling?",
    "HUMOR_INJECTION: Add humor. Where's the joke? What's absurd about the situation?",
    "SILENCE_SPACE: Remove all noise. What's left when you strip everything away?",
    "RITUAL_DESIGN: Build a ritual around the solution. What's the ceremony?",
    "SLOW_MOVEMENT: Deliberately slow down. What quality emerges with patience?",
    "GENERATIONAL: Design for your grandchildren. What would they thank you for?",
    "NEGATIVE_SPACE: Don't add features. Remove them. What's powerful about absence?",
    "FORCE_FIELD: List driving forces and restraining forces. Strengthen drivers, weaken restraints.",
    "PRE_MORTEM: It failed. Why? Work backwards from failure to prevent it.",
    "OBLIQUE_STRATEGIES: Random creative prompt cards. Apply to the problem.",
    "CONTRAST_HUGE: Make one dimension huge, another tiny. What emerges?",
    "BORROW_BRILLIANCE: Steal the BEST idea from another industry. Apply directly.",
    "SHOSHIN: Beginner's mind. Forget expertise. What would a complete novice ask?",
    "DARK_SIDE: What's the evil twin of this solution? What can we learn from it?",
    "MINIMAL_INTERFACE: One button. One action. What's THE thing?",
    "UBIQUITOUS: What if this was everywhere? Embedded in walls, clothes, air?",
    "TEMPORARY_FOREVER: What if this was temporary? Permanent? Both at once?",
    "FRACTAL: Same pattern at every scale. How does the solution scale infinitely?",
    "SYNCHRONICITY: Meaningful coincidences. What unexpected connections exist?",
    "NUDGE_THEORY: Small changes that dramatically shift behavior. What's the nudge?",
    "IKIGAI: Intersection of what you love, what world needs, what you're paid for.",
    "ANTIFRAGILE: Not just robust — gets STRONGER from shocks. How?",
    "WABI_SABI: Beauty in imperfection. What's perfectly imperfect about this?",
    "LEGO_BLOCKS: Modularize. What are the atomic pieces? How do they combine?",
    "COPILOT_MODE: Don't automate. Augment. How does AI make the human superhuman?",
    "DAY_IN_LIFE: Live a day as the user. What do you discover that research missed?",
    "GUT_FEELING: Trust your gut. Write down the first 3 ideas without thinking.",
    "SERENDIPITY: Engineer happy accidents. How can randomness lead to discovery?",
  ];

  static List<String> generateIdeas(String problem, int count) {
    final ideas = <String>[];
    for (var i = 0; i < count; i++) {
      ideas.add("${techniques[i % techniques.length]}\n\nConsider: $problem\n\nWhat novel solution emerges?");
    }
    return ideas;
  }

  static String get prompt => """
## CREATIVE IDEATION (80 techniques)

Use lateral thinking. Do NOT suggest obvious solutions.

### Key techniques:
${techniques.take(10).map((t) => "- $t").join("\n")}
...and 70 more.

### Rules:
1. Every idea NOVEL — if it's on Google, it's not novel enough.
2. Combine unrelated domains. Challenge 3 assumptions, violate each.
3. Minimum 3 ideas. Never fewer. Push beyond obvious.

### Output per idea:
**Idea N: [Catchy Name]** — Core Insight | How | Why Novel | Risks
""";
}
