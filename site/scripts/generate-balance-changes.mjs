// Generates site/src/content/balance-changes/*.md from the $BEGIN_TB/$END_TB
// comment blocks in scripts/mods/TourneyBalance/changes/career_changes/*.lua.
// Runs automatically via the predev/prebuild npm hooks - see package.json.
import { readdirSync, readFileSync, rmSync, mkdirSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const SOURCE_DIR = path.resolve(__dirname, '../../scripts/mods/TourneyBalance/changes/career_changes');
const OUTPUT_DIR = path.resolve(__dirname, '../src/content/balance-changes');

const KEY_LINE = /^(title|ult|passives|talent[a-zA-Z0-9]*)\s*:\s*(.*)$/i;
const NAME_DASH = /^(.+?)\s-\s(.+)$/;

function startParagraph(sectionType, line) {
  if (sectionType === 'ult' || sectionType === 'title') {
    return { name: null, text: line };
  }
  const m = line.match(NAME_DASH);
  if (m) return { name: m[1].trim(), text: m[2].trim() };
  return { name: null, text: line };
}

// Parses one $BEGIN_TB..$END_TB block into { title, ultParagraphs, passivesParagraphs, talentParagraphs }.
function parseBlock(block) {
  const lines = block
    .split('\n')
    .map((l) => l.trim())
    .filter((l) => l.length > 0);

  const sections = [];
  let current = null;
  let currentParagraph = null;

  for (const line of lines) {
    const keyMatch = line.match(KEY_LINE);
    if (keyMatch) {
      const rawKey = keyMatch[1].toLowerCase();
      const type = rawKey.startsWith('talent') ? 'talent' : rawKey;
      current = { type, paragraphs: [] };
      sections.push(current);
      currentParagraph = null;

      const rest = keyMatch[2].trim();
      if (rest) {
        currentParagraph = startParagraph(type, rest);
        current.paragraphs.push(currentParagraph);
      }
      continue;
    }

    if (!current) continue; // stray line before any key line, ignore

    if (current.type === 'ult' || current.type === 'title') {
      currentParagraph = startParagraph(current.type, line);
      current.paragraphs.push(currentParagraph);
    } else if (NAME_DASH.test(line)) {
      currentParagraph = startParagraph(current.type, line);
      current.paragraphs.push(currentParagraph);
    } else if (currentParagraph) {
      currentParagraph.text += `\n${line}`;
    } else {
      currentParagraph = startParagraph(current.type, line);
      current.paragraphs.push(currentParagraph);
    }
  }

  const isMeaningful = (p) => p.text.trim() !== '' && p.text.trim() !== '-';
  const collect = (type) =>
    sections
      .filter((s) => s.type === type)
      .flatMap((s) => s.paragraphs)
      .filter(isMeaningful);

  const title = sections.find((s) => s.type === 'title')?.paragraphs[0]?.text.trim() || '';

  return {
    title,
    ultParagraphs: collect('ult'),
    passivesParagraphs: collect('passives'),
    talentParagraphs: collect('talent'),
  };
}

function renderParagraph(p) {
  const text = p.text.split('\n').join('  \n');
  return p.name ? `**${p.name}** - ${text}` : text;
}

function renderSection(heading, paragraphs) {
  if (paragraphs.length === 0) return '';
  return `## ${heading}\n\n${paragraphs.map(renderParagraph).join('\n\n')}\n\n`;
}

function toMarkdown(fileBase, parsed) {
  const orderMatch = fileBase.match(/^(\d+)_/);
  const order = orderMatch ? Number(orderMatch[1]) : 0;
  const title = parsed.title || fileBase;

  const frontmatter = `---\ntitle: ${JSON.stringify(title)}\norder: ${order}\n---\n\n`;

  let body =
    renderSection('Ultimate', parsed.ultParagraphs) +
    renderSection('Passives', parsed.passivesParagraphs) +
    renderSection('Talents', parsed.talentParagraphs);

  if (!body) body = 'No changes documented yet.\n';

  return frontmatter + body.trimEnd() + '\n';
}

function main() {
  rmSync(OUTPUT_DIR, { recursive: true, force: true });
  mkdirSync(OUTPUT_DIR, { recursive: true });

  const files = readdirSync(SOURCE_DIR).filter((f) => f.endsWith('.lua'));
  let generated = 0;

  for (const file of files) {
    const source = readFileSync(path.join(SOURCE_DIR, file), 'utf8');
    const blockMatch = source.match(/\$BEGIN_TB([\s\S]*?)\$END_TB/i);
    if (!blockMatch) continue;

    const parsed = parseBlock(blockMatch[1]);
    const fileBase = file.replace(/\.lua$/, '');
    const markdown = toMarkdown(fileBase, parsed);

    writeFileSync(path.join(OUTPUT_DIR, `${fileBase}.md`), markdown, 'utf8');
    generated++;
  }

  console.log(`Generated ${generated} balance-changes page(s) into ${path.relative(process.cwd(), OUTPUT_DIR)}`);
}

main();
