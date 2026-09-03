const proc = require('child_process');

const run = cmd => {
    proc.execSync(cmd, { stdio: 'inherit' });
};

const read = cmd => proc.execSync(cmd, { encoding: 'utf8' }).trim();

run('npm run prepare-docs');
run('git add -f docs');  // --force needed because generated docs files are gitignored

// Check if there are staged changes to commit
const stagedChanges = read('git diff --cached --name-only');
if (!stagedChanges) {
    console.log('No changes to commit, skipping commit step');
    process.exit(0);
}

run('git commit -m "Update docs"');