// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract UniTrade1155 is ERC1155URIStorage, Ownable {
    using Strings for uint256;

    string public _baseURI = "";

    constructor() ERC1155("") {
    }
    receive() external payable {}

    function mint(address to, uint256 tokenId, uint256 amount) external {
        _mint(to, tokenId, amount, "");
    }

    function mintBatch(address to, uint256[] memory tokenIds, uint256[] memory amounts) external {
        _mintBatch(to, tokenIds, amounts, "");
    }

    function uri(uint256 tokenId) public view virtual override(ERC1155URIStorage) returns (string memory) {
        return bytes(_baseURI).length > 0 ? string(abi.encodePacked(_baseURI, tokenId.toString(),".json")) : "";
    }

    function setBaseURI(string memory _uri) external onlyOwner {
        _baseURI = _uri;
    }
}
