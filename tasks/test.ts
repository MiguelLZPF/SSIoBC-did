import { task, types } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import Environment from "models/Configuration";

export const quickTest = task("quick-test", "Random quick testing function")
  .addOptionalParam(
    "args",
    "Contract initialize function's arguments if any",
    undefined,
    types.json,
  )
  .setAction(async ({ args }, hre: HardhatRuntimeEnvironment) => {
    if (args) {
      // example: npx hardhat quick-test --args '[12, "hello"]'
      console.log(
        "RAW Args: ",
        args,
        typeof args[0],
        args[0],
        typeof args[1],
        args[1],
      );
    }
    const env = new Environment(hre);
    console.log(env);
    console.log("Latest block: ", await hre.ethers.provider.getBlockNumber());
    console.log(
      "First accounts: ",
      await (await hre.ethers.provider.getSigner(0)).getAddress(),
      await (await hre.ethers.provider.getSigner(1)).getAddress(),
    );
    console.log(
      "First account balance: ",
      await hre.ethers.provider.getBalance(
        await (await hre.ethers.provider.getSigner(0)).getAddress(),
      ),
    );
  });

// task("get-timestamp", "get the current timestamp in seconds")
//   .addOptionalParam(
//     "timeToAdd",
//     "time to add to the timestamp in seconds",
//     0,
//     types.int,
//   )
//   .setAction(async ({ timeToAdd }, hre: HardhatRuntimeEnvironment) => {
//     setGlobalHRE(hre);
//     console.log(Math.floor(Date.now() / 1000) + timeToAdd);
//   });
