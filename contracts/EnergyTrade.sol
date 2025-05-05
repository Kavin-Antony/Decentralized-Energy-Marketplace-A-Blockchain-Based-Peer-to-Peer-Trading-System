// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract EnergyTrade is ReentrancyGuard {
    address public owner;
    uint256 public disputeDeposit = 0.01 ether;
    uint256 public timeoutPeriod = 3 days;

    struct Trade {
        address seller;
        address buyer;
        uint256 energyAmount; // in kWh
        uint256 price; // in wei
        uint256 timestamp; // creation time
        bool isAccepted;
        bool isCompleted;
        bool isCancelled;
        bool isDisputed;
    }

    Trade[] public trades;
    mapping(address => uint256) public reputation;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only admin can perform this action");
        _;
    }

    modifier validTradeId(uint _tradeId) {
        require(_tradeId < trades.length, "Invalid trade ID");
        _;
    }

    event TradeCreated(uint indexed tradeId, address seller, uint energyAmount, uint price);
    event TradeAccepted(uint indexed tradeId, address buyer);
    event TradeCompleted(uint indexed tradeId);
    event TradeCancelled(uint indexed tradeId);
    event TradeDisputed(uint indexed tradeId);
    event DisputeResolved(uint indexed tradeId, bool favorSeller);
    event TradeTimedOut(uint indexed tradeId, address refundedTo);

    constructor() {
        owner = msg.sender;
    }

    receive() external payable {
        revert("Direct ETH transfer not allowed");
    }

    function createTrade(uint256 _energyAmount, uint256 _price) external {
        trades.push(Trade({
            seller: msg.sender,
            buyer: address(0),
            energyAmount: _energyAmount,
            price: _price,
            timestamp: block.timestamp,
            isAccepted: false,
            isCompleted: false,
            isCancelled: false,
            isDisputed: false
        }));

        emit TradeCreated(trades.length - 1, msg.sender, _energyAmount, _price);
    }

    function acceptTrade(uint _tradeId) external payable validTradeId(_tradeId) nonReentrant {
        Trade storage trade = trades[_tradeId];
        require(!trade.isCancelled, "Trade is cancelled");
        require(!trade.isAccepted, "Trade already accepted");
        require(msg.value == trade.price, "Incorrect payment");
        require(msg.sender != trade.seller, "Seller cannot be buyer");

        trade.buyer = msg.sender;
        trade.isAccepted = true;
        trade.timestamp = block.timestamp;

        emit TradeAccepted(_tradeId, msg.sender); 
    }

    function completeTrade(uint _tradeId) external validTradeId(_tradeId) nonReentrant {
        Trade storage trade = trades[_tradeId];
        require(trade.isAccepted, "Trade not accepted yet");
        require(!trade.isCompleted, "Trade already completed");
        require(msg.sender == trade.buyer, "Only buyer can confirm completion");

        trade.isCompleted = true;
        payable(trade.seller).transfer(trade.price);
        reputation[trade.seller]++;
        reputation[trade.buyer]++;

        emit TradeCompleted(_tradeId);
    }

    function cancelTrade(uint _tradeId) external validTradeId(_tradeId) {
        Trade storage trade = trades[_tradeId];
        require(!trade.isAccepted, "Cannot cancel after acceptance");
        require(msg.sender == trade.seller, "Only seller can cancel");

        trade.isCancelled = true;
        emit TradeCancelled(_tradeId);
    }

    function raiseDispute(uint _tradeId) external payable validTradeId(_tradeId) {
        Trade storage trade = trades[_tradeId];
        require(trade.isAccepted && !trade.isCompleted, "Only ongoing trades can be disputed");
        require(msg.sender == trade.seller || msg.sender == trade.buyer, "Only participants can raise disputes");
        require(!trade.isDisputed, "Already disputed");
        require(msg.value == disputeDeposit, "Dispute requires deposit");

        trade.isDisputed = true;
        emit TradeDisputed(_tradeId);
    }

    function resolveDispute(uint _tradeId, bool favorSeller) external onlyOwner validTradeId(_tradeId) nonReentrant {
        Trade storage trade = trades[_tradeId];
        require(trade.isDisputed, "No dispute to resolve");
        require(!trade.isCompleted, "Trade already completed");

        trade.isDisputed = false;
        trade.isCompleted = true;

        if (favorSeller) {
            payable(trade.seller).transfer(trade.price);
            reputation[trade.seller]++;
        } else {
            payable(trade.buyer).transfer(trade.price);
            reputation[trade.buyer]++;
        }

        payable(msg.sender).transfer(disputeDeposit); // Refund admin (or could burn deposit if needed)
        emit DisputeResolved(_tradeId, favorSeller);
    }

    function timeoutTrade(uint _tradeId) external validTradeId(_tradeId) nonReentrant {
        Trade storage trade = trades[_tradeId];
        require(trade.isAccepted, "Trade not accepted");
        require(!trade.isCompleted, "Trade already completed");
        require(!trade.isDisputed, "Cannot timeout disputed trade");
        require(block.timestamp > trade.timestamp + timeoutPeriod, "Timeout period not reached");

        trade.isCompleted = true;

        payable(trade.buyer).transfer(trade.price);
        emit TradeTimedOut(_tradeId, trade.buyer);
    }

    function getAllTrades() external view returns (Trade[] memory) {
        return trades;
    }

    function tradeCount() public view returns (uint) {
        return trades.length;
    }

    function updateDisputeDeposit(uint _newAmount) external onlyOwner {
        disputeDeposit = _newAmount;
    }

    function updateTimeoutPeriod(uint _seconds) external onlyOwner {
        timeoutPeriod = _seconds;
    }
}