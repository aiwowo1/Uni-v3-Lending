/// SPDX-License-Identifier: MIT
pragma solidity >0.5.6;


import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import './NoDelegateCall.sol';

import './interfaces/IVaultFactory.sol';
import './viaLendFeeMaker.sol';
import './ComboCompoundDeployer.sol';

contract vaultFactory is NoDelegateCall, IVaultFactory, ComboCompoundDeployer {
	
    address public override owner;
    address public univ3Factory;

	constructor(address _unifactory) {
        owner = msg.sender;
        univ3Factory = _unifactory ; 
    }
    
    event VaultCreated(address token0, address token1, uint24 fee, int24 tickSpacing, address _pool, address  vault); 


	function createVault(
        address token0,
        address token1,
        uint24  fee,
        address payable _weth,
		address _cToken0,
		address _cToken1,
		address _cEth,
		uint256 protocolFee,
		uint256 maxTotalSupply,
		int24 maxTwapDeviation,
		uint32 twapDuration,
		uint8 uniPortionRate
		

    ) external override noDelegateCall returns (address vault) {
        

        address _pool = IUniswapV3Factory( univ3Factory ).getPool( token0, token1, fee);
        
        require(_pool != address(0), "Pool");
        
        int24 tickSpacing = IUniswapV3Pool(_pool).tickSpacing();
        
        require(tickSpacing > 0, "FP");
        
        vault = deployComboUniCompound(
        	address(this), 
	        _pool ,
			_weth,
			_cToken0,
			_cToken1,
			_cEth,
			protocolFee,
			maxTotalSupply,
			maxTwapDeviation,
			twapDuration,
			uniPortionRate );
	        
        
        
        // emit VaultCreated(token0, token1, fee, tickSpacing, _pool, vault);
    }
    
  
    function setOwner(address _owner) external override {
        require(msg.sender == owner);
        //emit OwnerChanged(owner, _owner);
        owner = _owner;
    }
    
    
    
}
