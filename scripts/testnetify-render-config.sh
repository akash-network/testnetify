#!/usr/bin/env bash

akash=$1
key=$2
template=$3
result=$4

ACCOUNT_ADDRESS=$($akash keys show "$key" -a) \
ACCOUNT_PUBKEY=$($akash keys show "$key" -p) \
VALIDATOR_PUBKEY=$($akash tendermint show-validator) \
    gomplate \
        -d 'account_address=env:///ACCOUNT_ADDRESS' \
        -d 'account_pubkey=env:///ACCOUNT_PUBKEY' \
        -d 'validator_pubkey=env:///VALIDATOR_PUBKEY' \
        -f "$template" | jq > "$result"
