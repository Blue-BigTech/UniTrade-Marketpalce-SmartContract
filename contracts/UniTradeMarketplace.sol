// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract UniTradeNFTMarketplace is ERC1155Holder, ReentrancyGuard, Ownable {
    bytes4 private constant ERC721_INTERFACE_ID = 0x80ac58cd;
    bytes4 private constant ERC1155_INTERFACE_ID = 0xd9b67a26;
    
    uint256 feePercentage = 500;

    event MarketItemCreated(
        address indexed nftContract,
        uint256 indexed tokenId,
        address currentOwner,
        uint256 price,
        string status,
        uint256 startAt,
        uint256 expiresAt
    );

    event MarketItemForSaleUpdated(
        address indexed nftContract,
        uint256 tokenId,
        string status
    );

    event NFTPurchased(
        address indexed nftContract,
        uint256 tokenId,
        address currentOwner,
        string status
    );

    event BidMade(
        address nftContract,
        uint256 tokenId,
        address bidder,
        uint256 bidPrice
    );

    event AuctionEnded(
        address nftContract,
        uint256 tokenId,
        address highestBidder,
        uint256 highestBidAmount
    );

    modifier onlyNFTContract(address _contract) {
        require(
            isERC721(_contract) || isERC1155(_contract),
            "Not NFT Contract address"
        );
        _;
    }

    constructor() {}

    struct MarketItem {
        bool exist;
        address nftContract;
        uint256 tokenId;
        address payable currentOwner;
        address payable highestBidder;
        uint256 price;
        uint256 highestBidAmount;
        string status;
        uint256 startAt;
        uint256 expiresAt;
    }

    mapping(address => mapping(uint256 => MarketItem)) public marketItems;
    MarketItem[] private itemsList;

    /* Places an item for sale on the marketplace */
    function itemOnMarket(
        address nftContract,
        uint256 tokenId,
        uint256 price,
        string memory status,
        uint256 duration
    ) external nonReentrant onlyNFTContract(nftContract) {
        require(price > 0, "Price must be at least 1 wei.");
        if (
            keccak256(abi.encodePacked((status))) ==
            keccak256(abi.encodePacked(("forAuction")))
        ) {
            require(duration >= 1, "Auction duration must be more than 1 day.");
        }

        marketItems[nftContract][tokenId] = MarketItem(
            true,
            nftContract,
            tokenId,
            payable(msg.sender),
            payable(msg.sender),
            price,
            price,
            status,
            block.timestamp,
            block.timestamp + (duration * 1 days)
        );

        if (isERC721(nftContract)) {
            IERC721(nftContract).transferFrom(
                msg.sender,
                address(this),
                tokenId
            );
        }

        if (isERC1155(nftContract)) {
            uint256 amount = 1;
            IERC1155(nftContract).safeTransferFrom(
                msg.sender,
                address(this),
                tokenId,
                amount,
                "0x0"
            );
        }

        itemsList.push(marketItems[nftContract][tokenId]);

        emit MarketItemCreated(
            nftContract,
            tokenId,
            msg.sender,
            price,
            status,
            block.timestamp,
            block.timestamp + (duration * 1 days)
        );
    }

    /* Down the NFT of the market for Sale */
    function itemDownMarket(address _nftContract, uint256 _tokenId) external onlyNFTContract(_nftContract) {
        require(
            marketItems[_nftContract][_tokenId].exist,
            "This NFT doesn't exist!"
        );
        require(
            keccak256(
                abi.encodePacked((marketItems[_nftContract][_tokenId].status))
            ) != keccak256(abi.encodePacked(("down"))),
            "This NFT isn't on sale."
        );
        require(
            marketItems[_nftContract][_tokenId].currentOwner == msg.sender,
            "Creator can down the NFT."
        );

        marketItems[_nftContract][_tokenId].status = "down";

        if (
            marketItems[_nftContract][_tokenId].currentOwner !=
            marketItems[_nftContract][_tokenId].highestBidder
        ) {
            marketItems[_nftContract][_tokenId].highestBidder.transfer(
                marketItems[_nftContract][_tokenId].highestBidAmount
            );
        }

        if (isERC721(_nftContract)) {
            IERC721(_nftContract).transferFrom(
                address(this),
                msg.sender,
                _tokenId
            );
        } else {
            IERC1155(_nftContract).safeTransferFrom(
                address(this),
                msg.sender,
                _tokenId,
                1,
                "0x0"
            );
        }

        uint256 itemIndex = getItemIndex(_nftContract, _tokenId);
        removeItemAtIndex(itemIndex);

        emit MarketItemForSaleUpdated(_nftContract, _tokenId, "down");
    }

    function getItemIndex(
        address _nftContract,
        uint256 _tokenId
    ) public view returns (uint) {
        for (uint i = 0; i < itemsList.length; i++) {
            if (
                itemsList[i].nftContract == _nftContract &&
                itemsList[i].tokenId == _tokenId
            ) {
                return i;
            }
        }
        revert("MarketItem not found");
    }

    function removeItemAtIndex(uint index) internal {
        require(index < itemsList.length, "Index out of range");

        for (uint i = index; i < itemsList.length - 1; i++) {
            itemsList[i] = itemsList[i + 1];
        }

        itemsList.pop();
    }

    /* Purchase & Bid for the NFT */
    /* Transfers ownership of the item, as well as funds between parties */
    function purchaseNFT(
        address _nftContract,
        uint256 _tokenId
    ) external payable nonReentrant onlyNFTContract(_nftContract) {
        require(
            marketItems[_nftContract][_tokenId].exist,
            "This NFT doesn't exist!"
        );
        require(
            keccak256(
                abi.encodePacked((marketItems[_nftContract][_tokenId].status))
            ) != keccak256(abi.encodePacked(("down"))),
            "This NFT isn't on sale."
        );
        require(
            marketItems[_nftContract][_tokenId].currentOwner != msg.sender,
            "You already have this NFT."
        );
        require(
            msg.value == marketItems[_nftContract][_tokenId].price,
            "Please submit the asking price in order to complete the purchase."
        );

        uint256 commissionFee = msg.value * feePercentage / 10000;
        marketItems[_nftContract][_tokenId].currentOwner.transfer(msg.value - commissionFee);

        if (isERC721(_nftContract)) {
            IERC721(_nftContract).transferFrom(
                address(this),
                msg.sender,
                _tokenId
            );
        } else {
            IERC1155(_nftContract).safeTransferFrom(
                address(this),
                msg.sender,
                _tokenId,
                1,
                "0x0"
            );
        }

        marketItems[_nftContract][_tokenId].currentOwner = payable(msg.sender);
        marketItems[_nftContract][_tokenId].status = "down";

        uint256 itemIndex = getItemIndex(_nftContract, _tokenId);
        removeItemAtIndex(itemIndex);

        emit NFTPurchased(_nftContract, _tokenId, msg.sender, "down");
    }

    /* Bid for NFT auction and refund */
    function bid(
        address _nftContract,
        uint256 _tokenId
    ) external payable nonReentrant onlyNFTContract(_nftContract) {
        require(
            marketItems[_nftContract][_tokenId].currentOwner != msg.sender,
            "You already have this NFT."
        );
        require(
            block.timestamp <= marketItems[_nftContract][_tokenId].expiresAt,
            "Auction is already ended."
        );
        require(
            marketItems[_nftContract][_tokenId].exist,
            "This NFT doesn't exist!"
        );
        require(
            marketItems[_nftContract][_tokenId].highestBidder != msg.sender,
            "You have already bidded."
        );
        require(
            msg.value > marketItems[_nftContract][_tokenId].highestBidAmount,
            "There already is a higher bid."
        );

        if (marketItems[_nftContract][_tokenId].highestBidder != marketItems[_nftContract][_tokenId].currentOwner) {
            marketItems[_nftContract][_tokenId].highestBidder.transfer(
                marketItems[_nftContract][_tokenId].highestBidAmount
            );
        }

        marketItems[_nftContract][_tokenId].highestBidder = payable(msg.sender);
        marketItems[_nftContract][_tokenId].highestBidAmount = msg.value;

        emit BidMade(_nftContract, _tokenId, msg.sender, msg.value);
    }

    /* End the auction
    and send the highest bid to the Item owner
    and transfer the item to the highest bidder */
    function auctionEnd(address _nftContract, uint256 _tokenId) external onlyNFTContract(_nftContract) {
        require(
            keccak256(
                abi.encodePacked((marketItems[_nftContract][_tokenId].status))
            ) != keccak256(abi.encodePacked(("down"))),
            "Auction has already ended."
        );

        // End the auction
        marketItems[_nftContract][_tokenId].status = "down";
        //Send the highest bid to the seller.
        if (
            marketItems[_nftContract][_tokenId].currentOwner !=
            marketItems[_nftContract][_tokenId].highestBidder
        ) {
            uint256 currentBidAmount = marketItems[_nftContract][_tokenId].highestBidAmount;
            uint256 commissionFee = currentBidAmount * feePercentage / 10000;

            marketItems[_nftContract][_tokenId].currentOwner.transfer(
                currentBidAmount - commissionFee
            );
        }
        // Transfer the item to the highest bidder
        if (isERC721(_nftContract)) {
            IERC721(_nftContract).transferFrom(
                address(this),
                marketItems[_nftContract][_tokenId].highestBidder,
                _tokenId
            );
        } else {
            IERC1155(_nftContract).safeTransferFrom(
                address(this),
                marketItems[_nftContract][_tokenId].highestBidder,
                _tokenId,
                1,
                "0x0"
            );
        }

        marketItems[_nftContract][_tokenId].currentOwner = marketItems[
            _nftContract
        ][_tokenId].highestBidder;

        uint256 itemIndex = getItemIndex(_nftContract, _tokenId);
        removeItemAtIndex(itemIndex);

        emit AuctionEnded(
            _nftContract,
            _tokenId,
            marketItems[_nftContract][_tokenId].highestBidder,
            marketItems[_nftContract][_tokenId].highestBidAmount
        );
    }

    /* Gets a NFT to show ItemDetail */
    function getItemDetail(
        address _nftContract,
        uint256 _tokenId
    ) external view returns (MarketItem memory) {
        MarketItem memory item = marketItems[_nftContract][_tokenId];
        return item;
    }

    /* Withdraw to the contract owner */
    function withdraw() public onlyOwner {
        uint256 amount = address(this).balance;
        (bool success, ) = (msg.sender).call{value: amount}("");
        require(success, "Transfer failed.");
    }

    function getNow() external view returns (uint256) {
        return block.timestamp;
    }

    function getItemsList() external view returns (MarketItem[] memory) {
        return itemsList;
    }

    function isERC721(address _address) public view returns (bool) {
        return IERC721(_address).supportsInterface(ERC721_INTERFACE_ID);
    }

    function isERC1155(address _address) public view returns (bool) {
        return IERC1155(_address).supportsInterface(ERC1155_INTERFACE_ID);
    }
}
