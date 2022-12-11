// SPDX-License-Identifier: ISC
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title Payable Contract
 * @author hey@kumareth.com
 * @notice If this abstract contract is inherited, the Contract becomes payable, it also allows Admins to manage Assets owned by the Contract.
 */
abstract contract Payable is Ownable {
    // Events
    event ReceivedFunds(
        address indexed by,
        uint256 fundsInwei,
        uint256 timestamp
    );
    event SentToBeneficiary(
        address indexed actionCalledBy,
        address indexed beneficiary,
        uint256 fundsInwei,
        uint256 timestamp
    );
    event ERC20SentToBeneficiary(
        address indexed actionCalledBy,
        address indexed beneficiary,
        address indexed erc20Token,
        uint256 tokenAmount,
        uint256 timestamp
    );
    event ERC721SentToBeneficiary(
        address indexed actionCalledBy,
        address indexed beneficiary,
        address indexed erc721ContractAddress,
        uint256 tokenId,
        uint256 timestamp
    );

    /// @notice To pay the contract
    function fund() external payable {
        emit ReceivedFunds(msg.sender, msg.value, block.timestamp);
    }

    // Fallbacks
    fallback() external payable virtual {
        emit ReceivedFunds(msg.sender, msg.value, block.timestamp);
    }

    receive() external payable virtual {
        emit ReceivedFunds(msg.sender, msg.value, block.timestamp);
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @notice So the Admins can maintain control over all the Funds this NFT Contract might accidentally own in future (to refund lost funds, etc.)
     * @dev Sends Wei the Contract might own, to the Beneficiary
     * @param _amountInWei Amount in Wei you think the Contract has, that you want to send to the Beneficiary
     * @return _success Whether the transaction was successful or not
     */
    function sendToBeneficiary(uint256 _amountInWei)
        external
        onlyOwner
        returns (bool _success)
    {
        (bool success, ) = payable(owner()).call{value: _amountInWei}("");
        require(success, "Transfer to Beneficiary failed.");

        emit SentToBeneficiary(
            msg.sender,
            owner(),
            _amountInWei,
            block.timestamp
        );

        return true;
    }

    /**
     * @notice So the Admins can maintain control over all the Tokens this NFT Contract might accidentally own in future (to refund lost tokens, etc.)
     * @dev Sends ERC20 tokens the Contract might own, to the Beneficiary
     * @param _erc20address Address of the ERC20 Contract
     * @param _tokenAmount Token Amount you think the Contract has, that you want to send to the Beneficiary
     * @return _success Whether the transaction was successful or not
     */
    function sendERC20ToBeneficiary(address _erc20address, uint256 _tokenAmount)
        external
        onlyOwner
        returns (bool _success)
    {
        IERC20 erc20Token;
        erc20Token = IERC20(_erc20address);

        erc20Token.transfer(owner(), _tokenAmount);

        emit ERC20SentToBeneficiary(
            msg.sender,
            owner(),
            _erc20address,
            _tokenAmount,
            block.timestamp
        );

        return true;
    }

    /**
     * @notice So the Admins can maintain control over all the ERC721 Tokens this NFT Contract might accidentally own in future (to refund lost NFTs, etc.)
     * @dev Sends ERC721 tokens the Contract might own, to the Beneficiary
     * @param _erc721address Address of the ERC721 Contract
     * @param _tokenId ID of the Token you wish to send to the Beneficiary.
     * @return _success Whether the transaction was successful or not
     */
    function sendERC721ToBeneficiary(address _erc721address, uint256 _tokenId)
        external
        onlyOwner
        returns (bool _success)
    {
        IERC721 erc721Token;
        erc721Token = IERC721(_erc721address);

        erc721Token.safeTransferFrom(address(this), owner(), _tokenId);

        emit ERC721SentToBeneficiary(
            msg.sender,
            owner(),
            _erc721address,
            _tokenId,
            block.timestamp
        );

        return true;
    }
}
