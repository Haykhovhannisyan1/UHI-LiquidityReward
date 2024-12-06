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

// LiquidityRewardsHook contract integrates dynamic fee logic with Brevis verification
contract LiquidityRewardsHook is BaseHook, BrevisApp, Ownable {
    using SwapFeeLibrary for uint24;

    event LiquidityAmountAdded(uint64 blockNum, address LP, uint256 amount);

    // State variables
    bytes32 public vkHash; // Hash of the verifying key used for Brevis proof verification

    // Constants
    uint24 public constant BASE_FEE = 200; // 2bps base fee

    // Errors
    error MustUseDynamicFee(); // Raised when dynamic fees are not enabled

    // Constructor to initialize dependencies and owner
    constructor(
        IPoolManager _poolManager,
        address brevisProof
    )
        BaseHook(_poolManager)
        BrevisApp(IBrevisProof(brevisProof))
        Ownable(msg.sender)
    {}

    // Permissions required by the PoolManager for different hook functionalities
    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
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
    function beforeInitialize(
        address,
        PoolKey calldata key,
        uint160,
        bytes calldata
    ) external pure override returns (bytes4) {
        if (!key.fee.isDynamicFee()) revert MustUseDynamicFee();
        return this.beforeInitialize.selector;
    }

    // Executes custom logic before a swap, including taking a commission and overriding the fee
    function beforeSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata swapParams,
        bytes calldata
    )
        external
        view
        override
        poolManagerOnly
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        uint24 fee = BASE_FEE / 2; // Calculate half of the base fee
        fee = fee | LPFeeLibrary.OVERRIDE_FEE_FLAG; // Apply override flag to the fee

        return (
            BaseHook.beforeSwap.selector,
            BeforeSwapDeltaLibrary.ZERO_DELTA,
            fee
        );
    }

    // Brevis backend invokes this callback with proof results
    function handleProofResult(
        bytes32,
        bytes32 _vkHash,
        bytes calldata _circuitOutput
    ) internal override {
        require(vkHash == _vkHash, "invalid vk");
        (address LpAddr, uint64 blockNum, uint256 amount) = decodeOutput(
            _circuitOutput
        );
        emit LiquidityAmountAdded(blockNum, LpAddr, amount);
    }

    function decodeOutput(
        bytes calldata o
    ) internal pure returns (address, uint64, uint256) {
        uint64 blockNum = uint64(bytes8(o[0:8]));
        address LpAddr = address(bytes20(o[8:28]));
        uint256 amount = uint256(bytes32(o[28:60]));
        return (LpAddr, blockNum, amount);
    }

    // Updates the verifying key hash for Brevis proof verification
    function setVkHash(bytes32 _vkHash) external onlyOwner {
        vkHash = _vkHash;
    }
}
