#!/bin/bash
set -e
# set -x

export HALO2_PROOF_GPU_EVAL_CACHE=20 # for cuda 4090
# export CUDA_VISIBLE_DEVICES=0 # for enable only one device
export RUST_LOG=info

PWD=${PWD}
RLP_PATH=${PWD}/rlp
ZKWASM=${PWD}/zkWasm
ZKWASM_BIN=${PWD}/zkWasm/target/release/delphinus-cli
PRIVATE=$RLP_PATH/private.bin
WASM=${PWD}/zkWasm/crates/zkwasm/wasm/rlp.wasm
OUTPUT=$RLP_PATH/output
SEGMENTS=4  # total segments
K=18

OUTNAME=rlp_batch
BATCHER_DIR=${PWD}/continuation-batcher
BATCHER=${BATCHER_DIR}/target/release/circuit-batcher

# rm -rf ${OUTPUT}/[0-9]*

# 1. generate trace
if [[ ! -f $ZKWASM_BIN ]];then
    echo -e "\nbuilding zkwasm cuda================="
    cd $ZKWASM
    git submodule update --init
    cargo build --release --features cuda,continuation
fi

# $ZKWASM_BIN -k18 --function zkmain --output $OUTPUT --wasm $WASM witness-dump --public 133:i64 --private ${PRIVATE}:file

# 2. setup circuit
# $ZKWASM_BIN -k 18 --function zkmain  --output $OUTPUT --wasm $WASM setup

# 3.1 prove each segment

# for((i=0;i<$SEGMENTS;i++))
# do
#     echo -e "Proving ${i}-th segment================="
#     $ZKWASM_BIN -k 18 --function zkmain  --output $OUTPUT --wasm $WASM proof-from-trace  -p  $OUTPUT -t $RLP_PATH/output/$i
#     mv $RLP_PATH/output/$i/zkwasm.0.transcript.data $RLP_PATH/zkwasm.$i.transcript.data
# done

# 3.2 verify each segment

# can't verify for now
# RUST_LOG=info cargo run --release --features cuda,continuation -- -k 18 --function zkmain --output $OUTPUT -w $WASM single-verify --proof $TABLES --instance $OUTPUT 

# 4. continuation batcher
echo -e "\n===continuation-batcher proving"
BATCH=$RLP_PATH/batch.json
if [[ ! -f $BATCHER ]];then
    echo -e "\nbuilding continuation-batcher cuda================="
    cd $BATCHER_DIR
    cargo build --release --features cuda
fi
${BATCHER} --param ${OUTPUT} --output ${OUTPUT} batch -k ${K} --challenge poseidon --info $OUTPUT/zkwasm.0.loadinfo.json $OUTPUT/zkwasm.1.loadinfo.json $OUTPUT/zkwasm.2.loadinfo.json $OUTPUT/zkwasm.3.loadinfo.json --name ${OUTNAME} --commits $BATCH