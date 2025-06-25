# Fragment Protocol

Research infrastructure for fragment-based NFT ownership primitives.

## Overview

Fragment Protocol introduces programmable NFT ownership through fragment-based architecture. Instead of single-token ownership, NFTs are composed of 4 collectible fragments that users must acquire, complete, and transform through systematic workflows.

## Core Mechanics

- **Fragment Collection**: Random minting of 1-4 fragments per NFT
- **Set Completion**: Acquire all 4 fragments through minting or trading
- **Burn-to-Fuse**: Destroy complete sets to unlock transformation eligibility
- **Fusion Creation**: Transform burned sets into unique fusion NFTs

## Technical Architecture

- Multi-contract system with pluggable randomness
- Comprehensive validation and error handling
- ERC721-compliant with specialized metadata
- Professional testing and deployment infrastructure

## Development

### Install dependencies
```bash
forge install
```

### Run tests
```bash
forge test
```

### Build contracts
```bash
forge build
```

## Research Context

This implementation serves as technical infrastructure for investigating fragment-based ownership UI requirements and builder adoption patterns. The protocol's novel mechanics create unprecedented interface complexity requiring systematic research for ecosystem adoption.

## License

MIT License - see [LICENSE](LICENSE) file for details.
