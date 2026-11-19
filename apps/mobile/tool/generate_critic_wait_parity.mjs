// Read-only web-source oracle. Requires Node with stripTypeScriptTypes support.
import { readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { stripTypeScriptTypes } from 'node:module';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
const web = process.argv[2];
if (!web) throw new Error('Usage: node tool/generate_critic_wait_parity.mjs /path/to/music-dna');
const files = ['src/musicdna/engine/critic-fillers.ts', 'src/lib/quip-sequences.ts', 'src/lib/critic-wait.ts'];
const source = files.map((file) => readFileSync(resolve(web, file), 'utf8'));
const url = (code) => `data:text/javascript;base64,${Buffer.from(stripTypeScriptTypes(code)).toString('base64')}`;
const fillersUrl = url(source[0]);
const groupsUrl = url(source[1].replace('@/musicdna/engine/critic-fillers', fillersUrl));
const waitUrl = url(source[2].replace('@/musicdna/engine/critic-fillers', fillersUrl).replace('./quip-sequences', groupsUrl));
const { quipBudget, waitQuips } = await import(waitUrl);
const { FILLER_REACTION, FILLER_PERSON } = await import(fillersUrl);
const cases = [];
for (const flow of ['per_pick', 'checkpoints']) {
  for (const answered of [1, 2, 3, 4, 5, 6]) {
    for (const hunch of [null, 'early', 'with', 'against']) {
      for (const decade of [null, '1980s']) {
        const budget = quipBudget(flow, answered);
        cases.push({ flow, answered, hunch, decade, used: [], budget: Number.isFinite(budget) ? budget : null,
          expected: waitQuips(answered, hunch, decade, budget, new Set()) });
      }
    }
  }
}
for (const decade of [null, '1970s', '1980s', '1990s', '2000s', '2010s', '2020s']) {
  for (const used of [[FILLER_REACTION.with[0]], [FILLER_REACTION.against[0]], [FILLER_PERSON[0][0]]]) {
    cases.push({ flow: 'checkpoints', answered: 6, hunch: 'against', decade, used, budget: null,
      expected: waitQuips(6, 'against', decade, Infinity, new Set(used)) });
  }
}
writeFileSync('test/fixtures/critic-wait-web.json', JSON.stringify({
  repo: 'acedge123/music-dna', revision: execFileSync('git', ['-C', web, 'rev-parse', 'HEAD'], {encoding:'utf8'}).trim(),
  files: Object.fromEntries(files.map((file, i) => [file, createHash('sha256').update(source[i]).digest('hex')])),
  cases,
}, null, 2) + '\n');
console.log(`Saved ${cases.length} cases evaluated by the unchanged web functions.`);
