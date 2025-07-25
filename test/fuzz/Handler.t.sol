// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";


contract Handler is Test {
    // This contract is used to handle the fuzzing tests
    DSCEngine dsce;
    DecentralizedStableCoin dsc;

    ERC20Mock weth;
    ERC20Mock wbtc;

    uint256 public timesMintIsCalled;

    address[] public usersWithCollateralDeposited;
    MockV3Aggregator public ethUsdPriceFeed;
  //  MockV3Aggregator public btcUsdPriceFeed;

    uint256 MAX_DEPOSIT_SIZE = type(uint96).max;


    constructor(DSCEngine _dsce, DecentralizedStableCoin _dsc) {
        dsce = _dsce;
        dsc = _dsc;  

        address[] memory collateralTokens = dsce.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);

        ethUsdPriceFeed = MockV3Aggregator(dsce.getCollateralTokenPriceFeed(weth));
      //  dsce.getCollateralTokenPriceFeed(wbtc);
    }

    function mintDsc(uint256 amount, uint256 addressSeed) public {
        if(usersWithCollateralDeposited.length == 0) {
            return; // No users with collateral deposited
        }
        address sender = usersWithCollateralDeposited[addressSeed % usersWithCollateralDeposited.length];
        (uint256 totalDscMinted, uint collateralValueInUsd) = dsce.getAccountInformation(sender);
        int256 maxDscToMint = (int256(collateralValueInUsd) /2) - int256(totalDscMinted);
        if (maxDscToMint <= 0) {
           return; // No Dsc to mint
        }
         amount = bound(amount, 1, uint256(maxDscToMint));
        if (amount == 0) {
           
            return; // No Dsc to mint
    }
         vm.startPrank(sender);
        dsce.mintDsc(amount);
        vm.stopPrank();
        timesMintIsCalled++;
    }

    // redeem collateral

    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
          ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
          amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);

          vm.startPrank(msg.sender);
          collateral.mint(msg.sender, amountCollateral);
          collateral.approve(address(dsce), amountCollateral);
           dsce.depositCollateral(address(collateral), amountCollateral);
            vm.stopPrank();
            usersWithCollateralDeposited.push(msg.sender);

    }

    function redeemCollateral(
        uint256 collateralSeed,
        uint256 amountCollateral
    ) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        uint256 maxCollateralToRedeem = dsce.getCollateralBalanceOfUser(address(collateral), msg.sender);
        amountCollateral = bound(amountCollateral, 0, maxCollateralToRedeem);
        if (amountCollateral == 0) {
            return; // No collateral to redeem
        }
        dsce.redeemCollateral(address(collateral), amountCollateral);
    }

    // function updateCollateralPrice(uint96 newPrice) public {
    //     int256 newPriceInt = int256(uint256(newPrice));
    //     ethUsdPriceFeed.updateAnswer(newPriceInt);
    // }

    // Helper Functions
    function _getCollateralFromSeed(uint256 collateralSeed) private view returns(ERC20Mock){
               if(collateralSeed % 2 == 0) {
                return weth;
    }
    return wbtc;
    }
}
