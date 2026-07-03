/// <reference path="../env.d.ts" />
import { tool } from "@opencode-ai/plugin"
import { readdirSync, statSync, readFileSync, existsSync } from "fs"
import { join, relative, extname } from "path"

const CODE_EXTENSIONS = new Set([
  ".ts", ".tsx", ".js", ".jsx", ".py", ".rs", ".go", ".java",
  ".c", ".cpp", ".h", ".hpp", ".rb", ".php", ".swift", ".kt",
  ".sql", ".sh", ".bash", ".yaml", ".yml", ".toml", ".json",
])

export default tool({
  description: `Analyze the codebase structure of a directory.
Returns: file count by extension, largest files, directory tree depth, and key statistics.
Use to understand project structure before making changes.`,
  args: {
    path: tool.schema.string().describe("Directory path to analyze (relative to project root)").default("."),
    maxDepth: tool.schema.number().describe("Maximum directory depth to analyze").default(5),
  },
  async execute(args) {
    const root = process.cwd()
    const target = join(root, args.path)
    if (!existsSync(target)) return `Path not found: ${args.path}`

    const stats = { files: 0, dirs: 0, byExt: {} as Record<string, number>, totalSize: 0, largest: [] as { path: string; size: number }[] }

    function walk(dir: string, depth: number) {
      if (depth > args.maxDepth) return
      let entries
      try { entries = readdirSync(dir) } catch { return }
      for (const entry of entries) {
        if (entry.startsWith(".") && entry !== ".env.example") continue
        if (entry === "node_modules" || entry === "dist" || entry === ".git" || entry === ".next") continue
        const full = join(dir, entry)
        let s
        try { s = statSync(full) } catch { continue }
        if (s.isDirectory()) {
          stats.dirs++
          walk(full, depth + 1)
        } else {
          stats.files++
          stats.totalSize += s.size
          const ext = extname(entry) || "(no ext)"
          stats.byExt[ext] = (stats.byExt[ext] || 0) + 1
          if (CODE_EXTENSIONS.has(ext)) {
            stats.largest.push({ path: relative(root, full), size: s.size })
            stats.largest.sort((a, b) => b.size - a.size)
            if (stats.largest.length > 20) stats.largest.length = 20
          }
        }
      }
    }

    walk(target, 0)

    let output = `## Codebase Analysis: ${args.path}\n\n`
    output += `Files: ${stats.files} | Directories: ${stats.dirs} | Total: ${(stats.totalSize / 1024 / 1024).toFixed(1)} MB\n\n`
    output += `### Files by extension:\n`
    const sorted = Object.entries(stats.byExt).sort((a, b) => b[1] - a[1])
    for (const [ext, count] of sorted.slice(0, 15)) {
      output += `  ${ext}: ${count}\n`
    }
    if (stats.largest.length > 0) {
      output += `\n### Largest source files:\n`
      for (const f of stats.largest) {
        output += `  ${f.path} (${(f.size / 1024).toFixed(1)} KB)\n`
      }
    }
    return output
  },
})
