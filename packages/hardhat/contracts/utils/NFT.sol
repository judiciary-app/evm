// SPDX-License-Identifier: ISC
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

import "./Payable.sol";

/**
 * @title NFT Contract
 * @author hey@kumareth.com
 * @notice An ERC721 Inheritable Contract with many features (like, ERC721Enumerable, accepting payments, admin ability to transfer tokens, etc.)
 */
abstract contract NFT is ERC721Enumerable, Payable {
    constructor(
        string memory name_,
        string memory symbol_,
        string memory contractURI_
    ) ERC721(name_, symbol_) {
        _contractURI = contractURI_;
    }

    // Base URI Management
    string public baseURI = ""; //-> could have been "https://Judiciary.app/artifacts/"

    function _baseURI()
        internal
        view
        virtual
        override(ERC721)
        returns (string memory)
    {
        return baseURI;
    }

    function changeBaseURI(string memory baseURI_)
        public
        onlyOwner
        returns (string memory)
    {
        baseURI = baseURI_;
        return baseURI;
    }

    // Contract URI Management
    string _contractURI = "";

    function contractURI() public view returns (string memory) {
        return _contractURI;
    }

    function changeContractURI(string memory contractURI_)
        public
        onlyOwner
        returns (string memory)
    {
        _contractURI = contractURI_;
        return contractURI_;
    }

    // Exists
    function exists(uint256 tokenId) public view returns (bool) {
        return _exists(tokenId);
    }

    // URI Storage Management
    mapping(uint256 => string) private _tokenURIs;

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(_exists(tokenId), "URI query for nonexistent token");

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }

        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }

        return super.tokenURI(tokenId);
    }

    function _setTokenURI(uint256 tokenId, string memory _tokenURI)
        internal
        virtual
    {
        require(_exists(tokenId), "URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }
}
