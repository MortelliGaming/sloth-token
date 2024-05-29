// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract TokenSale is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    ERC20Burnable public immutable token; // ERC20 token being sold
    uint256 public immutable endBlock; // Block number when the sale ends
    uint256 public immutable maxTokensPerTx; // Block number when the sale ends

    uint256[4] public priceLevels; // Price levels for different stages of sale
    uint256 public totalTokens; // Total tokens available for sale
    uint256 public tokensSold; // Number of tokens sold
    uint256 public croSpent; // Number of tokens sold

    event TokensPurchased(address indexed buyer, uint256 amountPaid, uint256 amountReceived);

    constructor(
        address _token,
        uint256[4] memory _priceLevels,
        uint256 _totalTokens,
        uint256 _endBlock
    ) Ownable(_msgSender()) {
        require(_endBlock > block.number, "End block must be in the future");
        require(_priceLevels[0] > 0, "Price levels must be set");

        token = ERC20Burnable(_token);
        priceLevels = _priceLevels;
        totalTokens = _totalTokens;
        endBlock = _endBlock;
        maxTokensPerTx = _totalTokens.div(4).div(100); // 1 percent of level
    }

    function buyTokens(uint256 _amount) external payable nonReentrant {
        require(block.number < endBlock && tokensSold != totalTokens, "Sale Ended");
        require(tokensSold.add(_amount) <= totalTokens, string.concat("Requested amount exceeds remaining tokens (", Strings.toString(totalTokens.sub(tokensSold) / 10 ** token.decimals()), " remaining)"));
        require(token.balanceOf(address(this)) >= _amount, "Sale has insufficient tokens");
        require(_amount <= maxTokensPerTx, string.concat("Cannot buy more than ", Strings.toString(maxTokensPerTx / 10 ** token.decimals()), " tokens per transaction")); // cannot buy more than 1% of level in 1 tx

        uint256 currentPrice = getCurrentPrice();
        uint256 requiredCRO = _amount.mul(currentPrice).div(10**18);

        require(msg.value == requiredCRO, string.concat("Incorrect CRO amount sent, need ", Strings.toString(requiredCRO / 10**18)));

        token.transfer(msg.sender, _amount);
        tokensSold = tokensSold.add(_amount);
        croSpent = croSpent.add(msg.value);
        emit TokensPurchased(msg.sender, requiredCRO, _amount);
    }

    function getProgress() public view returns (uint256) {
        return tokensSold.mul(100).div(totalTokens);
    }

    function getCurrentPrice() public view returns (uint256) {
        require(block.number < endBlock && tokensSold != totalTokens, "Sale Ended");
        uint256 progress = getProgress();
        if (progress < 25) {
            return priceLevels[0];
        } else if (progress < 50) {
            return priceLevels[1];
        } else if (progress < 75) {
            return priceLevels[2];
        } else {
            return priceLevels[3];
        }
    }

    function tokensToBuy(uint256 _croAmount) public view returns (uint256) {
        require(block.number < endBlock && tokensSold != totalTokens, "Sale Ended");
        uint256 currentPrice = getCurrentPrice();
        return _croAmount.mul(10**18).div(currentPrice);
    }

    function withdraw() external onlyOwner nonReentrant {
        require(block.number >= endBlock || tokensSold == totalTokens, "Sale is still ongoing");
        // Send remaining tokens to owner
        token.burn(token.balanceOf(address(this)));
        // Send remaining CRO to owner
        payable(owner()).transfer(address(this).balance);
    }
}
