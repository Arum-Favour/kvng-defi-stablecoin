// SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity >=0.8.20 <0.9.0;

/*
 * @title DSCEngine
 * @author Favour Arum
 *
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg at all times.
 * This is a stablecoin with the properties:
 * - Exogenously Collateralized
 * - Dollar Pegged
 * - Algorithmically Stable
 *
 * It is similar to DAI if DAI had no governance, no fees, and was backed by only WETH and WBTC.
 *
 * Our DSC system should always be "overcollateralized". At no point, should the value of
 * all collateral < the $ backed value of all the DSC.
 *
 * @notice This contract is the core of the Decentralized Stablecoin system. It handles all the logic
 * for minting and redeeming DSC, as well as depositing and withdrawing collateral.
 * @notice This contract is based on the MakerDAO DSS system
 */

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract DSCEngine is ReentrancyGuard {
    /////////////////
    //Errors
    /////////////////
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
    error DSCEngine__TokenNotAlowed();
    error DSCEngine__TransferFailed();
    error DSCEngine__BreaksHealthFactor(uint256 healthFactor);
    error DSCEngine__MintedFailed();
    /////////////////
    //State Variables
    /////////////////
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10; // Used to adjust the price feed values to a common precision
    uint256 private constant PRECISION = 1e18; // Used for price calculations
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // 200% overcollateralization means 50% liquidation threshold
    uint256 private constant LIQUIDATION_PRECISION = 100; // 10% liquidation penalty
    uint256 private constant MIN_HEALTH_FACTOR = 1; // Minimum health factor to avoid liquidation

    mapping(address token => address priceFeed) private s_priceFeeds; // Maps token addresses to their price feed addresses
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited; // Maps user addresses to their collateral deposits
    mapping(address user => uint256 amountDscMinted) private s_DscMinted; // Maps user addresses to the amount of DSC they have minted
    address[] private s_collateralTokens; // Array of collateral token addresses

    DecentralizedStableCoin private immutable i_dsc; // The Decentralized Stable Coin (DSC) contract

    /////////////////
    //Events
    /////////////////
    event CollateralDeposited(address indexed user, address indexed tokenCollateralAddress, uint256 amountCollateral);

    /////////////////
    //Modifiers
    /////////////////
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        // Check if the token is allowed in the system
        // This could be a mapping or an array of allowed tokens
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine__TokenNotAlowed();
        }
        _;
    }

    /////////////////
    //Functions
    /////////////////
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address dscAddress) {
        // USD Price Feed Address
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
        }
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    /////////////////
    //External Functions
    /////////////////

    function depositCollateralAndMintDsc() external {}

    /*
     * @param tokenCollateralAddress: The ERC20 token address of the collateral you're depositing
     * @param amountCollateral: The amount of collateral you're depositing
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        external
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        // Transfer the collateral from the user to this contract
        (bool success) = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    function redeemCollateralForDsc() external {}

    function redeemCollateral() external {}


    /*
     * @param amountDscToMint: The amount of DSC you want to mint
     * You can only mint DSC if you have enough collateral
     */

    function mintDsc(uint256 amountDscToMint) external moreThanZero(amountDscToMint) nonReentrant {
        s_DscMinted[msg.sender] += amountDscToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, amountDscToMint);
        if (!minted) {
            revert DSCEngine__MintedFailed();
    }
    }

    function burnDsc() external {}

    function liquidate() external {}

    function getHealthFactor() external view {}





    
    //////////////////////////////
    //Private & Internal view Functions
    //////////////////////////////


    function _getAccountInformation(address user) private view returns (uint256 totalDscMinted, uint256 collateralValueInUsd) {
        // This function should return the total amount of DSC minted by the user and the total value of their collateral in USD
        totalDscMinted = s_DscMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user); 
        // You would need to loop through the user's collateral deposits and calculate the total value in USD
        return (totalDscMinted, collateralValueInUsd);
    }


function _healthFactor(address user) internal view returns (uint256) {
        // This function should calculate the health factor of the user
        // The health factor is the ratio of the value of collateral to the value of DSC minted
        // It should return a value greater than 1 if the user is healthy, and less than 1 if they are in danger of liquidation
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION; // Adjusting for liquidation threshold
        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted ; // Adjusting for precision
    }


    function _revertIfHealthFactorIsBroken(address user) internal view {
      uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BreaksHealthFactor(userHealthFactor);
        }
    }



    //////////////////////////////
    //Public & External view Functions
    //////////////////////////////
    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
        // This function should return the total value of the user's collateral in USD
        // Loop through the user's collateral deposits and calculate the total value in USD
        // You would need to use the price feeds to get the price of each collateral token in USD
        for(uint256 i = 0; i < s_collateralTokens.length; i++){
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }
        return totalCollateralValueInUsd;
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256){
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price, , , ) = priceFeed.latestRoundData();

        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION; // Adjusting for price feed precision
    }

}
