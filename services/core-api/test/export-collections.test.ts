import { readFileSync } from 'node:fs';

import { GeoPoint, Timestamp } from 'firebase-admin/firestore';
import { strFromU8, unzipSync } from 'fflate';
import { describe, expect, it } from 'vitest';

import { blocksNewRequest } from '../src/account/data-export.js';
import {
  EXCLUDED_TOP_LEVEL_COLLECTIONS,
  EXCLUDED_USER_COLLECTIONS,
  EXPORTED_USER_COLLECTIONS,
} from '../src/account/export-collections.js';
import {
  buildArchive,
  summaryLines,
  summaryPdf,
  toPlain,
  type ExportData,
} from '../src/account/export-files.js';

/** Collection paths in the first column of docs/data-model.md's Firestore
 * tables (every `path` in that cell; the Cloud Storage section is not
 * Firestore and is classified by USER_STORAGE_PREFIXES). */
function dataModelPaths(): string[] {
  const md = readFileSync(new URL('../../../docs/data-model.md', import.meta.url), 'utf8');
  const firestore = md.split(/^## Cloud Storage/m)[0]!;
  return [...firestore.matchAll(/^\| ((?:\\\||[^|])*`(?:\\\||[^|])*)\|/gm)].flatMap((m) => {
    const cell = [...m[1]!.matchAll(/`([^`]+)`/g)].map((c) => c[1]!);
    // `users/{uid}/a/{x}`, `b/{x}`: later paths in a cell share the first's parent.
    const parent = /^(users\/\{uid\}\/)/.exec(cell[0]!)?.[1] ?? '';
    return cell.map((c, i) => (i > 0 && !c.startsWith('users/') ? parent + c : c));
  });
}

describe('every collection in docs/data-model.md is classified (D-82)', () => {
  const paths = dataModelPaths();
  const subs = paths
    .map((p) => /^users\/\{uid\}\/([a-z_]+)/.exec(p)?.[1])
    .filter((s): s is string => !!s);
  const tops = paths
    .filter((p) => !p.startsWith('users/'))
    .map((p) => p.split('/')[0]!);

  it('finds the table', () => {
    expect(paths).toContain('users/{uid}');
    expect(subs.length).toBeGreaterThan(15);
  });

  it('each users/{uid} sub-collection is exported or excluded with a reason', () => {
    const classified = [...EXPORTED_USER_COLLECTIONS, ...Object.keys(EXCLUDED_USER_COLLECTIONS)];
    expect(subs.filter((s) => !classified.includes(s))).toEqual([]);
    // ... and nothing is listed that the data model doesn't have.
    expect(classified.filter((s) => !subs.includes(s))).toEqual([]);
    // Never both.
    expect(EXPORTED_USER_COLLECTIONS.filter((s) => s in EXCLUDED_USER_COLLECTIONS)).toEqual([]);
  });

  it('each top-level collection is classified', () => {
    const classified = Object.keys(EXCLUDED_TOP_LEVEL_COLLECTIONS);
    expect(tops.filter((s) => !classified.includes(s))).toEqual([]);
    expect(classified.filter((s) => !tops.includes(s))).toEqual([]);
  });
});

describe('toPlain', () => {
  it('turns Firestore values into JSON and drops internal fields at any depth', () => {
    const out = toPlain({
      mood: 4,
      at: Timestamp.fromDate(new Date('2026-11-01T08:00:00Z')),
      where: new GeoPoint(1, 2),
      vendor: 'acme',
      vendor_voice_id: 'v-123',
      matched_email_hash: 'sha256:x',
      tts_cache_url: 'https://cdn/x',
      thumbnail_urls: { happy: 'https://cdn/y' },
      ed_safe_mode: true,
      safety_state: 'hold',
      tagmango_customer_ref: 'tm-1',
      nested: [{ vendor_avatar_id: 'a', keep: 'yes' }],
    });
    expect(out).toEqual({
      mood: 4,
      at: '2026-11-01T08:00:00.000Z',
      where: { latitude: 1, longitude: 2 },
      nested: [{ keep: 'yes' }],
    });
  });
});

describe('rate limit', () => {
  const now = new Date('2026-11-16T12:00:00Z');
  const ago = (min: number) => Timestamp.fromMillis(now.getTime() - min * 60_000);
  it('a ready export in the last 24 h blocks; older ones do not', () => {
    expect(blocksNewRequest({ status: 'ready', created_at: ago(60) }, now)).toBe(true);
    expect(blocksNewRequest({ status: 'ready', created_at: ago(24 * 60) }, now)).toBe(false);
  });
  it('failed and stale (over an hour preparing) exports never block', () => {
    expect(blocksNewRequest({ status: 'failed', created_at: ago(5) }, now)).toBe(false);
    expect(blocksNewRequest({ status: 'preparing', created_at: ago(30) }, now)).toBe(true);
    expect(blocksNewRequest({ status: 'preparing', created_at: ago(61) }, now)).toBe(false);
  });
});

describe('archive', () => {
  const data: ExportData = {
    format: 'livewell-export',
    format_version: 1,
    generated_at: '2026-11-16T12:00:00.000Z',
    expires_at: '2026-11-23T12:00:00.000Z',
    uid: 'u1',
    profile: { display_name: 'Priya (Pérez) \\ test' },
    collections: { checkins: [{ id: '2026-11-16', data: { mood: 4 } }] },
    storage_files: [],
    unlisted_collections: [],
    left_out: ['Internal fields.'],
  };

  it('zip holds data.json, summary.pdf and README.txt', () => {
    const files = unzipSync(buildArchive(data));
    expect(Object.keys(files).sort()).toEqual([
      'livewell-data/README.txt',
      'livewell-data/data.json',
      'livewell-data/summary.pdf',
    ]);
    expect(JSON.parse(strFromU8(files['livewell-data/data.json']!))).toEqual(data);
    expect(strFromU8(files['livewell-data/README.txt']!)).toContain('Daily check-ins: 1');
  });

  it('summary.pdf is a well-formed PDF with a correct xref table', () => {
    const pdf = Buffer.from(summaryPdf(summaryLines(data))).toString('latin1');
    expect(pdf.startsWith('%PDF-1.4')).toBe(true);
    expect(pdf.trimEnd().endsWith('%%EOF')).toBe(true);
    const startxref = Number(/startxref\n(\d+)/.exec(pdf)![1]);
    expect(pdf.slice(startxref, startxref + 4)).toBe('xref');
    const offsets = [...pdf.slice(startxref).matchAll(/^(\d{10}) 00000 n $/gm)].map((m) => Number(m[1]));
    offsets.forEach((o, i) => {
      const head = `${i + 1} 0 obj\n`;
      expect(pdf.slice(o, o + head.length)).toBe(head);
    });
    expect(pdf).toContain('(- Daily check-ins: 1) Tj');
  });

  it('PDF text escapes brackets and drops non-ASCII', () => {
    const pdf = Buffer.from(summaryPdf(['A (b) \\ é ’'])).toString('latin1');
    expect(pdf).toContain("(A \\(b\\) \\\\ ? ') Tj");
  });
});
