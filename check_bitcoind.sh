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
	local params=$2

        nodeblock=$(curl --user $node_user:$node_pass -sf --data-binary '{"jsonrpc": "1.0", "id":"check_btc_blockchain", "method": "'${method}'", "params":['${params}'] }' -H 'content-type: text/plain;' http://$node_address:$node_port/)
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

while getopts ":B:H:P:w:c:u:p:t:i:" opt; do
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
                i)
                        ignore=$OPTARG
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

		case $coin in
			"btc")
				address="https://api.blockchair.com/bitcoin/stats"
				path=".data.blocks"
			;;

			"bsv")
				address="https://api.blockchair.com/bitcoin-sv/stats"
				path=".data.blocks"
			;;

			"bch")
				address="https://api.blockchair.com/bitcoin-cash/stats"
				path=".data.blocks"
			;;

			"btg")
				address="https://explorer.bitcoingold.org/insight-api/status?q=getInfo"
				path=".info.blocks"
			;;

			*)
				echo "UNKNOWN - unknown coin type requested. Select one of btc/bsv/bch/btg"
				exit 3
			;;
		esac

                remote=$(curl -sf $address)
                if [ $? -ne "0" ]; then
                        echo "UNKNOWN - Could not fetch remote information (from $address). Response from server was: $remote"
                        exit 3
                fi
		remote_blocks=$(echo $remote | jq -r "$path")

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

	"time")
                if [ -z "$warn_level" ]; then
                        echo "UNKNOWN - Must specify a warning level"
                        exit 3
                fi

                if [ -z "$crit_level" ]; then
                        echo "UNKNOWN - Must specify a critical level"
                        exit 3
                fi

		# Get the current best block
		info=$(rpcGrab "getblockchaininfo")
		best_hash=$(echo $info | jq -r '.result.bestblockhash')

		# Fetch information on that specific block to get the generated time
		grab=$(rpcGrab "getblock" "\"$best_hash\"")
		block_time=$(echo $grab | jq -r '.result.time')
		current_time=$(date +%s)

		diff=$(expr $current_time - $block_time)

		output="last block = $diff secs ago|time=$block_time"

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

        "warnings")
                grab=$(rpcGrab "getnetworkinfo")
                node_warnings=$(echo $grab | jq -r '.result.warnings')

		# If we have a list of warnings to ignore, then run through each one and see if it matches our warnings
		if [ ! -z "$ignore" ] && [ ! -z "$node_warnings" ]; then
			export IFS=";"
                        for i in $ignore; do
                                if [[ "$node_warnings" =~ "$i" ]]; then
                                        node_warnings=""
                                fi
                        done
		fi

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
