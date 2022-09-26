//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


/** 
    This hacky solution is needed in order to receive the funds from selling spr->busd for auto liquidity.
    As with non "main" coin pair's you cant send the receiving funds to the same token contract if the contract is part 
    of the LP, pair limitations.
    Checkout PancakePair->swap require:
    require(to != _token0 && to != _token1, 'Pancake: INVALID_TO');
*/
contract FundProxy is Ownable {
    function sendTokenFundsBack(address tokenAddress) external onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        token.transfer(owner(), token.balanceOf(address(this)));
    }
}