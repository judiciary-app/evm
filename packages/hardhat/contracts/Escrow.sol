// SPDX-License-Identifier: ISC
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IJudiciary {
    function escrowFactoryContractAddress() external view returns (address);

    function treasuryAddress() external view returns (address);

    function feesPermyriad() external view returns (uint8);
}

/**
 * @title The Escrow Contract
 * @author hey@kumareth.com
 * @notice Contract that holds the funds of the participants and releases them when the conditions are met
 */
contract Escrow is Initializable, ReentrancyGuardUpgradeable {
    address public treasuryAddress;
    address public mainContractAddress;
    uint8 public feesPermyriad;

    constructor() {
        //
    }

    bool public isFreezed;
    bool public blockNewParticipants;
    address public judge;

    address[] public participants;
    mapping(address => bool) public participantExists;

    /**
     * @notice Get an array of all the participants in the Escrow Wallet
     * @return _participants All the participants in the Escrow Wallet.
     */
    function getParticipants()
        public
        view
        returns (address[] memory _participants)
    {
        return participants;
    }

    /**
     * @notice Get number of participants in the Escrow Wallet
     * @return _totalParticipants Number of participants in the Escrow Wallet.
     */
    function totalParticipants()
        external
        view
        returns (uint256 _totalParticipants)
    {
        return participants.length;
    }

    // mappings to store the balances of the participants
    // amount of money an address has deposited in the contract
    mapping(address => mapping(address => uint256))
        public getEscrowRemainingInput; // [tokenAddress][participantAddress] => amount

    // amount of money an address can withdraw from the contract
    mapping(address => mapping(address => uint256))
        public getWithdrawableBalance; // [tokenAddress][participantAddress] => amount

    // amount of money an address can refund to a particular participant in the contract
    mapping(address => mapping(address => uint256)) public getRefundableBalance; // [tokenAddress][participantAddress] => amount

    /**
     * @notice Constructor function for the Escrow Contract Instances
     * @param _participants The array of addresses that will be the participants in the Escrow Wallet
     * @param _judge The address of the judge of the Escrow Wallet
     * @param _blockNewParticipants A boolean that determines if new participants can be added to the Escrow Wallet
     */
    function initialize(
        address[] memory _participants,
        address _judge,
        bool _blockNewParticipants
    ) public initializer {
        require(
            _participants.length >= 2,
            "at least two participants required"
        );

        // the Judiciary contract (so the Judiciary contract can pay this Escrow contract directly without being a participant)
        mainContractAddress = msg.sender;

        // no signatory should be a judge & make them participants
        for (uint256 i = 0; i < _participants.length; i++) {
            address _participant = _participants[i];
            require(
                _participant != _judge &&
                    _participant != address(0) &&
                    _participant != mainContractAddress,
                "corrupt participant found"
            );
            _addParticipant(_participant);
        }

        judge = _judge;
        isFreezed = false;
        blockNewParticipants = _blockNewParticipants;

        IJudiciary _mainContract = IJudiciary(mainContractAddress);
        treasuryAddress = _mainContract.treasuryAddress();
        feesPermyriad = _mainContract.feesPermyriad();
    }

    /**
     * @notice Get the tokens balance of the Escrow Wallet
     * @return _balance The tokens balance of the Escrow Wallet
     */
    function getBalance() public view returns (uint256 _balance) {
        return address(this).balance;
    }

    // Events
    event Deposit(
        address indexed depositor,
        address indexed recipient,
        address indexed token,
        uint256 amount,
        uint32 timestamp
    );
    event Freeze(uint32 timestamp);
    event Unfreeze(uint32 timestamp);
    event BlockNewParticipants(uint32 timestamp);
    event UnblockNewParticipants(uint32 timestamp);
    event NewParticipant(address indexed participant, uint32 timestamp);
    event Approve(
        address indexed from,
        address indexed by,
        address indexed to,
        address token,
        uint256 amount,
        uint32 timestamp
    );
    event Refund(
        address indexed from,
        address indexed by,
        address indexed to,
        address token,
        uint256 amount,
        uint32 timestamp
    );
    event Withdraw(
        address indexed by,
        address _token,
        uint256 amount,
        uint32 timestamp
    );

    // Fallbacks
    fallback() external payable virtual {
        deposit(address(0), address(this), msg.value);
    }

    receive() external payable virtual {
        deposit(address(0), address(this), msg.value);
    }

    // Modifiers
    modifier freezeCheck() {
        require(isFreezed == false, "escrow freezed");
        _;
    }
    modifier participantCheck() {
        require(
            blockNewParticipants == false ||
                participantExists[msg.sender] == true ||
                msg.sender == mainContractAddress, // so the Judiciary contract can pay this Escrow contract directly without being a participant
            "new participants blocked"
        );
        _;
    }
    modifier judgeCheck() {
        require(msg.sender == judge, "only for judge");
        _;
    }

    /**
     * @dev Internal function to add a participant to the Escrow Wallet if they are not already a participant
     */
    function _addParticipant(address _participant) internal {
        if (
            participantExists[_participant] != true &&
            _participant != judge &&
            _participant != address(0) &&
            _participant != mainContractAddress
        ) {
            participants.push(_participant);
            participantExists[_participant] = true;
            emit NewParticipant(_participant, uint32(block.timestamp));
        }

        // TODO: if they are a judge or the Judiciary contract, this function should probably revert?
    }

    /**
     * @dev Internal function that deposits funds/tokens into the Escrow Wallet
     */
    function _deposit(
        address _to,
        address _token,
        uint256 _amount
    ) internal {
        // sender becomes a participant and their input gets recorded
        _addParticipant(msg.sender);
        getEscrowRemainingInput[_token][msg.sender] =
            getEscrowRemainingInput[_token][msg.sender] +
            _amount;

        // get beneficiary
        address beneficiary = _to != address(0)
            ? _to
            : (
                participants[0] == msg.sender
                    ? participants[1]
                    : participants[0]
            );

        // if there are only 2 participants, then the other participant is the intended beneficiary unless specified
        if (participants.length == 2) {
            getRefundableBalance[_token][beneficiary] =
                getRefundableBalance[_token][beneficiary] +
                _amount;
        } else {
            // if there are more than 2 participants, then the beneficiary must be specified
            require(_to != address(0), "beneficiary not specified");

            // if the beneficiary is not a participant, then add them as a participant
            _addParticipant(_to);
        }

        emit Deposit(
            msg.sender,
            beneficiary,
            _token,
            _amount,
            uint32(block.timestamp)
        );
    }

    /**
     * @notice Deposit tokens to the Escrow Wallet
     * @param _to The address of the participant to whom the tokens is to be deposited
     * @param _token The address of the ERC20 smart contract of the token to be deposited
     * @param _amount The amount of tokens to be deposited
     * @return _success A boolean that determines if the deposit was successful
     */
    function deposit(
        address _to,
        address _token,
        uint256 _amount
    )
        public
        payable
        freezeCheck
        participantCheck
        nonReentrant
        returns (bool _success)
    {
        require(msg.sender != _to, "cant deposit yourself");

        uint256 treasuryAmount;

        if (msg.value > 0) {
            require(
                _token == address(this),
                "cant send tokens with native currency"
            ); // if tokens is being sent, then the token address must be the address of the contract

            // pay fees to treasury in native currency
            uint256 totalAmount = msg.value;
            treasuryAmount = (totalAmount * feesPermyriad) / 10000;
            if (treasuryAmount != 0) {
                (bool treasurySuccess, ) = payable(treasuryAddress).call{
                    value: treasuryAmount
                }("");
                require(treasurySuccess, "treasury payment failed");
            }

            _deposit(_to, address(this), totalAmount - treasuryAmount);

            return true;
        }

        // verify if _token is a valid erc20 token using interfaces
        require(
            IERC20(_token).totalSupply() > 0 && _token != address(this),
            "not a valid erc20 token"
        );

        // pay fees to treasury in tokens
        treasuryAmount = (_amount * feesPermyriad) / 10000;
        if (treasuryAmount != 0) {
            require(
                IERC20(_token).transferFrom(
                    msg.sender,
                    treasuryAddress,
                    treasuryAmount
                ),
                "treasury payment failed"
            );
        }

        // transfer tokens to the contract if this contract has the approval to transfer the tokens
        require(
            IERC20(_token).transferFrom(
                msg.sender,
                address(this),
                _amount - treasuryAmount
            ),
            "token transfer failed"
        );

        // run depository chores
        _deposit(_to, _token, _amount - treasuryAmount);

        return true;
    }

    /**
     * @notice For the buyer to approve the funds they sent into the contract, for the other party (usually the seller) to withdraw.
     * @param _from The address of the participant from whom the tokens is to be approved
     * @param _to The address of the participant to whom the tokens is to be approved
     * @param _token The address of the ERC20 smart contract of the token to be approved
     * @param _amount The amount of tokens to be approved
     * @param _attemptPayment A boolean that determines if the `_to` participant should be paid immediately
     * @return _success A boolean that determines if the approval was successful.
     */
    function approve(
        address _from,
        address _to,
        address _token,
        uint256 _amount,
        bool _attemptPayment
    ) external nonReentrant freezeCheck returns (bool _success) {
        require(
            msg.sender != _to &&
                _to != _from &&
                (msg.sender == _from || msg.sender == judge),
            "unauthorized approve"
        );
        require(
            _amount <= getEscrowRemainingInput[_token][_from],
            "insufficient escrow input"
        );

        require(
            _amount <= getRefundableBalance[_token][_to],
            "undeserving recipient"
        );

        // delete from remaining input
        getEscrowRemainingInput[_token][_from] =
            getEscrowRemainingInput[_token][_from] -
            _amount;

        // delete from refundable balance
        getRefundableBalance[_token][_to] =
            getRefundableBalance[_token][_to] -
            _amount;

        _addParticipant(_from);
        _addParticipant(_to);

        if (_attemptPayment) {
            if (_token == address(this)) {
                (bool success, ) = payable(_to).call{value: _amount}("");
                require(success, "payment failed");
            } else {
                IERC20(_token).transfer(_to, _amount);
            }
        } else {
            // add to beneficiary's withdrawable balance
            getWithdrawableBalance[_token][_to] =
                getWithdrawableBalance[_token][_to] +
                _amount;
        }

        emit Approve(
            _from,
            msg.sender,
            _to,
            _token,
            _amount,
            uint32(block.timestamp)
        );

        return true;
    }

    /**
     * @notice Withdraw your balance from the Escrow Contract
     * @param _token The address of the ERC20 smart contract of the token to be withdrawn
     * @param _amount The amount of tokens to be withdrawn
     * @return _success A boolean that determines if the approval was successful.
     */
    function withdraw(address _token, uint256 _amount)
        external
        nonReentrant
        freezeCheck
        returns (bool _success)
    {
        require(
            _amount <= getWithdrawableBalance[_token][msg.sender],
            "insufficient balance"
        );

        getWithdrawableBalance[_token][msg.sender] =
            getWithdrawableBalance[_token][msg.sender] -
            _amount;

        if (_token == address(this)) {
            (bool success, ) = payable(msg.sender).call{value: _amount}("");
            require(success, "withdraw failed");
        } else {
            IERC20(_token).transfer(msg.sender, _amount);
        }

        emit Withdraw(msg.sender, _token, _amount, uint32(block.timestamp));

        return true;
    }

    /**
     * @notice For the buyer to approve the funds they sent into the contract, for the other party (usually the seller) to withdraw.
     * @param _from The address of the participant from whom the tokens is to be refunded
     * @param _to The address of the participant to whom the tokens is to be refunded
     * @param _token The address of the ERC20 smart contract of the token to be refunded
     * @param _amount The amount of tokens to be refunded
     * @param _attemptPayment A boolean that determines if the `_to` participant should be paid immediately
     * @return _success A boolean that determines if the approval was successful.
     */
    function refund(
        address _from,
        address _to,
        address _token,
        uint256 _amount,
        bool _attemptPayment
    ) external nonReentrant freezeCheck returns (bool _success) {
        require(
            msg.sender != _to &&
                _to != _from &&
                (msg.sender == _from || msg.sender == judge),
            "unauthorized refund"
        );

        require(
            _amount <= getRefundableBalance[_token][_from],
            "insufficient refundable balance"
        );

        require(
            _amount <= getEscrowRemainingInput[_token][_to],
            "undeserving refund recipient"
        );

        // delete from remaining input
        getEscrowRemainingInput[_token][_to] =
            getEscrowRemainingInput[_token][_to] -
            _amount;

        // delete from refundable balance of msg.sender
        getRefundableBalance[_token][_from] =
            getRefundableBalance[_token][_from] -
            _amount;

        if (_attemptPayment) {
            if (_token == address(this)) {
                (bool success, ) = payable(_to).call{value: _amount}("");
                require(success, "refund failed");
            } else {
                IERC20(_token).transfer(_to, _amount);
            }
        } else {
            getWithdrawableBalance[_token][_to] =
                getWithdrawableBalance[_token][_to] +
                _amount;
        }

        emit Refund(
            _from,
            msg.sender,
            _to,
            _token,
            _amount,
            uint32(block.timestamp)
        );

        return true;
    }

    /**
     * @notice This function can be called by the judge to freeze the contract deposits, withdrawals, approvals and refunds.
     * @return _isFreezed A boolean that determines if the contract is freezed.
     */
    function toggleFreeze()
        external
        nonReentrant
        judgeCheck
        returns (bool _isFreezed)
    {
        if (isFreezed) {
            isFreezed = false;
            emit Unfreeze(uint32(block.timestamp));
        } else {
            isFreezed = true;
            emit Freeze(uint32(block.timestamp));
        }

        return isFreezed;
    }

    /**
     * @notice This function can be called by the judge to block new participants from joining the escrow.
     * @return _blockNewParticipants A boolean that determines if new participants can join the escrow.
     */
    function toggleParticipantBlock()
        external
        nonReentrant
        freezeCheck
        judgeCheck
        returns (bool _blockNewParticipants)
    {
        if (blockNewParticipants) {
            blockNewParticipants = false;
            emit UnblockNewParticipants(uint32(block.timestamp));
        } else {
            blockNewParticipants = true;
            emit BlockNewParticipants(uint32(block.timestamp));
        }

        return blockNewParticipants;
    }

    // TODO: Allow change of judge if all the participants agree
}
