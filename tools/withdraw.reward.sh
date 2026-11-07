#!/bin/bash
# Withdraw the node rewards (queried on ENDPOINT) to WITHDRAW_ADDRESS_HEX once
# the balance exceeds WITHDRAW_MIN_VALUE (attoaioz, a bc expression).
# Sourced by start-watching-reward.sh (withdraw_reward); runs once standalone.
# Amounts are compared with bc: they exceed 64-bit integers above ~9.22 AIOZ.

# Amount of the first entry of a reward field, 0 when missing.
amount_of() {
    jq -r ".$1[0].amount // 0" <<< "$2"
}

to_token() {
    echo "scale=5; $1 / $TOKEN_DECIMALS" | bc -l
}

withdraw_reward() {
    local reward balance denom minimum remaining
    if ! command -v "$BINARY_NAME" > /dev/null; then
        echo "Node is not installed"
        return 1
    fi

    reward=$("$BINARY_NAME" reward balance --endpoint "$ENDPOINT")
    balance=$(amount_of balance "$reward")
    denom=$(jq -r '.balance[0].denom // empty' <<< "$reward")
    minimum=$(echo "$WITHDRAW_MIN_VALUE" | bc -l)
    remaining=$(echo "$minimum - $balance" | bc)

    echo "Node rewards status ($ENDPOINT) : "
    echo "=> Balance : $balance $TOKEN_DENOM => $(to_token "$balance") $TOKEN_NAME"
    echo "=> Storage : $(amount_of storage_earned "$reward") $TOKEN_DENOM"
    echo "=> Delivery : $(amount_of delivery_earned "$reward") $TOKEN_DENOM"
    echo "=> Withdraw : $(amount_of withdraw "$reward") $TOKEN_DENOM"
    echo "=> Delivery count : $(jq -r '.delivery_counter // 0' <<< "$reward")"
    echo "=> Stored segment count : $(find "$NODEDATA_SEGMENT_FOLDER" -mindepth 1 -maxdepth 1 | wc -l)"
    echo "=> Remaining balance to withdraw : $remaining $TOKEN_DENOM => $(to_token "$remaining") $TOKEN_NAME"
    echo " "

    if [ "$(echo "$balance > $minimum" | bc)" -eq 1 ]; then
        echo "Try to withdraw $balance$denom to $WITHDRAW_ADDRESS_HEX"
        "$BINARY_NAME" reward withdraw --endpoint "$ENDPOINT" --address "$WITHDRAW_ADDRESS_HEX" \
            --amount "$balance$denom" --priv-key-file "$PRIV_KEY_FILE"
    fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    withdraw_reward
fi
