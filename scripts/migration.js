// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
require('dotenv').config()
const fs = require('fs');

async function deployAbis(networkName, smartContracts) {
  //if (networkName !== "local" || !process.env.AUTO_DEPLOY_LOCAL_CHANGES) {
  //  return;
  //}

  const contractAbiPathNames = {
    "PlanetNft.sol": "PlanetNft.json",
    "SpaceRiders.sol": "SpaceRiders.json",
    "SpaceRidersGame.sol": "SpaceRidersGame.json",
    //"TicketNft.sol": "TicketNft.json"
    //"SpaceRidersRewardPool.sol": "SpaceRidersRewardPool.json"
  }

  const contractNameMappings = {
    "PlanetNft.json": "SpaceRiderNFT.json",
    "SpaceRiders.json": "Spaceriders.json",
    "SpaceRidersGame.json": "SpaceRidersGame.json",
    //"TicketNft.json": "TicketNft.json",
    //"SpaceRidersRewardPool.json"
  }

  const currentPath = process.env.PWD;
  const apiAbiPath = process.env.API_ABI_PATH;
  const abiAbiFrontendPath = process.env.FRONTEND_ABI_PATH;

  const abiPath = `${currentPath}/artifacts/contracts`

  for (const path  in contractAbiPathNames) {
      const abiName = contractAbiPathNames[path];
      const abiFile = require(`${abiPath}/${path}/${abiName}`);
      const abiContent = JSON.stringify(abiFile.abi);

      const abiApiPath = `${apiAbiPath}/${contractNameMappings[abiName]}`;
      const abiFrontendPath = `${abiAbiFrontendPath}/${contractNameMappings[abiName]}`;

      fs.writeFileSync(abiApiPath, '', {encoding:'utf8', flag:'w'});
      fs.writeFileSync(abiApiPath, abiContent, {encoding:'utf8', flag:'w'});

      fs.writeFileSync(abiFrontendPath, '', {encoding:'utf8', flag:'w'});
      fs.writeFileSync(abiFrontendPath, abiContent, {encoding:'utf8', flag:'w'});
  }

  const apiPath = process.env.API_PATH;
  const contractAddrFilePath = `${apiPath}/contracts.${networkName}.json`;
  const smAddrContent = JSON.stringify(smartContracts);
  
  fs.writeFileSync(contractAddrFilePath, '', {encoding:'utf8', flag:'w'});
  fs.writeFileSync(contractAddrFilePath, smAddrContent, {encoding:'utf8', flag:'w'});
}

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');


  const networkName = hre.network.name
  const accounts = await hre.ethers.getSigners();
  //console.log(accounts[0].address)
  
  let wethAddress = "";
  let busdAddress = "";
  let routerAddress = "";
  let factoryAddress = "";
  let ticketNftAddress = "";

  if (networkName === "testnet") {
    routerAddress = "0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3";
    busdAddress = "0x78867BbEeF44f2326bF8DDd1941a4439382EF2A7"

  } else if (networkName === "local") {
    const Weth = await hre.ethers.getContractFactory("WETH");
    const Busd = await hre.ethers.getContractFactory("BUSD");
    const PancakeFactory = await hre.ethers.getContractFactory("PancakeFactory");
    const PancakeRouterV2 = await hre.ethers.getContractFactory("PancakeRouterV2");
    
    const weth = await Weth.deploy();
    const busd = await Busd.deploy();
    const pf = await PancakeFactory.deploy(accounts[0].address);

    const pancakeFactory = await pf.deployed();
    factoryAddress = pancakeFactory.address;

    const initCode = await pf.INIT_CODE_PAIR_HASH();
    const we = await weth.deployed();
    
    const b = await busd.deployed();
    wethAddress = we.address;
    busdAddress = b.address;
    const Router = await PancakeRouterV2.deploy(pancakeFactory.address, we.address, initCode);
    const r = await Router.deployed();
    routerAddress = r.address;
  }

  // Ticket nft
  if (networkName !== "mainnet") {
    const TicketNft = await hre.ethers.getContractFactory("TicketNft");
    const ticketNft = await TicketNft.deploy();

    await ticketNft.deployed();
    const accounts = await hre.ethers.getSigners();
    const acct = accounts[0].address;
    await ticketNft.mintTicket(
      acct,
      true,
      0,
      0,
    );

    ticketNftAddress = ticketNft.address;
  }

  const OnlyBackend = await hre.ethers.getContractFactory("OnlyBackend");
  const onlyBackend = await OnlyBackend.deploy();
  const ob = await onlyBackend.deployed();

  const Planetnft = await hre.ethers.getContractFactory("PlanetNft");
  const planetnft = await Planetnft.deploy();
  const pnft = await planetnft.deployed();

  const SpaceRiders = await hre.ethers.getContractFactory("SpaceRiders");
  const spaceRiders = await SpaceRiders.deploy(pnft.address, busdAddress);
  const spr = await spaceRiders.deployed();
  spr.transfer(spr.address, "11000000000000000000");

  const SpaceRidersRewardPool = await hre.ethers.getContractFactory("SpaceRidersRewardPool");
  const spaceRidersRewardPool = await SpaceRidersRewardPool.deploy(spr.address);
  const sprp = await spaceRidersRewardPool.deployed();

  await spr.setSprRewardPoolAddress(sprp.address);
  await spr.setWhitelistedAddresses(sprp.address, true);

  const SpaceRidersGame = await hre.ethers.getContractFactory("SpaceRidersGame", {
    libraries: {
      OnlyBackend: ob.address
    },
  });

  const spaceRidersGame = await SpaceRidersGame.deploy(spr.address, pnft.address, accounts[0].address,accounts[0].address,sprp.address);
  const sprg = await spaceRidersGame.deployed();

  await pnft.transferOwnership(sprg.address);
  await sprp.transferOwnership(sprg.address)
  await spr.setSprGameAddress(sprg.address);

  const SprSwapper = await hre.ethers.getContractFactory("SprFundProxy");
  const sprSwapper = await SprSwapper.deploy();
  const sprsw = await sprSwapper.deployed();
  await sprsw.transferOwnership(spr.address);
  await spr.setSprFundProxy(sprsw.address);

  if (networkName === "local") {
    const FACTORY = await hre.ethers.getContractFactory("PancakeFactory");
    const f = FACTORY.attach(factoryAddress);

    const ROUTER = await hre.ethers.getContractFactory("PancakeRouterV2");
    const r = await ROUTER.attach(routerAddress)

    const BUSD = await hre.ethers.getContractFactory("BUSD");
    const b = await BUSD.attach(busdAddress)
    
    await b.mint(accounts[0].address, "5555500000000000000000000");
    // test account
    await b.mint("0x03545A3A834A0837aac22eDAE92c0Ed1435F144b", "5555500000000000000000000");
    await b.increaseAllowance(spr.address, "5555500000000000000000000");
    await spr.addBnbLiquidity(r.address, "4500000000000000000000", "4500000000000000000000")
  
    const pairAddress = await f.getPair(spr.address, b.address);
    await spr.addDex(r.address, pairAddress);

    await spr.setWhitelistedAddresses(sprg.address, true);
  }

  const tenderlyContracts = [
    {
      name: "SpaceRiders",
      address: spr.address,
    },
    {
      name: "SpaceRidersGame",
      address: sprg.address
    }
  ];
  
  await hre.tenderly.persistArtifacts(...tenderlyContracts);

  if (networkName != "local") {
    await hre.tenderly.verify(...tenderlyContracts);
    await hre.tenderly.push(...tenderlyContracts);
    try {
      await hre.run("verify:verify", {
        address: spr.address,
        constructorArguments: [
          pnft.address,
          busdAddress
        ],
      });

      await hre.run("verify:verify", {
        address: ticketNftAddress,
        constructorArguments: [],
      });
  
      await hre.run("verify:verify", {
        address: sprg.address,
        constructorArguments: [
          spr.address, 
          pnft.address,
          accounts[0].address,
          accounts[0].address,
          sprp.address
        ],
      });
    } catch(e){
      
    }
    
  }
  
  let sma = {
    SPACERIDERS_TOKEN_CONTRACT: spr.address,
    SPACERIDERS_GAME_CONTRACT: sprg.address,
    SPACERIDERS_NFT_CONTRACT: pnft.address
  };

  sma.SPACERIDERS_TICKET_NFT_CONTRACT = ticketNftAddress;


  str = `
  ${networkName}:
  \n
{
  "SPACERIDERS_TOKEN_CONTRACT": "${spr.address}",
  "SPACERIDERS_GAME_CONTRACT": "${sprg.address}",
  "SPACERIDERS_NFT_CONTRACT": "${pnft.address}",
  "SPACERIDERS_TICKET_NFT_CONTRACT": "${ticketNftAddress}",
  "ROUTER_CONTRACT": "${routerAddress}"
}
`;

  if (networkName == "mainnet" || networkName == "testnet") {
      console.log("DONT FORGET TO ADD LIQUIDITY DUMBASS!")
  }

  console.log(str)
  deployAbis(networkName, sma);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
