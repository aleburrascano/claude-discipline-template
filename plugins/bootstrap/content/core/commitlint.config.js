module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'type-enum': [
      2,
      'always',
      ['feat', 'fix', 'refactor', 'chore', 'docs', 'test', 'perf', 'style', 'ci', 'revert'],
    ],
    // scope-enum is intentionally NOT enforced strictly here.
    // Add your project's scopes when you know them:
    //   - feature/slice names get added when /feature-spec creates them
    //   - layer names (domain, application, adapters) if you adopt hexagonal
    //   - cross-cutting (docs, adr, spec, claude-md, rules, skills, agents, hooks, deps, tooling, ci, release)
    'scope-empty': [1, 'never'], // warning, not error — adjust to [2,'never'] to enforce
    'subject-case': [2, 'always', 'lower-case'],
    'subject-empty': [2, 'never'],
    'subject-full-stop': [2, 'never', '.'],
    'header-max-length': [2, 'always', 72],
    'body-max-line-length': [1, 'always', 100],
    'body-leading-blank': [2, 'always'],
    'footer-leading-blank': [2, 'always'],
  },
};
