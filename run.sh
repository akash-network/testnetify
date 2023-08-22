#!/usr/bin/env bash

set -e

AKASH_MONIKER=node-tmp1
AKASH_STATESYNC_ENABLE=false

CHAIN_METADATA=$(curl -s https://raw.githubusercontent.com/akash-network/net/master/mainnet/meta.json)

function content_size() {
    local size_in_bytes

    size_in_bytes=$(wget "$1" --spider --server-response -O - 2>&1 | grep "Content-Length" | awk '{print $2}' | tr -d '\n')
    err=$?
    case "$size_in_bytes" in
        # Value cannot be started with `0`, and must be integer
    [1-9]*[0-9])
        echo "$size_in_bytes"
        ;;
    esac

    return "$err"
}

function content_name() {
    name=$(wget "$1" --spider --server-response -O - 2>&1 | grep "Content-Disposition:" | tail -1 | awk -F"filename=" '{print $2}')
    # shellcheck disable=SC2181
    if [[ "$name" == "" ]]; then
        echo "$1"
    else
        echo "$name"
    fi
}

function content_type() {
    case "$1" in
        *.tar.cz*)
            tar_cmd="tar -xJ -"
            ;;
        *.tar.gz*)
            tar_cmd="tar xzf -"
            ;;
        *.tar.lz4*)
            tar_cmd="lz4 -d | tar xf -"
            ;;
        *.tar.zst*)
            tar_cmd="zstd -cd | tar xf -"
            ;;
        *)
            tar_cmd="tar xf -"
            ;;
    esac

    echo "$tar_cmd"
}

# shellcheck disable=SC2153
data_path=$AKASH_HOME/data

# shellcheck disable=SC2153
rm -rf "$AKASH_HOME/config"
rm -rf "$data_path"

${AKASH} init "$AKASH_MONIKER"
rm "$AKASH_HOME/config/genesis.json"

GENESIS_URL="$(echo "$CHAIN_METADATA" | jq -r '.genesis.genesis_url? // .genesis?')"
curl -sfL "$GENESIS_URL" > "$AKASH_HOME/config/genesis.json"

rm -rf "$data_path"

pushd "$(pwd)"

mkdir -p "$data_path"
cd "$data_path"

if [ ! "$SNAPSHOT_URL" ]; then
    SNAPSHOT_URL=$(wget https://polkachu.com/api/v1/chains/akash/snapshot -qO - 2>&1 | jq -r '.snapshot.url')
fi

if [ "$SNAPSHOT_URL" ]; then
    if [[ "${SNAPSHOT_URL}" =~ ^https?:\/\/.* ]]; then
        echo "Downloading snapshot to [$(pwd)] from $SNAPSHOT_URL..."

        # Detect content size via HTTP header `Content-Length`
        # Note that the server can refuse to return `Content-Length`, or the URL can be incorrect
        pv_args="-petrafb -i 5"
        sz=$(content_size "$SNAPSHOT_URL")
        # shellcheck disable=SC2181

        if [ $? -eq 0 ]; then
            if [[ -n $sz ]]; then
                pv_args+=" -s $sz"
            fi

            tar_cmd=$(content_type "$(content_name "$SNAPSHOT_URL")")

            # shellcheck disable=SC2086
            (wget -nv -O - "$SNAPSHOT_URL" | pv $pv_args | eval " $tar_cmd") 2>&1 | stdbuf -o0 tr '\r' '\n'
        else
            echo "unable to download snapshot"
            AKASH_STATESYNC_ENABLE=true
        fi
    else
        echo "Unpacking snapshot to [$(pwd)] from $SNAPSHOT_URL..."

        tar_cmd=$(content_type "$SNAPSHOT_URL")

        # shellcheck disable=SC2086
        (pv -petrafb -i 5 "$SNAPSHOT_URL" | eval "$tar_cmd") 2>&1 | stdbuf -o0 tr '\r' '\n'
    fi


    # if snapshot provides data dir then move all things up
    if [[ -d data ]]; then
        echo "snapshot has data dir. moving content..."
        mv data/* ./
        rm -rf data
    fi
else
    AKASH_STATESYNC_ENABLE=true
fi

popd

# STATE-SYNC
AKASH_NODE="$(echo "$CHAIN_METADATA" | jq -r .apis.rpc[0].address)"
AKASH_CHAIN_ID=$(curl -Ls "$AKASH_NODE"/status | jq -r '.result.node_info.network')
MAINNET_PEERS="$(echo "$CHAIN_METADATA" | jq -r '.peers.persistent_peers | map(.id+"@"+.address) | join(",")')"

export AKASH_NODE
export AKASH_CHAIN_ID
export AKASH_MINIMUM_GAS_PRICES="0.025uakt"
export POLKACHU_PEERS="d1e47b071859497089c944dc082e920403484c1a@65.108.128.201:12856"
export AKASH_P2P_PERSISTENT_PEERS="$POLKACHU_PEERS,$MAINNET_PEERS"
export AKASH_STATESYNC_ENABLE
export AKASH_STATESYNC_RPC_SERVERS=https://rpc.akashnet.net:443,https://rpc.akashnet.net:443
export AKASH_STATESYNC_RPC_SERVERS=https://akash-rpc.polkachu.com:443,https://akash-rpc.polkachu.com:443

if [[ "$AKASH_STATESYNC_ENABLE" == true ]]; then
    IFS=',' read -ra rpc_servers <<< "$AKASH_STATESYNC_RPC_SERVERS"

    STATESYNC_TRUSTED_NODE=${rpc_servers[0]}
    LATEST_HEIGHT=$(curl -Ls "$STATESYNC_TRUSTED_NODE/block" | jq -r .result.block.header.height)
    BLOCK_HEIGHT=$((LATEST_HEIGHT - 2000))
    TRUST_HASH=$(curl -Ls "$STATESYNC_TRUSTED_NODE/block?height=$BLOCK_HEIGHT" | jq -r .result.block_id.hash)

    export AKASH_STATESYNC_TRUST_HEIGHT=$BLOCK_HEIGHT
    export AKASH_STATESYNC_TRUST_HASH=$TRUST_HASH

    HALT_BLOCK_HEIGHT=$((LATEST_HEIGHT+5))
    echo "Waiting to for halt at block height: $HALT_BLOCK_HEIGHT"

    ${AKASH} start --halt-height $HALT_BLOCK_HEIGHT |& grep --line-buffered -vi 'peer'
fi

echo "exporting state to [${GENESIS_ORIG}]"
${AKASH} export --home="${AKASH_HOME}" > "${GENESIS_ORIG}"
