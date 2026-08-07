import { getCollection } from 'astro:content';

export function slugifyTitle(title: string) {
  return title
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

export async function getSortedBalanceChanges() {
  const entries = await getCollection('balanceChanges');
  return entries
    .map((entry) => ({ entry, slug: slugifyTitle(entry.data.title) }))
    .sort((a, b) => a.entry.data.order - b.entry.data.order);
}
