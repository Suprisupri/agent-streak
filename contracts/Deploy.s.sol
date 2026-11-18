// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/AgentStreak.sol";

/// @title Deploy AgentStreak
/// @notice DRY-RUN ONLY by default. This script does NOT broadcast unless
///         invoked with `--broadcast`. Deploying to BSC mainnet/testnet
///         requires the project owner's explicit approval — see DEPLOY.md.
///
/// @dev DIRECT-DEPLOY path (testnet / ad-hoc). The PRODUCTION mainnet deploy
///      goes through the canonical Arachnid CREATE2 factory (see
///      FACTORY-DEPLOY.md): the Agentic wallet cannot send contract-creation
///      transactions, so it calls the factory instead, and the owner is
///      passed explicitly as a constructor argument.
///
///      Usage (dry-run, no broadcast, no key needed):
///         forge script script/Deploy.s.sol --rpc-url <RPC>
///      Broadcast (ONLY with owner approval):
///         forge script script/Deploy.s.sol --rpc-url <RPC> --broadcast \
///             --private-key $PRIVATE_KEY
contract Deploy is Script {
    /// @notice SPACE ID Agent ID contract on BNB Chain (chain 56).
    address public constant AGENT_ID_BSC = 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F;

    function run() external returns (AgentStreak) {
        // Broadcast only happens when `--broadcast` is passed; without it
        // this is a local simulation. Owner = the deploying wallet.
        vm.startBroadcast();
        AgentStreak streak = new AgentStreak(AGENT_ID_BSC, msg.sender);
        vm.stopBroadcast();

        console.log("AgentStreak deployed at:", address(streak));
        console.log("Agent ID contract:    ", AGENT_ID_BSC);
        console.log("Owner:                ", streak.owner());
        return streak;
    }
}
