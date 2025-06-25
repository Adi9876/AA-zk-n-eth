// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {EthAA} from "../../src/ethereum/EthAA.sol";
import {DeployEthAA} from "../../script/DeployEthAA.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract EthAATest is Test {
    HelperConfig helperConfig;
    EthAA ethAA;
    ERC20Mock usdc;

    uint256 constant AMOUNT = 1e18;

    function setUp() public {
        DeployEthAA deployEthAA = new DeployEthAA();
        (helperConfig, ethAA) = deployEthAA.deployEthAA();
        usdc = new ERC20Mock();
    }

    // test
    function test_ownerCanExecuteCommands() public {
        // need a mock erc20 contract and inputs
        assertEq(usdc.balanceOf(address(ethAA)), 0);
        address destination = address(usdc);
        uint256 value = 0;
        bytes memory data = abi.encodeWithSelector(ERC20Mock.mint.selector, address(ethAA), AMOUNT);

        vm.prank(ethAA.owner());
        ethAA.execute(destination, value, data);

        assertEq(usdc.balanceOf(address(ethAA)), AMOUNT);
    }

    // we want to test user can go through the
    // sign -> alt-mempool -> entrypoint -> interact with our contract
    // process should be tested

    // so for testing

    // USDC Mint
    // msg.sender -> EthAA
    // approve some amount
    // USDC contract
    // come from the entrypoint
}
