import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import { validateDocumentationLinks } from '../../scripts/Validate-Documentation.mjs';

function fixture(t, source, target = '# Target\n') {
  const root = mkdtempSync(join(tmpdir(), 'kapsel-docs-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  mkdirSync(join(root, 'docs'));
  writeFileSync(join(root, 'README.md'), source);
  writeFileSync(join(root, 'docs', 'target.md'), target);
  return { root, document: join(root, 'README.md') };
}

test('resolves relative links and GitHub duplicate heading anchors', (t) => {
  const { root, document } = fixture(t, '[First](docs/target.md#api-contract) [Second](docs/target.md#api-contract-1)',
    '# API `Contract`\n\n## API Contract\n');
  assert.deepEqual(validateDocumentationLinks(root, [document]), []);
});

test('reports a removed document and a renamed heading independently', (t) => {
  const { root, document } = fixture(t, '[Missing](docs/missing.md) [Renamed](docs/target.md#old-heading)');
  const failures = validateDocumentationLinks(root, [document]);
  assert.equal(failures.length, 2);
  assert.match(failures[0], /docs\/missing.md/);
  assert.match(failures[1], /heading #old-heading does not exist/);
});

test('ignores remote links and fenced examples but checks real HTML assets', (t) => {
  const { root, document } = fixture(t, '[Web](https://example.com/no-network)\n```md\n[Example](missing.md)\n```\n<img src="missing.png">');
  const failures = validateDocumentationLinks(root, [document]);
  assert.equal(failures.length, 1);
  assert.match(failures[0], /missing.png/);
});

test('checks encoded file paths and same-document anchors', (t) => {
  const { root, document } = fixture(t, '# Local Section\n[Here](#local-section) [Space](docs/file%20name.md#target)');
  writeFileSync(join(root, 'docs', 'file name.md'), '# Target\n');
  assert.deepEqual(validateDocumentationLinks(root, [document]), []);
});

test('rejects links escaping the release tree and directory targets', (t) => {
  const { root, document } = fixture(t, '[Outside](../outside.md) [Directory](docs)');
  const failures = validateDocumentationLinks(root, [document]);
  assert.equal(failures.length, 2);
  assert.match(failures[0], /escapes the documentation root/);
  assert.match(failures[1], /target is not a file/);
});
