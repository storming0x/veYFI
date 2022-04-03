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
import {ExtraReward} from "../../ExtraReward.sol";
import {Gauge} from "../../Gauge.sol";
import {GaugeFactory} from "../../GaugeFactory.sol";
import {Registry} from "../../Registry.sol";
import {VeYfiRewards} from "../../VeYfiRewards.sol";

// Artifact paths for deploying from the deps folder, assumes that the command is run from
// the project root.
string constant veArtifact = "foundry-artifacts/VotingEscrow.json";

// Base fixture
contract TestFixture is ExtendedDSTest, stdCheats {
    using SafeERC20 for IERC20;

    IVotingEscrow public veYFI;
    VeYfiRewards public veYfiRewards;
    IERC20 public yfi;
    IERC20 public vault;
    GaugeFactory public gaugeFactory;
    Registry public registry;

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
        deployGaugeFactory();
        deployRegistry();
        deployVault();

        // add more labels to make your traces readable
        vm_std_cheats.label(address(yfi), "YFI");
        vm_std_cheats.label(address(veYFI), "veYFI");
        vm_std_cheats.label(address(veYfiRewards), "veYfiRewards");
        vm_std_cheats.label(address(vault), "Vault");
        vm_std_cheats.label(address(gaugeFactory), "GaugeFactory");
        vm_std_cheats.label(address(registry), "Registry");
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
            abi.encode(_token, "veYFI", "veYFI", "1.0.0")
        );
        veYFI = IVotingEscrow(_ve);
        // setup rewards
        veYfiRewards = new VeYfiRewards(address(veYFI), address(yfi), gov);
        hoax(gov);
        veYFI.set_reward_pool(address(veYfiRewards));

        return address(veYFI);
    }

    function deployGaugeFactory() public returns (address) {
        startHoax(gov);
        Gauge _gauge = new Gauge();
        ExtraReward _extraReward = new ExtraReward();
        gaugeFactory = new GaugeFactory(address(_gauge), address(_extraReward));
        vm_std_cheats.stopPrank();
        return address(gaugeFactory);
    }

    function deployRegistry() public returns (address) {
        hoax(gov);
        registry = new Registry(
            address(veYFI),
            address(yfi),
            address(gaugeFactory),
            address(veYfiRewards)
        );
        return address(registry);
    }

    function deployVault() public returns (address) {
        hoax(gov);
        vault = new Token("Yearn vault");
        return address(vault);
    }

    function createToken(string memory _name) public returns (Token) {
        hoax(gov);
        Token _token = new Token(_name);
        return _token;
    }

    function createGauge(address _vault) public returns (address) {
        hoax(gov);
        address _gauge = registry.addVaultToRewards(_vault, gov, gov);
        return _gauge;
    }

    function createExtraReward(address _gauge, address _reward)
        public
        returns (address)
    {
        hoax(gov);
        address _extraReward = gaugeFactory.createExtraReward(
            _gauge,
            _reward,
            gov
        );
        return _extraReward;
    }
}
