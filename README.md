# dcasset

This repository contains the latest revision of the DCAsset contract system. The source code of the live contracts is also verified on [http://etherscan.io](http://etherscan.io). Refer to [http://decentralizedcapital.com](http://decentralizedcapital.com) for the contract addresses (token addresses are available via [this link](https://www.decentralizedcapital.com/#/tokens)).

## High-level overview

The primary aim of DCAsset is to establish a token on the blockchain such that risk can be mitigated across a distributed system of trust. Each contract in the network has administrative controls which require two signatures from a set of trusted keys which can be set by the contract owner prior to the "lock" event. The backend is upgradeable, and the frontend fully adheres to the [Ethereum Token standard](https://github.com/ethereum/EIPs/issues/20). Minted tokens appear in a multisig "HotWallet" and transfers from this contract must be approved ahead of time by the "Oversight" contract. In addition, the Oversight contract can approve addresses which are authorized to shut down transactions in the event of a breach. Refer to source-code documentation for detailed functional description.

## Authors

Raymond Pulver [@raypulver](https://github.com/raypulver)

Peter Reitsma [@preitsma](https://github.com/preitsma)

## License

MIT
