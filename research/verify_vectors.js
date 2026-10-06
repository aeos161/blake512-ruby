// Research-only verifier. Requires an extracted @noble/hashes 1.8.0 package.
const assert = require('node:assert/strict');
const cp = require('node:child_process');
const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const packageRoot = process.argv[2] && path.resolve(process.argv[2]);
if (!packageRoot) throw new Error('Pass the extracted noble-hashes package directory');
const fixture = require(path.join(root, 'spec/fixtures/blake512_vectors.json'));
const sourceRoot = path.join(root, 'ext/aeos_blake512/upstream');
const sourceHashes = {
  'blake.h': '1a2011a191e48c23df9d21405c15faf22a8b00171b665e040066093c34114448',
  'blake512.c': 'b0830b8be2509786dc00468c68b7a13ccecfbde3fa31e3cde5d106fe2dfef10a',
  LICENSE: '5537d4d10b76b81b6e8dfd8b644480a4b1efa332fbb0cdb61126c5be781ef7b4',
  'README.md': '942d154e3ffd88cb2ae9473854984002826cb04f76c09a53a51081a1c879ff10',
};
function sha256(file) {
  return crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
}
for (const [name, expected] of Object.entries(sourceHashes)) {
  assert.equal(sha256(path.join(sourceRoot, name)), expected, `upstream ${name}`);
}
assert.equal(
  sha256(path.join(packageRoot, 'src/blake1.ts')),
  fixture.oracle.source_blake1_ts_sha256,
  'independent oracle source'
);
const { blake512 } = require(path.join(packageRoot, 'blake1.js'));
function inputBytes(input) {
  if (Object.hasOwnProperty.call(input, 'hex')) {
    assert.match(input.hex, /^(?:[0-9a-f]{2})*$/);
    return Buffer.from(input.hex, 'hex');
  }
  if (Object.hasOwnProperty.call(input, 'repeat_hex')) {
    assert.match(input.repeat_hex, /^[0-9a-f]{2}$/);
    return Buffer.alloc(input.length, parseInt(input.repeat_hex, 16));
  }
  if (Object.hasOwnProperty.call(input, 'sequence_mod_256')) {
    return Buffer.from(Array.from({ length: input.sequence_mod_256 }, (_, i) => i % 256));
  }
  throw new Error('Unrecognized input construction');
}
const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'blake512-verify-'));
try {
  const executable = path.join(temp, 'blake512-reference');
  cp.execFileSync('cc', ['-std=c99', '-O2', '-o', executable, path.join(sourceRoot, 'blake512.c')]);
  for (const vector of fixture.vectors) {
    assert.match(vector.expected_hex, /^[0-9a-f]{128}$/, vector.id);
    const bytes = inputBytes(vector.input);
    const independent = Buffer.from(blake512(bytes)).toString('hex');
    assert.equal(independent, vector.expected_hex, `independent: ${vector.id}`);
    const inputFile = path.join(temp, vector.id);
    fs.writeFileSync(inputFile, bytes);
    const reference = cp.execFileSync(executable, [inputFile], { encoding: 'utf8' }).trim();
    assert.equal(reference, `${vector.expected_hex} ${inputFile}`, `reference: ${vector.id}`);
  }
  console.log(`${fixture.vectors.length} literal vectors match noble-hashes and designer C`);
} finally {
  fs.rmSync(temp, { recursive: true, force: true });
}
