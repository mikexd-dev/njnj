// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract NFTMarketplace {
    using SafeMath for uint256;
    
    struct Auction {
        address seller;
        uint256 tokenId;
        uint256 price;
        uint256 duration;
        uint256 startTime;
    }
    
    struct Sale {
        address seller;
        uint256 tokenId;
        uint256 price;
    }
    
    mapping(uint256 => Auction) public tokenIdToAuction;
    mapping(uint256 => Sale) public tokenIdToSale;
    
    event AuctionCreated(uint256 indexed tokenId, uint256 price, uint256 duration);
    event AuctionCancelled(uint256 indexed tokenId);
    event AuctionSuccessful(uint256 indexed tokenId, uint256 totalPrice, address buyer);
    event SaleCreated(uint256 indexed tokenId, uint256 price);
    event SaleSuccessful(uint256 indexed tokenId, uint256 price, address buyer);
    
    ERC721 public nftContract;
    uint256 public serviceFeePercentage; // Service fee percentage charged by the marketplace
    
    constructor(address _nftContract) {
        nftContract = ERC721(_nftContract);
        serviceFeePercentage = 2; // 2% service fee charged by default
    }
    
    function createAuction(uint256 _tokenId, uint256 _price, uint256 _duration) external {
        require(nftContract.ownerOf(_tokenId) == msg.sender, "Only the token owner can create an auction");
        require(_price > 0, "Price must be greater than zero");
        require(_duration > 0, "Duration must be greater than zero");
        
        nftContract.transferFrom(msg.sender, address(this), _tokenId);
        
        tokenIdToAuction[_tokenId] = Auction({
            seller: msg.sender,
            tokenId: _tokenId,
            price: _price,
            duration: _duration,
            startTime: block.timestamp
        });
        
        emit AuctionCreated(_tokenId, _price, _duration);
    }
    
    function cancelAuction(uint256 _tokenId) external {
        Auction memory auction = tokenIdToAuction[_tokenId];
        require(auction.seller == msg.sender, "Only the auction creator can cancel the auction");
        
        delete tokenIdToAuction[_tokenId];
        
        nftContract.transferFrom(address(this), msg.sender, _tokenId);
        
        emit AuctionCancelled(_tokenId);
    }
    
    function bid(uint256 _tokenId) external payable {
        Auction memory auction = tokenIdToAuction[_tokenId];
        require(auction.seller != address(0), "Auction does not exist");
        require(block.timestamp < auction.startTime.add(auction.duration), "Auction has already ended");
        require(msg.value >= auction.price, "Bid amount is not enough");
        
        delete tokenIdToAuction[_tokenId];
        
        uint256 serviceFee = auction.price.mul(serviceFeePercentage).div(100);
        uint256 sellerAmount = auction.price.sub(serviceFee);
        
        nftContract.transferFrom(address(this), msg.sender, _tokenId);
        
        payable(auction.seller).transfer(sellerAmount);
        payable(address(this)).transfer(serviceFee);
        payable(msg.sender).transfer(msg.value.sub(auction.price));
        
        emit AuctionSuccessful(_tokenId, auction.price, msg.sender);
    }
    
    function createSale(uint256 _tokenId, uint256 _price) external {
        require(nftContract.ownerOf(_tokenId) == msg.sender, "Only the token owner can create a sale");
        require(_price > 0, "Price must be greater than zero");
        
        nftContract.transferFrom(msg.sender, address(this), _tokenId);
        
        tokenIdToSale[_tokenId] = Sale({
            seller: msg.sender,
            tokenId: _tokenId,
            price: _price
        });
        
        emit SaleCreated(_tokenId, _price);
    }
    
    function buy(uint256 _tokenId) external payable {
        Sale memory sale = tokenIdToSale[_tokenId];
        require(sale.seller != address(0), "Sale does not exist");
        require(msg.value >= sale.price, "Amount is not enough");
        
        delete tokenIdToSale[_tokenId];
        
        uint256 serviceFee = sale.price.mul(serviceFeePercentage).div(100);
        uint256 sellerAmount = sale.price.sub(serviceFee);
        
        nftContract.transferFrom(address(this), msg.sender, _tokenId);
        
        payable(sale.seller).transfer(sellerAmount);
        payable(address(this)).transfer(serviceFee);
        payable(msg.sender).transfer(msg.value.sub(sale.price));
        
        emit SaleSuccessful(_tokenId, sale.price, msg.sender);
    }
}