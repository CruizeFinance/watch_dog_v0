// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @author CRUIZE.
 * @title Cruize Beta Access.
 * @notice A simple NFT airdropped to waitlist address to allow testnet beta access.
 */
contract CruizeBetaAccess is ERC721, Ownable {
    using Counters for Counters.Counter;
    string private _baseURIextended;

    Counters.Counter private _tokenIdCounter;

    constructor(string memory baseURIextended) ERC721("Cruize Private Beta Access", "crBETA") {
      _baseURIextended = baseURIextended;
    }

    function safeMint(address to) internal {
      uint256 tokenId = _tokenIdCounter.current();
      _tokenIdCounter.increment();
      _safeMint(to, tokenId);
    }

    function airDrop(address[] calldata _recipient) external onlyOwner {
      for (uint256 i = 0; i < _recipient.length; i++){
        safeMint(_recipient[i]);
      } 
    }

    function setBaseURI(string memory baseURI_) external onlyOwner {
      _baseURIextended = baseURI_;
    }

    function tokenURI(uint256 tokenId)
    public
    view
    virtual
    override
    returns (string memory) {
      require(
          _exists(tokenId),
          "ERC721Metadata: URI query for nonexistent token"
      );
      return _baseURIextended;
    }

}