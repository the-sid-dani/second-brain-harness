#!/usr/bin/env node
// SessionStart hook — injects current Notion task state (overdue + today, 1st Priority)
// into session context so the assistant is always aware of pending tasks before responding.
//
// Fails silently if env missing or Notion errors — never blocks session start.
// Timeout: 5s soft (Notion typically responds <1s).

import { readFileSync, existsSync } from "node:fs";
import { homedir } from "node:os";

function loadEnvFile(path) {
  if (!existsSync(path)) return;
  for (const line of readFileSync(path, "utf8").split("\n")) {
    const m = line.match(/^(?:export\s+)?([A-Z_][A-Z0-9_]*)=(.*)$/);
    if (!m) continue;
    let val = m[2].trim();
    if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
      val = val.slice(1, -1);
    }
    if (!process.env[m[1]]) process.env[m[1]] = val;
  }
}

loadEnvFile(`${homedir()}/.second-brain-os.env`);

const token = process.env.NOTION_API_TOKEN;
const ds = process.env.NOTION_ACTION_ITEMS_DS;
if (!token || !ds) process.exit(0); // silent skip

const today = new Date().toISOString().slice(0, 10);
const yesterday = new Date(Date.now() - 86400000).toISOString().slice(0, 10);

const filter = {
  and: [
    { property: "Kanban Status", status: { does_not_equal: "Done" } },
    { property: "Kanban Status", status: { does_not_equal: "Archived" } },
    {
      or: [
        { property: "Due Date", date: { on_or_before: today } },
      ],
    },
  ],
};

async function query() {
  const ctl = new AbortController();
  const t = setTimeout(() => ctl.abort(), 4500);
  try {
    const r = await fetch(`https://api.notion.com/v1/data_sources/${ds}/query`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
        "Notion-Version": "2025-09-03",
      },
      body: JSON.stringify({
        page_size: 30,
        filter,
        sorts: [
          { property: "Due Date", direction: "ascending" },
          { property: "Priority", direction: "ascending" },
        ],
      }),
      signal: ctl.signal,
    });
    if (!r.ok) return null;
    return await r.json();
  } catch {
    return null;
  } finally {
    clearTimeout(t);
  }
}

function fmt(p) {
  const props = p.properties || {};
  const title = (props["Action Items"]?.title?.[0]?.plain_text || "").trim();
  const due = props["Due Date"]?.date?.start || "";
  const pri = props["Priority"]?.select?.name || "";
  const lno = props["LNO Category"]?.select?.name || "";
  const status = props["Kanban Status"]?.status?.name || "";
  return { title, due, pri, lno, status };
}

const res = await query();
if (!res || !res.results) process.exit(0);

const items = res.results.map(fmt).filter((x) => x.title);
const overdue = items.filter((x) => x.due && x.due < today);
const todayItems = items.filter((x) => x.due === today);

if (overdue.length === 0 && todayItems.length === 0) {
  // Nothing to surface — silent.
  process.exit(0);
}

const lines = [];
lines.push("## Active Notion tasks (auto-loaded at session start)");
lines.push("");
lines.push(`Source: Action Items [DB] · queried ${new Date().toISOString().slice(0, 16)}Z · refresh with \`/todo today\``);
lines.push("");
if (overdue.length) {
  lines.push(`### Overdue (${overdue.length})`);
  for (const x of overdue.slice(0, 15)) {
    lines.push(`- [${x.due}] ${x.pri} · ${x.lno} — ${x.title}`);
  }
  lines.push("");
}
if (todayItems.length) {
  lines.push(`### Due today — ${today} (${todayItems.length})`);
  for (const x of todayItems.slice(0, 20)) {
    lines.push(`- ${x.pri} · ${x.lno} — ${x.title}`);
  }
  lines.push("");
}
lines.push("**When the user says \"tasks\" / \"pending\" / \"action items\" — these are the source of truth. Use `/todo` skill for mutations (add/done). Don't answer from project memory alone.**");

process.stdout.write(lines.join("\n") + "\n");
