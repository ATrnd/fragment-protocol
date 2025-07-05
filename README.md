# Fragment Protocol

A novel blockchain ownership primitive that transforms traditional NFT mechanics through fragment-based architecture. NFTs are composed of exactly **4 collectible fragments** that users must acquire, complete, and transform through a systematic burn-to-fuse workflow.

## Overview

Fragment Protocol introduces **fragment-based multi-ownership** where complete NFTs require collecting 4 separate fragment tokens. This creates a collection → completion → transformation lifecycle with unprecedented interface complexity requiring specialized UI patterns.

**Core Workflow**: Mint random fragments → Collect complete sets → Burn fragments → Fuse into transformation NFTs

## Architecture

**Multi-Contract System**:
- **FragmentEngine**: Fragment minting, ownership verification, and burning operations
- **FragmentFusion**: Burn-to-fuse transformation with access control and fusion NFT creation
- **FragmentRandomness**: Development-grade randomness for fair fragment distribution

**Key Features**:
- Fragment sets with dynamic completion states (0/4, 1/4, 2/4, 3/4, 4/4)
- Irreversible burn operations unlocking transformation potential
- Cross-contract workflow coordination for multi-step processes
- Comprehensive testing suite with 80+ validation scenarios

## UI Research Context

Fragment Protocol serves as the **technical foundation** for researching interface requirements for experimental ownership primitives.

**Research Focus**: What UI patterns are essential for fragment collection progress, completion validation, and transformation workflows?

**Grant Objective**: Produce prototype interface components and builder experimentation guidelines for novel NFT (Fragment-Based Multi-Ownership) mechanics.

## Quick Start

```bash
# Clone repository
git clone https://github.com/ATrnd/fragment-protocol
cd fragment-protocol

# Build and test contracts
forge build
forge test

# View test coverage
forge coverage
```

## Documentation

**[Fragment Protocol Architecture](https://github.com/ATrnd/fragment-protocol/blob/main/docs/ARCHITECTURE.md)**
Technical architecture overview with contract specifications, UI complexity demonstration, and integration requirements.

**[UI Research Documentation](https://github.com/ATrnd/fragment-protocol/blob/main/docs/RESEARCH-CONTEXT.md)**
Comprehensive research context including methodology, expected outcomes, and ecosystem value proposition for ETH Foundation grant application.

## Key Interfaces

- **IFragmentEngine**: Core fragment operations (minting, burning, verification)
- **IFragmentFusion**: Burn-to-fuse transformation and eligibility tracking
- **IRandomnessProvider**: Pluggable randomness architecture

## Research Applications

This protocol enables investigation of:
- Multi-state collection interface patterns
- High-stakes confirmation workflows for irreversible operations
- Cross-contract coordination UI requirements
- Transformation visualization for burn-to-fuse mechanics

## License

MIT License - See [LICENSE](https://github.com/ATrnd/fragment-protocol/blob/main/LICENSE) for details.
