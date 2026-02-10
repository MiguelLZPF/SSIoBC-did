## Description

<!-- What does this PR do? Why is this change needed? -->

Fixes #<!-- issue number -->

## Type of Change

- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Optimization (gas, bytecode size, or performance improvement)
- [ ] Refactor (no functional change)
- [ ] Breaking change (fix or feature that would cause existing functionality to change)
- [ ] Documentation / CI update

## Changes

<!-- Briefly list the key changes made. For contract changes, note affected functions. -->

-

## Testing

<!-- How were these changes verified? List any new or modified tests. -->

- [ ] New unit tests added
- [ ] Existing tests updated
- [ ] Fuzz tests cover edge cases
- [ ] Tested locally with `forge test`

## Gas Impact

<!-- For contract changes: did gas costs change meaningfully? Check the gas-diff PR comment. -->

- [ ] No significant gas impact
- [ ] Gas impact reviewed (see gas-diff comment below)

## Checklist

- [ ] Code follows project style (`forge fmt --check` passes)
- [ ] Linter passes (`forge lint`)
- [ ] All tests pass (`forge test`)
- [ ] Coverage remains above 90%
- [ ] Contract sizes remain under 24KB (EIP-170)
- [ ] NatSpec added for new public/external functions
- [ ] No new `require(string)` — custom errors only
