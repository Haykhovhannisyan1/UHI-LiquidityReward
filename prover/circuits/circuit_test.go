package circuits

import (
	"testing"

	"github.com/brevis-network/brevis-sdk/sdk"
	"github.com/brevis-network/brevis-sdk/test"
	"github.com/ethereum/go-ethereum/common"
)

func TestCircuit(t *testing.T) {
	rpc := "RPC_URL"
	localDir := "$HOME/circuitOut/myBrevisApp"
	app, err := sdk.NewBrevisApp(11155111, rpc, localDir)
	check(err)

	txHash := common.HexToHash(
		"0xb1481048a3f3b09c234049c2653ed825444a5f628f9c087e518558478e398d92")

	app.AddReceipt(sdk.ReceiptData{
		TxHash: txHash,
		Fields: []sdk.LogFieldData{
			{
				IsTopic:    false,
				LogPos:     1,
				FieldIndex: 2,
			},
		},
	})
	app.AddReceipt(sdk.ReceiptData{
		TxHash: txHash,
		Fields: []sdk.LogFieldData{
			{
				IsTopic:    true,
				LogPos:     2,
				FieldIndex: 1,
			},
			{
				IsTopic:    false,
				LogPos:     2,
				FieldIndex: 0,
			},
		},
	})

	appCircuit := &AppCircuit{}
	appCircuitAssignment := &AppCircuit{}

	circuitInput, err := app.BuildCircuitInput(appCircuit)
	check(err)

	///////////////////////////////////////////////////////////////////////////////
	// Testing
	///////////////////////////////////////////////////////////////////////////////

	test.ProverSucceeded(t, appCircuit, appCircuitAssignment, circuitInput)
}

func check(err error) {
	if err != nil {
		panic(err)
	}
}
