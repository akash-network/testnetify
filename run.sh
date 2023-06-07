#!/usr/bin/env bash

set -ex

if [[ "$OSTYPE" == "darwin"* ]]; then
    sedcmd=gsed
else
    # shellcheck disable=SC2209
    sedcmd=sed
fi

AKASH_MONIKER=node-tmp1

CHAIN_METADATA=$(curl -s https://raw.githubusercontent.com/akash-network/net/master/mainnet/meta.json)

function content_size() {
    size_in_bytes=$(wget "$1" --spider --server-response -O - 2>&1 | $sedcmd -ne '/Content-Length/{s/.*: //;p}')
    case "$size_in_bytes" in
        # Value cannot be started with `0`, and must be integer
    [1-9]*[0-9])
        echo "$size_in_bytes"
        ;;
    esac
}

rm -rf "$AKASH_HOME/config"
rm -rf "$AKASH_HOME/data"

${AKASH} init "$AKASH_MONIKER"
rm "$AKASH_HOME/config/genesis.json"

GENESIS_URL="$(echo "$CHAIN_METADATA" | jq -r '.genesis.genesis_url? // .genesis?')"
curl -sfL "$GENESIS_URL" > "$AKASH_HOME/config/genesis.json"

pv_args="-petrafb -i 5"
sz=$(content_size "$SNAPSHOT_URL")
if [[ -n $sz ]]; then
    pv_args+=" -s $sz"
fi

# shellcheck disable=SC2086
(wget -nv -O - "$SNAPSHOT_URL" | pv $pv_args | eval "lz4 -d | tar xf - -C "$AKASH_HOME"") 2>&1 | stdbuf -o0 tr '\r' '\n'

# STATE-SYNC
#export AKASH_NODE="$(echo "$CHAIN_METADATA" | jq -r .apis.rpc[0].address)"
#export AKASH_CHAIN_ID=$(curl -Ls "$AKASH_NODE"/status | jq -r '.result.node_info.network')
#export AKASH_MINIMUM_GAS_PRICES="0.025uakt"
#export POLKACHU_PEERS="d1e47b071859497089c944dc082e920403484c1a@65.108.128.201:12856"
#export MAINNET_PEERS="$(echo "$CHAIN_METADATA" | jq -r '.peers.persistent_peers | map(.id+"@"+.address) | join(",")')"
#export AKASH_P2P_PERSISTENT_PEERS="$POLKACHU_PEERS,$MAINNET_PEERS"
#export AKASH_STATESYNC_ENABLE=true
##export AKASH_STATESYNC_RPC_SERVERS=https://rpc.akashnet.net:443,https://rpc.akashnet.net:443
#export AKASH_STATESYNC_RPC_SERVERS=https://akash-rpc.polkachu.com:443,https://akash-rpc.polkachu.com:443
#IFS=',' read -ra rpc_servers <<< "$AKASH_STATESYNC_RPC_SERVERS"
#STATESYNC_TRUSTED_NODE=${rpc_servers[0]}
#LATEST_HEIGHT=$(curl -Ls "$STATESYNC_TRUSTED_NODE/block" | jq -r .result.block.header.height)
#BLOCK_HEIGHT=$((LATEST_HEIGHT - 2000))
##BLOCK_HEIGHT=$((LATEST_HEIGHT - 500))
#TRUST_HASH=$(curl -Ls "$STATESYNC_TRUSTED_NODE/block?height=$BLOCK_HEIGHT" | jq -r .result.block_id.hash)
#
#export AKASH_STATESYNC_TRUST_HEIGHT=$BLOCK_HEIGHT
#export AKASH_STATESYNC_TRUST_HASH=$TRUST_HASH
#
#HALT_BLOCK_HEIGHT=$((LATEST_HEIGHT+5))
#echo "Halt block height: $HALT_BLOCK_HEIGHT"
#
#${AKASH} start --halt-height $HALT_BLOCK_HEIGHT |& grep -iv p2p

${AKASH} export --home="${AKASH_HOME}" > "${GENESIS_ORIG}"
