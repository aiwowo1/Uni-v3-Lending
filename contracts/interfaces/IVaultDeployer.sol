/// SPDX-License-Identifier: MIT

pragma solidity >=0.5.6;

interface IVaultDeployer {

    function comboUniCompoundParams()
        external
        view
        returns (
        	address _vaultFactory,
            address _pool,
	         address payable _weth,
	         address _cToken0,
	         address _cToken1,
	         address _cEth,
	         uint256 _protocolFee,
	         uint256 _maxTotalSupply,
	         int24 _maxTwapDeviation,
	         uint32 _twapDuration,
			 uint8 _uniPortion
        );
/*
   function singleUniParams()
        external
        view
        returns (
            address factory,
            address token0,
            address token1,
            uint24 fee,
            int24 tickSpacing
        ); 
	*/
}
