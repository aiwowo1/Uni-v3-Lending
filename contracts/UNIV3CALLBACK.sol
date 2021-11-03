// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;


import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3MintCallback.sol";
import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";


contract UniV3Callback is 
	ViaUniswap,
	IUniswapV3MintCallback,
	IUniswapV3SwapCallback
    
{

}
