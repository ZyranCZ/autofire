import { mkdir, writeFile } from 'node:fs/promises';

const OWNER = 'ZyranCZ';
const API = 'https://api.github.com';
const token = process.env.GITHUB_TOKEN || '';

const headers = {
  'Accept': 'application/vnd.github+json',
  'X-GitHub-Api-Version': '2022-11-28',
  'User-Agent': 'ZyranCZ-Gen1Recomp-Mod-Index'
};
if (token) headers.Authorization = `Bearer ${token}`;

async function request(path, { allow404 = false } = {}) {
  const res = await fetch(`${API}${path}`, { headers });
  if (allow404 && res.status === 404) return null;
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`${res.status} ${path}: ${text.slice(0, 400)}`);
  }
  return res.json();
}

async function listOwnerRepos() {
  const all = [];
  for (let page = 1; ; page++) {
    const rows = await request(`/users/${OWNER}/repos?type=owner&sort=full_name&per_page=100&page=${page}`);
    all.push(...rows);
    if (rows.length < 100) break;
  }
  return all.filter(r => !r.private && !r.archived && !r.disabled && !r.fork);
}

async function readManifest(repo) {
  const file = await request(`/repos/${repo.full_name}/contents/manifest.json`, { allow404: true });
  if (!file || file.type !== 'file' || !file.content) return null;
  try {
    const text = Buffer.from(file.content.replace(/\n/g, ''), 'base64').toString('utf8');
    const m = JSON.parse(text);
    if (!m || typeof m !== 'object') return null;
    if (!m.id || !m.name || !m.version || !m.entry || !m.api) return null;
    return m;
  } catch {
    return null;
  }
}

function normalize(s) {
  return String(s || '').toLowerCase().replace(/[^a-z0-9]+/g, '');
}

function pickZip(assets, manifest, release) {
  const zips = (assets || []).filter(a => typeof a?.name === 'string' && /\.zip$/i.test(a.name));
  if (!zips.length) return null;

  const id = normalize(manifest.id);
  const version = normalize(String(release?.tag_name || manifest.version).replace(/^v/i, ''));
  const scored = zips.map((a, index) => {
    const n = normalize(a.name.replace(/\.zip$/i, ''));
    let score = 0;
    if (id && n.includes(id)) score += 4;
    if (version && n.includes(version)) score += 3;
    if (/source|src/i.test(a.name)) score -= 5;
    return { a, score, index };
  });
  scored.sort((x, y) => y.score - x.score || x.index - y.index);
  return scored[0].a;
}

function mapCategory(category) {
  switch (String(category || '').toUpperCase()) {
    case 'UI': return 'UI';
    case 'TOOL': return 'TOOL';
    case 'GAMEPLAY': return 'GAMEPLAY';
    case 'CONTENT': return 'CONTENT';
    case 'BALANCE': return 'BALANCE';
    case 'ART': return 'ART';
    case 'AUDIO': return 'AUDIO';
    case 'TRANSLATION': return 'TRANSLATION';
    case 'LIBRARY': return 'LIBRARY';
    case 'TOTAL_CONVERSION': return 'TOTAL_CONVERSION';
    case 'MECHANIC': return 'GAMEPLAY';
    case 'TWEAK': return 'QOL';
    default: return 'OTHER';
  }
}

function cleanArray(value) {
  return Array.isArray(value) ? value.filter(v => typeof v === 'string') : [];
}

async function buildEntry(repo, manifest) {
  const release = await request(`/repos/${repo.full_name}/releases/latest`, { allow404: true });
  const asset = release ? pickZip(release.assets, manifest, release) : null;

  let updateCheck = 'off';
  let latest;
  if (release && asset) {
    updateCheck = 'ok';
    latest = {
      version: String(release.tag_name || manifest.version).replace(/^v(?=\d)/i, ''),
      tag: release.tag_name || null,
      name: release.name || null,
      prerelease: release.prerelease === true,
      published_at: release.published_at || null,
      zip: {
        name: asset.name,
        url: asset.browser_download_url,
        size: Number(asset.size) || undefined
      }
    };
  } else if (release) {
    updateCheck = 'no installable release';
  }

  return {
    folder: `${OWNER}@${manifest.id}`,
    id: manifest.id,
    title: manifest.name,
    author: OWNER,
    version: manifest.version,
    summary: manifest.description || '',
    categories: [mapCategory(manifest.category)],
    tags: ['Gen1Recomp', 'Pokemon'],
    repo: repo.html_url,
    github: repo.full_name,
    api: Number(manifest.api) || undefined,
    game_version: manifest.game_version || undefined,
    profile: manifest.profile || undefined,
    affects_link: manifest.affects_link === true,
    experimental: manifest.experimental === true,
    permissions: cleanArray(manifest.permissions),
    dependencies: manifest.dependencies || [],
    conflicts: manifest.conflicts || [],
    ...(latest ? { latest } : {}),
    update_check: updateCheck
  };
}

const repos = await listOwnerRepos();
const mods = [];

for (const repo of repos) {
  const manifest = await readManifest(repo);
  if (!manifest) continue;
  try {
    mods.push(await buildEntry(repo, manifest));
  } catch (err) {
    console.error(`Skipping ${repo.full_name}: ${err.message}`);
  }
}

mods.sort((a, b) => a.title.localeCompare(b.title, 'en', { sensitivity: 'base' }));
const categories = [...new Set(mods.flatMap(m => m.categories))].sort();

const index = {
  schema_version: 1,
  generated_at: new Date().toISOString(),
  count: mods.length,
  categories,
  mods
};

await mkdir('site/data', { recursive: true });
await writeFile('site/data/index.json', JSON.stringify(index, null, 2) + '\n', 'utf8');
console.log(`Wrote site/data/index.json with ${mods.length} mod(s).`);
for (const mod of mods) {
  console.log(`- ${mod.github}: ${mod.latest?.version || mod.version} [${mod.update_check}]`);
}
