// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {EthAA} from "src/ethereum/EthAA.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract DeployEthAA is Script {
    function run() public {
        deployEthAA();
    }

    function deployEthAA() public returns (HelperConfig, EthAA) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        vm.startBroadcast(config.account);
        EthAA ethAA = new EthAA(config.entryPoint);
        ethAA.transferOwnership(config.account);
        vm.stopBroadcast();
        return (helperConfig, ethAA);
    }
}