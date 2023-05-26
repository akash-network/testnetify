#!/bin/bash

set -x
set -e

mkdir -p $HOME/.local/bin
export PATH="$PATH:$HOME/.local/bin"
echo $PATH

commands=("curl" "git" "unzip" "jq" "make" "lz4" "hub")

for cmd in "${commands[@]}"; do
  if ! command -v $cmd &> /dev/null; then
    echo "$cmd could not be found"
    exit 1
  fi
done

# AKASH_VER should come from GH Action workflow env
##export AKASH_VER=v0.22.0
if [[ -z "${AKASH_VER}" ]]; then
  echo "AKASH_VER is not set or is empty"
  exit 1
fi

echo "AKASH_VER=$AKASH_VER"

##curl -sfL https://direnv.net/install.sh | bash
curl -L -o $HOME/.local/bin/direnv https://github.com/direnv/direnv/releases/download/v2.32.3/direnv.linux-amd64
chmod +x $HOME/.local/bin/direnv

curl -L -O -J https://github.com/akash-network/node/releases/download/${AKASH_VER}/akash_linux_amd64.zip
unzip akash_linux_amd64.zip
install akash $HOME/.local/bin/
rm -rf -- akash akash_linux_amd64.zip

export AKASH_HOME=$HOME/.akash
AKASH_MONIKER=node-tmp1

CHAIN_METADATA=$(curl -s https://raw.githubusercontent.com/akash-network/net/master/mainnet/meta.json)

export AKASH_NODE="$(echo $CHAIN_METADATA | jq -r .apis.rpc[0].address)"
export AKASH_CHAIN_ID=$(curl -Ls AKASH_NODE/status | jq -r '.result.node_info.network')
export AKASH_MINIMUM_GAS_PRICES="0.025uakt"

# https://polkachu.com/seeds/akash
#export AKASH_P2P_SEEDS="ade4d8bc8cbe014af6ebdf3cb7b1e9ad36f412c0@seeds.polkachu.com:12856"

# https://polkachu.com/live_peers/akash
export POLKACHU_PEERS="d1e47b071859497089c944dc082e920403484c1a@65.108.128.201:12856"

export MAINNET_PEERS="$(echo $CHAIN_METADATA | jq -r '.peers.persistent_peers | map(.id+"@"+.address) | join(",")')"

export AKASH_P2P_PERSISTENT_PEERS="$POLKACHU_PEERS,$MAINNET_PEERS"

rm -rf "$AKASH_HOME"
# node id
# $ cat $HOME/.akash/config/node_key.json | jq -r '.priv_key.value' | openssl base64 -A -d | tail -c32 | sha256sum | awk '{print $1}' | head -c40 ; echo
# b2127168256b4f34dc1ab20939e5f7fd1d8db466
mkdir -p "$AKASH_HOME/config"
echo -n '{"priv_key":{"type":"tendermint/PrivKeyEd25519","value":"qu+62srbXdoWaYh6wUecg4NoctFUKX7QvUdukLGEoHMgIl95POmQL/wt9egmaM2CDCxioTtOs3DpqjMJ95lYQg=="}}' > "$AKASH_HOME/config/node_key.json"

mkdir -p "$AKASH_HOME/data"
echo -n '{"height":"0","round":0,"step":0}' > "$AKASH_HOME/data/priv_validator_state.json"
akash init "$AKASH_MONIKER"
ls -la $HOME/.akash/config/
rm "$AKASH_HOME/config/genesis.json"

GENESIS_URL="$(echo $CHAIN_METADATA | jq -r '.genesis.genesis_url? // .genesis?')"
curl -sfL "$GENESIS_URL" > "$AKASH_HOME/config/genesis.json"

ls -la $HOME/.akash/config/

## STATE-SYNC

export "AKASH_STATESYNC_ENABLE=true"
export "AKASH_STATESYNC_RPC_SERVERS=https://rpc.akashnet.net:443,https://rpc.akashnet.net:443"
IFS=',' read -ra rpc_servers <<< "$AKASH_STATESYNC_RPC_SERVERS"
STATESYNC_TRUSTED_NODE=${STATESYNC_TRUSTED_NODE:-${rpc_servers[0]}}
LATEST_HEIGHT=$(curl -Ls $STATESYNC_TRUSTED_NODE/block | jq -r .result.block.header.height)
#BLOCK_HEIGHT=$((LATEST_HEIGHT - 2000))
BLOCK_HEIGHT=$((LATEST_HEIGHT - 500))
TRUST_HASH=$(curl -Ls "$STATESYNC_TRUSTED_NODE/block?height=$BLOCK_HEIGHT" | jq -r .result.block_id.hash)
export "AKASH_STATESYNC_TRUST_HEIGHT=${STATESYNC_TRUST_HEIGHT:-$BLOCK_HEIGHT}"
export "AKASH_STATESYNC_TRUST_HASH=${STATESYNC_TRUST_HASH:-$TRUST_HASH}"
export "AKASH_STATESYNC_TRUST_PERIOD=${STATESYNC_TRUST_PERIOD:-168h0m0s}"

HALT_BLOCK_HEIGHT=$((LATEST_HEIGHT+5))
echo "Halt block height: $HALT_BLOCK_HEIGHT"

#set +x
#nohup akash start &
#nohup akash start < /dev/null & > /dev/null &
#nohup akash start |& grep -iv p2p > nohup.out &
#nohup akash start |& grep -iv p2p &
#export AKASH_PID=$!
#set -x

akash start --halt-height $HALT_BLOCK_HEIGHT |& grep -iv p2p

export RPC_NODE=127.0.0.1:26657

#while ! $(curl -s $RPC_NODE/status | jq -r '.result.sync_info.catching_up' | grep -q false); do
#  echo "=== Catching up with the tip of the chain ... ==="
#  curl -s $RPC_NODE/status | jq -r '.result'
#  echo "================================================="
#  ls -la
#  du -sm .
#  sleep 60s
#done

ls -la
du -sm .
#curl -s $RPC_NODE/status | jq -r '.result'
#LATEST_BLOCK_HEIGHT=$(curl -s $AKASH_NODE/status | jq -r '.result.sync_info.latest_block_height')
#echo "Latest block height: $LATEST_BLOCK_HEIGHT"

#kill $AKASH_PID

#cd testnetify
##direnv hook bash >> $HOME/.bashrc
##. $HOME/.bashrc
#direnv allow .
eval "$(direnv export bash)"
export GENESIS_ORIG=genesis.json
ls -la $HOME/.akash/config/
ls -la
akash export --home=$HOME/.akash > ${GENESIS_ORIG}
ls -la
make archive
ls -la
mv genesis.json.tar.lz4 ../latest-${AKASH_VER}.json.tar.lz4
ls -la
## ./latest-${AKASH_VER}.json.tar.lz4 - gets published as release by GH Action
##curl -T ./latest-${AKASH_VER}.json.tar.lz4 https://transfer.sh; echo
