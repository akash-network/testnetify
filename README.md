# Testnetify genesis

## Prerequisites

- `direnv` installed and hooked to shell
- `direnv allow` executed in the project dir

**NOTE** if planning to release from local machine, make sure `gh` tool is installed

## Resource requirements
Testnetify process is rather resource demanding and thus has to run on self-hosted running.
If `testnetify` command fails during GH actions,
most likely due to OOM. So the first cure is to increase amount of available memory
Currently working hw config is:
- 2vCPU
- 32GB RAM

## Adding new network version
1. Find new upgrade name. For this example we'll use `v0.28.0`
2. copy last network config-vX.Y.Z.json (`v0.26.0.json` in this example) to with a new network name
   ```shell
   cp config-v0.26.0.json config-v0.28.0.json
3. check if carried over validator's configuration fits network needs (in 99% it does)
4. run testnetify `make run`
5. if previous step successful commit and push new config

## Manual upload

```shell
make run
make release
```
