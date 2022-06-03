pragma solidity >=0.6.6;
import "./SpaceRiders.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface ISpaceRidersRewardPool {
    function giveReward(uint256 amount) external;
}

contract SpaceRidersRewardPool is ISpaceRidersRewardPool, Ownable {
    
    address payable spaceRiderTokenAddress;

    constructor(address payable _spaceRiderTokenAddress) {
        spaceRiderTokenAddress = _spaceRiderTokenAddress;
    }

    function giveReward(uint256 amount) override external onlyOwner {
        SpaceRiders sp = SpaceRiders(spaceRiderTokenAddress);
        require(sp.balanceOf(address(this)) >= amount, "Not enough tokens");

        sp.transfer(sp.sprGameAddress(), amount);
    }
}