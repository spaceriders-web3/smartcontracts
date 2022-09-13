struct UserStaking {
    address owner;
    string planetId;
    uint256 amount;
    string tier;
    uint256 time;
    uint256 timeRelease;
    bool staked;
}

struct Transaction {
    string guid;
    string planetId;
    address owner;
    uint256 createdTimestamp;
    uint256 amount;
    bool exists;
    string txType;
    uint256 fee;
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
    address wallet;
    uint256 lpAmount;
    address router;
    address pair;
}