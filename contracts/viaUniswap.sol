// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3MintCallback.sol";
import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import "@uniswap/v3-periphery/contracts/libraries/PositionKey.sol";

import "libraries/lib.sol";
import "./ownable.sol";
import "interfaces/IFeeMakerEvents.sol";

contract ViaUniswap is 
	Ownable,
    IFeeMakerEvents,
    IUniswapV3MintCallback,
    IUniswapV3SwapCallback
    
{
	
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
	

    IUniswapV3Pool internal  pool;
    int24 internal  tickSpacing;

 
    int24 public cLow;
    int24 public cHigh;

	uint256 public uFees0;	// uniswap fee of token0 for the current position
	uint256 public uFees1;	// uniswap fee of token1 for the current position

	uint256 public curUni0;
	uint256 public curUni1;
	
    
    uint256 public accruedProtocolFees0;
    uint256 public accruedProtocolFees1;

    uint256 public AccumulateUniswapFees0;
    uint256 public AccumulateUniswapFees1;
    
  	uint256 public lastRebalance;
    int24 public lastTick;
	

    // poke to update fees from uniswap. 
    function _poke(int24 tickLower, int24 tickUpper) internal {
        (uint128 liquidity, , , , ) = _position(tickLower, tickUpper);
        if (liquidity > 0) {
            pool.burn(tickLower, tickUpper, 0);
        }
    }


	
	 // calculate price based on pair reserves
	function getUniswapPrice()
        public
        view
        returns (uint256 price)
    {
        (uint160 sqrtPriceX96,,,,,,) =  pool.slot0();
        return uint(sqrtPriceX96).mul(uint(sqrtPriceX96)).mul(1e18) >> (96 * 2);
    }


	/// collect fees and remove liquidity from Uniswap pool.
	/// @param amount0 burned amount of token0
	/// @param amount1 burned amount of token1
	/// @notice commented because currently  remove all
    // function _burnLiquidityShare(
    //     int24 tickLower,
    //     int24 tickUpper,
    //     uint256 shares,
    //     uint256 totalSupply
    // ) internal returns (uint256 amount0, uint256 amount1) {
    //     (uint128 totalLiquidity, , , , ) = _position(tickLower, tickUpper);
        
    //     //#debug require(totalSupply > 0, _hint2("t2",totalLiquidity,0,0,"") ) ;
        
    //     uint256 liquidity = uint256(totalLiquidity).mul(shares).div(totalSupply);

    //     if (liquidity > 0) {
    //         (uint256 burned0, uint256 burned1, uint256 fees0, uint256 fees1) =
    //             _burnAndCollectUnis(tickLower, tickUpper, lib._toUint128(liquidity));

    //         // Add share of fees
    //         amount0 = burned0.add(fees0.mul(shares).div(totalSupply));
    //         amount1 = burned1.add(fees1.mul(shares).div(totalSupply));
            
    //         //updateUserInfo(burned0, fees0,burned1,fees1);
            
    //     }
    // }
 
    function _mintUniV3(
        int24 newLow,
        int24 newHigh,
        uint256 amount0,
        uint256 amount1
        
    ) internal { 

        
		// Place position on Uniswap
        uint128 liquidity = _liquidityForAmounts( newLow, newHigh, amount0, amount1);
        
        //#debug require(liquidity > 0 ,append("liquidity: ",uint2str(liquidity),"","","")) ;

   
        (curUni0, curUni1) = pool.mint(address(this), newLow, newHigh, liquidity, "");

        // // uint256 newBalance0 = getBalance0();
        // // uint256 newBalance1 = getBalance1();

        // emit RebalanceLog(liquidity, newBalance0, newBalance1);

        (cLow, cHigh) = (newLow, newHigh);
        
    }
   
	
	///remove uniswap position; generate fees
	function removeUniswap() internal {
       
    	if (cLow == 0 && cHigh ==0)  return;
		
       (uint128 liquidity, , , , ) = _position(cLow, cHigh);   // get liquidity by current ticklow, tickhigh
       
 		(uint256 burned0, uint256 burned1, uint256 collect0, uint256 collect1) = _burnAndCollectUnis(cLow, cHigh, liquidity);
    
    	if (liquidity > 0) {
	        uFees0 = collect0.sub(burned0);
	       	uFees1 = collect1.sub(burned1);
	        AccumulateUniswapFees0 = AccumulateUniswapFees0 + uFees0;
	        AccumulateUniswapFees1 = AccumulateUniswapFees1 + uFees1;
        }


	}
	

	/// to be optimized , or moved offchain
	function swap( 
		int256 swapAmount, 
		bool zeroForOne ,
		uint160 sqrtPriceLimitX96 
		) public returns (int256 , int256) {


    	return pool.swap(
               address(this),
               zeroForOne,
               swapAmount,
               sqrtPriceLimitX96,
               abi.encode(msg.sender)
        );
	}
	

  
	/// @dev Fetches time-weighted average price in ticks from Uniswap pool.
    function getTwap() public view returns (int24) {
        uint32 _twapDuration = twapDuration;
        uint32[] memory secondsAgo = new uint32[](2);
        secondsAgo[0] = _twapDuration;
        secondsAgo[1] = 0;

        (int56[] memory tickCumulatives, ) = pool.observe(secondsAgo);
        return int24((tickCumulatives[1] - tickCumulatives[0]) / _twapDuration);
    }

	///@notice burn and collect 
    function _burnAndCollectUnis(
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    )
        internal
        
        returns (
            uint256 burned0,
            uint256 burned1,
   			uint256 collect0,
			uint256 collect1 

        )
    {
    	
		
        if ( liquidity > 0) {
        	( burned0, burned1) =  pool.burn(tickLower, tickUpper, liquidity) ;
        } 
        
         // Collect all owed tokens including earned fees
        (collect0,  collect1) =
            pool.collect(
                address(this),
                tickLower,
                tickUpper,
                type(uint128).max,
                type(uint128).max
            );

        
        emit CollectFees(liquidity, burned0, burned1,collect0,collect1);
        
    }    
	
    /// @dev Wrapper around `LiquidityAmounts.getLiquidityForAmounts()`.
    function _liquidityForAmounts(
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0,
        uint256 amount1
    ) internal view returns (uint128) {
        (uint160 sqrtRatioX96, , , , , , ) = pool.slot0();
        return
            LiquidityAmounts.getLiquidityForAmounts(
                sqrtRatioX96,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                amount0,
                amount1
            );
    }
    
    
     function _validRange(int24 _lower, int24 _upper, int24 _tick) internal view {
    	
		
        require(_lower < _upper, "V1");
        require(_lower < _tick , "V2");
        require(_upper > _tick , "V3");
        
        require(_lower >= TickMath.MIN_TICK, "V4");
        require(_upper <= TickMath.MAX_TICK, "V5");

        
        require(_lower % tickSpacing == 0, "V6");
        require(_upper % tickSpacing == 0, "V7");
    }

     /// @notice Used to collect accumulated protocol fees.
    
	/**
     * @notice Amounts of token0 and token1 held in vault's position. Includes
     * owed fees but excludes the proportion of fees that will be paid to the
     * protocol. Doesn't include fees accrued since last poke.
    /// @param tickLower lower line price from last rebalance, 
    /// @param tickUpper upper line price from last rebalance
     */
    function getPositionAmounts(int24 tickLower, int24 tickUpper)
        public
        view
        returns (uint256 amount0, uint256 amount1)
    {
        (uint128 liquidity, , , uint128 tokensOwed0, uint128 tokensOwed1) =
            _position(tickLower, tickUpper);
        (amount0, amount1) = _amountsForLiquidity(tickLower,tickUpper, liquidity);

        // Subtract protocol fees
        uint256 oneMinusFee = uint256(1e6).sub(protocolFee);
        amount0 = amount0.add(uint256(tokensOwed0).mul(oneMinusFee).div(1e6));
        amount1 = amount1.add(uint256(tokensOwed1).mul(oneMinusFee).div(1e6));
    }


	/// @dev Wrapper around `IUniswapV3Pool.positions()`.
    function _position(int24 tickLower, int24 tickUpper)
        internal
        view
        returns (
            uint128,
            uint256,
            uint256,
            uint128,
            uint128
        )
    {

        bytes32 positionKey = PositionKey.compute(address(this), tickLower, tickUpper);
        return pool.positions(positionKey);
        
    }
    
    /// @dev Wrapper around `LiquidityAmounts.getAmountsForLiquidity()`.
    function _amountsForLiquidity(
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) internal view returns (uint256, uint256) {
        (uint160 sqrtRatioX96, , , , , , ) = pool.slot0();
        return
            LiquidityAmounts.getAmountsForLiquidity(
                sqrtRatioX96,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                liquidity
            );
    }

	

	/// @notice vault liquidity in uniswap
    function getSSLiquidity(int24 tickLower, int24 tickUpper) external view returns(uint128 liquidity) {
    	( liquidity , , , , ) = _position(tickLower, tickUpper);
    }


	function poolAddress() public view returns (address) {
         return address(pool);
    }




 /// @dev Callback for Uniswap V3 pool
    function uniswapV3MintCallback(
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external override {
        require(msg.sender == address(pool),"PS");
        


        if (amount0 > 0) IERC20(IUniswapV3Pool(pool).token0()).safeTransfer(msg.sender, amount0);
        if (amount1 > 0) IERC20(IUniswapV3Pool(pool).token1()).safeTransfer(msg.sender, amount1);
        
    }

    /// @dev Callback for Uniswap V3 pool
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external override {
         
        require(msg.sender == address(pool),"PS2");
        

        ////#debug require(false, _hint2("deltaamount", uint256(amount0Delta),uint256(amount1Delta),0,""));
        
        if (amount0Delta > 0) IERC20(IUniswapV3Pool(pool).token0()).safeTransfer(msg.sender, uint256(amount0Delta));
        if (amount1Delta > 0) IERC20(IUniswapV3Pool(pool).token1()).safeTransfer(msg.sender, uint256(amount1Delta));
    }
}