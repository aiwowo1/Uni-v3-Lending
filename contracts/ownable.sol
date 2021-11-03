// SPDX-License-Identifier: MIT

pragma solidity >0.5.0;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import './interfaces/IVaultFactory.sol';

/**
* @title Ownable
* @dev The Ownable contract has an owner address, and provides basic authorization control
* functions.
*/
contract Ownable is ReentrancyGuard {

    address public governance;
    address public team;
    address public pendingGovernance;
    uint256 public protocolFee;
    
    address public vaultFactory;


     // Asset of each user.
	struct Assets  {
    	uint256 deposit0;   	// user's accumulative deposits for token0
		uint256 deposit1; 	// user's accumulative deposits for token1
		uint256 fees0;		// user's dividend of token0 from uniswap v3
		uint256 fees1;		// user's dividend of token1 from lending pool
//		uint16 block0;  	// block num of user's initial deposit
//		uint16 block1;  	// block num of user's last deposit
    }
    
    address[] public accounts;
    
    mapping(address => Assets)  public Assetholder;
    
	
    //Asset storage c = Assetholder[accounts[i]]
  	//Asset({capital0:amountToken0, capital1:0,fees0:0,fees1:0});
    
    uint256 public maxTotalSupply;
    uint32 public twapDuration;
	int24 public maxTwapDeviation;    
    
	uint8 public uniPortion ;


	
	event MyLog(string, uint256);
	event MyLog2(string, uint256,uint256);
	event MyLog4(string, uint256,uint256,uint256,uint256);



    function _push(address _address ) internal {
    	
		bool _exists= false;
		uint cnt = accounts.length;
		
		for (uint i=0; i< cnt; i++) {
			if (accounts[i] == _address) {
				_exists = true;
				break;
			}
        }
        
        if (!_exists) accounts.push(_address);

    }

	// commen out because code size exceeds 24576bytes    
    // function list() external view onlyTeam returns (address[]  memory ) {
    //     return accounts;
    // }


	///@notice set new maxTotalSupply
	function setMaxTotalSupply(uint256 newMax) external nonReentrant onlyGovernance {
			maxTotalSupply = newMax;
	}

	function setGovernance(address _governance) external onlyGovernance {
        pendingGovernance = _governance;
    }
    /**
     * @notice `setGovernance()` should be called by the existing governance
     * address prior to calling this function.
     */
    function acceptGovernance() external {
         require(msg.sender == pendingGovernance, "pendingGovernance");
        governance = msg.sender;
    }

	function setTeam(address _team) external onlyGovernance {
        team = _team;
    }
    
    modifier onlyTeam {
         require(msg.sender == team, "team");
        _;
    }

	
    modifier onlyGovernance {
         require(msg.sender == governance, "governance");
        _;
    }
    
    

    function setMaxTwapDeviation(int24 _maxTwapDeviation) external onlyTeam {
         require(_maxTwapDeviation > 0, "maxTwapDeviation");
        maxTwapDeviation = _maxTwapDeviation;
    }

    function setTwapDuration(uint32 _twapDuration) external onlyTeam {
         require(_twapDuration > 0, "twapDuration");
        twapDuration = _twapDuration;
    }
    
    function setUniPortionRatio(uint8 ratio) external onlyTeam {
    	require (ratio <= 100,"ratio");
		uniPortion = ratio;
    }

    function setProtocolFee(uint256 _protocolFee) external onlyGovernance {
        require(_protocolFee < 1e6, "protocolFee");
        protocolFee = _protocolFee;
    }
    
	function getETHBalance() public view returns (uint256) {
         return address(this).balance;
    }

	// /// return capital amount
	function getStoredAssets(address who) public view returns( uint256 , uint256,uint256, uint256 ) {
	   	return (
			Assetholder[who].deposit0,
			Assetholder[who].deposit1 , 
			Assetholder[who].fees0 , 
			Assetholder[who].fees1 );
	}


    /// @dev Prevents calling a function from anyone except the address returned by IUniswapV3Factory#owner()
    modifier onlyFactoryOwner() {
        require(msg.sender == IVaultFactory(vaultFactory).owner(), "fOwner");
        _;
    }
    



}
