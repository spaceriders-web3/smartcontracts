struct UserStaking {
    address owner;
    string planetId;
    uint256 amount;
    string tier;
    uint256 time;
    uint256 timeRelease;
    bool staked;
}

struct EnergyDeposit {
    string guid;
    string planetId;
    address owner;
    uint256 createdTimestamp;
    uint256 amount;
    bool exists;
}

struct PlanetData {
    string guid;
    address owner;
    uint256 timeClaimable;
    bool claimed;
    bool exists;
}

struct ConversionRequests {
    string guid;
    address owner;
    uint256 tokenAmount;
    bool exists;
}

struct UserAddLiquidity {
    address user;
    uint256 lpAmount;
    uint256 tradeableBalance;
    uint256 playableBalance;
    address router;
    address pair;
}