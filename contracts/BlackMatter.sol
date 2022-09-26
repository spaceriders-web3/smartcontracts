// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {UserAddLiquidity} from "./Structs.sol";
import "./FundProxy.sol";

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}

contract BlackMatter is Ownable, ERC20 {
    
    string public NAME = "BlackMatter";
    string public SYMBOL = "BKM";
    
    bool public inSwapAndLiquify;
    address public busdAddress;
    address public fundProxyAddress;
    address public gameAddress;

    constructor(address _busdAddress) ERC20(NAME, SYMBOL) {
        _mint(msg.sender, 1000000000 * (10 ** decimals()));
        busdAddress = _busdAddress;
    }

    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    modifier onlySprGame {
        require(msg.sender == gameAddress, "CALLER: Only Spr Game allowed");
        _;
    }

    function setFundProxy(address _fundProxy) external onlyOwner {
        fundProxyAddress = _fundProxy;
    }

    function setGameAddress(address _gameAddress) external onlyOwner {
        gameAddress = _gameAddress;
    }

    //sp.addBusdLiquidity("100000000000000000000000", {value: web3.utils.toWei("1", "ether")})
    function addBusdLiquidity (address routerAddr, uint256 sprAmount, uint256 busdAmount) external payable lockTheSwap {
        IERC20 busd = IERC20(busdAddress);
        IUniswapV2Router02 router = IUniswapV2Router02(routerAddr);

        _transfer(msg.sender, address(this), sprAmount);
        busd.transferFrom(msg.sender, address(this), busdAmount);
        
        _approve(address(this), routerAddr, sprAmount);
        busd.approve(address(router), busdAmount);
        
        // Add liquidity and send LP to sender.
        router.addLiquidity(
            address(this),
            busdAddress,
            sprAmount,
            busdAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            msg.sender,
            block.timestamp
        );
    }


    function _sellTokenForBusd(IUniswapV2Router02 router, uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> wbnb
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = busdAddress;

        _approve(address(this), address(router), tokenAmount);
        
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            fundProxyAddress,
            block.timestamp
        );
        
        FundProxy(fundProxyAddress).sendTokenFundsBack(busdAddress);
    }

    function _buySprTokenWithBusd(IUniswapV2Router02 router, uint256 tokenAmount) private {
        IERC20 busd = IERC20(busdAddress);

        address[] memory path = new address[](2);
        path[0] = busdAddress;
        path[1] = address(this);

        busd.approve(address(router), tokenAmount);
        
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of SPR
            path,
            fundProxyAddress,
            block.timestamp
        );
        
        FundProxy(fundProxyAddress).sendTokenFundsBack(address(this));
    }

    function userRemoveLiquidity(address routerAddr, address pair, uint256 lpAmount, address receiver) external lockTheSwap onlySprGame {
        
        IUniswapV2Router02 router = IUniswapV2Router02(routerAddr);
        IERC20(pair).approve(routerAddr, lpAmount);
        (uint sprReceived, uint busdReceived) = router.removeLiquidity(
            address(this),
            busdAddress,
            lpAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            fundProxyAddress,
            block.timestamp
        );

        FundProxy(fundProxyAddress).sendTokenFundsBack(address(this));
        FundProxy(fundProxyAddress).sendTokenFundsBack(busdAddress);
        
        uint256 previousSprBalance = balanceOf(address(this));
    
        // Buy back $BKM with the BUSD we got
        _buySprTokenWithBusd(router, busdReceived);
        uint256 purchasedSpr = balanceOf(address(this)) - previousSprBalance;

        // Total we got from undoing the LP + buying back $BKM
        uint256 totalSprBack = sprReceived+purchasedSpr;
    
        _transfer(address(this), receiver, totalSprBack);
    }

    function userAddLiquidity(address _wallet, address _routerAddr, uint256 _sprAmount) external lockTheSwap onlySprGame returns (UserAddLiquidity memory) {        
        require(_sprAmount <= balanceOf(_wallet), "Not enough funds");

        IUniswapV2Router02 router = IUniswapV2Router02(_routerAddr);
        IERC20 busd = IERC20(busdAddress);

        IUniswapV2Factory factory = IUniswapV2Factory(router.factory());

       
        // Move funds from user to smart contract to be able to sell and make LP
        _transfer(_wallet, address(this), _sprAmount);

        uint256 half = _sprAmount / 2;

        _approve(address(this), address(router), _sprAmount);

        uint256 initialBusdBalance = busd.balanceOf(address(this));
        _sellTokenForBusd(router, half);
        uint256 newBusdBalance = busd.balanceOf(address(this)) - initialBusdBalance;
        
        busd.approve(address(router), newBusdBalance);
        _approve(address(this), address(router), _sprAmount);

        (,, uint liquidity) = router.addLiquidity(
            address(this),
            busdAddress,
            half,
            newBusdBalance,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            gameAddress,
            block.timestamp
        );

        return UserAddLiquidity({
            wallet: _wallet,
            lpAmount: liquidity,
            router: address(router),
            pair: factory.getPair(address(this), busdAddress)
        });
    }
}