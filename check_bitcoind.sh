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

use_bch=False
coin="btc" # Default to BTC if not specified

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

if [ -z "$warn_level" ]; then
        echo "UNKNOWN - Must specify a warning level"
        exit 3
fi

if [ -z "$crit_level" ]; then
        echo "UNKNOWN - Must specify a critical level"
        exit 3
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

if [ "$coin" != "btc" ] && [ "$coin" != "bch" ]; then
        echo "UNKNOWN - Invalid coin type specified (btc/bch)"
        exit 3
fi

case $checktype in
        "blockchain")
                # Check the wallet for current blockchain height
                nodeblock=$(curl --user $node_user:$node_pass -sf --data-binary '{"jsonrpc": "1.0", "id":"check_btc_blockchain", "method": "getblockchaininfo", "params":[] }' -H 'content-type: text/plain;' http://$node_address:$node_port/)
                if [ $? -ne "0" ]; then
                        echo "UNKNOWN - Request to bitcoind failed"
                        exit 3
                fi

                node_error=$(echo "$nodeblock" | jq -r '.error')
                if [ "$node_error" != "null" ]; then
                        echo "UNKNOWN - Request to bitcoind returned error - $node_error"
                        exit 3
                fi

                node_blocks=$(echo "$nodeblock" | jq -r '.result.blocks')
                if [ $coin == "bch" ]; then
                        remote_addr="bitcoincash.blockexplorer.com"
                else
                        remote_addr="blockexplorer.com"
                fi

                remote=$(curl -sf https://$remote_addr/api/status?q=getBlockchainInfo)
                if [ $? -ne "0" ]; then
                        echo "UNKNOWN - Could not fetch remote information"
                        exit 3
                fi

                remote_blocks=$(echo "$remote" | jq -r '.info.blocks')

                diff=$(expr $remote_blocks - $node_blocks)
                output="node block height = $node_blocks, global block height = $remote_blocks|node=$node_blocks, global=$remote_blocks"

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
                nodeconn=$(curl --user $node_user:$node_pass -sf --data-binary '{"jsonrpc": "1.0", "id":"check_btc_blockchain", "method": "getnetworkinfo", "params": [] }' -H 'content-type: text/plain;' http://$node_address:$node_port/)
                if [ $? -ne "0" ]; then
                        echo "UNKNOWN - Request to bitcoind failed"
                        exit 3
                fi

                node_error=$(echo "$nodeconn" | jq -r '.error')
                if [ "$node_error" != "null" ]; then
                        echo "UNKNOWN - Request to bitcoind returned error - $node_error"
                        exit 3
                fi

                node_conns=$(echo "$nodeconn" | jq -r '.result.connections')
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
esac
