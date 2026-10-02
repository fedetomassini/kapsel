// Offline documentation checks shared by source and staged release packages.
import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs';
import { dirname, extname, isAbsolute, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

function withoutCode(source) {
  return source.replace(/^(`{3,}|~{3,})[^\n]*\n[\s\S]*?^\1\s*$/gm, '');
}

function markdownAnchors(source) {
  const anchors = new Set();
  const counts = new Map();
  for (const match of withoutCode(source).matchAll(/^ {0,3}#{1,6}\s+(.+?)\s*#*\s*$/gm)) {
    const heading = match[1].replace(/\[([^\]]+)\]\([^)]*\)/g, '$1');
    const slug = heading.toLowerCase().replace(/<[^>]*>/g, '')
      .replace(/[^\p{L}\p{N}\p{M}_\-\s]/gu, '').replace(/\s/g, '-');
    const count = counts.get(slug) ?? 0;
    anchors.add(count ? `${slug}-${count}` : slug);
    counts.set(slug, count + 1);
  }
  return anchors;
}

export function validateDocumentationLinks(root, documents) {
  const failures = [];
  const anchorCache = new Map();
  for (const document of documents) {
    const source = withoutCode(readFileSync(document, 'utf8'));
    // Repository docs use inline links; HTML src/href covers the README screenshot.
    const targets = [
      ...Array.from(source.matchAll(/!?\[[^\]\n]*\]\(\s*(<[^>]+>|[^\s)]+)(?:\s+"[^"]*")?\s*\)/g), (m) => m[1].replace(/^<|>$/g, '')),
      ...Array.from(source.matchAll(/\b(?:src|href)="([^"]+)"/g), (m) => m[1]),
    ];
    for (const target of targets) {
      if (/^(?:[a-z][a-z\d+.-]*:|\/\/)/i.test(target)) continue;
      try {
        const hash = target.indexOf('#');
        const path = decodeURIComponent((hash < 0 ? target : target.slice(0, hash)).split('?')[0]);
        const anchor = hash < 0 ? '' : decodeURIComponent(target.slice(hash + 1));
        const destination = path ? resolve(dirname(document), path) : document;
        const inside = relative(root, destination);
        if (inside === '..' || inside.startsWith(`..${sep}`) || isAbsolute(inside)) {
          throw new Error('target escapes the documentation root');
        }
        if (!statSync(destination).isFile()) throw new Error('target is not a file');
        if (anchor && extname(destination).toLowerCase() === '.md') {
          if (!anchorCache.has(destination)) {
            anchorCache.set(destination, markdownAnchors(readFileSync(destination, 'utf8')));
          }
          if (!anchorCache.get(destination).has(anchor)) throw new Error(`heading #${anchor} does not exist`);
        }
      } catch (error) {
        failures.push(`${relative(root, document)}: ${target}: ${error.message}`);
      }
    }
  }
  return failures;
}

function main() {
  const args = process.argv.slice(2);
  if (args.length && (args.length !== 2 || args[0] !== '--root')) {
    throw new Error('Usage: node scripts/Validate-Documentation.mjs [--root <directory>]');
  }
  const root = resolve(args[1] ?? fileURLToPath(new URL('../', import.meta.url)));
  // Honor exact root-file ignore rules; staged releases do not need a Git checkout.
  const ignorePath = resolve(root, '.gitignore');
  const ignoredRootFiles = new Set(existsSync(ignorePath)
    ? readFileSync(ignorePath, 'utf8').split(/\r?\n/).map((line) => line.trim())
      .filter((line) => /^\/[^/*?]+$/.test(line)).map((line) => line.slice(1))
    : []);
  const documents = [];
  function visit(directory) {
    for (const entry of readdirSync(directory, { withFileTypes: true })) {
      if (['.git', 'dist', 'build', 'node_modules', 'TestResults'].includes(entry.name)) continue;
      const path = resolve(directory, entry.name);
      if (ignoredRootFiles.has(relative(root, path))) continue;
      if (entry.isDirectory()) visit(path);
      else if (entry.isFile() && extname(path).toLowerCase() === '.md') documents.push(path);
    }
  }
  visit(root);
  const failures = validateDocumentationLinks(root, documents);
  for (const required of ['README.md', 'CONTRIBUTING.md', 'CHANGELOG.md', 'CATALOG.md',
    'SUPPORT.md', 'CODE_OF_CONDUCT.md', 'LICENSE', 'docs/README.md',
    'assets/fonts/LICENSE-Font-Awesome.txt']) {
    try {
      if (!statSync(resolve(root, required)).isFile()) throw new Error('not a file');
    } catch {
      failures.push(`Required project document missing: ${required}`);
    }
  }
  const pkg = JSON.parse(readFileSync(resolve(root, 'package.json'), 'utf8'));
  const metadata = readFileSync(resolve(root, 'src/modules/Shared/ProductMetadata.psm1'), 'utf8');
  const appVersion = metadata.match(/\bVersion\s*=\s*'([^']+)'/)?.[1];
  if (!/^\d+\.\d+\.\d+$/.test(pkg.version) || pkg.version !== appVersion) {
    failures.push(`Version mismatch: package.json=${pkg.version}, ProductMetadata=${appVersion}`);
  }
  const nodeMajor = readFileSync(resolve(root, '.node-version'), 'utf8').trim();
  if (!/^\d+$/.test(nodeMajor) || pkg.engines?.node !== `>=${nodeMajor}`) {
    failures.push('The Node major in .node-version must match the minimum in package.json engines.node.');
  }
  if (pkg.license !== 'MIT') failures.push('package.json must declare the root MIT license.');
  if (failures.length) throw new Error(failures.join('\n'));
  console.log(`Documentation OK: ${documents.length} Markdown files; product version ${pkg.version}; Node ${nodeMajor}.`);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    main();
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
