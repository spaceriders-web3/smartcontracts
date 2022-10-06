async function main() {
    // Hardhat always runs the compile task when running scripts with its command
    // line interface.
    //
    // If this script is run directly using `node` you may want to call compile
    // manually to make sure everything is compiled
    // await hre.run('compile');
  
  
    const networkName = hre.network.name
    const accounts = await hre.ethers.getSigners();
  
    
    let busdAddress = "";
    let routerAddress = "";
    let factoryAddress = "";

    let pairAddress = "";
  
    if (networkName === "testnet") {
      routerAddress = "0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3";
      busdAddress = "0x78867BbEeF44f2326bF8DDd1941a4439382EF2A7"
    }


    const SPR = await hre.ethers.getContractFactory("BlackMatter");
    const spr = await SPR.attach("0xA093c3C85096ddc130B4979d0426059bD5a1f3a5");

    
    const ROUTER = await hre.ethers.getContractFactory("PancakeRouterV2");
    const r = await ROUTER.attach(routerAddress)

    const FACTORY = await hre.ethers.getContractFactory("PancakeFactory");
    const f = await FACTORY.attach(await r.factory());
    

    const BUSD = await hre.ethers.getContractFactory("BUSD");
    const b = await BUSD.attach(busdAddress)
    
    await b.increaseAllowance(spr.address, "5555500000000000000000000");
    await spr.addBusdLiquidity(r.address, "100000000000000000000", "100000000000000000000")

    pairAddress = await f.getPair(spr.address, busdAddress);
    
    console.log(`"PAIR_CONTRACT": "${pairAddress}"`);
    
  }
  
  // We recommend this pattern to be able to use async/await everywhere
  // and properly handle errors.
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
  