/// SPDX-License-Identifier: MIT
pragma solidity >=0.5.6;

import './interfaces/IVaultDeployer.sol';

import './viaLendFeeMaker.sol';

contract ComboCompoundDeployer is IVaultDeployer {
	
    struct ComboUniCompoundParams {
    	address _vaultFactory;
		address _pool;
		address payable _weth;
		address _cToken0;
		address _cToken1;
		address _cEth;
		uint256 protocolFee;
		uint256 maxTotalSupply;
		int24 maxTwapDeviation;
		uint32 twapDuration;
		uint8 uniPortionRate;
    }

    //SingleUniParams public override singleUniParams;
    
    ComboUniCompoundParams public override comboUniCompoundParams;

  
    function deployComboUniCompound(
    	address _vaultFactory,
    	address _pool,
         address payable _weth,
         address _cToken0,
         address _cToken1,
         address _cEth,
         uint256 protocolFee,
         uint256 maxTotalSupply,
         int24 maxTwapDeviation,
         uint32 twapDuration,
		 uint8 uniPortionRate
		
    ) internal returns (address vault) {

        comboUniCompoundParams = ComboUniCompoundParams({
        	_vaultFactory: _vaultFactory,
   	    	_pool: _pool,
			_weth: _weth,
			_cToken0: _cToken0,
			_cToken1:_cToken1,
			_cEth:_cEth,
			protocolFee:protocolFee,
			maxTotalSupply:maxTotalSupply,
			maxTwapDeviation:maxTwapDeviation,
			twapDuration:twapDuration,
			uniPortionRate:uniPortionRate
			});
			
        vault = address(new ViaLendFeeMaker{salt: keccak256(abi.encode(
        	_vaultFactory,
        	_pool,
			_weth,
			_cToken0,
			_cToken1,
			_cEth,
			protocolFee,
			maxTotalSupply,
			maxTwapDeviation,
			twapDuration,
			uniPortionRate
			
			))}());
			
        delete comboUniCompoundParams;
    }
}
