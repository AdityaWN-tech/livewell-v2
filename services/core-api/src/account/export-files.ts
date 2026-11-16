import { DocumentReference, GeoPoint, Timestamp } from 'firebase-admin/firestore';
import { strToU8, zipSync } from 'fflate';

import { isInternalField } from './export-collections.js';

/**
 * Pure helpers that turn one person's documents into the export archive
 * (FR-SET-02, T-CMP-03, D-82): data.json (machine-readable), summary.pdf
 * (the human-readable summary the spec asks for) and README.txt.
 */

export interface StorageFileEntry {
  path: string;
  size_bytes: number;
  content_type: string | null;
  updated: string | null;
}

export interface ExportData {
  format: 'livewell-export';
  format_version: 1;
  generated_at: string;
  expires_at: string;
  uid: string;
  profile: Record<string, unknown> | null;
  collections: Record<string, Array<{ id: string; data: unknown }>>;
  storage_files: StorageFileEntry[];
  /** Sub-collections found that are not in the export list (names only). */
  unlisted_collections: string[];
  left_out: string[];
}

/**
 * Firestore values as plain JSON, with internal fields removed at every
 * depth (vendor ids, hashes, internal links, safety-review state).
 */
export function toPlain(value: unknown): unknown {
  if (value === null || value === undefined) return null;
  if (value instanceof Timestamp) return value.toDate().toISOString();
  if (value instanceof Date) return value.toISOString();
  if (value instanceof GeoPoint) {
    return { latitude: value.latitude, longitude: value.longitude };
  }
  if (value instanceof DocumentReference) return value.path;
  if (value instanceof Uint8Array) return Buffer.from(value).toString('base64');
  if (Array.isArray(value)) return value.map(toPlain);
  if (typeof value === 'object') {
    const out: Record<string, unknown> = {};
    for (const key of Object.keys(value as object).sort()) {
      if (isInternalField(key)) continue;
      out[key] = toPlain((value as Record<string, unknown>)[key]);
    }
    return out;
  }
  return value;
}

/** Plain-language names for the summary. */
const LABELS: Record<string, string> = {
  consents: 'Consents you gave or took back',
  avatar: 'Your coach (avatar) settings',
  voices: 'Coach voices',
  assessments: 'Assessments',
  goals: 'Goals',
  habits: 'Habits',
  habit_logs: 'Habit check-offs',
  checkins: 'Daily check-ins',
  reflections: 'Reflections',
  routines: 'Routines',
  routine_items: 'Routine items',
  routine_logs: 'Routine check-offs',
  daily_plans: 'Daily plans',
  messages: 'Coach messages',
  memory_facts: 'Things the coach remembers',
  streaks: 'Streaks',
  portal_link: 'Linked portal account',
  content_progress: 'Lessons in progress',
  portal_events: 'Portal activity',
};

const day = (iso: string) => iso.slice(0, 10);

/** The lines shared by summary.pdf and README.txt. */
export function summaryLines(data: ExportData): string[] {
  const lines = [
    'Your Live Well data',
    '',
    `Prepared on ${day(data.generated_at)} (UTC) for account ${data.uid}.`,
    `This file and its download link expire on ${day(data.expires_at)}.`,
    '',
    'What is inside',
    `- Your profile and settings: ${data.profile ? 'yes' : 'none saved'}`,
  ];
  for (const [name, docs] of Object.entries(data.collections)) {
    lines.push(`- ${LABELS[name] ?? name}: ${docs.length}`);
  }
  lines.push(
    `- Files in cloud storage (listed, not copied): ${data.storage_files.length}`,
    '',
    'Left out',
    ...data.left_out.map((s) => `- ${s}`),
    '',
    'All of the data is in data.json (JSON, UTF-8, dates in UTC).',
    'Keep this file somewhere safe: it is personal information.',
  );
  return lines;
}

export function readme(data: ExportData): string {
  return [
    ...summaryLines(data),
    '',
    'data.json format',
    '- profile: your profile document (users/{uid}).',
    '- collections: one list per kind of data; each item is {id, data}.',
    '- storage_files: path, size, type and date of each file kept for you.',
    '- Dates are ISO 8601 strings in UTC.',
    '',
  ].join('\n');
}

/** PDF text: printable ASCII only, with ( ) \ escaped. */
function pdfText(s: string): string {
  return s
    .replace(/[‘’]/g, "'")
    .replace(/[^\x20-\x7e]/g, '?')
    .replace(/([\\()])/g, '\\$1');
}

/**
 * A minimal text-only PDF (Helvetica, A4/Letter-safe margins). Hand-written
 * so the export needs no PDF library; enough for a one- or two-page summary.
 */
export function summaryPdf(lines: string[]): Uint8Array {
  const perPage = 48;
  const pages: string[][] = [];
  for (let i = 0; i < lines.length; i += perPage) {
    pages.push(lines.slice(i, i + perPage));
  }
  if (pages.length === 0) pages.push([]);

  const objects: string[] = [];
  // 1 catalog, 2 pages, 3 regular font, 4 bold font, then page + content pairs.
  const kids = pages.map((_, i) => `${5 + i * 2} 0 R`).join(' ');
  objects.push('<< /Type /Catalog /Pages 2 0 R >>');
  objects.push(`<< /Type /Pages /Kids [${kids}] /Count ${pages.length} >>`);
  objects.push('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>');
  objects.push('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>');
  pages.forEach((pageLines, p) => {
    const ops = ['BT', '/F1 11 Tf', '14 TL', '56 760 Td'];
    pageLines.forEach((line, i) => {
      const heading = (p === 0 && i === 0) || line === 'What is inside' || line === 'Left out';
      ops.push(heading ? '/F2 13 Tf' : '/F1 11 Tf');
      ops.push(`(${pdfText(line)}) Tj T*`);
    });
    ops.push('ET');
    const stream = ops.join('\n');
    objects.push(
      `<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] ` +
        `/Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> /Contents ${6 + p * 2} 0 R >>`,
    );
    objects.push(`<< /Length ${Buffer.byteLength(stream, 'latin1')} >>\nstream\n${stream}\nendstream`);
  });

  let out = '%PDF-1.4\n';
  const offsets: number[] = [];
  objects.forEach((body, i) => {
    offsets.push(Buffer.byteLength(out, 'latin1'));
    out += `${i + 1} 0 obj\n${body}\nendobj\n`;
  });
  const xref = Buffer.byteLength(out, 'latin1');
  out += `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n`;
  for (const o of offsets) out += `${String(o).padStart(10, '0')} 00000 n \n`;
  out += `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`;
  return new Uint8Array(Buffer.from(out, 'latin1'));
}

/** The archive the person downloads. */
export function buildArchive(data: ExportData): Uint8Array {
  const dir = 'livewell-data';
  return zipSync(
    {
      [`${dir}/README.txt`]: strToU8(readme(data)),
      [`${dir}/summary.pdf`]: summaryPdf(summaryLines(data)),
      [`${dir}/data.json`]: strToU8(JSON.stringify(data, null, 2)),
    },
    { level: 6 },
  );
}
