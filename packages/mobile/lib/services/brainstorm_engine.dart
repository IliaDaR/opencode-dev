/// Brainstorm engine — 18 lateral thinking techniques
class BrainstormEngine {
  static final List<String> _techniques = [
    "INVERSION: Reverse the flow. Flip the assumption. What if we did the opposite?",
    "ANALOGY: What does this resemble from biology? Physics? Games? Music? Military?",
    "CONSTRAINT_REMOVAL: Unlimited budget/time/users. Then scale back to reality.",
    "COMBINATION: Merge with unrelated concept. AI + farming? Code + cooking? Blockchain + dating?",
    "EXTREME: Most extreme version? Simplest? Most complex? Fastest? Slowest?",
    "FIRST_PRINCIPLES: Strip ALL assumptions. What's the fundamental problem beneath?",
    "USER_OBSESSION: What makes users cry with joy? Their deepest unspoken frustration?",
    "FUTURE_BACK: Fast-forward 5 years. What exists then? Work backwards to today.",
    "RANDOM_STIMULUS: Open dictionary on random word. How does it connect to the problem?",
    "PROVOCATION: Make absurd statement. 'Code writes itself.' Extract the useful kernel.",
    "SCAMPER: Substitute, Combine, Adapt, Modify, Put to another use, Eliminate, Reverse.",
    "SIX_HATS: White(facts), Red(emotions), Black(risks), Yellow(benefits), Green(creativity), Blue(process).",
    "TRIZ: 40 inventive principles. Key: segmentation, asymmetry, merging, universality, nesting.",
    "BIOMIMICRY: How does nature solve this? Ant colonies? Bee hives? Evolution? Neural nets?",
    "CONTRADICTION: Identify contradiction (want X and not-X). Resolve, don't compromise.",
    "BLUE_OCEAN: Eliminate, Reduce, Raise, Create. Remove what industry takes for granted.",
    "JOBS_TO_BE_DONE: What 'job' is the user hiring this product for? Not features — the progress.",
    "PRETOTYPE: What's the FAKEST version testing the core assumption? Fake before you build.",
  ];

  static List<String> generateIdeas(String problem, int count) {
    final ideas = <String>[];
    for (var i = 0; i < count; i++) {
      ideas.add("${_techniques[i % _techniques.length]}\n\nConsider: $problem\n\nWhat novel solution emerges?");
    }
    return ideas;
  }

  static String get prompt => """
## CREATIVE IDEATION

Use lateral thinking. Do NOT suggest obvious solutions.

### Techniques:
${_techniques.map((t) => "- $t").join("\n")}

### Rules:
1. Every idea NOVEL — if it's on Google, it's not novel enough.
2. Combine unrelated domains. Challenge 3 assumptions, violate each.
3. Minimum 3 ideas. Never fewer. Push beyond obvious.

### Output per idea:
**Idea N: [Catchy Name]**
- Core Insight: [non-obvious realization]
- How: [2-3 sentences]
- Why Novel: [different from existing]
- Risks: [honest challenges]
""";
}
