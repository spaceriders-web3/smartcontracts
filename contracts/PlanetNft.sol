pragma solidity >=0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

interface PlanetNftInterface {
    function mintNFT(address recipient, string calldata planetData,  string memory tokenURI) external returns (uint256);
}

struct PlanetInfo {
    uint256 tokenId;
    string planetId;
    bool exists;
    bool tradeable;
    address owner;
}

contract PlanetNft is PlanetNftInterface, ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    
    uint public dec = 10;
    
    mapping(string => uint) public byPlanetIdData;
    mapping(uint => PlanetInfo) public byTokenIdIdData;
    mapping(address => uint[]) public ownerTokenIds;

    constructor() ERC721("SpaceRidersPlanet", "SPR") {}
    
    function getTokenIdByOwner(address owner) public view returns (uint[] memory ) {
        return ownerTokenIds[owner];
    }

    function getPlanetById(string calldata id) public view returns (PlanetInfo memory) {
        return byTokenIdIdData[byPlanetIdData[id]];
    }

    function burnPlanet(string calldata id) public onlyOwner {
        PlanetInfo memory planet = byTokenIdIdData[byPlanetIdData[id]];
        super._burn(planet.tokenId);
        delete byTokenIdIdData[planet.tokenId];
        delete byPlanetIdData[id];
        
        for (uint x = 0; x < ownerTokenIds[planet.owner].length; x++) {
            if(ownerTokenIds[planet.owner][x] == planet.tokenId) {
                delete ownerTokenIds[planet.owner][x];
                break;
            }
        }
    }

    function mintNFT(address recipient, string calldata planetId, string calldata tokenURI)
        external override onlyOwner
        returns (uint256)
    {
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();

        byPlanetIdData[planetId] = newItemId;
        byTokenIdIdData[newItemId] = PlanetInfo ({
            tokenId: newItemId,
            planetId: planetId,
            exists: true,
            tradeable: false,
            owner: recipient
        });

        ownerTokenIds[recipient].push(newItemId);

        _mint(recipient, newItemId);
        _setTokenURI(newItemId, tokenURI);

        return newItemId;
    }

    function enableTrading(string calldata planetId, bool enable) external onlyOwner {
        byTokenIdIdData[byPlanetIdData[planetId]].tradeable = enable;
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) view internal override {
        require( (from == address(0) || to == address(0)) || byTokenIdIdData[tokenId].tradeable, "Withdraw planet first!");
    }
}
