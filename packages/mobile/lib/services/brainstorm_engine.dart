/// Brainstorm engine — generates novel, non-obvious ideas by combining unrelated concepts.
/// Uses lateral thinking techniques: inversion, analogy, constraint removal, combination.
class BrainstormEngine {
  static final List<String> _techniques = [
    "INVERSION: What if we did the opposite? Reverse the flow, flip the assumption.",
    "ANALOGY: What does this resemble from another domain? Biology? Physics? Games?",
    "CONSTRAINT_REMOVAL: What if we had unlimited budget/time/users? Then scale back.",
    "COMBINATION: What if we merged this with an unrelated concept? AI + farming? Code + music?",
    "EXTREME: What's the most extreme version? The simplest? The most complex?",
    "FIRST_PRINCIPLES: Strip assumptions. What's the fundamental problem?",
    "USER_OBSESSION: What would make users cry with joy? What's their deepest frustration?",
    "FUTURE_BACK: Fast-forward 5 years. What does the solution look like? Work backwards.",
  ];

  /// Generate novel ideas for a problem
  static List<String> generateIdeas(String problem, int count) {
    final ideas = <String>[];

    for (var i = 0; i < count; i++) {
      final technique = _techniques[i % _techniques.length];
      ideas.add("$technique\n\nConsider: $problem\n\nWhat novel solution emerges?");
    }

    return ideas;
  }

  /// Get a brainstorming prompt for the agent
  static String get prompt => """
## CREATIVE IDEATION MODE

When asked to generate ideas, you MUST use lateral thinking techniques. Do NOT suggest obvious solutions. Do NOT Google the answer. Think differently.

### Techniques to apply (rotate through them):
${_techniques.map((t) => "- $t").join("\n")}

### Rules for Idea Generation:
1. Every idea must be NOVEL — if it exists on Google, it's not novel enough
2. Combine unrelated domains: "What would a chef do? A musician? A biologist?"
3. Challenge assumptions: list 3 assumptions about the problem, then violate each one
4. Extreme thinking: what if cost was zero? What if users were infinite? What if time stopped?
5. Cross-pollinate: take a solution from one industry and apply it here

### Output Format:
For each idea, provide:
- **Idea Name** (catchy, 2-4 words)
- **Core Insight** (the non-obvious realization)
- **How It Works** (2-3 sentences)
- **Why It's Novel** (what makes it different from existing solutions)
- **Risks/Challenges** (honest assessment)

Generate at least 3 ideas. Never fewer. Push beyond the obvious.
""";
}
