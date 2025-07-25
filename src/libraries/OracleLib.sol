// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

 /*
 * @title OracleLib
 * @authour Favour Chibueze
 * @notice This library is used to handle oracle related functions for stale data
 * If a price is stale, the function will revert and render the DSCEngine unusable - this is by design
 * @dev This is to ensure that the protocol does not operate with stale prices, which could lead to incorrect valuations and potential exploits.
  */

library OracleLib{ 

    error OracleLib__PriceIsStale();
    uint256 private constant TIMEOUT = 3 hours; 


    function staleCheckLatestRoundData(
        AggregatorV3Interface priceFeed
    ) public view returns (uint80, int256, uint256, uint256, uint80){
   ( uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound) = priceFeed.latestRoundData();

      uint256 secondsSince = block.timestamp - updatedAt;
      if (secondsSince > TIMEOUT) {
          revert OracleLib__PriceIsStale();
      }
      return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
  
}