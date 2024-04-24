// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ERC20.sol";
import "./Ownable.sol";

contract Crowdsale is Ownable {
    IERC20 public token;
    address payable public wallet;
    uint256 public rate;

    constructor(uint256 _rate, address payable _wallet, IERC20 _token) {
        require(_rate > 0, "Rate must be greater than 0");
        require(_wallet != address(0), "Invalid wallet address");
        require(_token != IERC20(0), "Invalid token address");

        token = _token;
        wallet = _wallet;
        rate = _rate;
    }

    function buyTokens(uint256 _numberOfTokens) external payable {
        require(_numberOfTokens > 0, "Number of tokens must be greater than 0");

        uint256 tokens = _numberOfTokens * rate;
        require(token.transferFrom(address(this), msg.sender, tokens), "Transfer failed");
    }

    function _mint(address _to, uint _amount) internal {
        token.mint(_to, _amount);
    }

    function _beforeTokenTransfer(address _from, address _to, uint _value) internal {
        require(_to != address(this), "Cannot transfer tokens to the contract");
    }
}

contract TimedCrowdsale is Crowdsale {
    uint256 public openingTime;
    uint256 public closingTime;

    constructor(uint256 _openingTime, uint256 _closingTime, uint256 _rate, address payable _wallet, IERC20 _token)
        Crowdsale(_rate, _wallet, _token)
        public
    {
        openingTime = _openingTime;
        closingTime = _closingTime;
    }

    function isOpen() public view returns (bool) {
        return block.timestamp >= openingTime && block.timestamp <= closingTime;
    }

    function buyTokens(uint256 _numberOfTokens) external payable override {
        require(isOpen(), "Crowdsale is not open");
        super.buyTokens(_numberOfTokens);
    }
}

contract PostDeliveryCrowdsale is Crowdsale {
    bool public hasEnded = false;

    constructor(uint256 _rate, address payable _wallet, IERC20 _token)
        Crowdsale(_rate, _wallet, _token)
        public
    {
    }

    function saleHasEnded() public view override returns (bool) {
        return hasEnded;
    }

    function buyTokens(uint256 _numberOfTokens) external payable override {
        require(!hasEnded, "Crowdsale has ended");
        super.buyTokens(_numberOfTokens);
    }

    function finalize() external onlyOwner {
        require(!hasEnded, "Crowdsale has already ended");
        hasEnded = true;
    }
}

contract MintedCrowdsale is Crowdsale, TimedCrowdsale, PostDeliveryCrowdsale {
    constructor(
        uint256 _rate,            // rate, in TKNbits
        address payable _wallet,  // wallet to send Ether
        IERC20 _token,            // the token
        uint256 _openingTime,     // opening time in unix epoch seconds
        uint256 _closingTime      // closing time in unix epoch seconds
    )
        PostDeliveryCrowdsale()
        TimedCrowdsale(_openingTime, _closingTime)
        Crowdsale(_rate, _wallet, _token)
        public
    {
        // nice! this Crowdsale will keep all of the tokens until the end of the crowdsale
        // and then users can `withdrawTokens()` to get the tokens they're owed
    }

    function mint(address _to, uint _amount) external onlyOwner {
        _mint(_to, _amount);
    }
}