// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "hardhat/console.sol";
import "./SprFundProxy.sol";
import {UserAddLiquidity} from "./Structs.sol";
import { OnlyBackend as OB } from "./Library/OnlyBackend.sol";

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

interface IPancakeFactory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;

    function INIT_CODE_PAIR_HASH() external view returns (bytes32);
}

contract SpaceRiders is Ownable, IERC20 {
    using OB for address;
    using SafeMath for uint256;

    struct Balance {
        uint256 tradeableBalance;
        uint256 playableBalance;
    }

    mapping(address => Balance) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 public constant override totalSupply = 100000000000000000000000000;
    string public constant name = "SpaceRiders";
    string public constant symbol = "SPR";
    uint8  public constant decimals  = 18;

    ERC721 public sprNft;
    address public busdAddress;
    address public sprGameAddress;
    address public sprRewardPoolAddress;
    uint256 public minAmountToLiquify = 10 * (10**decimals);
    
    bool public purchasingPowerEnabled = true;
    uint256 public maxUsdPurchasePerPlanetNft = 300;
    
    // maxUsdPurchasePerPlanetNft + user wallet => amount
    mapping(address => uint256) public extraPurchasingPower;
    
    bool public liquifyEnabled = true;
    bool public isTokenTaxEnabled = true;
    uint256 public lpTax = 2;
    uint256 public burnTax = 2;
    uint256 public rewardPoolTax = 1;
    bool public inSwapAndLiquify;

    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;

    // Whitelist from 50/50 mark system
    mapping (address => bool) public whitelistedAddresses;
    
    // router address => bool
    mapping (address => bool) public dexAddress;
    address[] public dexAddresses;

    // is pair address => bool
    mapping (address => bool) public pairAddress;
    
    // pair to router mapping
    mapping (address => address) public pairDexAddress;

    // router address => pair address
    mapping (address => address) public dexPairAddress;

    address public sprFundProxyAddress;

    address public backendSignerAddress;

    constructor(address _sprNftAddress, address _busdAddress) {
        sprNft = ERC721(_sprNftAddress);
        busdAddress = _busdAddress;

        // Mint all the supply to the deployer. With this we can remove the mint function.
        // No more $SPR can be minted ever not even by the owner.
        _balances[msg.sender].tradeableBalance += totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);

        whitelistedAddresses[address(this)] = true;
        whitelistedAddresses[msg.sender] = true;
    }

    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    modifier onlySprGame {
        require(msg.sender == sprGameAddress, "CALLER: Only Spr Game allowed");
        _;
    }

    receive() external payable {}

    function setWhitelistedAddresses(address _addr, bool _exclude) external onlyOwner {
        whitelistedAddresses[_addr] = _exclude;
    }

    function setSprFundProxy(address _sprFundProxy) external onlyOwner {
        sprFundProxyAddress = _sprFundProxy;
        whitelistedAddresses[_sprFundProxy] = true;
    }

    function setSprRewardPoolAddress(address _sprRewardPoolAddress) external onlyOwner {
        sprRewardPoolAddress = _sprRewardPoolAddress;
    }

    function setIsTokenTaxEnabled(bool _isTokenTaxEnabled) external onlyOwner{
        isTokenTaxEnabled = _isTokenTaxEnabled;
    }

    function setMaxUsdPurchasePerPlanetNft(uint256 _maxUsdPurchasePerPlanetNft) external onlyOwner {
        maxUsdPurchasePerPlanetNft = _maxUsdPurchasePerPlanetNft;
    }

    function setPurchasingPowerEnabled(bool _purchasingPowerEnabled) external onlyOwner {
        purchasingPowerEnabled = _purchasingPowerEnabled;
    }

    function setSprGameAddress(address _sprGameAddress) external onlyOwner {
        sprGameAddress = _sprGameAddress;
    }

    function setLiquifyEnabled(bool _liquifyEnabled) external onlyOwner {
        liquifyEnabled = _liquifyEnabled;
    }

    function setRewardPoolTax(uint256 _rewardPoolTax) external onlyOwner {
        require(_rewardPoolTax <= 5, "Max REWARD POOL TAX 5%");
        rewardPoolTax = _rewardPoolTax;
    }

    function setBackendSignerAddress(address _backendSignerAddress) external onlyOwner {
        backendSignerAddress = _backendSignerAddress;
    }

    function setLpTax(uint256 _lpTax) external onlyOwner {
        require(_lpTax <= 5, "Max LP TAX 5%");
        lpTax = _lpTax;
    }

    function setBurnTax(uint256 _burnTax) external onlyOwner {
        require(_burnTax <= 5, "Max BURN TAX 5%");
        burnTax = _burnTax;
    }

    function addDex(address routerAddress, address pair) external onlyOwner {
        require(!dexAddress[routerAddress], "DEX exists");
        
        dexAddresses.push(routerAddress);
        dexAddress[routerAddress] = true;
        pairAddress[pair] = true;
        dexPairAddress[routerAddress] = pair;
        pairDexAddress[pair] = routerAddress;
    }

    function setMinAmountToLiquify(uint256 _minAmountToLiquify) external onlyOwner {
        require(_minAmountToLiquify >= 10 * (10**decimals), "Min liq. >= 10 ");
        minAmountToLiquify = _minAmountToLiquify;
    }

    function addPurchasingPower(address _wallet, uint256 _amount) external onlySprGame {
        extraPurchasingPower[_wallet] += _amount;
    }

    function purchasingPowerAmount(address _wallet) view external returns (uint256) {
        return maxUsdPurchasePerPlanetNft + extraPurchasingPower[_wallet];
    }
    
    function userRemoveLiquidity(address routerAddr, UserAddLiquidity memory userAddLiquidity) external lockTheSwap onlySprGame {
        IUniswapV2Router02 router = IUniswapV2Router02(routerAddr);
        IERC20(userAddLiquidity.pair).approve(routerAddr, userAddLiquidity.lpAmount);
        (uint sprReceived, uint busdReceived) = router.removeLiquidity(
            address(this),
            busdAddress,
            userAddLiquidity.lpAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            sprFundProxyAddress,
            block.timestamp
        );

        SprFundProxy(sprFundProxyAddress).sendTokenFundsBack(address(this));
        SprFundProxy(sprFundProxyAddress).sendTokenFundsBack(busdAddress);
        
        uint256 previousSprBalance = balanceOf(address(this));
        // Buy back $SPR with the BUSD we got
        _buySprTokenWithBusd(router, busdReceived);
        uint256 purchasedSpr = balanceOf(address(this)).sub(previousSprBalance);

        // Total we got from undoing the LP + buying back $SPR
        uint256 totalSprBack = sprReceived+purchasedSpr;
        console.log("totalSprBack %", totalSprBack);

        // Calculate difference from previous token amount
        (uint256 newTradeableBalance, uint256 newPlayableBalance) = _recalculateNewBalance(totalSprBack, userAddLiquidity);
        
        console.log("newTradeableBalance %", newTradeableBalance);
        console.log("newPlayableBalance %", newPlayableBalance);
        console.log("(newTradeableBalance+newPlayableBalance) <= totalSprBack %", (newTradeableBalance+newPlayableBalance) <= totalSprBack);
        
        // Something fucked up.
        require((newTradeableBalance+newPlayableBalance) <= totalSprBack, "If you see this, its probably a bug");

        _balances[address(this)].tradeableBalance -= totalSprBack;
        _balances[userAddLiquidity.user].tradeableBalance += newTradeableBalance;
        _balances[userAddLiquidity.user].playableBalance += newPlayableBalance;

        emit Transfer(address(this), userAddLiquidity.user, newTradeableBalance);
    }

    function _recalculateNewBalance(uint256 totalSprBack, UserAddLiquidity memory userAddLiquidity) private view returns(uint256 newTradeableBalance, uint256 newPlayableBalance) {
        uint256 originalTradeableBalance = userAddLiquidity.tradeableBalance;
        uint256 originalPlayableBalance = userAddLiquidity.playableBalance;
        uint256 originalTotalTokenAmount = originalTradeableBalance + originalPlayableBalance;

        if (totalSprBack == originalTotalTokenAmount) {
            newTradeableBalance = originalTradeableBalance;
            newPlayableBalance = originalPlayableBalance;

        } else if (totalSprBack < originalTotalTokenAmount) {
            uint256 difference = originalTotalTokenAmount-totalSprBack;
            console.log("difference %s", difference);
            uint256 rest = difference%2;
            console.log("rest %s", rest);

            uint256 halfDiff = difference+rest;
            console.log("halfDiff %s", halfDiff);
            halfDiff = halfDiff.div(2);
            console.log("halfDiff %s", halfDiff);


            if (halfDiff <= originalTradeableBalance && halfDiff <= originalPlayableBalance) {
                console.log("RT2");
                
                newTradeableBalance = originalTradeableBalance-halfDiff;
                console.log("newTradeableBalance %s", newTradeableBalance);

                newPlayableBalance = originalPlayableBalance-halfDiff;
                console.log("newPlayableBalance %s", newPlayableBalance);


            } else if (halfDiff <= originalTradeableBalance && halfDiff > originalPlayableBalance) {
                console.log("RT2");

                uint ptDiff = halfDiff - originalPlayableBalance;
                newTradeableBalance = originalTradeableBalance - (halfDiff + ptDiff);
                newPlayableBalance = 0;
                
            } else if (halfDiff > originalTradeableBalance && halfDiff <= originalPlayableBalance) {
            console.log("RT3");

                uint ttDiff = halfDiff - originalTradeableBalance;
                newPlayableBalance = originalPlayableBalance-(halfDiff + ttDiff);
                newTradeableBalance = 0;
            }

        } else if (totalSprBack > originalTotalTokenAmount) {
            console.log("RT4");

            uint256 difference = totalSprBack-originalTotalTokenAmount;
            uint256 halfDiff = difference.div(2);
            
            newTradeableBalance = originalTradeableBalance+halfDiff;
            newPlayableBalance = originalPlayableBalance+halfDiff;
        }
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
            sprFundProxyAddress,
            block.timestamp
        );
        
        SprFundProxy(sprFundProxyAddress).sendTokenFundsBack(address(this));
    }
    

    function userAddLiquidity(address user, address routerAddr, uint256 sprAmount) external lockTheSwap onlySprGame returns (UserAddLiquidity memory) {        
        require(sprAmount <= totalBalanceOf(user), "Not enough funds");

        IUniswapV2Router02 router = IUniswapV2Router02(routerAddr);
        IERC20 busd = IERC20(busdAddress);

        IUniswapV2Factory factory = IUniswapV2Factory(router.factory());

        uint256 tradeableBalance = 0;
        uint256 playableBalance = 0;
        if (tradeableBalanceOf(user) >= sprAmount) {
            tradeableBalance = sprAmount;
        } else {
            tradeableBalance = tradeableBalanceOf(user);
            playableBalance = sprAmount - tradeableBalance;
        }

        // Move funds from user to smart contract to be able to sell and make LP
        _balances[user].playableBalance -= playableBalance;
        _balances[user].tradeableBalance -= tradeableBalance;
        _balances[address(this)].tradeableBalance += tradeableBalance+playableBalance;

        emit Transfer(user, address(this), sprAmount);

        uint256 half = sprAmount.div(2);

        _approve(address(this), address(router), sprAmount);

        uint256 initialBusdBalance = busd.balanceOf(address(this));
        _sellTokenForBusd(router, half);
        uint256 newBusdBalance = busd.balanceOf(address(this)).sub(initialBusdBalance);
        
        busd.approve(address(router), newBusdBalance);
        _approve(address(this), address(router), sprAmount);

        (,, uint liquidity) = router.addLiquidity(
            address(this),
            busdAddress,
            half,
            newBusdBalance,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            sprGameAddress,
            block.timestamp
        );

        return UserAddLiquidity({
            user: user,
            lpAmount: liquidity,
            tradeableBalance: tradeableBalance,
            playableBalance: playableBalance,
            router: address(router),
            pair: factory.getPair(address(this), busdAddress)
        });
    }

    // Function to add BNB/SPR liquidity easily.
    //sp.addBnbLiquidity("100000000000000000000000", {value: web3.utils.toWei("1", "ether")})
    function addBnbLiquidity (address routerAddr, uint256 sprAmount, uint256 busdAmount) external payable lockTheSwap {
        IERC20 busd = IERC20(busdAddress);
        IUniswapV2Router02 router = IUniswapV2Router02(routerAddr);

        _normalTransfer(msg.sender, address(this), sprAmount);
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

    function balanceOf(address account)
        public
        view
        virtual
        override
        returns (uint256)
    {
        // Hack for DEXs to avoid needing slippage due to having 2 accountabilities for each account.
        if (dexAddress[msg.sender] || whitelistedAddresses[msg.sender]) {
            return _balances[account].tradeableBalance + _balances[account].playableBalance;
        }
        
        return _balances[account].tradeableBalance;
    }

    function playableBalanceOf(address account)
        public
        view
        virtual
        returns (uint256)
    {
        return _balances[account].playableBalance;
    }

    function tradeableBalanceOf(address account)
        public
        view
        virtual
        returns (uint256)
    {
        return _balances[account].tradeableBalance;
    }

    function totalBalanceOf(address account)
        public
        view
        virtual
        returns (uint256)
    {
        return (_balances[account].tradeableBalance +
            _balances[account].playableBalance);
    }

    function transfer(address recipient, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        uint256 currentAllowance = _allowances[sender][msg.sender];
        require(
            currentAllowance >= amount,
            "ERC20: transfer amount exceeds allowance"
        );

        unchecked {
            _approve(sender, msg.sender, currentAllowance - amount);
        }

        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            msg.sender,
            spender,
            _allowances[msg.sender][spender] + addedValue
        );
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        returns (bool)
    {
        uint256 currentAllowance = _allowances[msg.sender][spender];
        require(
            currentAllowance >= subtractedValue,
            "ERC20: decreased allowance below zero"
        );
        unchecked {
            _approve(msg.sender, spender, currentAllowance - subtractedValue);
        }

        return true;
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
            sprFundProxyAddress,
            block.timestamp
        );
        
        SprFundProxy(sprFundProxyAddress).sendTokenFundsBack(busdAddress);
    }

    function _addLiquidity(IUniswapV2Router02 router, uint256 tokenAmount, uint256 bnbAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(router), tokenAmount);
        
        IERC20 busd = IERC20(busdAddress);
        busd.approve(address(router), bnbAmount);

        router.addLiquidity(
            address(this),
            busdAddress,
            tokenAmount,
            bnbAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner(),
            
            block.timestamp
        );
    }

    function _liquify(address routerAddress) private lockTheSwap {
        IUniswapV2Router02 router = IUniswapV2Router02(routerAddress);
        IERC20 busd = IERC20(busdAddress);

        uint256 balance = balanceOf(address(this));
        uint256 half = balance.div(2);
        uint256 otherHalf = balance.sub(half);

        // Sell half of $SPR
        uint256 initialBusdBalance = busd.balanceOf(address(this));

        // generate the uniswap pair path of token -> wbnb
        _sellTokenForBusd(router, half);

        // how much BUSD did we received
        uint256 newBusdBalance = busd.balanceOf(address(this)).sub(initialBusdBalance);
        _addLiquidity(router, otherHalf, newBusdBalance);
    }
    
    /**
     * Calculate how many tokens the user can still buy/hold (in usd value) depending on how many planet NFT's he has.
     * + The planet level's up he had also
     */
    function purchasingPower(address routerAddr, address buyer) public view returns(uint256) {
        IUniswapV2Router02 router = IUniswapV2Router02(routerAddr);

        // change this test array lenght from 7 to 20
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = busdAddress;

        uint256 sprUsdCost = (router.getAmountsOut(10**18, path))[1];

        uint256 multiplier = sprNft.balanceOf(buyer);
        if (multiplier < 1) {
            multiplier = 1;
        }
        
        uint256 usdAmount = maxUsdPurchasePerPlanetNft + extraPurchasingPower[buyer];
        uint256 tokAmount = 0;
        unchecked {
            tokAmount = (((usdAmount*multiplier)*10**18)/(sprUsdCost));
        }
        
        uint purchasingPowerLeft = (tokAmount*(10**decimals));

        if (totalBalanceOf(buyer) > purchasingPowerLeft) {
            purchasingPowerLeft = 0;
        } else {
            purchasingPowerLeft -= totalBalanceOf(buyer);
        }

        return purchasingPowerLeft;
    }

    function _dexTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) private {
        require(
            _balances[sender].tradeableBalance >= amount,
            "ERC20: transfer amount exceeds balance"
        );

        unchecked {
            _balances[sender].tradeableBalance -= amount;
        }

        if (isTokenTaxEnabled) {
            uint256 lpAmount = amount.div(100).mul(lpTax);
            uint256 burnAmount = amount.div(100).mul(burnTax);
            uint256 rewardPool = amount.div(100).mul(rewardPoolTax);

            // Rest LP, Burn fee & Reward Pool
            amount -= lpAmount+burnAmount+rewardPool;

            _balances[address(this)].tradeableBalance += lpAmount;
            _balances[DEAD].tradeableBalance += burnAmount;
            _balances[sprRewardPoolAddress].tradeableBalance += rewardPool;

            emit Transfer(sender, address(this), lpTax);
            emit Transfer(address(this), DEAD, burnAmount);
            emit Transfer(sender, sprRewardPoolAddress, rewardPool);
        }

        // Adding 50/50 to each balance to the user
        // if sender is router we know that user bought
        if (pairAddress[sender]) {
            if (purchasingPowerEnabled) {
                uint256 maxTokenPurchaseAmount = purchasingPower(pairDexAddress[sender], recipient);
                require(amount <= maxTokenPurchaseAmount, "Not holding enough Planet Nfts");
            }

            uint256 toAdd = amount.div(100).mul(50);
            _balances[recipient].tradeableBalance += toAdd;
            _balances[recipient].playableBalance += toAdd;
            // Only make 50% of the purchase visible (tradeable balance).
            emit Transfer(sender, recipient, toAdd);

        // User selling to DEX, add 100% to tradeBalance for the router
        } else if (pairAddress[recipient]) {
            _balances[recipient].tradeableBalance += amount;
            emit Transfer(sender, recipient, amount);
        }
    }

    function _normalTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) private {
        uint256 senderBalance = _balances[sender].tradeableBalance;
        require(
            senderBalance >= amount,
            "ERC20: transfer amount exceeds balance"
        );

        unchecked {
            _balances[sender].tradeableBalance = senderBalance - amount;
        }

        _balances[recipient].tradeableBalance += amount;
        emit Transfer(sender, recipient, amount);
    }

    function _transferToSprGame(
        address sender,
        uint256 amount
    ) private { 
        uint256 senderBalance = _balances[sender].tradeableBalance +
                _balances[sender].playableBalance;

        require(
            senderBalance >= amount,
            "ERC20: transfer amount exceeds balance"
        );

        uint256 tmpAmount = amount;
        if (amount > _balances[sender].playableBalance) {
            tmpAmount -= _balances[sender].playableBalance;
            _balances[sender].playableBalance = 0;
            _balances[sender].tradeableBalance -= tmpAmount;
            _balances[sprGameAddress].tradeableBalance += amount;
            emit Transfer(sender, sprGameAddress, amount);
        } else {
            _balances[sender].playableBalance -= amount;
            _balances[sprGameAddress].tradeableBalance += amount;
            /*
                A small "workaround" since we dont want to see balance transactions
                from 'playableBalance', but we do want to keep track on the smart contract
                of how much tokens it has. This is so we dont make visible users "playable" balance
            */
            emit Transfer(address(0), sprGameAddress, amount);
        }
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) private {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        // Only liquify when selling
        // recent additions:
        // - whitelist 
        // msg.sender is router
        if (
            dexAddress[msg.sender] &&
            !inSwapAndLiquify &&
            !pairAddress[sender] &&
            liquifyEnabled &&
            balanceOf(address(this)) >= minAmountToLiquify &&
            !(whitelistedAddresses[sender] || whitelistedAddresses[recipient])
        ) {
            console.log("liquifi");
            // msg.sender in this context is router.
            _liquify(msg.sender);
        }

        // 1. User buying/selling from DEX
        if ( (pairAddress[sender] || pairAddress[recipient]) && !(whitelistedAddresses[sender] || whitelistedAddresses[recipient])) {
            console.log("T1");
            
            _dexTransfer(sender, recipient, amount);
        // 2. User depositing to SPR game
        } else if (recipient == sprGameAddress) {
            console.log("T2");

            _transferToSprGame(sender, amount);
        } else {
            console.log("T3");

            _normalTransfer(sender, recipient, amount);
        }
        
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
}