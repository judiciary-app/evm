// SPDX-License-Identifier: ISC
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IEscrow {
    function initialize(
        address[] memory _participants,
        address _judge,
        bool _blockNewParticipants
    ) external;

    function getParticipants()
        external
        view
        returns (address[] memory _participants);

    function totalParticipants()
        external
        view
        returns (uint256 _totalParticipants);

    function deposit(
        address _to,
        address _token,
        uint256 _amount
    ) external payable;
}

/**
 * @title The Escrow Factory Contract
 * @author hey@kumareth.com
 * @notice This is the factory that creates the Escrow instances
 */
contract EscrowFactory is Ownable {
    address public escrowContractAddress;
    address[] public allEscrows;

    event NewEscrow(
        address indexed hash,
        address indexed creator,
        uint32 timestamp
    );

    constructor(address _escrowContractAddress) {
        escrowContractAddress = _escrowContractAddress;
    }

    function _clone() internal returns (address result) {
        bytes20 targetBytes = bytes20(escrowContractAddress);

        //-> learn more: https://coinsbench.com/minimal-proxy-contracts-eip-1167-9417abf973e3 & https://medium.com/coinmonks/diving-into-smart-contracts-minimal-proxy-eip-1167-3c4e7f1a41b8
        assembly {
            let clone := mload(0x40)
            mstore(
                clone,
                0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
            )
            mstore(add(clone, 0x14), targetBytes)
            mstore(
                add(clone, 0x28),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )
            result := create(0, clone, 0x37)
        }

        require(result != address(0), "ERC1167: clone failed");
    }

    function _createEscrow(
        address[] memory _participants,
        address _judge,
        bool _blockNewParticipants
    ) internal returns (address result) {
        address proxy = _clone();
        allEscrows.push(proxy);
        IEscrow(proxy).initialize(_participants, _judge, _blockNewParticipants);
        emit NewEscrow(proxy, msg.sender, uint32(block.timestamp));
        return proxy;
    }

    function changeEscrowContractAddress(address _escrowContractAddress)
        external
        onlyOwner
        returns (address)
    {
        escrowContractAddress = _escrowContractAddress;
        return _escrowContractAddress;
    }
}
