// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { MockV3Aggregator } from "../mocks/MockV3Aggregator.sol";
import { MockMoreDebtDSC } from "../mocks/MockMoreDebtDSC.sol";

contract DSCEngineTest is StdCheats, Test {
        event CollateralRedeemed(address indexed redeemFrom, address indexed redeemTo, address token, uint256 amount); // if
        // redeemFrom != redeemedTo, then it was liquidated


    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    HelperConfig config;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;
    
    uint256 amountCollateral = 10 ether;
    uint256 amountToMint = 100 ether;

    address public USER = makeAddr("user");
    uint256 public deployerKey;
    uint256 public constant AMOUNT_COLLATERAL = 10 ether; // 10 ETH
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether; // 10 ETH
    uint256 public constant LIQUIDATION_THRESHOLD = 50;


     // Liquidation
    address public liquidator = makeAddr("liquidator");
    uint256 public collateralToCover = 20 ether;



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
        assertEq( expectedUsdValue,actualUsdValue, "USD value +ion is incorrect");
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



   modifier depositedCollateral(){
    vm.startPrank(USER);
    ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
    dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
    vm.stopPrank();
    _;
   }

   modifier depositedCollateralAndMintedDsc() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);
        dsce.depositCollateralAndMintDsc(weth, amountCollateral, amountToMint);
        vm.stopPrank();
        _;
    }

      function testCanDepositCollateralAndGetAccountInfo()public depositedCollateral{
           (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(USER);

           uint256 expectedTotalDscMinted = 0; // No DSC minted yet
            uint256 expectedDepositAmount = dsce.getTokenAmountFromUsd(weth, collateralValueInUsd);
            assertEq(totalDscMinted, expectedTotalDscMinted, "Total DSC minted should be zero");
            assertEq(AMOUNT_COLLATERAL, expectedDepositAmount, "Collateral value in USD should match the deposited amount");
      }
      
          /////////////////////////////////
          /// mintDsc Tests ///////////////
          /////////////////////////////////
      
          function testRevertsIfMintDscZero() public {
              vm.startPrank(USER);
              ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
              dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
              vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
              dsce.mintDsc(0);
              vm.stopPrank();
          }
      
          function testRevertsIfMintDscBreaksHealthFactor() public {
              vm.startPrank(USER);
              ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
              dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
              // Try to mint more DSC than allowed by collateral
              uint256 excessiveMint = 1_000_000 ether;
              vm.expectRevert();
              dsce.mintDsc(excessiveMint);
              vm.stopPrank();
          }
      
          function testMintDscSucceedsWhenHealthy() public {
              vm.startPrank(USER);
              ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
              dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
              uint256 mintAmount = 1 ether;
              dsce.mintDsc(mintAmount);
              (uint256 totalDscMinted, ) = dsce.getAccountInformation(USER);
              assertEq(totalDscMinted, mintAmount, "Minted DSC should match");
              vm.stopPrank();
          }
      
          /////////////////////////////////
          /// burnDsc Tests ///////////////
          /////////////////////////////////
      
          function testBurnDscRevertsIfZero() public depositedCollateral {
              vm.startPrank(USER);
                  ERC20Mock(weth).approve(address(dsce), amountCollateral);
        dsce.depositCollateralAndMintDsc(weth, amountCollateral, amountToMint);
              vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
              dsce.burnDsc(0);
              vm.stopPrank();
          }


            function testCantBurnMoreThanUserHas() public {
        vm.prank(USER);
        vm.expectRevert();
        dsce.burnDsc(1);
    }

    function testCanBurnDsc() public depositedCollateralAndMintedDsc {
        vm.startPrank(USER);
        dsc.approve(address(dsce), amountToMint);
        dsce.burnDsc(amountToMint);
        vm.stopPrank();

        uint256 userBalance = dsc.balanceOf(USER);
        assertEq(userBalance, 0);
    }
      
      
        
      
          /////////////////////////////////
          /// redeemCollateral Tests //////
          /////////////////////////////////
      
          function testRedeemCollateralRevertsIfZero() public {
              vm.startPrank(USER);
              ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
              dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
              vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
              dsce.redeemCollateral(weth, 0);
              vm.stopPrank();
          }
      
              function testCanRedeemCollateral() public depositedCollateral {
        vm.startPrank(USER);
        uint256 userBalanceBeforeRedeem = dsce.getCollateralBalanceOfUser(USER, weth);
        assertEq(userBalanceBeforeRedeem, amountCollateral);
        dsce.redeemCollateral(weth, amountCollateral);
        uint256 userBalanceAfterRedeem = dsce.getCollateralBalanceOfUser(USER, weth);
        assertEq(userBalanceAfterRedeem, 0);
        vm.stopPrank();
    }

    function testEmitCollateralRedeemedWithCorrectArgs() public depositedCollateral {
        vm.expectEmit(true, true, true, true, address(dsce));
        emit CollateralRedeemed(USER, USER, weth, amountCollateral);
        vm.startPrank(USER);
        dsce.redeemCollateral(weth, amountCollateral);
        vm.stopPrank();
    }
      
          /////////////////////////////////
          /// getAccountCollateralValue ///
          /////////////////////////////////
      
          function testGetAccountCollateralValueReturnsCorrectValue() public depositedCollateral {
              uint256 value = dsce.getAccountCollateralValue(USER);
              uint256 expected = dsce.getUsdValue(weth, AMOUNT_COLLATERAL);
              assertEq(value, expected, "Collateral value should match USD value");
          }
      
          /////////////////////////////////
          /// getHealthFactor /////////////
          /////////////////////////////////
      
              function testProperlyReportsHealthFactor() public depositedCollateralAndMintedDsc {
        uint256 expectedHealthFactor = 100 ether;
        uint256 healthFactor = dsce.getHealthFactor(USER);
        // $100 minted with $20,000 collateral at 50% liquidation threshold
        // means that we must have $200 collatareral at all times.
        // 20,000 * 0.5 = 10,000
        // 10,000 / 100 = 100 health factor
        assertEq(healthFactor, expectedHealthFactor);
    }

    function testHealthFactorCanGoBelowOne() public depositedCollateralAndMintedDsc {
        int256 ethUsdUpdatedPrice = 18e8; // 1 ETH = $18
        // Remember, we need $200 at all times if we have $100 of debt

        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);

        uint256 userHealthFactor = dsce.getHealthFactor(USER);
        // 180*50 (LIQUIDATION_THRESHOLD) / 100 (LIQUIDATION_PRECISION) / 100 (PRECISION) = 90 / 100 (totalDscMinted) =
        // 0.9
        assert(userHealthFactor == 0.9 ether);
    }
      
          /////////////////////////////////
          /// liquidate Tests /////////////
          /////////////////////////////////
      
       // This test needs it's own setup
    function testMustImproveHealthFactorOnLiquidation() public {
        // Arrange - Setup
        MockMoreDebtDSC mockDsc = new MockMoreDebtDSC(ethUsdPriceFeed);
        tokenAddresses = [weth];
        priceFeedAddresses = [ethUsdPriceFeed];
        address owner = msg.sender;
        vm.prank(owner);
        DSCEngine mockDsce = new DSCEngine(tokenAddresses, priceFeedAddresses, address(mockDsc));
        mockDsc.transferOwnership(address(mockDsce));
        // Arrange - User
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(mockDsce), amountCollateral);
        mockDsce.depositCollateralAndMintDsc(weth, amountCollateral, amountToMint);
        vm.stopPrank();

        // Arrange - Liquidator
        collateralToCover = 1 ether;
        ERC20Mock(weth).mint(liquidator, collateralToCover);

        vm.startPrank(liquidator);
        ERC20Mock(weth).approve(address(mockDsce), collateralToCover);
        uint256 debtToCover = 10 ether;
        mockDsce.depositCollateralAndMintDsc(weth, collateralToCover, amountToMint);
        mockDsc.approve(address(mockDsce), debtToCover);
        // Act
        int256 ethUsdUpdatedPrice = 18e8; // 1 ETH = $18
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);
        // Act/Assert
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorNotImproved.selector);
        mockDsce.liquidate(weth, USER, debtToCover);
        vm.stopPrank();
    }

    function testCantLiquidateGoodHealthFactor() public depositedCollateralAndMintedDsc {
        ERC20Mock(weth).mint(liquidator, collateralToCover);

        vm.startPrank(liquidator);
        ERC20Mock(weth).approve(address(dsce), collateralToCover);
        dsce.depositCollateralAndMintDsc(weth, collateralToCover, amountToMint);
        dsc.approve(address(dsce), amountToMint);

        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorOk.selector);
        dsce.liquidate(weth, USER, amountToMint);
        vm.stopPrank();
    }

    modifier liquidated() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);
        dsce.depositCollateralAndMintDsc(weth, amountCollateral, amountToMint);
        vm.stopPrank();
        int256 ethUsdUpdatedPrice = 18e8; // 1 ETH = $18

        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);
        uint256 userHealthFactor = dsce.getHealthFactor(USER);

        ERC20Mock(weth).mint(liquidator, collateralToCover);

        vm.startPrank(liquidator);
        ERC20Mock(weth).approve(address(dsce), collateralToCover);
        dsce.depositCollateralAndMintDsc(weth, collateralToCover, amountToMint);
        dsc.approve(address(dsce), amountToMint);
        dsce.liquidate(weth, USER, amountToMint); // We are covering their whole debt
        vm.stopPrank();
        _;
    }

    function testLiquidationPayoutIsCorrect() public liquidated {
        uint256 liquidatorWethBalance = ERC20Mock(weth).balanceOf(liquidator);
        uint256 expectedWeth = dsce.getTokenAmountFromUsd(weth, amountToMint)
            + (dsce.getTokenAmountFromUsd(weth, amountToMint) * dsce.getLiquidationBonus() / dsce.getLiquidationPrecision());
        uint256 hardCodedExpected = 6_111_111_111_111_111_110;
        assertEq(liquidatorWethBalance, hardCodedExpected);
        assertEq(liquidatorWethBalance, expectedWeth);
    }

    function testUserStillHasSomeEthAfterLiquidation() public liquidated {
        // Get how much WETH the user lost
        uint256 amountLiquidated = dsce.getTokenAmountFromUsd(weth, amountToMint)
            + (dsce.getTokenAmountFromUsd(weth, amountToMint) * dsce.getLiquidationBonus() / dsce.getLiquidationPrecision());

        uint256 usdAmountLiquidated = dsce.getUsdValue(weth, amountLiquidated);
        uint256 expectedUserCollateralValueInUsd = dsce.getUsdValue(weth, amountCollateral) - (usdAmountLiquidated);

        (, uint256 userCollateralValueInUsd) = dsce.getAccountInformation(USER);
        uint256 hardCodedExpectedValue = 70_000_000_000_000_000_020;
        assertEq(userCollateralValueInUsd, expectedUserCollateralValueInUsd);
        assertEq(userCollateralValueInUsd, hardCodedExpectedValue);
    }

    function testLiquidatorTakesOnUsersDebt() public liquidated {
        (uint256 liquidatorDscMinted,) = dsce.getAccountInformation(liquidator);
        assertEq(liquidatorDscMinted, amountToMint);
    }

    function testUserHasNoMoreDebt() public liquidated {
        (uint256 userDscMinted,) = dsce.getAccountInformation(USER);
        assertEq(userDscMinted, 0);
    }

      
          /////////////////////////////////
          /// getUsdValue Tests ///////////
          /////////////////////////////////
      
          function testGetUsdValueReturnsZeroIfNoCollateral() public {
              uint256 value = dsce.getUsdValue(weth, 0);
              assertEq(value, 0, "USD value should be zero if no collateral");
          }
}