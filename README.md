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
