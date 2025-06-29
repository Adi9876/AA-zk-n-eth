// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {EthAA} from "../../src/ethereum/EthAA.sol";
import {DeployEthAA} from "../../script/DeployEthAA.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {SendPackedUserOp, PackedUserOperation} from "../../script/SendPackedUserOp.s.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract EthAATest is Test {
    using MessageHashUtils for bytes32;

    HelperConfig helperConfig;
    EthAA ethAA;
    ERC20Mock usdc;
    SendPackedUserOp sendPackedUserOp;

    uint256 constant AMOUNT = 1e18;
    address randomUser = makeAddr("randomUser");

    function setUp() public {
        DeployEthAA deployEthAA = new DeployEthAA();
        (helperConfig, ethAA) = deployEthAA.deployEthAA();
        usdc = new ERC20Mock();
        sendPackedUserOp = new SendPackedUserOp();
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

    function test_nonOwnerCannotExecuteCommands() public {
        // need a mock erc20 contract and inputs
        assertEq(usdc.balanceOf(address(ethAA)), 0);
        address destination = address(usdc);
        uint256 value = 0;
        bytes memory data = abi.encodeWithSelector(ERC20Mock.mint.selector, address(ethAA), AMOUNT);

        vm.prank(randomUser);
        vm.expectRevert(EthAA.EthAA__NotFromEntryPointOrOwner.selector);
        ethAA.execute(destination, value, data);
    }

    function test_signingUserOp() public {
        // arange
        assertEq(usdc.balanceOf(address(ethAA)), 0);
        address destination = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(ethAA), AMOUNT);

        // since now we need to pass alt mempool + entrypoint contract + the contract so we need to wrap up all dest+value+funcitondata into the calldata
        bytes memory executeCallData = abi.encodeWithSelector(EthAA.execute.selector, destination, value, functionData);
        // hey entrpoint contract please call our contract and then our contract will call the usdc
        PackedUserOperation memory packedUserOp =
            sendPackedUserOp.generateSignedUserOperation(executeCallData, helperConfig.getConfig(),address(ethAA));


        bytes32 userOperationHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);
        //act
        address actualsigner = ECDSA.recover(userOperationHash.toEthSignedMessageHash(), packedUserOp.signature);

        //assert
        assertEq(actualsigner, ethAA.owner());
    }

    /**
     * Sign user ops
     * call validate userops
     * assert the return is correct
     */
    function test_validateUserOps() public {
        // we need packedUsersginedop for that we'll create a script which can get all of it and sign as well

        // copied part
        // arange
        assertEq(usdc.balanceOf(address(ethAA)), 0);
        address destination = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(ethAA), AMOUNT);

        // since now we need to pass alt mempool + entrypoint contract + the contract so we need to wrap up all dest+value+funcitondata into the calldata
        bytes memory executeCallData = abi.encodeWithSelector(EthAA.execute.selector, destination, value, functionData);
        // hey entrpoint contract please call our contract and then our contract will call the usdc
        PackedUserOperation memory packedUserOp =
            sendPackedUserOp.generateSignedUserOperation(executeCallData, helperConfig.getConfig(),address(ethAA));


        bytes32 userOperationHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);

        uint256 missingAccountFUnds = 1e18;
        vm.prank(helperConfig.getConfig().entryPoint);
        uint256 validationData = ethAA.validateUserOp(packedUserOp, userOperationHash, missingAccountFUnds);
        assertEq(validationData, 0);
    }

    function test_entryPointCanExecuteCommands() public {

        //copied again

         // copied part
        // arange
        assertEq(usdc.balanceOf(address(ethAA)), 0);
        address destination = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(ethAA), AMOUNT);

        // since now we need to pass alt mempool + entrypoint contract + the contract so we need to wrap up all dest+value+funcitondata into the calldata
        bytes memory executeCallData = abi.encodeWithSelector(EthAA.execute.selector, destination, value, functionData);
        // hey entrpoint contract please call our contract and then our contract will call the usdc
        PackedUserOperation memory packedUserOp =
            sendPackedUserOp.generateSignedUserOperation(executeCallData, helperConfig.getConfig(),address(ethAA));



        // since we do not have a paymaster setup we need to fund our contract for the alt-mempool to handle the gas stuff from it
        vm.deal(address(ethAA),1e18);

        // act
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = packedUserOp;
        // here we see that anybody can send to the entrypoint (here: any alt-mempool node) as long as its signed by us
        vm.prank(randomUser);
        // consider this random user as a node in alt-mempool getting the gas
        IEntryPoint(helperConfig.getConfig().entryPoint).handleOps(ops,payable(randomUser));

        //assert
        assertEq(usdc.balanceOf(address(ethAA)),AMOUNT);
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
