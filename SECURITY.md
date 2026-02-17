# Security Policy

## Table of Contents

- [Supported Versions](#supported-versions)
- [Reporting a Vulnerability](#reporting-a-vulnerability)
- [Response Timeline](#response-timeline)
- [DID/SSI-Specific Security Notes](#didssi-specific-security-notes)
- [Audit Status](#audit-status)
- [Security Resources](#security-resources)

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.x     | Yes       |
| < 1.0   | No        |

## Reporting a Vulnerability

If you discover a security vulnerability, please report it responsibly:

1. **Do NOT open a public issue**
2. Email: mgcdreamer@gmail.com
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Affected contract(s) and function(s)
   - Potential impact assessment
   - Suggested fix (if any)

## Response Timeline

| Action | Timeframe |
|--------|-----------|
| Acknowledgement | 48 hours |
| Initial assessment | 7 days |
| Fix development | Depends on severity |
| Public disclosure | After fix is deployed |

## DID/SSI-Specific Security Notes

This project stores DID documents fully on-chain, which introduces unique considerations:

- **On-chain identity data**: All verification methods, services, and controller relationships are publicly visible on the blockchain. Do not store sensitive personal information in DID documents.
- **Controller delegation**: The controller system allows delegated management of DIDs. Verify controller permissions carefully before granting access.
- **Verification method lifecycle**: Deactivated or expired verification methods must not be treated as valid for authentication or assertion purposes.
- **Hash-based storage**: DID identifiers are derived from `keccak256(methods, random, tx.origin, block.prevrandao)`. While collision-resistant, the use of `block.prevrandao` means DID IDs are not fully unpredictable to miners/validators.
- **Immutable architecture**: Contracts are not upgradeable. Security fixes require redeployment and DID migration.

## Audit Status

- **Professional audit**: Not yet performed
- **Static analysis**: [Slither](https://github.com/crytic/slither) runs in CI via GitHub Actions
- **Test coverage**: >90% enforced in CI (see [test-coverage-history](docs/metrics/test-coverage-history.md))
- **Threat model**: See [docs/analysis/threat-model.md](docs/analysis/threat-model.md)

## Security Resources

- [CONTRIBUTING.md](CONTRIBUTING.md) — Development guidelines
- [docs/analysis/threat-model.md](docs/analysis/threat-model.md) — Threat model analysis
- [W3C DID Core v1.0](https://www.w3.org/TR/did-core/) — Specification compliance reference
