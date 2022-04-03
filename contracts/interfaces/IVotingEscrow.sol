// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IVotingEscrow is IERC20 {
    struct LockedBalance {
        int128 amount;
        uint256 end;
    }

    function totalSupply() external view returns (uint256);

    function locked__end(address) external view returns (uint256);

    function queuedPenalty() external view returns (uint256);

    function locked(address) external view returns (LockedBalance memory);

    function deposit_for(address, uint256) external;

    function migration() external view returns (bool);

    function admin() external view returns (address);

    function create_lock(uint256, uint256) external;

    function create_lock_for(
        address,
        uint256,
        uint256
    ) external;

    function withdraw() external;

    function migrate() external;

    function force_withdraw() external;

    function set_next_ve_contract(address) external;

    function set_reward_pool(address) external;

    function token() external view returns (address);
}
