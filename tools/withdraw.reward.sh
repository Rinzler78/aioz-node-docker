#!/bin/bash
# Withdraw the node rewards (queried on ENDPOINT) to WITHDRAW_ADDRESS_HEX once
# the balance exceeds WITHDRAW_MIN_VALUE (attoaioz, a bc expression).
# Sourced by start-watching-reward.sh (withdraw_reward); runs once standalone.
# Amounts are compared with bc: they exceed 64-bit integers above ~9.22 AIOZ.

# The whole balance goes to this address at every withdraw: refuse a typo.
check_withdraw_address() {
    if [[ ! "$WITHDRAW_ADDRESS_HEX" =~ ^0x[0-9a-fA-F]{40}$ ]]; then
        echo "ERROR: WITHDRAW_ADDRESS_HEX must be set to the 0x address (40 hex digits) that receives the rewards." >&2
        return 1
    fi
}

# Amount of the first entry of a reward field, 0 when missing.
amount_of() {
    jq -r ".$1[0].amount // 0" <<< "$2"
}

to_token() {
    echo "scale=5; $1 / $TOKEN_DECIMALS" | bc -l
}

withdraw_reward() {
    local reward balance denom minimum remaining amount field
    check_withdraw_address || return 1
    if ! command -v "$BINARY_NAME" > /dev/null; then
        echo "Node is not installed"
        return 1
    fi

    if ! reward=$("$BINARY_NAME" reward balance --endpoint "$ENDPOINT") ||
        ! jq -e '.balance' <<< "$reward" > /dev/null 2>&1; then
        echo "ERROR: cannot read the rewards on $ENDPOINT" >&2
        return 1
    fi
    balance=$(amount_of balance "$reward")
    denom=$(jq -r '.balance[0].denom // empty' <<< "$reward")
    minimum=$(echo "$WITHDRAW_MIN_VALUE" | bc -l)
    remaining=$(echo "$minimum - $balance" | bc)

    echo "Node rewards status ($ENDPOINT) : "
    for field in Balance:balance Storage:storage_earned Delivery:delivery_earned Withdraw:withdraw; do
        amount=$(amount_of "${field#*:}" "$reward")
        echo "=> ${field%%:*} : $amount $TOKEN_DENOM => $(to_token "$amount") $TOKEN_NAME"
    done
    echo "=> Delivery count : $(jq -r '.delivery_counter // 0' <<< "$reward")"
    echo "=> Stored segment count : $(find "$NODEDATA_SEGMENT_FOLDER" -mindepth 1 -maxdepth 1 ! -name '.*' | wc -l). Size : $(du -sh "$NODEDATA_SEGMENT_FOLDER")"
    echo "=> Remaining balance to withdraw : $remaining $TOKEN_DENOM => => $(to_token "$remaining") $TOKEN_NAME"
    echo " "

    if [ "$(echo "$balance > $minimum" | bc)" -eq 1 ]; then
        echo "Try to withdraw... $BINARY_NAME reward withdraw --endpoint $ENDPOINT --address $WITHDRAW_ADDRESS_HEX --amount $balance$denom --priv-key-file $PRIV_KEY_FILE"
        "$BINARY_NAME" reward withdraw --endpoint "$ENDPOINT" --address "$WITHDRAW_ADDRESS_HEX" \
            --amount "$balance$denom" --priv-key-file "$PRIV_KEY_FILE"
    fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    withdraw_reward
fi
