// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.4;
import "./Ownable.sol";
import "./Interfaces.sol";

contract MasterPriceOracleV2 is PriceOracle, BasePriceOracle, Ownable {
    address public constant WETH = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
    BasePriceOracle public fallbackOracle;
    mapping(address => BasePriceOracle) public oracles;

    event UpdateFallbackOracle(
        BasePriceOracle oldFallbackOracle,
        BasePriceOracle newFallbackOracle
    );
    event SetOracles(address[] underlyings, BasePriceOracle[] oracles);

    constructor(address _fallbackOracle) {
        require(_fallbackOracle != address(0), "address zero provided");
        fallbackOracle = BasePriceOracle(_fallbackOracle);
    }

    function updateFallbackOracle(BasePriceOracle _fallbackOracle)
        external
        onlyOwner
    {
        emit UpdateFallbackOracle(fallbackOracle, _fallbackOracle);
        fallbackOracle = _fallbackOracle;
    }

    function setOraclesForUnderlyings(
        address[] memory underlyings,
        BasePriceOracle[] memory _oracles
    ) public onlyOwner {
        require(underlyings.length == _oracles.length, "length mismatch");

        for (uint256 i = 0; i < underlyings.length; i++) {
            oracles[underlyings[i]] = _oracles[i];
        }

        emit SetOracles(underlyings, _oracles);
    }

    function _price(address underlying) internal view returns (uint256) {
        /// @notice if weth return 1 ether or 1e18
        if (underlying == WETH) return 1 ether;

        /// @notice check if the MasterPriceOracle has an underlying
        /// oracle for the given token and call price on it
        BasePriceOracle underlyingOracle = oracles[underlying];
        if (address(underlyingOracle) != address(0)) {
            return underlyingOracle.price(underlying);
        }

        /// @notice otherwise call the fallback oracle for the price
        return fallbackOracle.price(underlying);
    }

    function price(address underlying)
        external
        view
        override
        returns (uint256)
    {
        return _price(underlying);
    }

    function getUnderlyingPrice(CToken cToken)
        external
        view
        override
        returns (uint256)
    {
        address underlying = CErc20(address(cToken)).underlying();
        uint256 baseUnit;
        unchecked {
            baseUnit = 10**uint256(IERC20Decimal(underlying).decimals());
        }

        return (_price(underlying) * 1e18) / baseUnit;
    }
}