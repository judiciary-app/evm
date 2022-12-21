// SPDX-License-Identifier: ISC
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./utils/NFT.sol";
import "./EscrowFactory.sol";

/**
 * @title Judiciary Contract
 * @author hey@kumareth.com
 * @notice This contract shall be the prime Judiciary NFT contract for creation of contracts in the Metaverse!
 */
contract Judiciary is NFT, EscrowFactory, ReentrancyGuard {
    /**
     * @notice Constructor function for the Judiciary Contract
     * @dev Constructor function for the Judiciary ERC721 Contract
     * @param name_ Name of the Judiciary artifact Collection
     * @param symbol_ Symbol for the Judiciary NFTs
     * @param initialAddresses_ Address of the Owner Contract that manages Permissions.
     * @param contractURI_ URL of Json metadata for this Contract
     */
    constructor(
        string memory name_,
        string memory symbol_,
        address[] memory initialAddresses_, // [ address ownerAddress, address escrowContractAddress, address treasuryAddress ]
        string memory contractURI_
    )
        payable
        NFT(name_, symbol_, contractURI_)
        EscrowFactory(initialAddresses_[1])
    {
        _transferOwnership(initialAddresses_[0]);
        escrowContractAddress = initialAddresses_[1];
        treasuryAddress = initialAddresses_[2];

        // create a fake genesis NFT (so tokenIds start with 1)
        _safeMint(msg.sender, 0);
    }

    // constants
    address public treasuryAddress;
    uint8 public feesPermyriad = 255;

    // token IDs counter
    using Counters for Counters.Counter;
    Counters.Counter public totalTokensMinted;

    // mappings
    mapping(address => uint256[]) public getTokenIdsByEscrowAddress;
    mapping(uint256 => address) public getEscrowAddressByTokenId;
    mapping(uint256 => address) public getContractSignerByTokenId;
    mapping(address => address[]) public getEscrowAddressesBySignerAddress;
    mapping(address => address[]) public getEscrowAddressesByJudgeAddress;
    mapping(address => mapping(address => bool)) public hasSignedContract; // [escrowAddress][signerAddress] => true/false

    /**
     * @notice returns escrowAddresses for the given signerAddress
     * @dev returns an array of escrowAddresses for the given signerAddress
     * @param _signerAddress Address of the Signer
     * @return _escrowAddressesBySignerAddress Array of Escrow Addresses
     */
    function fetchEscrowAddressesBySignerAddress(address _signerAddress)
        external
        view
        returns (address[] memory _escrowAddressesBySignerAddress)
    {
        return getEscrowAddressesBySignerAddress[_signerAddress];
    }

    /**
     * @notice returns escrowAddresses for the given judgeAddress
     * @dev returns an array of escrowAddresses for the given judgeAddress
     * @param _judgeAddress Address of the Judge
     * @return _escrowAddressesByJudgeAddress Array of Escrow Addresses
     */
    function fetchEscrowAddressesByJudgeAddress(address _judgeAddress)
        external
        view
        returns (address[] memory _escrowAddressesByJudgeAddress)
    {
        return getEscrowAddressesByJudgeAddress[_judgeAddress];
    }

    /**
     * @notice returns tokenIds for the given escrowAddress
     * @dev returns an array of tokenIds for the given escrowAddress
     * @param _escrowAddress Address of the Escrow Wallet
     * @return _tokenIds Array of Token IDs
     */
    function fetchTokenIdsByEscrowAddress(address _escrowAddress)
        external
        view
        returns (uint256[] memory _tokenIds)
    {
        return getTokenIdsByEscrowAddress[_escrowAddress];
    }

    // See EIP-2981 for more information: https://eips.ethereum.org/EIPS/eip-2981
    struct RoyaltyInfo {
        address receiver;
        uint256 percent; // it's actually a permyriad (parts per ten thousand)
    }
    mapping(uint256 => RoyaltyInfo) public getRoyaltyInfoByTokenId;

    /**
     * @notice returns royalties info for the given Token ID
     * @dev can be used by other contracts to get royaltyInfo
     * @param _tokenID Token ID of which royaltyInfo is to be fetched
     * @param _salePrice Desired Sale Price of the token to run calculations on
     * @return receiver Address of the receiver of the royalties
     * @return royaltyAmount Royalty Amount
     */
    function royaltyInfo(uint256 _tokenID, uint256 _salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount)
    {
        RoyaltyInfo memory rInfo = getRoyaltyInfoByTokenId[_tokenID];
        if (rInfo.receiver == address(0)) return (address(0), 0);
        uint256 amount = (_salePrice * rInfo.percent) / 10000;
        return (payable(rInfo.receiver), amount);
    }

    // Events
    event CreateContract(
        address indexed hash,
        address indexed creator,
        address indexed judge,
        address[] intendedSignatories,
        uint32 createdAt
    );
    event SignContract(
        address indexed hash,
        address indexed signer,
        string indexed contractURI,
        uint32 signedAt
    );

    /**
     * @dev Internal function used to handle any Escrow payment (manages fee collection)
     * @param _escrowWalletAddress Address of the Escrow Wallet
     */
    function _pay(address _escrowWalletAddress) internal {
        if (msg.value > 0) {
            require(
                IEscrow(_escrowWalletAddress).totalParticipants() <= 2,
                "cannot directly deposit"
            );
            IEscrow(_escrowWalletAddress).deposit{value: msg.value}(
                address(0),
                _escrowWalletAddress,
                msg.value
            );
        }
    }

    /**
     * @dev Internal function used to create the Judiciary NFT that represents signed contract
     * @param _receiver Address of the receiver of the NFT
     * @param _escrowWalletAddress Address of the Escrow Wallet
     * @param _tokenURI URL of the JSON metadata for the NFT
     * @return _tokenId Token ID of the NFT created
     */
    function _createNFT(
        address _receiver,
        address _escrowWalletAddress,
        string memory _tokenURI
    ) internal returns (uint256 _tokenId) {
        totalTokensMinted.increment();
        uint256 tokenId = totalTokensMinted.current();
        _safeMint(_receiver, tokenId);
        _setTokenURI(tokenId, _tokenURI);

        getTokenIdsByEscrowAddress[_escrowWalletAddress].push(tokenId);
        getEscrowAddressByTokenId[tokenId] = _escrowWalletAddress;
        getContractSignerByTokenId[tokenId] = _receiver;
        getEscrowAddressesBySignerAddress[_receiver].push(_escrowWalletAddress);

        hasSignedContract[_escrowWalletAddress][_receiver] = true;

        return tokenId;
    }

    /**
     * @notice Create a new Judiciary Contract
     * @param _contractURI URL of the JSON metadata for the Contract (can be IPFS hash)
     * @param _intendedSignatories Array of addresses of the intended signatories
     * @param _judge Address of the judge who can resolve the contract related dispute
     * @return _tokenId Token ID of the NFT created
     * @return _escrowWalletAddress Address of the Escrow Wallet created for the contract
     */
    function createContract(
        string memory _contractURI,
        address[] memory _intendedSignatories,
        address _judge
    ) public payable returns (uint256 _tokenId, address _escrowWalletAddress) {
        // contract uri cannot be empty
        require(bytes(_contractURI).length > 0, "empty contract uri");

        // create escrow wallet
        address escrowWalletAddress = _createEscrow(
            _intendedSignatories,
            _judge,
            true
        );

        getEscrowAddressesByJudgeAddress[_judge].push(escrowWalletAddress);

        // send payment to the newly created escrow wallet
        _pay(escrowWalletAddress);

        // mint a token to msg.sender if the msg.sender is in _intendedSignatories
        uint256 tokenId;
        for (uint256 i = 0; i < _intendedSignatories.length; i++) {
            if (msg.sender == _intendedSignatories[i]) {
                tokenId = _createNFT(
                    _intendedSignatories[i],
                    escrowWalletAddress,
                    _contractURI
                );

                emit SignContract(
                    _escrowWalletAddress,
                    msg.sender,
                    _contractURI,
                    uint32(block.timestamp)
                );

                break;
            }
        }

        emit CreateContract(
            escrowWalletAddress,
            msg.sender,
            _judge,
            _intendedSignatories,
            uint32(block.timestamp)
        );

        return (tokenId, escrowWalletAddress);
    }

    /**
     * @notice Sign a Judiciary Contract
     * @param _escrowWalletAddress Address of the Escrow Wallet associated to the contract that you want to sign
     * @return _tokenId Token ID of the NFT created
     */
    function signContract(address _escrowWalletAddress)
        external
        payable
        returns (uint256 _tokenId)
    {
        // get the participants from the escrowWalletAddress (Escrow.sol)
        address[] memory participants = IEscrow(payable(_escrowWalletAddress))
            .getParticipants();

        // send payment to the escrow wallet
        _pay(_escrowWalletAddress);

        // get contractURI from tokenID that is associated with the escrowWalletAddress
        uint256 formerTokenId = getTokenIdsByEscrowAddress[
            _escrowWalletAddress
        ][0];
        string memory contractURI = tokenURI(formerTokenId);

        // check if the msg.sender has already signed the contract
        require(
            hasSignedContract[_escrowWalletAddress][msg.sender] != true,
            "already signed"
        );

        // mint a token to msg.sender if the msg.sender is in participants
        uint256 tokenId;
        for (uint256 i = 0; i < participants.length; i++) {
            if (msg.sender == participants[i]) {
                tokenId = _createNFT(
                    participants[i],
                    _escrowWalletAddress,
                    contractURI
                );
                break;
            }
        }

        emit SignContract(
            _escrowWalletAddress,
            msg.sender,
            contractURI,
            uint32(block.timestamp)
        );

        return tokenId;
    }

    /**
     * @notice For the owner to change the fees (fees can never exceed 2.55%, range: 0-255)
     * @param _feesPermyriad Range: 0-255 (0.00% - 2.55%)
     * @return _success Boolean to indicate if the fees were changed successfully
     */
    function changeFeesPermyriad(uint8 _feesPermyriad)
        external
        onlyOwner
        returns (bool _success)
    {
        feesPermyriad = _feesPermyriad;
        return true;
    }

    /**
     * @notice For the owner to change the treasuryAddress
     * @param _treasuryAddress Any address that is non-zero
     * @return _success Boolean to indicate if the fees were changed successfully
     */
    function changeTreasuryAddress(address _treasuryAddress)
        external
        onlyOwner
        returns (bool _success)
    {
        require(_treasuryAddress != address(0));
        treasuryAddress = _treasuryAddress;
        return true;
    }
}
