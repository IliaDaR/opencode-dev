import "sub_agent_service.dart";

/// Debate mode — two sub-agents argue, main agent resolves
/// Simulates AI-to-AI deliberation for better decisions
class DebateService {
  /// Run a debate between two agent types on a topic
  static Future<String> debate(
      String topic, String agent1Type, String agent2Type) async {
    final buf = StringBuffer();
    buf.writeln("## Debate: $topic\n");
    buf.writeln("**${agent1Type.toUpperCase()}** vs **${agent2Type.toUpperCase()}**\n");

    // Position 1
    final pos1Task = "Argue FOR this approach to: $topic. Be persuasive. Give concrete reasons.";
    final pos1 = await SubAgentService.delegate(agent1Type, pos1Task);
    buf.writeln("### $agent1Type (FOR):\n$pos1\n");

    // Position 2
    final pos2Task = "Critique this approach: $topic. Find flaws, risks, and suggest a BETTER alternative.";
    final pos2 = await SubAgentService.delegate(agent2Type, pos2Task);
    buf.writeln("### $agent2Type (AGAINST):\n$pos2\n");

    // Resolution
    buf.writeln("### Resolution:");
    buf.writeln("Both sides presented. Consider:");
    buf.writeln("1. What are the strongest arguments from each side?");
    buf.writeln("2. Is there a synthesis that captures the best of both?");
    buf.writeln("3. What's the MINIMAL version we can try first to validate?");

    return buf.toString();
  }

  /// Quick compare — two options, agent picks best
  static String comparePrompt(String optionA, String optionB) {
    return """
Compare these two approaches:

**Option A:** $optionA

**Option B:** $optionB

Analyze:
1. Complexity: which is simpler?
2. Performance: which is faster?
3. Maintainability: which is easier to change?
4. Risk: which has fewer unknowns?
5. Ecosystem: which has better library/tool support?

Pick ONE and explain why. Be decisive.
""";
  }
}
