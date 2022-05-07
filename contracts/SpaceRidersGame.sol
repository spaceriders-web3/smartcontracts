pragma solidity >=0.6.6;

import "./SpaceRiders.sol";
import {UserStaking, EnergyDeposit, PlanetData, ConversionRequests, UserAddLiquidity} from "./Structs.sol";
import "./PlanetNft.sol";
import "./SpaceRidersRewardPool.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";

import { OnlyBackend as OB } from "./Library/OnlyBackend.sol";
//import { SafeMath } from "./Library/SafeMath.sol";

contract SpaceRidersGame is Ownable {
    using OB for address;
    using SafeMath for uint256;

    ////////// GENERAL /////////////
    address DEAD = 0x000000000000000000000000000000000000dEaD;
    
    // Fee Wallet
    address payable feeWallet;

    // Contract addresses
    address payable spaceRiderTokenAddress;
    address spaceRidersPlanetNFT;
    address spaceRidersRewardPoolAddress;

    // Backend API address to verify signatures 
    address public backendAddress;

    // Fixed TX BNB fee (for all IG transactions)
    uint256 public bnbFee = 0.0025 ether;

    // Indirect IG Taxes
    uint256 indirectBurn = 5;
    uint256 indirectLp = 30;
    uint256 indirectRewardPool = 50;
    uint256 indirectTeam = 15;
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
    // Requested planets in creation
    mapping(string => EnergyDeposit) public energyDeposits;

    // Mapping planet address to energy deposits guids
    mapping(string => string[]) public energyDepositsMap;

    bool enableEnergyDepositDeposits = true;
    ////////// END ENERGY DEPOSITS /////////////

    ////////// PLANET PURCHASES /////////////

    // Allow to buy planets
    bool public enablePlanetPurchases = true;
    
    // Allow to fusion planets
    bool public enablePlanetFusion = false;
    
    // Allow planet trading
    bool public enablePlanetTrading = false;
    mapping(string => bool) public togglePlanetTradingRequests;

    ////////// END PLANET PURCHASES /////////////

    ////////// TOKEN MANAGEMENT /////////////
    // Request GUID => ConversionRequests 
    mapping(string => ConversionRequests) public conversions;
    ////////// END TOKEN MANAGEMENT /////////////
    
    // claim id => bool
    mapping(string => bool) public claimedExtraPurchasingPower;

    constructor(
        address payable _spaceRiderTokenAddress,
        address _spaceRidersPlanetNFT,
        address payable _feeWallet, 
        address _backendAddress,
        address _spaceRidersRewardPoolAddress
    ) {
        spaceRiderTokenAddress = _spaceRiderTokenAddress;
        spaceRidersPlanetNFT = _spaceRidersPlanetNFT;
        feeWallet = _feeWallet;
        backendAddress = _backendAddress;
        spaceRidersRewardPoolAddress = _spaceRidersRewardPoolAddress;
    }

    function getSpaceRiders() private view returns (SpaceRiders) {
        return SpaceRiders(spaceRiderTokenAddress);
    }

    function getSpaceRidersRewardPool() private view returns (SpaceRidersRewardPool) {
        return SpaceRidersRewardPool(spaceRidersRewardPoolAddress);
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

    function setIndirectTax(uint256 newLp, uint256 newRp, uint256 newT, uint256 newB) external onlyOwner {
        require((indirectLp+indirectRewardPool+indirectTeam+indirectBurn) == 100, "Total == 100");
        indirectLp = newLp;
        indirectRewardPool = newRp;
        indirectTeam = newT;
        indirectBurn = newB;
    }

    function applyIngameTax(uint256 tokenSent) private {
        SpaceRiders sp = getSpaceRiders();
        sp.transferFrom(msg.sender, address(this), tokenSent);

        uint256 lpAmount = tokenSent.div(100).mul(indirectLp);
        uint256 poolAmount = tokenSent.div(100).mul(indirectRewardPool);
        uint256 teamAmount = tokenSent.div(100).mul(indirectTeam);
        uint256 burnAmount = tokenSent.div(100).mul(indirectBurn);
        
        sp.transfer(spaceRiderTokenAddress, lpAmount);
        sp.transfer(spaceRidersRewardPoolAddress, poolAmount);
        sp.transfer(feeWallet, teamAmount);
        sp.transfer(DEAD, burnAmount);
    }
    ////////// END GENERAL /////////////

    function addPurchasingPower(uint256 _amount, string memory _claimReq, OB.signatureData calldata sD) payable external {
        require(!claimedExtraPurchasingPower[_claimReq], "PP increase already claimed");
        require(msg.value == bnbFee, "Not send enough BNB's");

        feeWallet.transfer(bnbFee);
        SpaceRiders sp = getSpaceRiders();
        
        bytes memory msgBytes = abi.encodePacked(
            msg.sender,
            _claimReq,
            _amount
        );

        backendAddress.isMessageFromBackend(msgBytes, sD);

        claimedExtraPurchasingPower[_claimReq] = true;
        sp.addPurchasingPower(msg.sender, _amount);
    }

    ////////// BENEFIT STAKING /////////////
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

        SpaceRiders sp = getSpaceRiders();
        address r = sp.dexAddresses(0);
        IERC20(userStakingLpInfo[planetId].pair).transfer(address(sp), userStakingLpInfo[planetId].lpAmount);
        sp.userRemoveLiquidity(r, userStakingLpInfo[planetId]);
    }

    function stakingRequestV2(
        OB.signatureData calldata sD,
        string calldata planetId,
        uint256 amount,
        string calldata tier,
        uint256 timeRelease
    ) external payable { 
        SpaceRiders sp = getSpaceRiders();

        require(benefitStakingEnabled, "Staking is not enabled.");
        require(!userStaking[planetId].staked, "Only 1 staking at once.");
        require(timeRelease > block.timestamp, "Time cant be less than current time");
        require(sp.totalBalanceOf(msg.sender) >= amount, "Not enough tokens.");
        require(msg.value == bnbFee, "Not send enough BNB's");
        feeWallet.transfer(bnbFee);
        
        // test with huge differences in both PT & TT
        uint256 fee = amount.mul(benefitStakingPerformanceFeeBP).div(10000);        
        sp.transferFrom(msg.sender, feeWallet, fee);

        //sp.transferFrom(msg.sender, address(this), amount);
        //sp.transfer(spaceRiderTokenAddress, amount);
        address r = sp.dexAddresses(0);
        
        userStakingLpInfo[planetId] = sp.userAddLiquidity(msg.sender, r, amount);
        userStaking[planetId] = UserStaking({
            owner: msg.sender,
            time: block.timestamp,
            timeRelease: block.timestamp + timeRelease,
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
        SpaceRiders sp = getSpaceRiders();

        require(
            enableEnergyDepositDeposits,
            "Depositing energy tokens is disabled"
        );
        require(sp.totalBalanceOf(msg.sender) >= amount, "Not enough tokens.");
        require(
            sp.allowance(msg.sender, address(this)) >= amount,
            "Approve transaction first"
        );
        require(msg.value == bnbFee, "Not send enough BNB's");

        energyDeposits[guid] = EnergyDeposit({
            guid: guid,
            owner: msg.sender,
            createdTimestamp: block.timestamp,
            amount: amount,
            planetId: planetId,
            exists: true
        });

        energyDepositsMap[planetId].push(guid);

        applyIngameTax(amount);
        feeWallet.transfer(bnbFee);
    }

    ////////// END ENERGY DEPOSITS /////////////

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
        SpaceRiders sp = getSpaceRiders();
        PlanetNft planetNft = PlanetNft(spaceRidersPlanetNFT);
        PlanetInfo memory pI = planetNft.getPlanetById(planetGuid);

        require(enablePlanetPurchases, "Purchasing planets is disabled");

        require(
            !pI.exists,
            "Planet guid already exists"
        );
        require(
            sp.totalBalanceOf(msg.sender) >= planetPrice,
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

        applyIngameTax(planetPrice);
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

        applyIngameTax(tokenPrice);
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

    ////////// TOKEN MANAGEMENT /////////////
    function convertFromPrimaryResources(OB.signatureData calldata sD, string calldata id, uint256 tokens, address forAddress) external {
        bytes memory msgBytes = abi.encodePacked(
            id,
            tokens,
            forAddress
        );

        backendAddress.isMessageFromBackend(msgBytes, sD);
        
        require(!conversions[id].exists, "Request already exists");
        require(msg.sender == forAddress, "Request not for you");

        conversions[id] = ConversionRequests({
            guid: id,
            owner: msg.sender,
            tokenAmount: tokens,
            exists: true
        });

        getSpaceRidersRewardPool().giveReward(tokens);
        getSpaceRiders().transfer(msg.sender, tokens);
    }

    ////////// END TOKEN MANAGEMENT /////////////
}
