// SPDX-License-Identifier: MIT
/*
personal deposit cap

Contract code size exceeds 24576 bytes 
(a limit introduced in Spurious Dragon). 
This contract may not be deployable on mainnet. 
Consider enabling the optimizer (with a low "runs" value!), 
turning off revert strings, or using libraries.

where the share used:
_burnLiquidityShare(cLow, cHigh, shares, totalSupply);
_burnLendingShare(shares, totalSupply);
unusedbalance (share, totalsupply)
withdraw
deposit

*/
pragma solidity >=0.5.0;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import "@uniswap/v3-periphery/contracts/libraries/PositionKey.sol";

//import "libraries/libVialendCompound.sol";
import "libraries/lib.sol";

import "interfaces/IFeeMakerEvents.sol";
import "interfaces/IVaultDeployer.sol";

import "./ownable.sol";
import "./viaCompound.sol";
import "./viaUniswap.sol";



/// @author  ViaLend FeeMaker
/// @title   ViaLend FeeMaker
/// @notice  A Smart Contract that helps liquidity providers managing their funds on Uniswap V3 .

contract ViaLendFeeMaker is 
	Ownable,
	ViaCompound,
	ViaUniswap,
    ERC20
    
{
	
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
	

  
	IERC20 public immutable token0;
    IERC20 public immutable token1;
    
    uint256 prev0;
    uint256 prev1;

	
	constructor() ERC20("ViaLend Token0","VLT0") {
        
        ( address _vaultFactory,
         address _pool,
         address payable _weth,
         address _cToken0,
         address _cToken1,
         address _cEth,
         uint256 _protocolFee,
         uint256 _maxTotalSupply,
         int24 _maxTwapDeviation,
         uint32 _twapDuration,
		 uint8 _uniPortion) = IVaultDeployer(msg.sender).comboUniCompoundParams();
		
	    governance = msg.sender;
		
        team = msg.sender;  
        
        vaultFactory = _vaultFactory;
        
        // temporary team and governance are the same

		pool = IUniswapV3Pool(_pool);	
		
        token0 = IERC20(IUniswapV3Pool(_pool).token0());
        
        token1 = IERC20(IUniswapV3Pool(_pool).token1());

		//require (address(token0) == _weth || address(token1) == _weth)
		
        CToken0 = IcErc20(_cToken0);
        CToken1 = IcErc20(_cToken1);
        CEther = IcEther(_cEth);

        
        require(_weth != address(0), "WETH");
	
	    WETH = IWETH9(_weth);

        protocolFee = _protocolFee;

		tickSpacing = IUniswapV3Pool(_pool).tickSpacing();

        require(_protocolFee < 1e6, "PFR");

        maxTotalSupply = _maxTotalSupply;

        maxTwapDeviation = _maxTwapDeviation;

        twapDuration = _twapDuration;
        
        uniPortion =  _uniPortion ;

		require(_maxTwapDeviation > 0, "MTD");
		
        require(_twapDuration > 0, "TD");
        
    }    
    // constructor(
    //     address _pool,
    //     address payable _weth,
    //     address _cToken0,
    //     address _cToken1,
    //     address _cEth,
    //     uint256 _protocolFee,
    //     uint256 _maxTotalSupply,
    //     int24 _maxTwapDeviation,
    //     uint32 _twapDuration,
		// uint8 _uniPortion
        
    // ) ERC20("ViaLend Token0","VLT0") {

    //     governance = msg.sender;
    //     team = msg.sender;  
    //     // temporary team and governance are the same

		// pool = IUniswapV3Pool(_pool);	
		
    //     token0 = IERC20(IUniswapV3Pool(_pool).token0());
        
    //     token1 = IERC20(IUniswapV3Pool(_pool).token1());

		// //require (address(token0) == _weth || address(token1) == _weth)
		
    //     CToken0 = IcErc20(_cToken0);
    //     CToken1 = IcErc20(_cToken1);
    //     CEther = IcEther(_cEth);

        
    //     require(_weth != address(0), "WETH");
	
	   //  WETH = IWETH9(_weth);

    //     protocolFee = _protocolFee;

		// tickSpacing = IUniswapV3Pool(_pool).tickSpacing();

    //     require(_protocolFee < 1e6, "PFR");

    //     maxTotalSupply = _maxTotalSupply;

    //     maxTwapDeviation = _maxTwapDeviation;

    //     twapDuration = _twapDuration;
        
    //     uniPortion =  _uniPortion ;

		// require(_maxTwapDeviation > 0, "MTD");
		
    //     require(_twapDuration > 0, "TD");
    // }

   
    function withdraw(
        uint256 percent
    ) external  nonReentrant returns (uint256 amount0, uint256 amount1) {
        
        

		address to = msg.sender;
		
        require(to != address(0) && to != address(this), "toW");
        
        require(percent > 0 && percent <= 100, "Pcnt");
        
		_alloc();  //remove positions and dividen fees

        // calc percent shares to withdraw
        uint256 shares = balanceOf(to).mul(percent).div(100);   	
        //uint256 shares = balanceOf(to);

		// get total shares
        uint256 totalSupply = totalSupply();

        require(totalSupply > 0, "ts0");

		require(shares <= totalSupply , "sh1");

		
        amount0 = getBalance0().mul(shares).div(totalSupply);
        amount1 = getBalance1().mul(shares).div(totalSupply);

		// burn user's share
        _burn(to, shares);

        // update user's record
        if (amount0 > 0) {
        	token0.safeTransfer(to, amount0);
			Assetholder[to].deposit0 -= (Assetholder[to].deposit0 > amount0 ) ? amount0 : Assetholder[to].deposit0;
		}
        if (amount1 > 0) {
        	token1.safeTransfer(to, amount1);
			Assetholder[to].deposit1 -= (Assetholder[to].deposit1 > amount1 ) ? amount1 : Assetholder[to].deposit1;
		}

		//if ( totalSupply > 0 ) 	rebalance(0,0);
		
		//log
        emit Withdraw(msg.sender, shares, amount0, amount1);
    }
    
    /// @notice deposit amount will be adjusted to the current ratio
    function deposit(
        uint256 amountToken0,		// deposit amount of token0
        uint256 amountToken1,		// deposit amount of token1
        bool doRebalence			// whether do rebalance or not
    )
        external
        nonReentrant
    {

        address to = msg.sender;	//  to address = msg.sender

		require(amountToken0>0 || amountToken1>0,"amt0");

        require(to != address(0) && to != address(this), "to");

	
        _push(to);  			// push new address into accounts

  		
       // _poke(cLow, cHigh);		// Poke v3 positions so to get uniswap v3 fees up to date. do not need if position removed
		
		
		_alloc();				// dividen fees if any for prev users
		
		
		uint256 P = getUniswapPrice();

        (uint256 shares, uint256 amount0, uint256 amount1) = lib._calcShares(amountToken0, amountToken1, P ); 	
		
		updateOthers(P);

        // transfer tokens from sender
        if (amount0 > 0) token0.safeTransferFrom(msg.sender, address(this), amount0);
        if (amount1 > 0) token1.safeTransferFrom(msg.sender, address(this), amount1);

		
        _mint(to, shares);

        require(totalSupply() <= maxTotalSupply, "CAP");

	    Assetholder[to].deposit0 += amount0;		// add or increase msg.sender's asset0
		Assetholder[to].deposit1 += amount1;		// add or increase msg.sender's asset1

		if (doRebalence )  rebalance(0,0);		// rebalance

        emit Deposit(msg.sender, to, shares, amount0, amount1);

    }     
    
    //update Others share with current price
    function updateOthers(uint256 P ) internal {
	
			uint256 tt = totalSupply();

			if (tt <= 0 ) return;		// return totalsupply is 0 

			uint cnt = accounts.length;		// get array size 

			uint256 total0 = token0.balanceOf(address(this));
			uint256 total1 = token1.balanceOf(address(this));
		   

			for (uint i=0; i< cnt; i++) {	
				
				uint256 share = balanceOf(accounts[i]);
				
				uint256 myamount0 = total0.mul(share).div(tt);
				uint256 myamount1 = total1.mul(share).div(tt);
		        
				uint256 nshare = myamount0.add(myamount1.mul(1e18).div(P) ) ;
				
				if (nshare != share) {
				
					_burn(accounts[i], share);
					
					//#review, #debug hardcode 1e18, need to do decimals  x = y*1e18/P  
					_mint(accounts[i], nshare) ;
	
					// update user assets with new amounts
					Assetholder[accounts[i]].deposit0 = myamount0;		
					Assetholder[accounts[i]].deposit1 = myamount1;
				}
        	}
    	
    }
    
    /// allocate fees for external
    function alloc() external onlyTeam {
    	_alloc();
    }

    /// allocate fees and adjust user's share
    function _alloc() internal returns ( bool ){
		
		removePositions();		// remove all positions off v3 and lending pool


		//uint256 new0 = token0.balanceOf(address(this));	//get token0 current balance in vault 
		//uint256 new1 = token1.balanceOf(address(this));	//get token1 current balance in vault 
		
		
		uint256 _totalSupply = totalSupply();
		if (_totalSupply <=0) return false;

		if (_totalSupply > 0 ) {
			
			//*** important
			(uint256 fees0, uint256 fees1, uint256 netfees0, uint256 netfees1) = collectProtocolFees();
			
			if (fees0 == 0 && fees1==0 ) return(false);  // no fees need to be allocated

			emit MyLog4("fees",fees0,fees1,netfees0,netfees1);
		
			uint cnt = accounts.length;
		
			// update fees for each holder
			for (uint i=0; i< cnt; i++) {
				uint256 _share = balanceOf(accounts[i]);
				
				require(accounts[i]!=address(0) ,"A0");
				
				uint256 myfees0 = netfees0.mul(_share).div(_totalSupply);
				uint256 myfees1 = netfees1.mul(_share).div(_totalSupply);
			
				//record the fees in each account's total
				Assetholder[accounts[i]].fees0 += myfees0;
				Assetholder[accounts[i]].fees1 += myfees1;
			}


		} 
		
		
		return(true);  // fees are allocated
		    	
    }
    
    
    //calculate net fees and protocol fees 
	function collectProtocolFees() internal 
		returns(
			uint256 fees0, 			// total fees0  from univ3 and lending
			uint256 fees1, 			// total fess1 from univ3 and lending
			uint256 netfees0, 		// fees0 after protocol cut
			uint256 netfees1)		// fees0 after protocol cut
	{
		
		uint256 _protocolFee = protocolFee;
		
		// add up all earned fees
		fees0 = uFees0.add(lFees0);
		fees1 = uFees1.add(lFees1);
		
		uint256 feesToProtocol0;
		uint256 feesToProtocol1;
		
        if (_protocolFee > 0 )  {
        	
			// calculate protocol fees
			if (fees0 > 0 ) {
	            feesToProtocol0 = fees0.mul(_protocolFee).div(1e6);
	            netfees0 = fees0.sub(feesToProtocol0);
	            accruedProtocolFees0 = accruedProtocolFees0.add(feesToProtocol0);
			}
			
			if (fees1 > 0 ) {
	            feesToProtocol1 = fees1.mul(_protocolFee).div(1e6);
	            // generate net fees
	            netfees1 = fees1.sub(feesToProtocol1);
	            //record the protocol fees
	            accruedProtocolFees1 = accruedProtocolFees1.add(feesToProtocol1);
			}
            
            //send protocol fees to governance
            if (feesToProtocol0 > 0) token0.safeTransfer(team, feesToProtocol0);
        	if (feesToProtocol1 > 0) token1.safeTransfer(team, feesToProtocol1);

        } else {
	        netfees0 = fees0;
            netfees1 = fees1;
        }
        
 
        
	}


	
	/*
    function _calcShares(uint256 amountIn0, uint256 amountIn1)
        internal
        view
        returns (
            uint256 shares,
            uint256 amount0,
            uint256 amount1
        )
    {

		//todo, check current ratio and calc amount0 and amount1 with same ratio

		uint256 x1 = amountIn0;
		uint256 y1 = amountIn1;
		
		require(amountIn0 > 0 && amountIn1 > 0, "AMin");
		
		uint256 x = token0.balanceOf(address(this) );
		uint256 y = token1.balanceOf(address(this) );
		
		
		if (x == 0 && y == 0) {
	        (amount0, amount1 ) = (amountIn0, amountIn1);
		} else if (x == 0) {
			(amount0, amount1 ) = (0, amountIn1);
		} else if (y == 0) {
			(amount0, amount1 ) = (amountIn0, 0);
		} else {
			
			uint256 r = y.mul(1e12).div(x);
			
			uint256 r1 = y1.mul(1e12).div(x1) ;
			
			require( r>0 , "r");
			require( r1>0 , "r1");
			
			if (r > r1)  {   
				
				// y1 < x1 *price, take full y1, calc xx1
				// xx1 = y1/r1 = y1/r = y1/(y/x) 

				uint256 xx1 = y1.mul(1e12).div(r) ;		
				(amount0, amount1 ) = (xx1,y1);
				
			} else if ( r1 > r ) {	
				
				// x1 * price < y1, take full x1, calc yy1
				// yy1 = x1*r1 = x1 * r = x1 * (y/x) 	
				
				uint256 yy1 = x1.mul(r).div(1e12);		
				(amount0, amount1 ) = (x1,yy1);
	
			} else {		// y1 = x1*price, take both full amount
	
		        (amount0, amount1 ) = (amountIn0, amountIn1);
				
			}
		}
		


		//#todo get decimals , amount1 is assumed usdc with 6 decimals ,eth is 18 decimals,  so 1e12 = 1e (18-6)
		
		if (amount0 == 0) {
			shares = lib._sqrt (amount1.mul(1e12));
		}
		else if (amount1 == 0) {
				shares = lib._sqrt(amount0);
		} else {
		
			shares = lib._sqrt (amount0.mul(amount1.mul(1e12)) );
		}

        
    }    
*/
    
 /*// COMMENT OUT BECAUSE CODE SIZE EXCEEDS DEPLOYER LIMIT. MOVE TO FRONTEND

    function getTVL() public view returns (uint256 total0, uint256 total1) {
         
        (uint256 uniliq0, uint256 uniliq1) =  getPositionAmounts(cLow, cHigh);
        (uint256 lending0, uint256 lending1) =  getLendingAmounts();

		// balance remaining + liquidity + lending supply
        total0 = getBalance0().add(uniliq0).add(lending0);
        total1 = getBalance1().add(uniliq1).add(lending1);

    }

 
    function getLendingAmounts() public view returns(uint256 , uint256 ){

    	(uint256 cAmount0, uint256 cAmount1) = getCAmounts();
		
		
        //uint8 decimals0 = EIP20Interface(CToken0.underlying()).decimals();
        
        //uint8 decimals1 = EIP20Interface(CToken1.underlying()).decimals();
            
		//require(token0.decimals() ==       underlyingDecimals = EIP20Interface(cErc20.underlying()).decimals();
       //oneCTokenInUnderlying  = exchangeRateCurrent / (1 * 10 ** (18 + underlyingDecimals - cTokenDecimals))
        uint256 amount0 = cAmount0.mul(CToken0.exchangeRateStored().div(10 ** (18 + 18 - 8))  );
        uint256 amount1 = cAmount1.mul(CToken1.exchangeRateStored().div(10 ** (18 + 6 - 8) ) );

		return(amount0,amount1);
    }
    
*/    
	function removePositions() internal {
		

		(uint256 camount0, uint256 camount1) = getCAmounts();
		
		if (camount0 > 0 || camount1 > 0) {
			removeLending( address(token0), address(token1), camount0,camount1 );
		}
		
		removeUniswap();
	}
	
	

	function strategy1(
		int24 newLow,
        int24 newHigh
		) external nonReentrant onlyTeam  {
		
		
		require(totalSupply() > 0,"t0");
        
        _alloc();
        
        rebalance(newLow,newHigh);
        		
	}
	
	// make sure all position has been removed before doing rebalance. 
	// when newLow and newHigh is 0, calc new range with current cLow and cHigh
	function rebalance(
			int24 newLow,
			int24 newHigh
			) internal  {
	
      	(	,int24 tick, , , , , ) 	= pool.slot0();
    
    	if (newLow==0 && newHigh==0) {
			
			if (cHigh == 0 && cLow ==0) return;  // cannot do rebalance if cLow and cHigh is 0
			
			int24 hRange = ( cHigh - cLow ) / 2;
			
			newHigh = (tick + hRange) / tickSpacing * tickSpacing;
			newLow  = (tick - hRange) / tickSpacing * tickSpacing;
			
		}

  		_validRange(newLow, newHigh, tick);  // passed 1200 , 2100, 18382
        
        // Check price is not too close to min/max allowed by Uniswap. Price
        // shouldn't be this extreme unless something was wrong with the pool.

        //int24 range = newHigh - newLow ;
            
        // int24 twap = getTwap();
        // int24 deviation = tick > twap ? tick - twap : twap - tick;
        
        // // avoid high slipage
        // require(deviation <= maxTwapDeviation, "deviation");


        //#review todo   calc best ratio to 50:50 in uni v3
        uint256 uniPortion0 =  getBalance0().mul(uniPortion).div(100);
        uint256 uniPortion1 = getBalance1().mul(uniPortion).div(100);

		//add rest portion to uniswap
		_mintUniV3(
	        newLow,
	        newHigh,
			uniPortion0,
			uniPortion1
			);


		// get remainting assets to lending
        uint256 unUsedbalance0 = getBalance0();
        uint256 unUsedbalance1 = getBalance1();
        
        bool result = _mintCompound(address(token0), address(token1), unUsedbalance0,  unUsedbalance1);
        
        require(result, "MCp");


        // lastRebalance = block.timestamp;
        // lastTick = tick;

	}

	
    
     /// @notice Used to collect accumulated protocol fees.
    function collectProtocol(
        uint256 amount0,
        uint256 amount1,
        address to
    ) external onlyGovernance {
    	
    	require (accruedProtocolFees0 >= amount0 && accruedProtocolFees1 >= amount1,"CP");

		if (amount0 > 0) {
	        accruedProtocolFees0 = accruedProtocolFees0.sub(amount0);
	        token0.safeTransfer(to, amount0);
		}
							
        if (amount1 > 0) {
        	accruedProtocolFees1 = accruedProtocolFees1.sub(amount1);
        	token1.safeTransfer(to, amount1);
        }
    }
    
	///calculate the minimum amount for token0 and token1 to deposit
	/// todo
	// function amountMin(uint256 amount0, uint256 amount1) internal pure returns (bool){
	// 	return true; 
		
	// }
    /// @notice return Balance of available token0.
     
    function getBalance0() public view returns (uint256) {
        return token0.balanceOf(address(this));
    }


    /// @notice return Balance of available token1.
    
    function getBalance1() public view returns (uint256) {
        return token1.balanceOf(address(this));
    }   

/* CODE SIZE
    /// @notice Removes tokens accidentally sent to this vault.
    function sweep(
        IERC20 token,
        uint256 amount,
        address to
    ) external onlyGovernance {
        require(token != token0 && token != token1, "Sw");
        token.safeTransfer(to, amount);
    }

*/
     

/*    due to size
 	function sweep(
        IERC20 token,
        uint256 amount
    ) external onlyGovernance {
        require(token != token0 && token != token1, "token");
        token.safeTransfer(msg.sender, amount);
    }	
*/

	// remove all positions and send fund to each user
	// send any left over to governance
    function emergencyBurn() external onlyFactoryOwner {
			
		removePositions();	// remove all positions from uniswap and lending pool
		
		removeCTokens(); // in case assets stuck in compound


		//should remove the code below after testing

		uint cnt = accounts.length;		// get array size 
		
		uint256 total0 = token0.balanceOf(address(this));
		uint256 total1 = token1.balanceOf(address(this));
        
		uint256 tt = totalSupply();
		
		for (uint i=0; i< cnt; i++) {	
			
			uint256 share = balanceOf(accounts[i]);
	        
			_burn(accounts[i], share);

		    Assetholder[accounts[i]].deposit0 = 0;
			Assetholder[accounts[i]].deposit1 = 0;
		    
			uint256 amount0 = total0.mul( share ).div(tt);
			uint256 amount1 = total1.mul( share ).div(tt);
			

	        if (amount0 > 0) token0.safeTransfer(accounts[i], amount0);
	        if (amount1 > 0) token1.safeTransfer(accounts[i], amount1);
			
			
        }
        

		//send rest tokens to governance
		if ( token0.balanceOf(address(this)) > 0 ) 
			token0.safeTransfer(governance, token0.balanceOf(address(this))) ;

		if ( token1.balanceOf(address(this)) > 0 ) 
			token1.safeTransfer(governance, token1.balanceOf(address(this))) ;

		

    }


	/// fallback function has been split into receive() and fallback(). It is a new change of the compiler.
	fallback() external payable {}
	receive() external payable {}
}