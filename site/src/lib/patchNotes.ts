import { getCollection } from 'astro:content';

export function slugifyTitle(title: string) {
  return title
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

export async function getSortedPatchNotes() {
  const entries = await getCollection('patchNotes');
  return entries
    .map((entry) => ({ entry, slug: slugifyTitle(entry.data.title) }))
    .sort((a, b) => b.entry.data.date.valueOf() - a.entry.data.date.valueOf());
}
