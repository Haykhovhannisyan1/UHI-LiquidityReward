// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Import dependencies
import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";
import {SwapFeeLibrary} from "./SwapFeeLibrary.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../../contracts/contracts/lib/IBrevisProof.sol";
import "../../contracts/contracts/lib/BrevisApp.sol";

// VolFeesHook contract integrates dynamic fee logic with Brevis verification
contract VolFeesHook is BaseHook, BrevisApp, Ownable {
    using SwapFeeLibrary for uint24;

    // Events
    event VolatilityUpdated(uint256 volatility);

    // State variables
    bytes32 public vkHash; // Hash of the verifying key used for Brevis proof verification
    uint256 public volatility; // Tracks the current volatility

    // Constants
    uint24 public constant BASE_FEE = 200; // 2bps base fee
    uint24 public constant HOOK_COMMISSION = 100; // Commission (0.01%) for covering Brevis service costs

    // Errors
    error MustUseDynamicFee(); // Raised when dynamic fees are not enabled

    // Constructor to initialize dependencies and owner
    constructor(IPoolManager _poolManager, address brevisProof)
        BaseHook(_poolManager)
        BrevisApp(IBrevisProof(brevisProof))
        Ownable(msg.sender)
    {}

    // Permissions required by the PoolManager for different hook functionalities
    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: true,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    // Ensures dynamic fee functionality is enabled during pool initialization
    function beforeInitialize(address, PoolKey calldata key, uint160, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        if (!key.fee.isDynamicFee()) revert MustUseDynamicFee();
        return this.beforeInitialize.selector;
    }

    // Executes custom logic before a swap, including taking a commission and overriding the fee
    function beforeSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata swapParams, bytes calldata)
        external
        view
        override
        poolManagerOnly
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        takeCommission(key, swapParams);

        uint24 fee = BASE_FEE / 2; // Calculate half of the base fee
        fee = fee | LPFeeLibrary.OVERRIDE_FEE_FLAG; // Apply override flag to the fee

        return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, fee);
    }

    // Internal function to deduct a commission for Brevis service costs
    function takeCommission(PoolKey calldata key, IPoolManager.SwapParams calldata swapParams) internal {
        uint256 tokenAmount =
            swapParams.amountSpecified < 0 ? uint256(-swapParams.amountSpecified) : uint256(swapParams.amountSpecified);

        uint256 commissionAmt = Math.mulDiv(tokenAmount, HOOK_COMMISSION, 10000); // Calculate commission amount

        Currency inbound = swapParams.zeroForOne ? key.currency0 : key.currency1; // Determine inbound token

        // Transfer commission to the hook's reserves
        poolManager.take(inbound, address(this), commissionAmt);
    }

    // Brevis backend invokes this callback with proof results
    function handleProofResult(bytes32, /*_requestId*/ bytes32 _vkHash, bytes calldata _circuitOutput)
        internal
        override
    {
        // Ensure proof verification is performed with the correct verifying key
        require(vkHash == _vkHash, "invalid vk");

        // Decode the volatility from the circuit output
        volatility = decodeOutput(_circuitOutput);

        emit VolatilityUpdated(volatility);
    }

    // Decodes volatility value from circuit output
    function decodeOutput(bytes calldata o) internal pure returns (uint256) {
        uint248 vol = uint248(bytes31(o[0:31])); // Extract the first 31 bytes as uint248
        return uint256(vol);
    }

    // Updates the verifying key hash for Brevis proof verification
    function setVkHash(bytes32 _vkHash) external onlyOwner {
        vkHash = _vkHash;
    }
}
