pragma solidity ^0.4.19;

import 'zeppelin-solidity/contracts/math/SafeMath.sol';
import 'zeppelin-solidity/contracts/token/ERC20/ERC20Basic.sol';
import 'zeppelin-solidity/contracts/ownership/Ownable.sol';

//For Local Testing:
import 'zeppelin-solidity/contracts/token/ERC20/StandardToken.sol';

//////////////////////////////////
//////////////////////////////////
//////////////////////////////////
//////////////////////////////////

contract Diversify is Ownable {
    using SafeMath for uint256;

    event logInt(uint256 indexed value1);
    event logAddr(address indexed value1);
    event logStr(string indexed value1);

    uint256 constant FEE = 5;
    uint256 constant PRECISION = 100000;


    // ACTIVE: allows user contributions
    // LOCKED: user contributions and withdrawals are prohibited
    // FINALIZED: allows user withdrawls
    enum State {ACTIVE, LOCKED, FINALIZED}
    struct User {
        // Total user contribution in ETH
        uint256 contribution;
        bool hasFinalized;
    }
    // The current state of the contract
    State state = State.LOCKED;
    // Total contirbution in ETH
    uint256 totalGlobalBalance;
    // Address to send ETH for it to get diverisfied
    address exchangeAddr;
    mapping(address => User) users;
    address[] coinAddresses;
    mapping(address => uint256) initialCoinAmounts;

    function Diversify(address _exchangeAddr) public {
        exchangeAddr = _exchangeAddr;
        // TODO: make this more dynamic
        coinAddresses = [0x82d50ad3c1091866e258fd0f1a7cc9674609d254, 0xdda6327139485221633a1fcd65f4ac932e60a2e1];
        state = State.ACTIVE;
    }
    
    modifier onlyByExchange() {
        require(msg.sender == exchangeAddr);
        _;
    }

    modifier onlyWhileActive() {
        require(state == State.ACTIVE);
        _;
    }

    modifier onlyWhileLocked() {
        require(state == State.LOCKED);
        _;
    }

    modifier onlyWhileFinalized() {
        require(state == State.FINALIZED);
        _;
    }
    
    function globalBalance() public constant returns (uint256 _total) {
        if (totalGlobalBalance <= 0) return 0;
        return totalGlobalBalance;
    }
    
    function individualContribution() public constant returns (uint256 _contribution) {
        User storage user = users[msg.sender];
        if (user.contribution <= 0) return 0;
        return user.contribution;
    }
    
    // Deafult method: Process all ETH sent to the address
    function () public payable onlyWhileActive {
        // Allow the owner or exchange to send Ether to the contract arbitrarily.
        if ((msg.sender == owner || msg.sender == exchangeAddr) && msg.value > 0) {
          return;
        }

        handleUserContribution();
    }
    
    function handleUserContribution() public payable onlyWhileActive {
        User storage user = users[msg.sender];
        user.contribution = user.contribution.add(msg.value);
        totalGlobalBalance = totalGlobalBalance.add(msg.value);
    }
    
    // Exchange calls this function to have funds transferd to the exchange
    function initiateExchange() public onlyByExchange {
        state = State.LOCKED;
        // Send money to exchange minus the fee
        exchangeAddr.transfer(uint256((totalGlobalBalance.mul(100).sub(totalGlobalBalance.mul(FEE))).div(100)));
    }
    
    // Exhange calls this function when all funds have been transfered back to contract
    function finalizeExchange() public onlyByExchange onlyWhileLocked {
        for (uint i = 0; i < coinAddresses.length; i++) {
            address coinAddress = coinAddresses[i];
            ERC20Basic coinContract = ERC20Basic(coinAddress);
            uint256 currentCoinBalance = coinContract.balanceOf(this);
            assert(currentCoinBalance >= 0);
            initialCoinAmounts[coinAddress] = currentCoinBalance;
        }

        // If everything went well, update the state
        state = State.FINALIZED;
    }
    
    /**
     * If in the FINALIZED state
     * User can withdraw all the converted alt coins purchase by the exchange
     */
    function withdrawFunds() public onlyWhileFinalized {
        User storage user = users[msg.sender];
        require(totalGlobalBalance > 0);
        require(user.contribution > 0);
        require(!user.hasFinalized);
        user.hasFinalized = true;
        uint256 usersPercentage = uint256(user.contribution.mul(PRECISION).div(totalGlobalBalance));

        for (uint i = 0; i < coinAddresses.length; i++) {
            address coinAddress = coinAddresses[i];
            uint256 initialCoinAmount = initialCoinAmounts[coinAddress];
            // TODO: handle rounding better
            uint256 returnAmount = uint256(initialCoinAmount.mul(usersPercentage).div(PRECISION));
            ERC20Basic coinContract = ERC20Basic(coinAddress);
            if (!coinContract.transfer(msg.sender, returnAmount)) {
                revert();
            }
        }
    }

    ///////////////////////////////////////////////
    // Admin methods incase something went wrong //
    ///////////////////////////////////////////////

    function setActive() public onlyOwner {
        state = State.ACTIVE;
    }

    function setLocked() public onlyOwner {
        state = State.LOCKED;
    }

    function setFinalized() public onlyOwner {
        state = State.FINALIZED;
    }

    // Dummy Exchange Method for Testing
    function addCoins_testOnly() public onlyOwner {
        TestCoinOne testCoinOneContract = TestCoinOne(0x82d50ad3c1091866e258fd0f1a7cc9674609d254);
        testCoinOneContract.unsafeTransferFrom(owner, this, 100);

        TestCoinTwo testCoinTwoContract = TestCoinTwo(0xdda6327139485221633a1fcd65f4ac932e60a2e1);
        testCoinTwoContract.unsafeTransferFrom(owner, this, 200);
    }
}

// For Local Testing:

contract TestCoinOne is StandardToken {
    string public name = 'TestCoinOne';
    string public symbol = 'TCO';
    uint8 public decimals = 2;
    uint public INITIAL_SUPPLY = 12000;

    function TestCoinOne() public {
      totalSupply_ = INITIAL_SUPPLY;
      balances[msg.sender] = INITIAL_SUPPLY;
    }

    function unsafeTransferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        require(_to != address(0));
        require(_value <= balances[_from]);

        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);
        //emit Transfer(_from, _to, _value);
        return true;
    }
}

contract TestCoinTwo is StandardToken {
    string public name = 'TestCoinTwo';
    string public symbol = 'TCT';
    uint8 public decimals = 2;
    uint public INITIAL_SUPPLY = 12000;

    function TestCoinTwo() public {
      totalSupply_ = INITIAL_SUPPLY;
      balances[msg.sender] = INITIAL_SUPPLY;
    }

    function unsafeTransferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        require(_to != address(0));
        require(_value <= balances[_from]);

        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);
        //emit Transfer(_from, _to, _value);
        return true;
    }
}







