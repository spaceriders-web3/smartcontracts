pragma solidity >=0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

struct TicketInfo {
    uint256 tokenId;
    address owner;
    bool exists;
    bool lifeTime;
    uint256 generation;
    uint256 expiryDate;
    uint256 timeAccess;
}

contract TicketNft is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    uint public dec = 10;


    mapping(uint => TicketInfo) public byTokenIdIdData;
    mapping(uint => uint) public generationMintLimit;
    mapping(uint => bool) public generationEnabled;

    mapping(uint => uint) public generationMintedAmount;

    constructor() ERC721("SPRTicket", "SPRTICK") {
        // Genesis generation
        generationEnabled[0] = true;
    }
    
    function setGenerationMintLimit(uint generation, uint limit) external onlyOwner{
        require(generation > 0, "Cant modify genesis generation");
        require(generationMintLimit[generation] <= 0, "Cant modify set max generation");
        generationMintLimit[generation] = limit;
        generationEnabled[generation] = true;
    }

    function mintTicket(
        address recipient,
        bool lifeTime,
        uint256 generation,
        uint256 expiryDate,
        uint256 timeAccess,
        string calldata tokenURI
    )
        external onlyOwner
        returns (uint256)
    {
        require(generationEnabled[generation], "Not Enabled to mint yet");
        if (generationMintLimit[generation] > 0) {
            require(generationMintedAmount[generation] < generationMintLimit[generation], "Max minted for generation");
        }

        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();

        byTokenIdIdData[newItemId] = TicketInfo({
            tokenId: newItemId,
            owner: recipient,
            exists: true,
            lifeTime: lifeTime,
            generation: generation,
            expiryDate: expiryDate,
            timeAccess: timeAccess
        });
        
        generationMintedAmount[generation] += 1;

        _mint(recipient, newItemId);
        _setTokenURI(newItemId, tokenURI);

        return newItemId;
    }
}
