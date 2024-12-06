package circuits

import (
	"github.com/brevis-network/brevis-sdk/sdk"
	"github.com/ethereum/go-ethereum/common/hexutil"
)

type AppCircuit struct{}

var USDCTokenAddr = sdk.ConstUint248("0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48")
var PositionManager = sdk.ConstUint248("0x1b1c77b606d13b09c84d1c7394b96b147bc03147")
var EventIdLiquidity = sdk.ParseEventID(
	hexutil.MustDecode("0xf208f4912782fd25c7f114ca3723a2d5dd6f3bcc3ac8db5af63baa85f711d5ec"))
var EventIdTransfer = sdk.ParseEventID(
		hexutil.MustDecode("0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"))
var minimumLiqudity = sdk.ConstUint248(5000000000) // minimum 5000 USDC
var _ sdk.AppCircuit = &AppCircuit{}

func (c *AppCircuit) Allocate() (maxReceipts, maxStorage, maxTransactions int) {
	// We are going to use 2 receipts one to check that USDC transfer happened 
	// and another one to check that ModifyLiquidity was called.
	return 64, 0, 0
}

func (c *AppCircuit) Define(api *sdk.CircuitAPI, in sdk.DataInput) error {
	receipts := sdk.NewDataStream(api, in.Receipts)
	receipt0 := sdk.GetUnderlying(receipts, 0)
	receipt1 := sdk.GetUnderlying(receipts, 1)

	// Verify that the event occurred on the PositionManager contract
	api.Uint248.AssertIsEqual(receipt0.Fields[0].Contract, PositionManager)
	// Ensure that the Amount is part of the data section, not a topic
	api.Uint248.AssertIsEqual(receipt0.Fields[0].IsTopic, sdk.ConstUint248(0))
	// Confirm that the Index of the field is 2
	api.Uint248.AssertIsEqual(receipt0.Fields[0].Index, sdk.ConstUint248(2))
	// Validate that the Event corresponds to the ModifyLiquidity event
	api.Uint248.AssertIsEqual(receipt0.Fields[0].EventID, EventIdLiquidity)
	//Check that the Amount is at least 5000 USDC
	api.Uint248.AssertIsLessOrEqual(minimumLiqudity, api.ToUint248(receipt0.Fields[0].Value))

	// Verify that the event occurred on the USDC contract
	api.Uint248.AssertIsEqual(receipt1.Fields[0].Contract, USDCTokenAddr)
	// Ensure that the Sender is part of the topic section.
	api.Uint248.AssertIsEqual(receipt1.Fields[0].IsTopic, sdk.ConstUint248(1))
	// Confirm that the Index of the field is 1
	api.Uint248.AssertIsEqual(receipt1.Fields[0].Index, sdk.ConstUint248(1))
	// Validate that the Event corresponds to the Transfer event
	api.Uint248.AssertIsEqual(receipt1.Fields[0].EventID, EventIdTransfer)

	// Ensure that the Amount is part of the data section, not a topic
	api.Uint248.AssertIsEqual(receipt1.Fields[1].IsTopic, sdk.ConstUint248(0))
	// Confirm that the Index of the field is 0
	api.Uint248.AssertIsEqual(receipt1.Fields[1].Index, sdk.ConstUint248(0))
	// Check that the Amount is the same as the Amount in the ModifyLiquidity Event 
	api.Bytes32.AssertIsEqual(receipt0.Fields[0].Value, receipt1.Fields[1].Value)//TODO

	// Make sure that the Sender and the Amount are from the same event(have the same log)
	api.Uint32.AssertIsEqual(receipt1.Fields[0].LogPos, receipt1.Fields[1].LogPos)

	// Returns the blocknumber, the LP's address(Sender) and the amount of Added Liqudity
	api.OutputUint(64, api.ToUint248(receipt0.BlockNum))
	api.OutputAddress(api.ToUint248(receipt1.Fields[0].Value))
	api.OutputBytes32(receipt0.Fields[1].Value)
	return nil
}
