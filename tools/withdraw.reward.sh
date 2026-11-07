#!/bin/bash

if ! node.isInstalled.sh 
then
    echo "Node is not installed"
    exit 1
fi

toNumber(){
    if [ -z "$1" ] || [ "$1" == "null" ]; then
        echo 0
    else
        echo "$1"
    fi
}

convertToTokenValue(){
    echo "scale=5; $1 / $TOKEN_DECIMALS" | bc -l
}

reward=$(aioznode reward balance --endpoint "$ENDPOINT")
# echo "Reward balance json : $reward"

# Retrieve storage earned
balance=$(toNumber $(echo $reward | jq '.balance[0].amount' | sed 's/\"//g'))
balanceDenom=$(echo $reward | jq '.balance[0].denom' | sed 's/\"//g')

# Retrieve storage earned
storageEarned=$(toNumber $(echo $reward | jq '.storage_earned[0].amount' | sed 's/\"//g'))
# storageEarnedDenom=$(echo $reward | jq '.storage_earned[0].denom' | sed 's/\"//g')

# Retrieve storage earned
deliveryEarned=$(toNumber $(echo $reward | jq '.delivery_earned[0].amount' | sed 's/\"//g'))
# deliveryEarnedDenom=$(echo $reward | jq '.delivery_earned[0].denom' | sed 's/\"//g')

# Retrieve withdraw
withdraw=$(toNumber $(echo $reward | jq '.withdraw[0].amount' | sed 's/\"//g'))
# withdrawDenom=$(echo $reward | jq '.withdraw[0].denom' | sed 's/\"//g')

# Retrieve deliver count
deliveryCount=$(echo $reward | jq '.delivery_counter' | sed 's/\"//g')

# Retrieve data file count
storedSegmentCount=$(ls $NODEDATA_SEGMENT_FOLDER | wc -l)

echo "Node rewards status ($ENDPOINT) : "
echo "=> Balance : $balance $TOKEN_DENOM => $(convertToTokenValue $balance) $TOKEN_NAME"
echo "=> Storage : $storageEarned $TOKEN_DENOM => $(convertToTokenValue $storageEarned) $TOKEN_NAME"
echo "=> Delivery : $deliveryEarned $TOKEN_DENOM => $(convertToTokenValue $deliveryEarned) $TOKEN_NAME"
echo "=> Withdraw : $withdraw $TOKEN_DENOM => $(convertToTokenValue $withdraw) $TOKEN_NAME"
echo "=> Delivery count : $deliveryCount"
echo "=> Stored segment count : $storedSegmentCount. Size : $(du -sh $NODEDATA_SEGMENT_FOLDER)"
minimumBalanceToWithDraw=$(echo "$WITHDRAW_MIN_VALUE" | bc -l)
remainingBalanceToWithDraw=$(($minimumBalanceToWithDraw - $balance))
echo "=> Remaining balance to withdraw : $remainingBalanceToWithDraw $TOKEN_DENOM => => $(convertToTokenValue $remainingBalanceToWithDraw) $TOKEN_NAME"
echo " "

if [ "$balance" -gt "$minimumBalanceToWithDraw" ]; then
    echo "Try to withdraw... aioznode reward withdraw --endpoint "$ENDPOINT" --address $WITHDRAW_ADDRESS_HEX --amount $balance$balanceDenom --priv-key-file $PRIV_KEY_FILE"
    aioznode reward withdraw --endpoint "$ENDPOINT" --address $WITHDRAW_ADDRESS_HEX --amount $balance$balanceDenom --priv-key-file $PRIV_KEY_FILE
fi