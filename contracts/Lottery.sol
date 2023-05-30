pragma solidity ^0.8.18;
// SPDX-License-Identifier: Unlicense

contract Lottery {
    uint public contractBalance;
    uint public userCount;
    uint256 public lotteryStartTime;
    uint public lotteryRunTime;
    address public contractOwner;
    uint public ticketPrice;
    address[] public userAddresses;
    
    /*
        *** EXPLAINING TICKET PRICE DATA TYPE ***
        8 bits (1 byte) can store from 0 to 255 numbers. 
        We want to store only the value 3. So, we optimize 
        space by using uint8, rather than uint 256. 
    */
    
    mapping (address => uint8) public users;

    /*
        EXPLAINING MAPPING DATA STRUCTURE WRITTEN ABOVE ^^^
        
        *** SPACE OPTIMIZATION ***
        We only want to store "1" if they have already
        purchased the ticket as value of the key in the mapping. So, 
        we use uint8, so that we can save space, rather than using
        uint256 etc.


        *** TIME-COMPLEXITY OPTIMIZATION FROM 0(n) TO 0(1) ***
        We are adding our users to mapping 
        only because a mapping is key-value, which means
        the next time we have to see if the user has already
        bought ticket and we want to stop them from buying
        again, then we can quickly use hash functions to look
        up in the mapping if this person is present or not.
        Therefore, we will be able to perform this task in
        O(1) with mapping, rather than O(n) with arrays.

        However, we do have an array as well. That's because
        we want to iterate over the entire mapping to empty it
        when re-starting the whole lottery system.
    */

    event TicketPurchaseSuccessful(
        address indexed purchasedBy
    );

    event LotteryWinner(
        address indexed lotteryWinner
    );

    constructor(uint _ticketPrice, uint _lotteryStartTime) {
        ticketPrice = _ticketPrice; // ETH
        contractBalance = 0;
        userCount = 0;
        lotteryStartTime = block.timestamp;
        lotteryRunTime = _lotteryStartTime; // 1800 seconds, 30 minutes
        contractOwner = msg.sender;
    }

    /*
        *** STEP-01: buyTicket( ... ) FUNCTION EXPLAINED ***

        We reject you in either if you have already purchased a ticket, 
        or if you are sending in less ETH to buy the ticket, or if you
        are trying to purchase the ticket after the time has expired (even
        if no external party has called the winner). If all the conditions are met,
        we take money from you and mark you as "1", meaning you have bought the ticket.
        The function is supposed to be external, as only the parties from outside the 
        contract will be calling it. The function is also payable, so that
        we can receive money via this function when they are trying to buy
        the ticket.



        *** STEP-02: GAS EFFICIENCY Vs. CODE READABILITY TRADE-OFFS EXPLAINED ***

        In the require statement, we are reading state values, like 
        ticketPrice and lotteryRunTime. We could have hardcoded them 
        as well as 3 ETH and 30 minutes respectively which wouldh have
        saved us some gas (reading state incurs gas). But I deliberately
        did not hardcode values, as they are being used in other places
        too. So, to maintain the value consistency and code maintainability
        throughout the contract, it is better that we read the state rather than
        hardcoding the values, though we can save us some gas that way.

    */

    function buyTicket() external payable { 
        require(users[msg.sender] == 0, "You have already purchased the lottery ticket. You cannot purhcase a ticket again."); // only once purchasing allowed
        require(msg.value >= ticketPrice, "Insufficient ETH tokens sent. Ticket price: 3 ETH"); 
        require(block.timestamp < lotteryStartTime + lotteryRunTime, "Time's up. No more tickets will be sold now.");
        
        contractBalance += msg.value;
        users[msg.sender] = 1;
        userCount++;
        userAddresses.push(msg.sender);

        emit TicketPurchaseSuccessful(msg.sender);
    }

    /*
        *** STEP-01: announceWinner( ... ) FUNCTION EXPLAINED ***

        Only the owner of the contract can announce the winners, and that
        too only after 30 minutes. Else, we reject you. Then, we randomly
        choose the winner and finally re-set the entire contract state
        to re-start the process.


        *** STEP-02: ALGORITHM EXPLAINED FOR CHOOSING THE WINNER RANDOMLY ***

        WARNING!!! =====> I have created a system with fair-enough security. However, if more
        time is given, a robust system with more security can be created using, 
        for example, commit-now, reveal-future algorithm, which is very
        famous for doing these kind of things. But what I have used (in limited time
        available to me to solve the tasks) goes as follows:

        We try to get as many as possible elements (publicly known) from the blockchain.
        We hash them twice and convert them to integer in the end. Now, this integer
        is taken modulo with the length of the array (all users) to find address of 
        one person who will win.

        The idea is simple: when there are more elements going into our formula, it 
        will be harder for bad guys to pre-compute / guess ALL OF THEM at the same time.
        So, we will get some level of certainty and surety that the code will be hard to
        crack.

    */

    function announceWinner() external {
        require(block.timestamp >= lotteryStartTime + lotteryRunTime, "The lottery process must continue for 30 minutes at least.");
        require(msg.sender == contractOwner, "Only the contract owner can announce the lottery winner.");
        
        uint256 winnerIndex = uint256(
            keccak256(
                abi.encode(
                    keccak256(
                        abi.encodePacked(
                            msg.sender,
                            tx.origin,
                            gasleft(),
                            block.timestamp,
                            block.number,
                            blockhash(block.number),
                            blockhash(block.number - 100)
                        )
                    )
                )
            )
        ) % userAddresses.length;

        address winnerAddress = userAddresses[winnerIndex];
        address payable winnerPayable = payable(winnerAddress);
        winnerPayable.transfer(contractBalance);
        
        emit LotteryWinner(winnerPayable);
        
        restartLotterySystem();
    }

    /*
        *** STEP-01: restartLotterySystem( ... ) FUNCTION EXPLAINED ***

        We set several state values to their initial value. Total users 0, 
        new start time to now and contract balance to 0 (it already is, as we
        transferred all the money to the winner). Also, we empty the mapping
        and the array, so that we can start all over.
    */

    function restartLotterySystem() private {
        userCount = 0;
        contractBalance = 0;

        for (uint i = 0; i < userAddresses.length; i++) {
            delete users[userAddresses[i]];
        }
        delete userAddresses;

        lotteryStartTime = block.timestamp;
    }
}
