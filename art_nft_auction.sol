// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import './art_nft_token.sol';

contract ArtNFTAuction {
    address public admin;               // owner of the auction sale
    ArtNFTToken public tokenContract;
    
    uint256 public highestBid;
    
    address public highestBidder;
    
    struct Auction {
        address seller;
        uint256 startPrice;
        uint256 startTime;
        uint256 endTime;
        bool auctionOn;
    }
    
    mapping (uint256 => Auction) public tokenIdToAuction;
    
    // address[] public bidders;
    
    // mapping(address => uint256) public bids;
    
    mapping(uint256 => address[]) public bidders;
    
    mapping(uint256 => mapping(address => uint256)) public bids;
    
    event AuctionCreated(address _seller, uint256 _tokenId, uint256 _startPrice, uint256 _endTime);
    
    event BidPlaced(address _bidder, uint256 _tokenId, uint256 _price);
    
    constructor(ArtNFTToken _tokenContract) {
        require(ArtNFTToken(_tokenContract) != ArtNFTToken(address(0)), 'Invalid token contract address given');
        
        admin = msg.sender;
        tokenContract = _tokenContract;
    }
    
    modifier onlyOwner() {
        require(msg.sender == admin, "Only owner can perform this operation");
        _;
    }
    
    function createAuction(uint256 _tokenId, uint256 _startTime, uint256 _endTime, uint256 _startPrice) public payable {
        require(msg.sender == ArtNFTToken(tokenContract).ownerOf(_tokenId), "Only owner of the token can create the auction");
        
        // address tokenOwner = ArtNFTToken(tokenContract).ownerOf(_tokenId);
        address tokenOwner = msg.sender;
        
        require(ArtNFTToken(tokenContract).balanceOf(tokenOwner) > 0, "Insufficient tokens to start the auction");
        
        require(_startPrice > 0, "Start Price should be greater than 0");
        
        tokenIdToAuction[_tokenId].seller = tokenOwner;
        tokenIdToAuction[_tokenId].startPrice = _startPrice;
        tokenIdToAuction[_tokenId].startTime = _startTime;
        tokenIdToAuction[_tokenId].endTime = _endTime;
        tokenIdToAuction[_tokenId].auctionOn = true;
        
        emit AuctionCreated(tokenOwner, _tokenId, _startPrice, _endTime);
    }
    
    
    
    function bidAmount(uint256 _tokenId) public payable {
        Auction memory _auction = tokenIdToAuction[_tokenId];
        require(_isAuctionOn(_tokenId) == true, "Token is not on sale anymore");
        
        require(_auction.startTime < block.timestamp, "Auction not started yet");
        
        require(block.timestamp < _auction.endTime, "Auction ended");
        
        require(msg.sender != _auction.seller, "Owner cannot bid price in the auction");
        
        require(msg.value > _auction.startPrice, "Bid amount should be greater than the token's start price");
        
        bids[_tokenId][msg.sender] = msg.value;
        
        bidders[_tokenId].push(msg.sender);
        
        emit BidPlaced(msg.sender, _tokenId, msg.value);
    }
    
    function getResults(uint256 _tokenId) public {
        Auction memory _auction = tokenIdToAuction[_tokenId];
        
        require(_auction.seller == msg.sender, "Only owner of the auction can call the result function");
        
        // require(_isAuctionOn(_tokenId) == false, "Token's sale is not complete yet, cannot get results");
        
        require(_auction.startTime < block.timestamp && block.timestamp > _auction.endTime, "Results are being called either before or during the auction");
        
        _auction.auctionOn = false;
        
        for(uint256 i = 0; i < bidders[_tokenId].length; i++) {
            address _bidder = bidders[_tokenId][i];
            highestBidder = (bids[_tokenId][_bidder] > highestBid) ? _bidder : highestBidder;
            highestBid = (bids[_tokenId][_bidder] > highestBid) ? bids[_tokenId][_bidder] : highestBid;
        }
        
        // Amount gets transferred to the owner of the art
        payable (_auction.seller).transfer(highestBid);
        
        // NFT gets transferred to new owner of the art
        ArtNFTToken(tokenContract).transferFrom(_auction.seller, highestBidder, _tokenId);
        
        // Transfer back the amount of all losing bidders
        for(uint256 i = 0; i < bidders[_tokenId].length; i++) {
            address _bidder = bidders[_tokenId][i];
            if(_bidder != highestBidder) {
                
                payable (_bidder).transfer(bids[_tokenId][_bidder]);
                
                // Resetting the variable after result of a bid is done.
                delete bids[_tokenId][_bidder];
            }
        }
        
        // Resetting the variable after result of a bid is done.
        delete bidders[_tokenId];
    }
    
    function cancelAuction(uint256 _tokenId) public {
        Auction memory _auction = tokenIdToAuction[_tokenId];
        require(msg.sender == _auction.seller, "Only creator of the auction can cancel the auction");
        
        delete tokenIdToAuction[_tokenId];
        
        // ArtNFTToken(tokenContract).transfer(msg.sender, _tokenId);
    }
    
    function endAuction(uint256 _tokenId) public view {
        Auction memory _auction = tokenIdToAuction[_tokenId];
        require(msg.sender == _auction.seller, "Only creator of the auction can cancel the auction");
        
        _auction.auctionOn = false;
    }
    
    function _isAuctionOn(uint256 _tokenId) public view returns(bool) {
        Auction memory _auction = tokenIdToAuction[_tokenId];
        
        return _auction.auctionOn;
    }
}
