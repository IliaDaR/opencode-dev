/// <reference path="../env.d.ts" />
import { tool } from "@opencode-ai/plugin"
import { execSync } from "child_process"

export default tool({
  description: `Run a command in the project directory and return the output.
Use for: running tests, typecheck, lint, build, or any project script.
Prefer this over raw bash when you need structured output from a known command.
Never use for: git push, destructive operations, or commands that modify files outside the project.`,
  args: {
    command: tool.schema.string().describe("The command to execute (e.g., 'bun test', 'bun typecheck')"),
    cwd: tool.schema.string().describe("Working directory (relative to project root)").optional(),
    timeout: tool.schema.number().describe("Timeout in milliseconds (default: 60000)").default(60000),
  },
  async execute(args) {
    const cwd = args.cwd || process.cwd()
    try {
      const output = execSync(args.command, {
        cwd,
        timeout: args.timeout,
        encoding: "utf-8",
        maxBuffer: 1024 * 1024 * 10,
        stdio: ["pipe", "pipe", "pipe"],
      })
      return output || "(command completed with no output)"
    } catch (error: any) {
      const stdout = error.stdout || ""
      const stderr = error.stderr || ""
      const status = error.status || "unknown"
      return `Exit code: ${status}\n\nSTDOUT:\n${stdout}\n\nSTDERR:\n${stderr}`
    }
  },
})
