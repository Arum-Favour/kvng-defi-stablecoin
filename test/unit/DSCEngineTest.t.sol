// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    HelperConfig config;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;
    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether; // 10 ETH
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether; // 10 ETH



      function setUp() public {
      deployer = new DeployDSC();
      (dsc, dsce, config) = deployer.run();
      (ethUsdPriceFeed, btcUsdPriceFeed , weth, , ) = config.activeNetworkConfig();

      ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
      }


      ///////////////////////////
      ///Constructor Tests///////
      ///////////////////////////
      address[] public tokenAddresses;
      address[] public priceFeedAddresses;

      function testRevertIfTokenLengthsDoesntMatchPriceFeeds() public{
             tokenAddresses.push(weth);
             priceFeedAddresses.push(ethUsdPriceFeed);
             priceFeedAddresses.push(btcUsdPriceFeed);

             vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
             new DSCEngine(tokenAddresses, priceFeedAddresses,address(dsc));
      }


      /////////////////////
      ///Price Tests///////
      /////////////////////

      function testGetUsdValue() public view {
        uint256 ethAmount = 15e18; // 15 ETH
        uint256 expectedUsdValue = 30000e18; // Assuming ETH price is $30000
        uint256 actualUsdValue = dsce.getUsdValue(weth, ethAmount);
        assertEq( expectedUsdValue,actualUsdValue, "USD value calculation is incorrect");
      }


      function testGetTokenAmountFromusd() public view {
        uint256 usdAmount = 100 ether;
        uint256 expectedWeth =0.05 ether; // Assuming ETH price is $2000
        uint256 actualWeth = dsce.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(expectedWeth, actualWeth, "Token amount from USD calculation is incorrect");
      }


      /////////////////////////////////
      ///depositCollateral Tests///////
      /////////////////////////////////


      function testRevertsIfCollateralZero() public {
          vm.startPrank(USER);
          ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
            vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
            dsce.depositCollateral(weth, 0);
          vm.stopPrank();
      }

      function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock ranToken = new ERC20Mock(); 
          vm.startPrank(USER);
          vm.expectRevert(DSCEngine.DSCEngine__TokenNotAlowed.selector);
          dsce.depositCollateral(address(ranToken), AMOUNT_COLLATERAL);
          vm.stopPrank();
      }

      function testCanDepositCollateralAndGetAccountInfo()public {

      }
}