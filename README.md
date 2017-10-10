# nagios-bitcoin
Nagios plugin to monitor bitcoind, to allow escalation of alerts when problems are sensed. Can be used on either the BTC or BCH networks as specified.

## Requirements
- A [Nagios](https://www.nagios.org/) installation
- [jq](https://stedolan.github.io/jq/) for JSON parsing
- [bitcoind](https://en.bitcoin.it/wiki/Bitcoind) with [RPC enabled](https://en.bitcoin.it/wiki/API_reference_(JSON-RPC)) 

## Setup
### Script
The easiest way of using this script is to check it out directly from Github into your Nagios plugins directory:
```
$ cd /usr/lib/nagios/plugins
$ git clone https://github.com/mattdy/nagios-bitcoin.git bitcoin
```

### Nagios Commands
Paste the following into the appropriate Nagios command configuration file
```
define command {
        command_line                   $USER1$/bitcoin/check_bitcoind.sh -u $ARG1$ -p $ARG2$ -H $HOSTADDRESS$ -P $ARG3$ -B $ARG4$ -w $ARG5$ -c $ARG6$ -t blockchain
        command_name                   check_bitcoin_blockchain
}

define command {
        command_line                   $USER1$/bitcoin/check_bitcoind.sh -u $ARG1$ -p $ARG2$ -H $HOSTADDRESS$ -P $ARG3$ -B $ARG4$ -w $ARG5$ -c $ARG6$ -t connections
        command_name                   check_bitcoin_connections
}

define command {
        command_line                   $USER1$/bitcoin/check_bitcoind.sh -u $ARG1$ -p $ARG2$ -H $HOSTADDRESS$ -P $ARG3$ -B $ARG4$ -w $ARG5$ -c $ARG6$ -t errors
        command_name                   check_bitcoin_errors
}
```

### Nagios Services
Paste the following into your Nagios service configuration file, changing the values as needed
```
define service {
        check_command                  check_bitcoin_connections!<USERNAME>!<PASSWORD>!<PORT>!<CURRENCY>!<WARN>!<CRIT>
        host_name                      <HOSTNAME>
        service_description            Bitcoind Connections
        use                            generic-service
}

define service {
        check_command                  check_bitcoin_blockchain!<USERNAME>!<PASSWORD>!<PORT>!<CURRENCY>!<WARN>!<CRIT>
        host_name                      <HOSTNAME>
        service_description            Bitcoind Blockchain
        use                            generic-service
}

define service {
        check_command                  check_bitcoin_errors!<USERNAME>!<PASSWORD>!<PORT>!<CURRENCY>!<WARN>!<CRIT>
        host_name                      <HOSTNAME>
        service_description            Bitcoind Errors
        use                            generic-service
}

```

## Service Descriptions
Check Type | Description | Example output
---------- | ----------- | --------------
blockchain | Check the height of the node blockchain against [Blockexplorer](https://blockexplorer.com) | `CRITICAL - node block height = 380882, global block height = 494377` 
connections | Check the number of connections (peers) reported | `OK - network connections = 8`
errors | Check for any errors reported by the bitcoind process | `OK`

## Command line options
Argument | Description | Example
-------- | ----------- | -------
-u | RPC username | rpcuser
-p | RPC password | rpcpass
-H | RPC host | localhost
-P | RPC port | 8332
-B | Currency to use (only for blockchain check) - either `btc` or `bch` | btc
-w | Warning level to use for Nagios output | 5
-c | Critical level to use for Nagios output | 10
-t | Type of check to run - either `blockchain`, `connections` or `errors` | blockchain

