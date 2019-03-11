#!/bin/bash

function yes_or_no() {
    read -p "Yes or No(y/n): " anw
    case $anw in
    [Yy][Ee][Ss]|[yY])
        return 1
    ;;
    [Nn][Oo]|[Nn])
        return 0
    ;;
    esac
    return 0
}

function check_ip() {
    ip=$1
    check=$(echo $ip|awk -F. '$1<=255&&$2<=255&&$3<=255&&$4<=255{print "yes"}')
    if echo $ip|grep -E "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$">/dev/null; then
        if [ ${check:-no} == "yes" ]; then
            return 0
        fi
    fi
    return 1
}

function create_node_key() {
    keyinfo=`./ethkey genkeypair | sed s/[[:space:]]//g`
    keyinfo=${keyinfo,,}
    address=${keyinfo:10:40}
    prikey=${keyinfo:62:64}
    pubkey=${keyinfo:137:128}

    ts=`date '+%Y%m%d%H%M%S'`
    if [ -f ../data/node.address ]; then
        mv ../data/node.address ../data/node.address.bak.$ts
    fi
    if [ -f ../data/node.prikey ]; then
        mv ../data/node.prikey ../data/node.prikey.bak.$ts
    fi
    if [ -f ../data/node.pubkey ]; then
        mv ../data/node.pubkey ../data/node.pubkey.bak.$ts
    fi

    mkdir -p ../data
    echo $address > ../data/node.address
    echo $prikey > ../data/node.prikey
    echo $pubkey > ../data/node.pubkey

    echo "Create node key succ. Files: data/node.address, data/node.prikey, data/node.pubkey"
}

function create_account() {
    if [ -f ../data/keystore/keyfile.json ]; then
        mv ../data/keystore/keyfile.json ../data/keystore/keyfile.json.bak.`date '+%Y%m%d%H%M%S'`
    fi

    echo "Input account passphrase."
    mkdir -p ../data/keystore
    cd ../data/keystore
    ../../bin/ethkey generate
    cd ../../bin
    echo "Create account succ. File: data/keystore/keyfile.json"
}

function create_genesis() {
    if [ -f ../conf/genesis.json ]; then
        mv ../conf/genesis.json ../conf/genesis.json.bak.`date '+%Y%m%d%H%M%S'`
    fi
    cp ../conf/genesis.json.template ../conf/genesis.json

    ./repstr ../conf/genesis.json "NODE-KEY" -f ../data/node.pubkey

    ip=$1
    ./repstr ../conf/genesis.json "NODE-IP" $ip

    keyinfo=`cat ../data/keystore/keyfile.json | sed s/[[:space:]]//g`
    keyinfo=${keyinfo,,}
    address=${keyinfo:12:40}
    ./repstr ../conf/genesis.json "DEFAULT-ACCOUNT" $address

    ./ctool codegen --abi ../conf/contracts/cnsManager.cpp.abi.json --code ../conf/contracts/cnsManager.wasm > ../conf/cns-code.hex
    ./repstr ../conf/genesis.json "CNS-CODE" -f ../conf/cns-code.hex
    rm -rf ../conf/cns-code.hex

    echo "Create genesis succ. File: conf/genesis.json"
}

function init_root() {
    if [ -d ../data/platon ]; then
        echo; echo "Node already initialized, re initailize?"
        yes_or_no
        if [ $? -ne 1 ]; then
            exit
        fi
    fi

    echo; echo "[Step 1: create node key]"
    if [ -f ../data/node.pubkey ]; then
        echo "Node key already exists, re create?"
        yes_or_no
        if [ $? -eq 1 ]; then
            create_node_key
        fi
    else
        create_node_key
    fi

    echo; echo "[Step 2: create default account]"
    if [ -f ../data/keystore/keyfile.json ]; then
        echo "Account key file already exists, re create?"
        yes_or_no
        if [ $? -eq 1 ]; then
            create_account
        fi
    else
        create_account
    fi

    echo; echo "[Step 3: input public ip addr]"
    while true
    do
        read -p "Your node ip: " ip
        check_ip $ip
        if [ $? -eq 0 ]; then
            break
        else
            echo "Invalid ip. Please re input."
        fi
    done

    echo; echo "[Step 4: create genesis]"
    create_genesis $ip

    rm -rf ../data/platon

    echo; echo "[Step 5: init chain data]"
    ./platon --datadir ../data init ../conf/genesis.json
}

function init_slave() {
    if [ -d ../data/platon ]; then
        echo; echo "Node already initialized, re initailize?"
        yes_or_no
        if [ $? -ne 1 ]; then
            exit
        fi
    fi

    echo; echo "[Step 1: create node key]"
    if [ -f ../data/node.pubkey ]; then
        echo "Node key already exists, re create?"
        yes_or_no
        if [ $? -eq 1 ]; then
            create_node_key
        fi
    else
        create_node_key
    fi

    echo; echo "[Step 2: create default account]"
    if [ -f ../data/keystore/keyfile.json ]; then
        echo "Account key file already exists, re create?"
        yes_or_no
        if [ $? -eq 1 ]; then
            create_account
        fi
    else
        create_account
    fi
    
    if [ ! -f ../conf/genesis.json ]; then
        echo "File conf/genesis.json not exists"
        return 1
    fi

    rm -rf ../data/platon

    echo; echo "[Step 3: init chain data]"
    ./platon --datadir ../data init ../conf/genesis.json
}

function main() {
    echo "[Node initailization]"
    echo "What type of your node?"
    read -p "1 for root, 2 for slave: " anw
    if [ $anw -eq 1 ]; then
        init_root
    elif [ $anw -eq 2 ]; then
        init_slave
    fi
}

main