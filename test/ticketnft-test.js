const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("TicketNft Deployment", function () {
  let ticketNft;

  beforeEach(async function () {
    const TicketNft = await hre.ethers.getContractFactory("TicketNft");
    ticketNft = await TicketNft.deploy();
  });

  it("Genesis information is configured", async function () {
    const re = await ticketNft.genInfo(0);
    
    expect(re[1]).to.equal(true);
  });


  it("Cant edit genesis configuration", async function () {
    await expect(ticketNft.setGenerationInfo(0, 10, 10)).
      to.be.revertedWith("Cant modify genesis generation");
  });

  it("Cant mint not configured generation", async function () {
    const accounts = await hre.ethers.getSigners();
    const myAccount = accounts[0].address;

    await expect(ticketNft.mintTicket(
      myAccount,
      false,
      1,
      86400,
      "http://google.es"
    )).
      to.be.revertedWith("Not Enabled to mint yet");
  });

  it("Can't put 1001 as mint limit for generation", async function () {
    await expect(ticketNft.setGenerationInfo(1, 1001, 10)).
      to.be.revertedWith("Mint limit for generation should be in range");
  });

  it("Can edit generation 1 configuration (already configured)", async function () {
    await ticketNft.setGenerationInfo(1, 10, 10)
    const re = await ticketNft.genInfo(1);
    
    expect(re[1]).to.equal(true);
    expect(re[2]).to.equal("10");
    expect(re[3]).to.equal("10");
  });

    /*
    address recipient,
        bool lifeTime,
        uint256 generation,
        uint256 timeAccess,
        string calldata tokenURI
    */
  it("Mint genesis lifetime ticket", async function () {
    const accounts = await hre.ethers.getSigners();
    const myAccount = accounts[0].address;
    
    await ticketNft.mintTicket(
      myAccount,
      true,
      0,
      86400,
      "http://google.es"
    );
    
    const balance = await ticketNft.balanceOf(myAccount);
    expect(balance).to.equal("1");

    const myNftTokenId = await ticketNft.walletTokenIds(myAccount, 0);

    const owner = await ticketNft.ownerOf(myNftTokenId);
    expect((await ticketNft.ownerOf(myNftTokenId))).to.equal(myAccount);
  });

  it("Can't fusion generation 0", async function () {
    const accounts = await hre.ethers.getSigners();
    const myAccount = accounts[0].address;
    
    await ticketNft.mintTicket(
      myAccount,
      true,
      0,
      86400,
      "http://google.es"
    );

    const myNftTokenId = await ticketNft.walletTokenIds(myAccount, 0);

    await expect(
      ticketNft.fusionTickets(myAccount, [myNftTokenId], "http://google.es")
    ).
      to.be.revertedWith("Can't fusion generation 0");
  });

  it("Fusion temporal tickets", async function () {
    await ticketNft.setGenerationInfo(1, 10, 10);

    const accounts = await hre.ethers.getSigners();
    const myAccount = accounts[0].address;
    
    await ticketNft.mintTicket(
      myAccount,
      false,
      1,
      86400,
      "http://google.es"
    );

    await ticketNft.mintTicket(
      myAccount,
      false,
      1,
      86400,
      "http://google.es"
    );
    
    const nftAmount = await ticketNft.walletNftAmount(myAccount);
    expect(nftAmount).to.equal(2);

    const myNftTokenId1 = await ticketNft.walletTokenIds(myAccount, 0);
    const myNftTokenId2 = await ticketNft.walletTokenIds(myAccount, 1);

    await ticketNft.fusionTickets(myAccount, [myNftTokenId1, myNftTokenId2], "http://google.es");

    const token1 = await ticketNft.byTokenIdIdData(myNftTokenId1);
    const token2 = await ticketNft.byTokenIdIdData(myNftTokenId2);

    expect(token1[7]).to.equal(true);
    expect(token2[7]).to.equal(true);
  });


  it("Fusion temporal tickets get not enough revert", async function () {
    await ticketNft.setGenerationInfo(1, 10, 5);

    const accounts = await hre.ethers.getSigners();
    const myAccount = accounts[0].address;
    
    await ticketNft.mintTicket(
      myAccount,
      false,
      1,
      86400,
      "http://google.es"
    );

    await ticketNft.mintTicket(
      myAccount,
      false,
      1,
      86400,
      "http://google.es"
    );

    await ticketNft.mintTicket(
      myAccount,
      false,
      1,
      86400,
      "http://google.es"
    );
    
    const nftAmount = await ticketNft.walletNftAmount(myAccount);
    expect(nftAmount).to.equal(3);

    const myNftTokenId1 = await ticketNft.walletTokenIds(myAccount, 0);
    const myNftTokenId2 = await ticketNft.walletTokenIds(myAccount, 1);
    const myNftTokenId3 = await ticketNft.walletTokenIds(myAccount, 2);

    
    await expect(ticketNft.fusionTickets(myAccount, [myNftTokenId1, myNftTokenId2, myNftTokenId3], "http://google.es")).
      to.be.revertedWith("Need 2 for temporary access");
  });



  it("Fusion temporal tickets get lifetime ticket", async function () {
    await ticketNft.setGenerationInfo(1, 10, 3);

    const accounts = await hre.ethers.getSigners();
    const myAccount = accounts[0].address;
    
    await ticketNft.mintTicket(
      myAccount,
      false,
      1,
      86400,
      "http://google.es"
    );

    await ticketNft.mintTicket(
      myAccount,
      false,
      1,
      86400,
      "http://google.es"
    );

    await ticketNft.mintTicket(
      myAccount,
      false,
      1,
      86400,
      "http://google.es"
    );

    const nftAmount = await ticketNft.walletNftAmount(myAccount);
    expect(nftAmount).to.equal(3);

    let myNftTokenId1 = await ticketNft.walletTokenIds(myAccount, 0);
    let myNftTokenId2 = await ticketNft.walletTokenIds(myAccount, 1);
    let myNftTokenId3 = await ticketNft.walletTokenIds(myAccount, 2);

    
    await ticketNft.fusionTickets(myAccount, [myNftTokenId1, myNftTokenId2, myNftTokenId3], "http://google.es");    

    myNftTokenId1 = await ticketNft.byTokenIdIdData(1);
    myNftTokenId2 = await ticketNft.byTokenIdIdData(2);
    myNftTokenId3 = await ticketNft.byTokenIdIdData(3);
    myNftTokenId4 = await ticketNft.byTokenIdIdData(4);
    
    // burned
    expect(myNftTokenId1[7]).to.equal(true);
    expect(myNftTokenId2[7]).to.equal(true);
    expect(myNftTokenId3[7]).to.equal(true);

    // is life time
    expect(myNftTokenId4[3]).to.equal(true);
  });



  it("Fusion temporal tickets with 1 lifetime revert", async function () {
    await ticketNft.setGenerationInfo(1, 10, 3);

    const accounts = await hre.ethers.getSigners();
    const myAccount = accounts[0].address;
    
    await ticketNft.mintTicket(
      myAccount,
      false,
      1,
      86400,
      "http://google.es"
    );

    await ticketNft.mintTicket(
      myAccount,
      false,
      1,
      86400,
      "http://google.es"
    );

    await ticketNft.mintTicket(
      myAccount,
      true,
      1,
      86400,
      "http://google.es"
    );

    const nftAmount = await ticketNft.walletNftAmount(myAccount);
    expect(nftAmount).to.equal(3);

    let myNftTokenId1 = await ticketNft.walletTokenIds(myAccount, 0);
    let myNftTokenId2 = await ticketNft.walletTokenIds(myAccount, 1);
    let myNftTokenId3 = await ticketNft.walletTokenIds(myAccount, 2);    
    
    await expect(ticketNft.fusionTickets(myAccount, [myNftTokenId1, myNftTokenId2, myNftTokenId3], "http://google.es")).
      to.be.revertedWith("Can't fusion lifetime tickets");
  });



  it("Fusion temporal tickets with 1 burned already revert", async function () {
    await ticketNft.setGenerationInfo(1, 10, 3);

    const accounts = await hre.ethers.getSigners();
    const myAccount = accounts[0].address;
    
    await ticketNft.mintTicket(
      myAccount,
      false,
      1,
      86400,
      "http://google.es"
    );

    await ticketNft.mintTicket(
      myAccount,
      false,
      1,
      86400,
      "http://google.es"
    );

    await ticketNft.mintTicket(
      myAccount,
      false,
      1,
      86400,
      "http://google.es"
    );

    const nftAmount = await ticketNft.walletNftAmount(myAccount);
    expect(nftAmount).to.equal(3);
    let myNftTokenId1 = await ticketNft.walletTokenIds(myAccount, 0);
    let myNftTokenId2 = await ticketNft.walletTokenIds(myAccount, 1);
    
    let myNftTokenId3 = await ticketNft.walletTokenIds(myAccount, 2);
    await ticketNft.fusionTickets(myAccount, [myNftTokenId1, myNftTokenId2], "http://google.es");

    await expect(ticketNft.fusionTickets(myAccount, [myNftTokenId2, myNftTokenId3], "http://google.es")).
      to.be.revertedWith("Already burned");
  });

});


