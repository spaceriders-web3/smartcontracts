pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

library OnlyBackend {
    struct signatureData {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }
    
    // Builds a prefixed hash to mimic the behavior of eth_sign.
    function prefixed(bytes32 hash) private pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    function recoverSigner(
        bytes32 msgHash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) private pure returns (address sender) {
        return ecrecover(msgHash, v, r, s);
    }

    /**
     * Bytes hsh: should be params encoded using abi.encodePacked
     */
    function isMessageFromBackend(address backend, bytes memory paramsPacked, signatureData memory sd) public pure {
        bytes32 hsh = prefixed(keccak256(paramsPacked));
        address snd = recoverSigner(hsh, sd.v, sd.r, sd.s);
        require(snd == backend, "Unauthorized ;)");
    }


}