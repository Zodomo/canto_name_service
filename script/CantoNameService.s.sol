// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/CantoNameService.sol";
import "../src/Allowlist.sol";

// forge script ./script/CantoNameService.s.sol --rpc-url http://127.0.0.1:8545 --broadcast

contract CantoNameServiceScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        uint256 allowlistCutoff = 30 * 86400;

        Allowlist allowlist = new Allowlist(allowlistCutoff);

        address AllowlistAddress = address(allowlist);

        CantoNameService cns = new CantoNameService(
            AllowlistAddress);

        for (uint256 i = 1; i < 6; ++i) {
            cns.vrgdaPrep(i, int256(5e18), int256(30 + i), int256(i + 10));
        }

        cns.vrgdaBatch();

        vm.stopBroadcast();
    }
}
