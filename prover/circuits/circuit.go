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
	// Our app is only ever going to use one storage data at a time so
	// we can simply limit the max number of data for storage to 1 and
	// 0 for all others
	return 64, 0, 0
}

func (c *AppCircuit) Define(api *sdk.CircuitAPI, in sdk.DataInput) error {
	receipts := sdk.NewDataStream(api, in.Receipts)
	receipt0 := sdk.GetUnderlying(receipts, 0)
	receipt1 := sdk.GetUnderlying(receipts, 1)

	api.Uint248.AssertIsEqual(receipt0.Fields[0].Contract, PositionManager)
	api.Uint248.AssertIsEqual(receipt0.Fields[0].IsTopic, sdk.ConstUint248(0))
	api.Uint248.AssertIsEqual(receipt0.Fields[0].Index, sdk.ConstUint248(2))
	api.Uint248.AssertIsEqual(receipt0.Fields[0].EventID, EventIdLiquidity)
	// Make sure this transfer has minimum 500 USDC volume
	api.Uint248.AssertIsLessOrEqual(minimumLiqudity, api.ToUint248(receipt0.Fields[1].Value))


	api.Uint248.AssertIsEqual(receipt1.Fields[0].Contract, USDCTokenAddr)
	api.Uint248.AssertIsEqual(receipt1.Fields[0].IsTopic, sdk.ConstUint248(1))
	api.Uint248.AssertIsEqual(receipt1.Fields[0].Index, sdk.ConstUint248(1))
	api.Uint248.AssertIsEqual(receipt1.Fields[0].EventID, EventIdTransfer)
	// Make sure two fields uses the same log to make sure account address linking with correct volume
	api.Uint32.AssertIsEqual(receipt1.Fields[0].LogPos, receipt1.Fields[1].LogPos)

	api.Uint248.AssertIsEqual(receipt1.Fields[1].IsTopic, sdk.ConstUint248(0))
	api.Uint248.AssertIsEqual(receipt1.Fields[1].Index, sdk.ConstUint248(0))
	api.Bytes32.AssertIsEqual(receipt0.Fields[0].Value, receipt1.Fields[1].Value)//TODO

	api.OutputUint(64, api.ToUint248(receipt0.BlockNum))
	api.OutputAddress(api.ToUint248(receipt1.Fields[0].Value))
	api.OutputBytes32(receipt0.Fields[1].Value)
	return nil
}
