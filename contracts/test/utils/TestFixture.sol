// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
pragma abicoder v2;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {stdCheats} from "forge-std/stdlib.sol";
import {Vm} from "forge-std/Vm.sol";

import {Token} from "../Token.sol";
import {ExtendedDSTest} from "./ExtendedDSTest.sol";
import {IVotingEscrow} from "../../interfaces/IVotingEscrow.sol";
import "../../VeYfiRewards.sol";
import "../../Registry.sol";
import "../../Gauge.sol";
import "../../GaugeFactory.sol";
import "../../ExtraReward.sol";

// Artifact paths for deploying from the deps folder, assumes that the command is run from
// the project root.
string constant veArtifact = "foundry-artifacts/VotingEscrow.json";

// Base fixture
contract TestFixture is ExtendedDSTest, stdCheats {
    using SafeERC20 for IERC20;

    IVotingEscrow public veYFI;
    VeYfiRewards public veYfiRewards;
    IERC20 public yfi;
    GaugeFactory public gaugeFactory;
    Registry public registry;
    Token public vault;
    
    
    uint256 public constant WHALE_AMOUNT = 10**22;
    uint256 public constant SHARK_AMOUNT = 10**20;
    uint256 public constant FISH_AMOUNT = 10**18;
    
    address public gov = address(1);
    address public whale = address(2);
    address public shark = address(3);
    address public fish = address(4);
    address public panda = address(5);
    address public doggie = address(6);
    address public bunny = address(7);

    function setUp() public virtual {
        Token _yfi = new Token("YFI");
        yfi = IERC20(address(_yfi));
        depoloyVE(address(yfi));
        vault = new Token("mockVault");

        // create gauge factory and template
        Gauge _gaugeTemplate = new Gauge();
        ExtraReward _extraRewardTemplate = new ExtraReward();
        hoax(gov);
        gaugeFactory = new GaugeFactory(address(_gaugeTemplate), address(_extraRewardTemplate));
        hoax(gov);
        registry = new Registry(address(veYFI), address(yfi), address(gaugeFactory), address(veYfiRewards));

        // add more labels to make your traces readable
        vm_std_cheats.label(address(yfi), "YFI");
        vm_std_cheats.label(address(veYFI), "veYFI");
        vm_std_cheats.label(address(veYfiRewards), "veYfiRewards");
        vm_std_cheats.label(address(registry), "registry");
        vm_std_cheats.label(address(gaugeFactory), "gaugeFactory");
        vm_std_cheats.label(address(vault), "vault");
        vm_std_cheats.label(gov, "ychad");
        vm_std_cheats.label(whale, "whale");
        vm_std_cheats.label(shark, "shark");
        vm_std_cheats.label(fish, "fish");
        vm_std_cheats.label(panda, "panda");
        vm_std_cheats.label(doggie, "doggie");
        vm_std_cheats.label(bunny, "bunny");

        // do here additional setup
        tip(address(yfi), whale, WHALE_AMOUNT);
        tip(address(yfi), shark, SHARK_AMOUNT);
        tip(address(yfi), fish, FISH_AMOUNT);
        
    }

    // Deploys VotingEscrow
    function depoloyVE(address _token) public returns (address) {
        skip(1);
        vm_std_cheats.roll(1);
        hoax(gov);
        address _ve = deployCode(
            veArtifact,
            abi.encode(_token,"veYFI","veYFI", "1.0.0")
        );
        veYFI = IVotingEscrow(_ve);
        // setup rewards
        veYfiRewards = new VeYfiRewards(address(veYFI), address(yfi), gov);
        hoax(gov);
        veYFI.set_reward_pool(address(veYfiRewards));

        return address(veYFI);
    }

    function createGauge(address _vault) public returns (Gauge) {
        hoax(gov);
        address _gauge = registry.addVaultToRewards(_vault, gov, gov);

        return Gauge(_gauge);
    }
}
