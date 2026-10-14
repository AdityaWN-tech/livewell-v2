// Rule coverage gate (T-FND-06: "100% rule coverage"). Runs after the tests,
// inside the same emulator session. Fails if any conditional `allow`
// statement in firestore.rules was never evaluated, and saves the emulator's
// HTML report to coverage/rule-coverage.html for review.
// Constant denies (`if false`) are not recorded by the emulator's coverage, so
// they are listed separately; test/rules.test.ts asserts each of them with an
// explicit "fails" case.
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';

const base = 'http://127.0.0.1:8080/emulator/v1/projects/demo-livewell';
const { report } = await (await fetch(`${base}:ruleCoverage`)).json();

const evaluated = new Set();
const walk = (nodes = []) => {
  for (const n of nodes) {
    if ((n.values ?? []).some((v) => v.count > 0)) evaluated.add(n.sourcePosition.line);
    walk(n.children);
  }
};
walk(report);

const lines = readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8').split('\n');
const allowLines = lines
  .map((text, i) => ({ line: i + 1, text: text.trim() }))
  .filter(({ text }) => text.startsWith('allow '));
const constantDeny = (text) => /:\s*if false;/.test(text);
const conditional = allowLines.filter(({ text }) => !constantDeny(text));
const missed = conditional.filter(({ line }) => !evaluated.has(line));

mkdirSync(new URL('../coverage/', import.meta.url), { recursive: true });
writeFileSync(
  new URL('../coverage/rule-coverage.html', import.meta.url),
  await (await fetch(`${base}:ruleCoverage.html`)).text(),
);

console.log(
  `Rule coverage: ${conditional.length - missed.length}/${conditional.length} conditional allow statements evaluated` +
    ` (+ ${allowLines.length - conditional.length} constant denies, asserted by deny tests)`,
);
if (missed.length) {
  for (const m of missed) console.error(`  never evaluated: line ${m.line}: ${m.text}`);
  process.exit(1);
}
