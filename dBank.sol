// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Token.sol";

contract dBank {

  //assign Token contract to variable
  Token private token;

  //add mappings
  mapping(address => uint) public depositStart;
  mapping(address => uint) public etherBalanceOf;
  mapping(address => uint) public collateralEther;
  mapping(address => bool) public isDeposited;
  mapping(address => bool) public isBorrowed;

  //add events
  event Deposit(address indexed user,uint etherAmount,uint timeStart);
  event Withdraw(address indexed user,uint etherAmount,uint depositTime,uint interest);
  event Borrow(address indexed user, uint collateralEtherAmount, uint borrowedTokenAmount);
  event PayOff(address indexed user, uint fee);

  //pass as constructor argument deployed Token contract
  constructor(Token _token) {

    token = _token;
    //assign token deployed contract to variable
  }

  function deposit() payable public {

    //check if msg.sender didn't already deposited funds
    require(isDeposited[msg.sender] == false,"Error,deposit already active");
    //check if msg.value is >= than 0.01 ETH
    require(msg.value >= 1e16,"Error,deposit must be >=0.01 ETH");
     
    //increase msg.sender ether deposit balance
    etherBalanceOf[msg.sender] = etherBalanceOf[msg.sender] + msg.value;
    //start msg.sender hodling time
    depositStart[msg.sender] = depositStart[msg.sender] + block.timestamp;
    
    //set msg.sender deposit status to true
    isDeposited[msg.sender] = true;
     //emit Deposit event
    emit Deposit(msg.sender, msg.value, block.timestamp);
  }

  function withdraw() payable public {

    //check if msg.sender deposit status is true
    require(isDeposited[msg.sender] == true,"Error,no previous deposit");
    uint userBalance = etherBalanceOf[msg.sender];
    //assign msg.sender ether deposit balance to variable for event

    //check user's hodl time
    uint depositTime = block.timestamp - depositStart[msg.sender];

    //calc interest per second
    uint interestPerSecond = 31668017 * (etherBalanceOf[msg.sender]/1e16);
    uint interest = interestPerSecond * depositTime;
    //calc accrued interest

    //send eth to user
    payable(msg.sender).transfer(userBalance);
    token.mint(msg.sender, interest);
    //send interest in tokens to user

    //reset depositer data
    depositStart[msg.sender] = 0;
    etherBalanceOf[msg.sender] = 0;
    isDeposited[msg.sender] = false;

    //emit event
    emit Withdraw(msg.sender,userBalance,depositTime,interest);
  }

  function borrow() payable public {

    //check if collateral is >= than 0.01 ETH
    require(msg.value>=1e16, 'Error, collateral must be >= 0.01 ETH');
    //check if user doesn't have active loan
    require(isBorrowed[msg.sender] == false, 'Error, loan already taken');
     
    //add msg.value to ether collateral
    //this Ether will be locked till user payOff the loan
    collateralEther[msg.sender] = collateralEther[msg.sender] + msg.value;

    //calc tokens amount to mint, 50% of msg.value
    uint tokensToMint = collateralEther[msg.sender] / 2;

    //mint&send tokens to user
    token.mint(msg.sender, tokensToMint);

    //activate borrower's loan status
    isBorrowed[msg.sender] = true;

     //emit event
    emit Borrow(msg.sender, collateralEther[msg.sender], tokensToMint);
  }

  function payOff() payable public {

    //check if loan is active
    require(isBorrowed[msg.sender] == true, 'Error, loan not active');
    //transfer tokens from user back to the contract
    require(token.transferFrom(msg.sender, address(this), collateralEther[msg.sender]/2), "Error, can't receive tokens"); //must approve dBank 1st
    
    //calc fee
    uint fee = collateralEther[msg.sender]/10; //calc 10% fee

    //send user's collateral minus fee
    payable(msg.sender).transfer(collateralEther[msg.sender]-fee);
  
    //reset borrower's data
    collateralEther[msg.sender] = 0;
    isBorrowed[msg.sender] = false;

    //emit event
    emit PayOff(msg.sender, fee);

  }
}
