/// <reference path="../env.d.ts" />
import { tool } from "@opencode-ai/plugin"

export default tool({
  description: `Search the codebase for code patterns using regex or literal text.
More powerful than grep: returns matching lines with surrounding context, grouped by file.
Use to find: function definitions, type declarations, import patterns, TODO/FIXME comments, specific API usage.`,
  args: {
    pattern: tool.schema.string().describe("Search pattern (regex supported)"),
    include: tool.schema.string().describe("File glob pattern (e.g., '*.ts', '*.{ts,tsx}')").optional(),
    exclude: tool.schema.string().describe("Exclude pattern (e.g., 'node_modules,dist')").optional(),
    contextLines: tool.schema.number().describe("Lines of context before/after each match").default(2),
    maxResults: tool.schema.number().describe("Maximum total results to return").default(30),
  },
  async execute(args) {
    // Use ripgrep if available, fallback to findstr
    const exclude = args.exclude || "node_modules,.git,dist,.next,build,target"
    const glob = args.include || ""
    const pattern = args.pattern
    const ctx = args.contextLines
    const max = args.maxResults

    // Build exclusion args
    const excludeArgs = exclude.split(",").map(e => `--glob=!${e.trim()}`).join(" ")

    const fs = await import("fs")
    const path = await import("path")
    const cp = await import("child_process")

    const cmd = `rg --line-number --context ${ctx} ${excludeArgs} ${glob ? `--glob=${glob}` : ""} "${pattern}" . | head -n ${max * (ctx * 2 + 3)}`

    return new Promise((resolve) => {
      cp.exec(cmd, { cwd: process.cwd(), maxBuffer: 1024 * 1024 * 5, timeout: 30000 }, (error, stdout, stderr) => {
        if (error && !stdout) {
          // Try PowerShell fallback
          const psCmd = `Get-ChildItem -Recurse -Include *.ts,*.tsx,*.js,*.jsx,*.py,*.rs,*.go | Select-String -Pattern "${pattern}" | Select-Object -First ${max}`
          cp.exec(`powershell -Command "${psCmd}"`, { cwd: process.cwd(), maxBuffer: 1024 * 1024 * 5 }, (err2, out2) => {
            resolve(out2 || stderr || error.message || "No results found")
          })
          return
        }
        resolve(stdout || "No results found")
      })
    })
  },
})
