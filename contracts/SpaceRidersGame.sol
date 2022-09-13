pragma solidity >=0.6.6;

import "./BlackMatter.sol";
import {UserStaking, Transaction, PlanetData, ConversionRequests, UserAddLiquidity} from "./Structs.sol";
import "./PlanetNft.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";

import { OnlyBackend as OB } from "./Library/OnlyBackend.sol";
import { SafeMath } from "./Library/SafeMath.sol";

contract SpaceRidersGame is Ownable {
    using OB for address;
    using SafeMath for uint256;

    ////////// GENERAL /////////////
    address DEAD = 0x000000000000000000000000000000000000dEaD;
    
    // Fee Wallet
    address payable feeWallet;

    // Contract addresses
    address payable blackMatterTokenAddress;
    address spaceRidersPlanetNFT;

    // Backend API address to verify signatures 
    address public backendAddress;

    // Fixed TX BNB fee (for all IG transactions)
    uint256 public bnbFee = 0.0025 ether;

    ////////// END GENERAL /////////////

    ////////// BENEFIT STAKING /////////////
    bool benefitStakingEnabled = true;

    // Map planet id to staking request
    mapping(string => UserStaking) public userStaking;
    
    // Map planet id to liquidity info
    mapping(string => UserAddLiquidity) public userStakingLpInfo;

    /*
        Performance fee in basis points.
        Calculates fees, fee represented in basis points, eg:
        5% = 5*100 = 500 / 10000 = 0.05
        0.05 is then used to calculate the percentage
    */
    uint256 benefitStakingPerformanceFeeBP = 50; // 0.5%

    ////////// END BENEFIT STAKING /////////////

    ////////// ENERGY DEPOSITS /////////////
    mapping(string => Transaction) public energyDeposits;

    // Mapping planet address to energy deposits guids
    mapping(string => string[]) public energyDepositsMap;

    bool enableEnergyDepositDeposits = true;
    ////////// END ENERGY DEPOSITS /////////////


    ////////// BKM DEPOSITS /////////////
    mapping(string => Transaction) public bkmTransactions;

    // Mapping planet address to energy deposits guids
    mapping(string => string[]) public bkmTransactionMap;

    bool enableBkmDeposit = true;
    bool enableBkmWithdraws = true;
    uint256 bkmFee = 1;
    ////////// END BKM DEPOSITS /////////////

    ////////// PLANET PURCHASES /////////////

    // Allow to buy planets
    bool public enablePlanetPurchases = true;
    
    // Allow to fusion planets
    bool public enablePlanetFusion = false;
    
    // Allow planet trading
    bool public enablePlanetTrading = false;
    mapping(string => bool) public togglePlanetTradingRequests;

    ////////// END PLANET PURCHASES /////////////

    constructor(
        address payable _blackMatterTokenAddress,
        address _spaceRidersPlanetNFT,
        address payable _feeWallet, 
        address _backendAddress
    ) {
        blackMatterTokenAddress = _blackMatterTokenAddress;
        spaceRidersPlanetNFT = _spaceRidersPlanetNFT;
        feeWallet = _feeWallet;
        backendAddress = _backendAddress;
    }

    function getBlackMatter() private view returns (BlackMatter) {
        return BlackMatter(blackMatterTokenAddress);
    }

    ////////// GENERAL /////////////
    function changeBnbFee(uint256 newBnbFee) external onlyOwner {
        bnbFee = newBnbFee;
    }

    function setBackendAddress(address backendSignerAddress) external onlyOwner {
        backendAddress = backendSignerAddress;
    }

    function setFeeWallet(address payable newFeeWallet) external onlyOwner {
        feeWallet = newFeeWallet;
    }
    
    function setBenefitStakingPerformanceFeeBP(uint256 newFee)
        external
        onlyOwner
    {
        benefitStakingPerformanceFeeBP = newFee;
    }

    function setBenefitStakingEnabled(bool enabled) external onlyOwner {
        benefitStakingEnabled = enabled;
    }

    function unstakingRequestV2(string calldata planetId) external payable {
        require(
            userStaking[planetId].staked,
            "You are not staking, no withdrawal available."
        );
        require(
            block.timestamp > userStaking[planetId].timeRelease,
            "Staking period is not finished."
        );
        
        require(userStaking[planetId].owner == msg.sender, "Not your staking.");
        require(msg.value == bnbFee, "Not send enough BNB's");
        
        feeWallet.transfer(bnbFee);

        userStaking[planetId].time = 0;
        userStaking[planetId].timeRelease = 0;
        userStaking[planetId].planetId = "";
        userStaking[planetId].tier = "";
        userStaking[planetId].amount = 0;
        userStaking[planetId].staked = false;
        
        address receiver = userStakingLpInfo[planetId].wallet;
        uint256 lpAmount = userStakingLpInfo[planetId].lpAmount;
        address router = userStakingLpInfo[planetId].router;
        address pair = userStakingLpInfo[planetId].pair;
        
        userStakingLpInfo[planetId].lpAmount = 0;
        userStakingLpInfo[planetId].router = address(0);
        userStakingLpInfo[planetId].pair = address(0);

        BlackMatter sp = getBlackMatter();

        IERC20(pair).transfer(address(sp), lpAmount);
        sp.userRemoveLiquidity(router, pair, lpAmount, receiver);
    }

    function stakingRequestV2(
        OB.signatureData calldata sD,
        string calldata planetId,
        uint256 amount,
        string calldata tier,
        uint256 timeRelease,
        address router
    ) external payable { 
        BlackMatter sp = getBlackMatter();

        require(benefitStakingEnabled, "Staking is not enabled.");
        require(!userStaking[planetId].staked, "Only 1 staking at once.");
        require(timeRelease > block.timestamp, "Time cant be less than current time");
        require(sp.balanceOf(msg.sender) >= amount, "Not enough tokens.");
        require(msg.value == bnbFee, "Not send enough BNB's");
        feeWallet.transfer(bnbFee);
        
        uint256 fee = amount * benefitStakingPerformanceFeeBP / 10000;        
        sp.transferFrom(msg.sender, feeWallet, fee);
        
        userStakingLpInfo[planetId] = sp.userAddLiquidity(msg.sender, router, amount);
        userStaking[planetId] = UserStaking({
            owner: msg.sender,
            time: block.timestamp,
            timeRelease: timeRelease,
            planetId: planetId,
            tier: tier,
            amount: amount,
            staked: true
        });
    }
    ////////// END BENEFIT STAKING /////////////

    ////////// ENERGY DEPOSITS /////////////
    function getEnergyDepositsMapCount(string calldata guid)
        external
        view
        returns (uint256)
    {
        return energyDepositsMap[guid].length;
    }

    function toggleEnergyDeposits(bool enable) external onlyOwner {
        enableEnergyDepositDeposits = enable;
    }

    function energyDeposit(
        uint256 amount,
        string calldata guid,
        string calldata planetId
    ) external payable {
        BlackMatter sp = getBlackMatter();

        require(
            enableEnergyDepositDeposits,
            "Depositing energy tokens is disabled"
        );
        require(sp.balanceOf(msg.sender) >= amount, "Not enough tokens.");
        require(
            sp.allowance(msg.sender, address(this)) >= amount,
            "Approve transaction first"
        );
        require(msg.value == bnbFee, "Not send enough BNB's");

        energyDeposits[guid] = Transaction({
            guid: guid,
            owner: msg.sender,
            createdTimestamp: block.timestamp,
            amount: amount,
            planetId: planetId,
            exists: true,
            txType: "deposit",
            fee: 0
        });

        energyDepositsMap[planetId].push(guid);
        sp.transferFrom(msg.sender, feeWallet, amount);
        feeWallet.transfer(bnbFee);
    }

    ////////// END ENERGY DEPOSITS /////////////

    ////////// BKM DEPOSITS /////////////
    function getBkmTransactionMapCount(string calldata guid)
        external
        view
        returns (uint256)
    {
        return bkmTransactionMap[guid].length;
    }

    function toggleBkmDeposits(bool enable) external onlyOwner {
        enableBkmDeposit = enable;
    }

    function toggleBkmWithdraws(bool enable) external onlyOwner {
        enableBkmWithdraws = enable;
    }
    
    function setBkmFee(uint _fee) external onlyOwner {
        bkmFee = _fee;
    }

    function bkmDeposit(
        uint256 amount,
        string calldata guid,
        string calldata planetId
    ) external payable {
        BlackMatter sp = getBlackMatter();

        require(
            enableBkmDeposit,
            "Depositing is disabled"
        );
        require(sp.balanceOf(msg.sender) >= amount, "Not enough tokens.");
        require(
            sp.allowance(msg.sender, address(this)) >= amount,
            "Approve transaction first"
        );
        require(msg.value == bnbFee, "Not send enough BNB's");

        uint256 fee = amount / 100 * bkmFee;

        bkmTransactions[guid] = Transaction({
            guid: guid,
            owner: msg.sender,
            createdTimestamp: block.timestamp,
            amount: amount,
            planetId: planetId,
            exists: true,
            txType: "deposit",
            fee: fee
        });

        bkmTransactionMap[planetId].push(guid);

        feeWallet.transfer(bnbFee);
        sp.transferFrom(msg.sender, address(this), amount);
        sp.transfer(feeWallet, fee);
    }


    function bkmWithdraw(
        uint256 amount,
        string calldata guid,
        string calldata planetId,
        OB.signatureData calldata sD
    ) external payable {
        BlackMatter sp = getBlackMatter();

        require(
            enableBkmWithdraws,
            "Withdraw is disabled"
        );
        
        require(msg.value == bnbFee, "Not send enough BNB's");

        uint256 fee = amount / 100 * bkmFee;

        bkmTransactions[guid] = Transaction({
            guid: guid,
            owner: msg.sender,
            createdTimestamp: block.timestamp,
            amount: amount,
            planetId: planetId,
            exists: true,
            txType: "withdraw",
            fee: fee
        });

        bytes memory msgBytes = abi.encodePacked(
            amount,
            planetId,
            msg.sender
        );

        backendAddress.isMessageFromBackend(
            msgBytes,
            sD
        );

        bkmTransactionMap[planetId].push(guid);

        feeWallet.transfer(bnbFee);
        sp.transfer(feeWallet, fee);
        sp.transfer(msg.sender, amount-fee);
    }

    ////////// END BKM DEPOSITS /////////////

    ////////// PLANET /////////////
    function togglePlanetPurchases(bool enable) external onlyOwner {
        enablePlanetPurchases = enable;
    }

    function togglePlanetFusion(bool enable) external onlyOwner {
        enablePlanetFusion = enable;
    }

    function togglePlanetTrading(bool enable) external onlyOwner {
        enablePlanetTrading = enable;
    }

    function buyPlanet(
        string calldata planetGuid,
        uint256 planetPrice,
        OB.signatureData calldata sD,
        string calldata tokenURI
    ) external payable {
        BlackMatter sp = getBlackMatter();
        PlanetNft planetNft = PlanetNft(spaceRidersPlanetNFT);
        PlanetInfo memory pI = planetNft.getPlanetById(planetGuid);

        require(enablePlanetPurchases, "Purchasing planets is disabled");

        require(
            !pI.exists,
            "Planet guid already exists"
        );
        require(
            sp.balanceOf(msg.sender) >= planetPrice,
            "Not enough tokens."
        );
        require(
            sp.allowance(msg.sender, address(this)) >=
                planetPrice,
            "Approve transaction first"
        );
        require(
            msg.value == bnbFee,
            "Not send enough BNB's"
        );

        bytes memory msgBytes = abi.encodePacked(
            planetGuid,
            msg.sender,
            planetPrice
        );

        backendAddress.isMessageFromBackend(
            msgBytes,
            sD
        );

        feeWallet.transfer(bnbFee);
        planetNft.mintNFT(msg.sender, planetGuid, tokenURI);
    }

    function fusionPlanetChecks(
        string calldata burnPlanetGuid1,
        string calldata burnPlanetGuid2,
        string calldata newPlanetGuid
    ) private view {
        PlanetNft planetNft = PlanetNft(spaceRidersPlanetNFT);
        PlanetInfo memory p1 = planetNft.getPlanetById(burnPlanetGuid1);
        PlanetInfo memory p2 = planetNft.getPlanetById(burnPlanetGuid2);
        PlanetInfo memory newPlanet = planetNft.getPlanetById(newPlanetGuid);

        require(p1.exists && p2.exists, "Both burn planets should exist");
        require(planetNft.ownerOf(p1.tokenId) == msg.sender && planetNft.ownerOf(p2.tokenId) == msg.sender, "Not owner");
        require(!newPlanet.exists, "New planet ID already exists.");
    }

    function fusionPlanet(
        OB.signatureData calldata sD,
        string calldata burnPlanetGuid1,
        string calldata burnPlanetGuid2,
        uint256 tokenPrice,
        string calldata newPlanetGuid,
        string calldata newTokenURI
    ) external payable {
        require(enablePlanetFusion, "Planet fusion disabled");
        fusionPlanetChecks(burnPlanetGuid1, burnPlanetGuid2, newPlanetGuid);

        backendAddress.isMessageFromBackend(
            abi.encodePacked(
                burnPlanetGuid1,
                burnPlanetGuid2,
                tokenPrice,
                newPlanetGuid,
                newTokenURI
            ),
            sD
        );

        PlanetNft planetNft = PlanetNft(spaceRidersPlanetNFT);
        planetNft.burnPlanet(burnPlanetGuid1);
        planetNft.burnPlanet(burnPlanetGuid2);

        feeWallet.transfer(bnbFee);
        planetNft.mintNFT(msg.sender, newPlanetGuid, newTokenURI);
    }

    function togglePlanetTrading(
        OB.signatureData calldata sD,
        string calldata requestId,
        string calldata planetGuid,
        bool trading
    ) external payable {
        require(enablePlanetTrading, "Planet trading toggle not enabled");

        PlanetNft planetNft = PlanetNft(spaceRidersPlanetNFT);
        PlanetInfo memory planet = planetNft.getPlanetById(planetGuid);
        
        require(!togglePlanetTradingRequests[requestId], "Already toggled with req. id");
        require(planet.exists, "Planet doesnt exists");
        require(planetNft.ownerOf(planet.tokenId) == msg.sender, "Not owner");

        bytes memory msgBytes = abi.encodePacked(
            requestId,
            planetGuid,
            trading
        );

        backendAddress.isMessageFromBackend(
            msgBytes,
            sD
        );

        togglePlanetTradingRequests[requestId] = true;
        planetNft.enableTrading(planetGuid, trading);
        feeWallet.transfer(bnbFee);
    }
    ////////// END PLANET /////////////
}
