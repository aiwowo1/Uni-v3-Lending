/// SPDX-License-Identifier: MIT

pragma solidity >=0.5.6;


interface IVaultFactory {

   function owner() external view returns (address);


/*
    function getVault(
        uint24 vaultStyle,
        address tokenA,
        address tokenB,
        uint24 fee
    ) external view returns (address vault);
*/
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
    ) external returns (address vault);

    function setOwner(address _owner) external;
    
}