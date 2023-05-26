# Testnetify genesis

## Prerequisites

- `direnv` installed and hooked to shell
- `direnv allow` executed in the project dir

```sh
export GENESIS_ORIG=genesis.json
```
## Export current state into genesis.json

```sh
akash export --home=<akash home> > $(GENESIS_ORIG)
```

## Patch and archive

```sh
make archive
```

## Deploy result

Archived genesis is `latest-<upgrade>.json.tar.lz4`
For example `latest-v0.22.0.json.tar.lz4`

## CI: Github Actions

Exports the Akash AppState and publishes it under Releases page of the this repo.

## Workflow

- gh runner runs on akash (= cheap);
- uses state-sync against our RPC node `https://rpc.akashnet.net:443` (= fast sync under `7-30` minutes);
- akash halts at the last_height+5 via `--halt-height` arg (= graceful stop);
- preconfigures node ID `b2127168256b4f34dc1ab20939e5f7fd1d8db466` so we can add it as `AKASH_P2P_UNCONDITIONAL_PEER_IDS` to our RPC;
- exports the state (about `5` minutes);
- applies `make archive` (this repo);
- publishes it as the release - https://github.com/akash-network/testnetify/releases

## GH Runner

You must use a self-hosted GH runner for the GH action job to complete.

Reqs: 2 CPU, 16 GiB RAM, 20 GiB storage

- SDL https://github.com/ovrclk/akash-deployments/blob/main/testnetify-gh-runner.yaml
- Docs https://github.com/ovrclk/engineering/wiki/Akash-Deployments

## Next steps

If Github API allows, we can probably even automate the GH runner deployment & registration.
