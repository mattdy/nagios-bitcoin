#!/bin/bash

# check_bitcoind.sh
# Matt Dyson - 10/10/17
# github.com/mattdy/nagios-bitcoin
#
# updated by Louis - 2018-09-22
# github.com/louiseth1/nagios-bitcoin
#
# Nagios plugin to check the given Bitcoin node against blockexplorer.com
# Can be used on BTC or BCH nodes as specified
#
# Some inspiration from https://github.com/daniel-lucio/ethereum-nagios-plugins

function rpcGrab()
{
        local method=$1

        nodeblock=$(curl --user $node_user:$node_pass -sf --data-binary '{"jsonrpc": "1.0", "id":"check_btc_blockchain", "method": "'${method}'", "params":[] }' -H 'content-type: text/plain;' http://$node_address:$node_port/)
        if [ $? -ne "0" ]; then
                echo "UNKNOWN - Request to bitcoind failed"
                exit 3
        fi

        node_error=$(echo "$nodeblock" | jq -r '.error')
        if [ "$node_error" != "null" ]; then
                echo "UNKNOWN - Request to bitcoind returned error - $node_error"
                exit 3
        fi

	echo $nodeblock
}

while getopts ":B:H:P:w:c:u:p:t:" opt; do
        case $opt in
                B)
                        coin=$OPTARG
                        ;;
                H)
                        node_address=$OPTARG
                        ;;
                P)
                        node_port=$OPTARG
                        ;;
                w)
                        warn_level=$OPTARG
                        ;;
                c)
                        crit_level=$OPTARG
                        ;;
                u)
                        node_user=$OPTARG
                        ;;
                p)
                        node_pass=$OPTARG
                        ;;
                t)
                        checktype=$OPTARG
                        ;;
                \?)
                        echo "UNKNOWN - Invalid option $OPTARG" >&2
                        exit 3
                        ;;
                :)
                        echo "UNKNOWN - Option $OPTARG requires an argument" >&2
                        exit 3
                ;;
        esac
done

if [ -z "$node_address" ]; then
        node_address=localhost
fi

if [ -z "$node_port" ]; then
        node_port=8332
fi

if [ -z "$checktype" ]; then
        echo "UNKNOWN - Must specify a check to perform (blockchain/connections)"
        exit 3
fi

if [ -z "$node_user" ]; then
        echo "UNKNOWN - No username specified"
        exit 3
fi

if [ -z "$node_pass" ]; then
        echo "UNKNOWN - No password specified"
        exit 3
fi

if [ -z "$coin" ]; then
        # Default to BTC if no coin specified
        coin = "btc"
fi

case $checktype in
        "blockchain")
                # Check the wallet for current blockchain height
                if [ -z "$warn_level" ]; then
                        echo "UNKNOWN - Must specify a warning level"
                        exit 3
                fi

                if [ -z "$crit_level" ]; then
                        echo "UNKNOWN - Must specify a critical level"
                        exit 3
                fi

                grab=$(rpcGrab 'getblockchaininfo')
                node_blocks=$(echo $grab | jq -r '.result.blocks')

                remote=$(curl -sf http://blockchain-api.io/v1/$coin/blocks)
                if [ $? -ne "0" ]; then
                        echo "UNKNOWN - Could not fetch remote information. Response from server was: $remote"
                        exit 3
                fi

                diff=$(expr $remote - $node_blocks)
                output="node block height = $node_blocks, global block height = $remote|node=$node_blocks, global=$remote"

                if [ "$diff" -lt "$warn_level" ]; then
                        echo "OK - $output"
                        exit 0
                elif [ "$diff" -ge "$warn_level" ] && [ "$diff" -lt "$crit_level" ]; then
                        echo "WARNING - $output"
                        exit 1
                elif [ "$diff" -ge "$crit_level" ]; then
                        echo "CRITICAL - $output"
                        exit 2
                else
                        echo "UNKNOWN - $output"
                        exit 3
                fi
                ;;

        "connections")
                # Check the wallet for peer connections amount
                if [ -z "$warn_level" ]; then
                        echo "UNKNOWN - Must specify a warning level"
                        exit 3
                fi

                if [ -z "$crit_level" ]; then
                        echo "UNKNOWN - Must specify a critical level"
                        exit 3
                fi

                grab=$(rpcGrab "getnetworkinfo")
                node_conns=$(echo $grab | jq -r '.result.connections')

                output="network connections = $node_conns|connections=$node_conns"
                if [ "$node_conns" -gt "$warn_level" ]; then
                        echo "OK - $output"
                        exit 0
                elif [ "$node_conns" -le "$warn_level" ] && [ "$node_conns" -gt "$crit_level" ]; then
                        echo "WARNING - $output"
                        exit 1
                elif [ "$node_conns" -le "$crit_level" ]; then
                        echo "CRITICAL - $output"
                        exit 2
                else
                        echo "UNKNOWN - $output"
                        exit 3
                fi
                ;;

        "warnings")
                grab=$(rpcGrab "getnetworkinfo")
                node_warnings=$(echo $grab | jq -r '.result.warnings')

                if [ -z "$node_warnings" ]; then
                        echo "OK"
                        exit 0
                else
                        echo "CRITICAL - $node_warnings"
                        exit 1
                fi
                ;;

        *)
                echo "UNKNOWN - Invalid check type specified"
                exit 3
                ;;
esac
