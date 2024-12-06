import { ethers } from 'ethers';
import { Brevis, ErrCode, ProofRequest, Prover, TransactionData, ReceiptData, Field, StorageData } from 'brevis-sdk-typescript';
import Web3, { Contract, ContractAbi, EventLog } from 'web3';
import { readFileSync } from 'fs';
import { RegisteredSubscription } from 'web3/lib/commonjs/eth.exports';


async function getStorageDataAtBlock(chosenBlock: number, contractAddress: string, index: number, web3: Web3<RegisteredSubscription>) {
    const storageVal = await web3.eth.getStorageAt(contractAddress, index, chosenBlock);

    const storageData = new StorageData({
        block_num: chosenBlock,
        address: contractAddress,
        slot: "0x0000000000000000000000000000000000000000000000000000000000000000",
        value: storageVal
    })
    console.log(chosenBlock, storageVal)

    return storageData
}



// Get N storage values
async function getStorageDataPoints(numDataPoints: number, startingBlock: number, contractAddress: string, index: number, web3: Web3<RegisteredSubscription>) {
    var dataPoints = []

    var curBlock = startingBlock;

    // repeat until we meet the requested data points
    while (dataPoints.length < numDataPoints) {
        // fetch brevis structured data
        const storageItem = await getStorageDataAtBlock(curBlock, contractAddress, index, web3);
        // append new item
        dataPoints.push(storageItem)
        // move to next block
        curBlock--;
    }

    return dataPoints;
}
async function main() {
    const web3 = new Web3('https://eth.llamarpc.com');
    const prover = new Prover('localhost:33247');
    // const prover = new Prover('127.0.0.1:8545');
    // const brevis = new Brevis('appsdk.brevis.network:11080');
    const brevis = new Brevis('appsdkv3.brevis.network:443');

    const proofReq = new ProofRequest();

    // Assume transaction hash will provided by command line
    const hash = process.argv[2]

    // Brevis Partner KEY IS NOT required to submit request to Brevis Gateway. 
    // It is used only for Brevis Partner Flow
    const brevis_partner_key = process.argv[3] ?? ""
    const callbackAddress = process.argv[4] ?? ""

    if (hash.length === 0) {
        console.error("empty transaction hash")
        return
    }

    // proofReq.addReceipt(
    //     new ReceiptData({
    //         tx_hash: hash,
    //         fields: [
    //             new Field({
    //                 log_pos: 0,
    //                 is_topic: true,
    //                 field_index: 1,
    //             }),
    //             new Field({
    //                 log_pos: 0,
    //                 is_topic: false,
    //                 field_index: 0,
    //             }),
    //         ],
    //     }),
    // );

    console.log(`Send prove request for ${hash}`)

    const storageDataList = await getStorageDataPoints(500, 19308799, "0x88e6a0c2ddd26feeb64f039a2c41296fcb3f5640", 0, web3)

    for (let i = 0; i < storageDataList.length; i++) {
        proofReq.addStorage(storageDataList[i], i)
    }

    const proofRes = await prover.prove(proofReq);
    // error handling
    if (proofRes.has_err) {
        const err = proofRes.err;
        switch (err.code) {
            case ErrCode.ERROR_INVALID_INPUT:
                console.error('invalid receipt/storage/transaction input:', err.msg);
                break;

            case ErrCode.ERROR_INVALID_CUSTOM_INPUT:
                console.error('invalid custom input:', err.msg);
                break;

            case ErrCode.ERROR_FAILED_TO_PROVE:
                console.error('failed to prove:', err.msg);
                break;
        }
        return;
    }
    console.log('proof', proofRes.proof);

    try {
        const brevisRes = await brevis.submit(proofReq, proofRes, 1, 11155111, 0, brevis_partner_key, callbackAddress);
        console.log('brevis res', brevisRes);

        await brevis.wait(brevisRes.queryKey, 11155111);
    } catch (err) {
        console.error(err);
    }
}

main();
