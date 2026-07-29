---
title: "GitHub Pages"
order: 1
---

# GitHub Pages
This page documents how this site itself is built and deployed — the tools
involved and the exact path from writing content to it going live.

## Tools

| Tool | Role |
|------|------|
| [Astro](https://astro.build) | Static site generator. Builds this site into plain HTML/CSS/JS — no server needed at runtime. |
| [Pagefind](https://pagefind.app) | Builds the site's search index after each build, by scanning the finished HTML. |
| GitHub Actions | Runs the build and publishes it to GitHub Pages on every push. |
| `actions/upload-pages-artifact` + `actions/deploy-pages` | The two official GitHub actions that hand a build off to GitHub Pages' hosting. |

## Where things live

- Site source: `site/` (Astro project — pages, layouts, components, content collections).
- Content: `site/src/content/patch-notes/` and `site/src/content/docs/` — plain Markdown files with frontmatter.
- Deploy workflow: `.github/workflows/deploy-site.yml`.

## Writing content

New patch notes or documentation pages are just Markdown files dropped into
the relevant content folder, with frontmatter (`title`, `date`/`order`).
Metadata is read straight from the frontmatter — nothing else needs
updating for a new page to show up.

To preview locally before pushing:

```
cd site
npm run dev
```

To check the exact production build (including search indexing) before
pushing:

```
npm run build
npm run preview
```

## From push to live site

1. Commit changes and push to `main`, touching anything under `site/**`.
2. GitHub Actions picks up `deploy-site.yml`, since its trigger is scoped
   to `site/**` changes on `main`.
3. **Build job**:
   - Checks out the repo, sets up Node 22.
   - `npm ci` — clean install from `site/package-lock.json`.
   - `npm run build` — runs `astro build`, which automatically triggers
     `postbuild` (`pagefind --site dist`) afterward via npm's built-in
     `post<script>` convention, so the search index is built in the same
     step with no extra wiring.
   - The finished `site/dist` folder is uploaded as the Pages artifact.
4. **Deploy job**: takes that artifact and publishes it via
   `actions/deploy-pages`.
5. The live site updates at `https://vt2-tourney-balance.github.io/Tourney-Balance-Open-Beta/`.

You never run the build yourself for deployment — pushing is enough. Local
`build`/`preview` are just for checking things look right first.

## Repo safety

Both jobs in `deploy-site.yml` are gated behind:

```
if: github.repository == 'vt2-tourney-balance/Tourney-Balance-Open-Beta'
```

This site is built only from the Open Beta fork. Since changes here
occasionally get merged upstream into the official repository, this
condition makes sure the workflow does nothing if it ever ends up there —
without it, a merge could silently start building/deploying a duplicate
site from the official repo too.

## GitHub Pages repo settings

Under repo **Settings → Pages**, the source is set to **GitHub Actions**
(not "Deploy from a branch"). This means there's no `gh-pages` branch
holding committed build output — GitHub Pages serves whatever the workflow
last published as an artifact.

## Base path

Since this is a project page (not `<org>.github.io` at the domain root),
`site/astro.config.mjs` sets:

```js
export default defineConfig({
  site: 'https://vt2-tourney-balance.github.io',
  base: '/Tourney-Balance-Open-Beta/',
});
```

`base` must keep the trailing slash — without it, base-prefixed asset
paths built as `${base}something` concatenate without a separator and
404 in production.

