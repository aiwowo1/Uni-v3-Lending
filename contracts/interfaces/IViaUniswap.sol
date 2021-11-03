/// SPDX-License-Identifier: MIT

pragma solidity >=0.5.6;


interface IViaUniswap {

   function _position(tickLower, tickUpper); external view returns (address);
}