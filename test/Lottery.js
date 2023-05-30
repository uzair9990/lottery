/*
  BECAUSE OF THE TIME CONSTRAINTS, I HAVE GENERATED
  TESTS USING HARDHAT ONLY FOR 1 OF THE SEVERAL 
  FUNCTIONS WRITTEN IN THE SMART CONTRACT.

  THE TESTS FOR REMAINER OF THE FUNCTIONS CAN
  ALSO BE GENERATED IN THE EXACT SAME MANNER.

  SO, THAT IS JUST COPY-PASTING STUFF ALMOST.
*/

const { expect } = require("chai");
const { ethers } = require("hardhat");

/*
  Testing the first function of our contract
  which allows us to purchase tickets. We will 
  test for two things here:
  
  1.That are supposed to go right
  2. Things that are supposed to go wrong
*/

describe("1. buyTicket( ... )", () => {
  let deployedLotteryContract, owner, user;
  let ticketPrice = ethers.utils.parseEther("3");
  let lotteryRunTime = 1800;

  /*
    This block of code will deploy the smart contract
    and give us addresses of the deployer and 1 dummy
    user every time before we run a test. We allow for
    1800 seconds (30 mins) to be the lottery running
    time.
  */

  beforeEach(async () => {
    let lotteryContract = await ethers.getContractFactory("Lottery");
    deployedLotteryContract = await lotteryContract.deploy(
      ticketPrice,
      lotteryRunTime
    );
    await deployedLotteryContract.deployed();

    let signers = await ethers.getSigners();
    (owner = signers[0]), (user = signers[1]);
  });

  it("successfully allows for ticket purchase if everything goes right", async () => {
    await expect(
      deployedLotteryContract.connect(user).buyTicket({ value: ticketPrice })
    ).to.not.be.reverted;
  });

  it("successfully emits an event when you buy a lottery ticket", async () => {
    const transaction = await deployedLotteryContract.connect(user).buyTicket({
      value: ticketPrice,
    });

    await expect(transaction)
      .to.emit(deployedLotteryContract, "TicketPurchaseSuccessful")
      .withArgs(transaction.from);
  });

  it("successfully updates the contractBalance after ticket purchase", async () => {
    await deployedLotteryContract
      .connect(user)
      .buyTicket({ value: ticketPrice });
    const updatedBalance = await deployedLotteryContract
      .connect(user)
      .contractBalance();
    expect(updatedBalance).to.equal(ticketPrice);
  });

  it("successfully updates user count during ticket purchase", async () => {
    await deployedLotteryContract
      .connect(user)
      .buyTicket({ value: ticketPrice });
    const updatedUserCount = await deployedLotteryContract
      .connect(user)
      .userCount();
    expect(updatedUserCount).to.equal(1);
  });

  it("fails to allow ticket purchase with insufficient ethers", async () => {
    await expect(
      deployedLotteryContract
        .connect(user)
        .buyTicket({ value: ethers.utils.parseEther("1") }) // 1 ETH
    ).to.be.revertedWith("Insufficient ETH tokens sent. Ticket price: 3 ETH");
  });

  it("fails to allow more than one tickets to be purchased", async () => {
    deployedLotteryContract.connect(user).buyTicket({ value: ticketPrice });

    await expect(
      deployedLotteryContract.connect(user).buyTicket({ value: ticketPrice })
    ).to.be.revertedWith(
      "You have already purchased the lottery ticket. You cannot purhcase a ticket again."
    );
  });

  it("fails to allow ticket purchase after lottery time is over", async () => {
    let lotteryContract = await ethers.getContractFactory("Lottery");
    deployedLotteryContract = await lotteryContract.deploy(
      ticketPrice, // 3 ETH
      1 // lottery time expires after 1 seconds to quickly test the expiration functionality
    );
    await deployedLotteryContract.deployed();
    let signers = await ethers.getSigners();
    (owner = signers[0]), (user = signers[1]);

    setTimeout(async () => {
      await expect(
        deployedLotteryContract.connect(user).buyTicket({ value: ticketPrice })
      ).to.be.revertedWith("Time's up. No more tickets will be sold now.");
    }, 2000); // 2 seconds wait
  });
});
