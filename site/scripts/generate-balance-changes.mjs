// Generates site/src/content/balance-changes/*.md from the $BEGIN_TB/$END_TB
// comment blocks in scripts/mods/TourneyBalance/changes/career_changes/*.lua.
// The block content is already plain markdown (starting with a "# Title"
// heading) - this just extracts it, dedents it, and adds frontmatter.
// Runs automatically via the predev/prebuild npm hooks - see package.json.
import { readdirSync, readFileSync, rmSync, mkdirSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const SOURCE_DIR = path.resolve(__dirname, '../../scripts/mods/TourneyBalance/changes/career_changes');
const OUTPUT_DIR = path.resolve(__dirname, '../src/content/balance-changes');

// Strips the common leading whitespace shared by every non-blank line.
function dedent(block) {
  const lines = block.replace(/^\n/, '').replace(/\s+$/, '').split('\n');
  const indents = lines.filter((l) => l.trim().length > 0).map((l) => l.match(/^[ \t]*/)[0].length);
  const minIndent = indents.length > 0 ? Math.min(...indents) : 0;
  return lines.map((l) => l.slice(minIndent)).join('\n');
}

function toMarkdown(fileBase, body) {
  const orderMatch = fileBase.match(/^(\d+)_/);
  const order = orderMatch ? Number(orderMatch[1]) : 0;
  const titleMatch = body.match(/^#\s+(.+)$/m);
  const title = titleMatch ? titleMatch[1].trim() : fileBase;

  const frontmatter = `---\ntitle: ${JSON.stringify(title)}\norder: ${order}\n---\n\n`;

  return frontmatter + body.trim() + '\n';
}

function main() {
  rmSync(OUTPUT_DIR, { recursive: true, force: true });
  mkdirSync(OUTPUT_DIR, { recursive: true });

  const files = readdirSync(SOURCE_DIR).filter((f) => f.endsWith('.lua'));
  let generated = 0;

  for (const file of files) {
    const source = readFileSync(path.join(SOURCE_DIR, file), 'utf8');
    const blockMatch = source.match(/\$BEGIN_TB\r?\n([\s\S]*?)\r?\n[ \t]*\$END_TB/i);
    if (!blockMatch) continue;

    const body = dedent(blockMatch[1]);
    if (!body) continue;

    const fileBase = file.replace(/\.lua$/, '');
    const markdown = toMarkdown(fileBase, body);

    writeFileSync(path.join(OUTPUT_DIR, `${fileBase}.md`), markdown, 'utf8');
    generated++;
  }

  console.log(`Generated ${generated} balance-changes page(s) into ${path.relative(process.cwd(), OUTPUT_DIR)}`);
}

main();
