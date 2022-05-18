pragma solidity >=0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

struct TicketInfo {
    uint256 tokenId;
    address owner;
    bool exists;
    bool lifeTime;
    uint256 generation;
    uint256 expiryDate; // exact expiry date
    uint256 timeAccess; // how much time the nft had (e.g 2 weeks)
    bool burned;
}

struct GenerationInfo {
    uint generation;
    bool enabled;
    uint mintLimit;
    uint fusionLifeTimeNeeded;
    uint mintedAmount;
}

contract TicketNft is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    uint public dec = 10;

    mapping(uint => TicketInfo) public byTokenIdIdData;    
    mapping(uint => GenerationInfo) public genInfo;
    
    mapping(address => uint[]) public walletTokenIds;

    uint public royaltyFeeBips;
    address public royaltyReceiver;

    string public nftBasePath = "http://api.spaceriders.io:81/nft/ticket/";

    bool private fusionInProgress;

    constructor() ERC721("SPRTicket", "SPRTICK") {
        royaltyFeeBips = 1000;
        royaltyReceiver = msg.sender;

        fusionInProgress = false;

        // Genesis generation no limit
        genInfo[0] = GenerationInfo({
            generation: 0,
            enabled: true,
            mintLimit: 0,
            fusionLifeTimeNeeded: 0,
            mintedAmount: 0
        });
    }


    function changeNftBasePath(string calldata _nftBasePath) external onlyOwner {
        nftBasePath = _nftBasePath;
    }

    function changeRoyaltyInfo(uint _royaltyFeeBips, address _royaltyReceiver) external onlyOwner {
        royaltyFeeBips = _royaltyFeeBips;
        royaltyReceiver = _royaltyReceiver;
    }

    function tokenOfOwnerByIndex(address owner, uint256 index) public view returns (uint256) {
        require(index < this.balanceOf(owner), "ERC721Enumerable: owner index out of bounds");
        return walletTokenIds[owner][index];
    }

    function tokenByIndex(uint256 index) public view returns (uint256) {
        require(index <= _tokenIds.current(), "ERC721Enumerable: global index out of bounds");
        return byTokenIdIdData[index].tokenId;
    }

    function totalSupply() public view returns (uint256) {
        return _tokenIds.current();
    }

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return  interfaceId == 0x2a55205a || 
                interfaceId == type(IERC721Enumerable).interfaceId || 
                super.supportsInterface(interfaceId);
    }

    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) external view returns (address receiver, uint256 royaltyAmount) {
        return (royaltyReceiver, ((_salePrice/10000)*royaltyFeeBips));
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        
        if (from != address(0) && !fusionInProgress) {
            uint256[] memory toDelete = new uint256[](1);
            toDelete[0] = tokenId;
            
            _deleteWalletTokenIds(from, toDelete);
            
            walletTokenIds[to].push(tokenId);
            byTokenIdIdData[tokenId].owner = to;
        }
    }
    
    function setGenerationInfo(uint generation, uint limit, uint fusionLifeTimeNeeded) external onlyOwner{
        require(generation > 0, "Cant modify genesis generation");
        require(!genInfo[generation].enabled, "Cant modify enabled generation");
        require(limit > 0 && limit < 1000, "Mint limit for generation should be in range");
        require(generation < 10, "Only 10 generations");

        genInfo[generation] = GenerationInfo({
            generation: generation,
            enabled: true,
            mintLimit: limit,
            fusionLifeTimeNeeded: fusionLifeTimeNeeded,
            mintedAmount: 0
        });
    }

    function mintTicket(
        address recipient,
        bool lifeTime,
        uint256 generation,
        uint256 timeAccess
    )
        external onlyOwner
        returns (uint256)
    {
        require(genInfo[generation].enabled, "Not Enabled to mint yet");
        if (genInfo[generation].generation > 0) {
            require(genInfo[generation].mintedAmount < genInfo[generation].mintLimit, "Max minted for generation");
        }

        uint256 newItemId = _tokenIds.current();
        _tokenIds.increment();

        uint tmpeExpiryDate = block.timestamp + timeAccess;
        uint tmpTimeAccess = timeAccess;
        if (lifeTime) {
            tmpeExpiryDate = 0;
            tmpTimeAccess = 0;
        }

        byTokenIdIdData[newItemId] = TicketInfo({
            tokenId: newItemId,
            owner: recipient,
            exists: true,
            lifeTime: lifeTime,
            generation: generation,
            expiryDate: tmpeExpiryDate,
            timeAccess: tmpTimeAccess,
            burned: false
        });
        
        genInfo[generation].mintedAmount += 1;
        walletTokenIds[recipient].push(newItemId);

        _mint(recipient, newItemId);
        _setTokenURI(newItemId, string(abi.encodePacked(nftBasePath, Strings.toString(newItemId))));

        return newItemId;
    }

    function fusionTickets(
        address recipient,
        uint[] memory tokenIds
    )
        external onlyOwner
        returns (uint256)
    {
        TicketInfo memory tmp = byTokenIdIdData[tokenIds[0]];
        require(tmp.generation > 0, "Can't fusion generation 0");

        GenerationInfo memory genInfo = genInfo[tmp.generation];

        bool lifeTime = tokenIds.length == genInfo.fusionLifeTimeNeeded;
        if (!lifeTime) {
            require(tokenIds.length == 2, "Need 2 for temporary access");
        }
        
        fusionInProgress = true;

        for (uint i = 0; i < tokenIds.length; i++) {
            uint tokenId = tokenIds[i];
            require(byTokenIdIdData[tokenId].exists, "Dont exists");
            require(block.timestamp >= byTokenIdIdData[tokenId].expiryDate, "Has not expired yet");
            require(!byTokenIdIdData[tokenId].burned, "Already burned");
            require(byTokenIdIdData[tokenId].owner == recipient, "Not owner");
            require(!byTokenIdIdData[tokenId].lifeTime, "Can't fusion lifetime tickets");
            require(tmp.generation == byTokenIdIdData[tokenId].generation, "Not same generation");

            byTokenIdIdData[tokenId].burned = true;

            _burn(tokenId);
        }

        _deleteWalletTokenIds(recipient, tokenIds);

        uint256 newItemId = _tokenIds.current();
        _tokenIds.increment();

        uint tmpeExpiryDate = block.timestamp + tmp.timeAccess;
        uint tmpTimeAccess = tmp.timeAccess;
        if (lifeTime) {
            tmpeExpiryDate = 0;
            tmpTimeAccess = 0;
        }

        byTokenIdIdData[newItemId] = TicketInfo({
            tokenId: newItemId,
            owner: recipient,
            exists: true,
            lifeTime: lifeTime,
            generation: tmp.generation,
            expiryDate: tmpeExpiryDate,
            timeAccess: tmpTimeAccess,
            burned: false
        });

        walletTokenIds[recipient].push(newItemId);

        _mint(recipient, newItemId);
        _setTokenURI(newItemId, string(abi.encodePacked(nftBasePath, Strings.toString(newItemId))));

        fusionInProgress = false;

        return newItemId;
    }

    function _deleteWalletTokenIds(address recipient, uint[] memory tokenIds) private {
        for (uint i = 0; i < walletTokenIds[recipient].length; i++) {

            uint tokId1 = walletTokenIds[recipient][i];

            for (uint x = 0; x < tokenIds.length; x++) {
                uint tokId2 = tokenIds[x];

                if (tokId1 == tokId2) {
                    delete walletTokenIds[recipient][i];
                }
            }
        }
    }
}
