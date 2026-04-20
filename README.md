# Bitcoin Commons Governance System

## Status

**Phase 1 (Infrastructure Building)**: System not yet activated or tested in production.

Contains the Bitcoin Commons governance and implementation ecosystem, managed by the BTCDecoded GitHub organization. Implements a constitutional governance model that makes Bitcoin governance 6x harder to capture than Bitcoin Core's current model.

## Important Disclaimers

- **Infrastructure Complete**: All core components implemented
- **Not Yet Activated**: Governance rules are not enforced
- **Test Keys Only**: No real cryptographic enforcement
- **Experimental Software**: Use at your own risk

## 📁 Project Structure

For a detailed overview of the project directory structure, see [DIRECTORY_STRUCTURE.md](./DIRECTORY_STRUCTURE.md).


**📚 Documentation**: See [Documentation Index](./docs/README.md) for complete navigation of all documentation.

## 🏗️ Architecture Overview

### Constitutional Governance Model

Bitcoin Commons implements a 5-tier constitutional governance system:

1. **Tier 1: Routine Maintenance** (3-of-5, 7 days)
   - Bug fixes, documentation, performance optimizations
   - Non-consensus changes only

2. **Tier 2: Feature Changes** (4-of-5, 30 days)
   - New RPC methods, P2P changes, wallet features
   - Must include technical specification

3. **Tier 3: Consensus-Adjacent** (5-of-5, 90 days)
   - Changes affecting consensus validation code

4. **Tier 4: Emergency Actions** (4-of-5, 0 days)
   - Critical security patches, network-threatening bugs
   - Post-mortem required

5. **Tier 5: Governance Changes** (5-of-5, 180 days)
   - Changes to governance rules themselves

### Core Components

- `blvm-commons/` - Governance enforcement system
- `blvm-sdk/` - Cryptographic primitives and CLI tools
- `governance/` - Governance configuration and documentation

## Quick Start

### Prerequisites
- Rust 1.70+
- SQLite3
- Git

### Setup Development Environment

```bash
# Clone repositories (BTCDecoded is the GitHub organization)
git clone https://github.com/BTCDecoded/blvm-commons.git
cd blvm-commons

# Set up blvm-commons
cargo build
cargo test

# Set up blvm-sdk
cd ../blvm-sdk
cargo build
cargo test
```

### Running Tests

```bash
# Run all tests
cargo test

# Run specific test suites
cargo test --test governance_fork_test
cargo test --test github_integration_test
cargo test --test simple_test
```

## Documentation

### Core Documentation
- [Governance Process](governance/GOVERNANCE.md) - How governance works
- [System Design](governance/DESIGN.md) - Architecture and design decisions
- [Developer Guide](blvm-sdk/README.md) - SDK usage and examples

### Development Guides
- [Maintainer Guide](governance/MAINTAINER_GUIDE.md) - For maintainers
- [Deployment Guide](blvm-commons/DEPLOYMENT.md) - Deployment instructions

## Implementation Status

### Completed Features
- Governance Fork Capability: Configuration export, adoption tracking, multiple ruleset support
- GitHub Status Check Integration: Status check posting, merge blocking, webhook integration
- Comprehensive Testing: Governance fork tests, GitHub integration tests, governance workflows
- Documentation: Organization-level disclaimers, repository-level warnings

## Contributing

### For Developers
1. Read the documentation to understand the system architecture
2. Set up development environment following setup guides
3. Run tests to ensure all tests pass
4. Submit pull requests and improvements
5. Report issues to help identify and fix bugs

### For Organizations
1. Monitor development progress and updates
2. Provide feedback and share requirements and use cases
3. Test in development environment
4. Wait for Phase 2 before deploying in production

### For Researchers
1. Study the architecture to understand the governance model
2. Analyze the code and review implementation and design
3. Provide feedback and share insights and recommendations
4. Collaborate with the development team

## Support

### Development Team
- GitHub Issues: Report bugs and feature requests
- GitHub Discussions: Ask questions and provide feedback
- Pull Requests: Contribute code and improvements

### Security
- Security Issues: Report privately to maintainers
- Vulnerabilities: Follow responsible disclosure
- Audit Results: Published when available

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Warning

Experimental software in active development. Use at your own risk. Do not deploy in production until Phase 2 activation.




