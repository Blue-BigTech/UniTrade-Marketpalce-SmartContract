// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract UniTrade721 is ERC721, Ownable{
   using Counters for Counters.Counter;
   using Strings for uint256;

    Counters.Counter private _tokenIdTracker;
    // Base token URI
    string private base;

    constructor() ERC721("NFT-UniTrade Token", "UNT") {
    }
    receive() external payable {}

    function totalSupply() external view returns (uint256){
        return _tokenIdTracker.current();
    }

    //Overriding ERC721.sol method for use w/ tokenURI method
    function _baseURI() internal view override returns(string memory) {
        return base;
    }
    
    function setBaseURI(string memory _newuri) external onlyOwner returns(bool){
     base = _newuri;
     return true;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString(),".json")) : "";
    }

    function mintNFT(uint256 numberOfNfts) public {
        require(numberOfNfts > 0, "numberOfNfts cannot be 0");

        for (uint i = 0; i < numberOfNfts; i++) {
            _tokenIdTracker.increment();
            _safeMint(_msgSender(), _tokenIdTracker.current());
        }
    }

    /** 
    * @dev function to check ethers in contract
    * @notice only contract owner can call
    */
    function contractBalance() public view onlyOwner returns(uint256){
        return address(this).balance;
    }

    /**
     * @dev Withdraw ether from this contract (Callable by owner)
    */
    function withdraw() onlyOwner public {
        uint balance = address(this).balance;
        payable(_msgSender()).transfer(balance);
    }
}
