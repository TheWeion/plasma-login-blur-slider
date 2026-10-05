#!/usr/bin/env node
// SPDX-FileCopyrightText: 2026 Terry Fallows <terry@weion.dev>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// release-preview.mjs [<from>] [<to>]
//
// Says what the release workflow would do with the commits in <from>..<to>
// (default: everything since the last release tag, up to HEAD): whether they
// cause a release, which version it would be, and what the release notes
// would say. It runs the same two semantic-release plugins with the same
// configuration (.releaserc.json), so it also fails if that configuration or
// its dependencies stop working, before anything is merged.
//
// Nothing is tagged, pushed or published. Prints Markdown.

import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { analyzeCommits } from '@semantic-release/commit-analyzer';
import { generateNotes } from '@semantic-release/release-notes-generator';

const git = (...args) => execFileSync('git', args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim();

const config = JSON.parse(readFileSync(new URL('../.releaserc.json', import.meta.url), 'utf8'));
const optionsOf = name => {
    const entry = config.plugins.find(plugin => Array.isArray(plugin) && plugin[0] === name);
    return entry ? entry[1] : {};
};

let lastTag = '';
try {
    lastTag = git('describe', '--tags', '--abbrev=0', '--match', 'v[0-9]*');
} catch {
    // no release yet
}

const [from = lastTag, to = 'HEAD'] = process.argv.slice(2);
const range = from ? `${from}..${to}` : to;

const commits = git('log', '--format=%H%x1f%B%x1e', range)
    .split('\x1e')
    .map(entry => entry.trim())
    .filter(Boolean)
    .map(entry => {
        const [hash, message] = entry.split('\x1f');
        return { hash, message: message.trim(), subject: message.trim().split('\n')[0] };
    });

const quiet = { log() {}, info() {}, warn() {}, success() {}, error: console.error };
const base = { cwd: process.cwd(), env: process.env, logger: quiet, commits };

const type = await analyzeCommits(optionsOf('@semantic-release/commit-analyzer'), base);

const bump = (version, kind) => {
    const [major, minor, patch] = version.split('.').map(Number);
    if (kind === 'major') {
        return `${major + 1}.0.0`;
    }
    return kind === 'minor' ? `${major}.${minor + 1}.0` : `${major}.${minor}.${patch + 1}`;
};

console.log('### Release preview');
console.log();
console.log(`${commits.length} commit${commits.length === 1 ? '' : 's'} in \`${range}\`.`);
console.log();

if (!type) {
    console.log('**No release.** None of these commits is a `fix`, a `feat` or a breaking change.');
    process.exit(0);
}

// The first release is 1.0.0 whatever the commits say.
const version = lastTag ? bump(lastTag.replace(/^v/, ''), type) : '1.0.0';
console.log(`**A ${lastTag ? type : 'first'} release: ${lastTag ? `${lastTag} → ` : ''}v${version}**`);
console.log();

let repositoryUrl = 'https://github.com/owner/repository';
if (process.env.GITHUB_SERVER_URL && process.env.GITHUB_REPOSITORY) {
    repositoryUrl = `${process.env.GITHUB_SERVER_URL}/${process.env.GITHUB_REPOSITORY}`;
}

const notes = await generateNotes(optionsOf('@semantic-release/release-notes-generator'), {
    ...base,
    options: { repositoryUrl },
    lastRelease: lastTag ? { gitTag: lastTag, gitHead: git('rev-parse', lastTag), version: lastTag.replace(/^v/, '') } : {},
    nextRelease: { gitTag: `v${version}`, gitHead: git('rev-parse', to), version },
});

console.log('The release notes would read:');
console.log();
console.log(notes.trim());
