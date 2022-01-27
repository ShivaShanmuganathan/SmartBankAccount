const { expect } = require("chai");
const { ethers, network } = require("hardhat");

describe("SmartBankAccount", function () {
  const acc = "0x645bE56bf2B43295dF59307F2e2259c52C88ECE8"; // my account
  
  before(async function () {
    await network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [acc],
    });
    const signer = await ethers.getSigner(acc);
    [owner, addr1, addr2, addr3, addr4] = await ethers.getSigners();          
    const contractName = "Smart Bank Account";
    SmartBankAccount = await ethers.getContractFactory('SmartBankAccount', signer);
    SmartBankAccountContract = await SmartBankAccount.deploy();
    await SmartBankAccountContract.deployed();
    console.log(`${contractName} deployed to: ${SmartBankAccountContract.address}`);
    

  });

  describe("Check deposit function", function () { 

    it("check if owner can deposit", async function () { 
      
      await network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [acc],
      });

      const signer = await ethers.getSigner(acc);
      
      await SmartBankAccountContract.connect(signer).addBalance( { value: ethers.utils.parseEther("0.01") });
    });


    it("check ceth balance of user", async function () {

      await network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [acc],
      });
      const signer = await ethers.getSigner(acc);
      const balance = parseFloat(ethers.utils.formatEther(await SmartBankAccountContract.connect(signer).getTotalEthFromCeth()));
      console.log("Balance of Contract",balance);


    });

  });



});
