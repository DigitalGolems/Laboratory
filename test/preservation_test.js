const GameContract = artifacts.require("Game");
const DigitalGolems = artifacts.require("DigitalGolems")
const AssetsContract = artifacts.require("Assets");
const Laboratory = artifacts.require("Laboratory");
const Inventory = artifacts.require("Inventory")
const Digibytes = artifacts.require("Digibytes")
const { assert } = require("chai");
const {
    catchRevert,            
    catchOutOfGas,          
    catchInvalidJump,       
    catchInvalidOpcode,     
    catchStackOverflow,     
    catchStackUnderflow,   
    catchStaticStateChange
} = require("../../utils/catch_error.js")


contract('Lab preservation', async (accounts)=>{
    let game;
    let inventory;
    let lab;
    let DIG;
    let assets;
    let user = accounts[9];
    let owner = accounts[0];
    let things = ["1","2","8","10","110"]
    let resources = ["2","3","1","4"]
    let augment = ["3","2","6","0","8","0","6","9","1"]
    let abilities = [];
    before(async () => {
        game = await GameContract.new()
        inventory = await Inventory.new()
        assets = await AssetsContract.new()
        lab = await Laboratory.new()
        DIG = await DigitalGolems.new()
        DBT = await Digibytes.new()
        await DBT.transfer(user, web3.utils.toWei("10"), {from:owner})
        // await game.setDBT(DBT.address, {from: owner})
        await game.setDIG(DIG.address, {from: owner})
        await game.setInventory(inventory.address, {from: owner})
        await game.setAssets(assets.address, {from: owner})
        await DIG.setGameAddress(game.address, {from: owner})
        await DIG.setLabAddress(lab.address, {from: owner})
        await lab.setAssets(assets.address, {from: owner})
        await lab.setDIG(DIG.address, {from: owner})
        await lab.setDBT(DBT.address, {from: owner})
        await assets.setGame(game.address)
        await assets.setLab(lab.address)  
        await DIG.ownerMint(
            user,
            "tokenURIs",
            "0",
            "0",
            {from:owner}
        )
        for (let i = 0; i < await DIG.getAmountOfNumAbilities(); i++) {
            abilities[i] = await DIG.getNumAbilityInt(1, i);
        }
    })

    
    it("Should be increased id(0) ability", async ()=>{
        //after session we decreased abilities on 1
        const secondsInADay = 86400;
        const newTime = (Math.trunc(Date.now()/ 1000) - secondsInADay * 8).toString(); //minus 8 days
        let abilityBefore = parseInt((await DIG.getNumAbilityInt(1, 0)).toString())
        //adding to preservation
        //get to lab approve for using user money
        await DBT.approve(lab.address, web3.utils.toWei("1"), {from: user})
        await lab.preservation(1, {from: user})
        //checking if really preserved
        assert.equal((await lab.isPreservated(1)).toString(), "true", "Really preserve")
        //mock time
        await lab.mockTimePreservated(1, newTime, {from: owner})
        //increasing ability
        await lab.preserveIncrease(1, 0, {from: user})
        //we icreased initial ability
        //need to feed golem
        await DBT.approve(lab.address, web3.utils.toWei("1"), {from: user})
        await lab.feeding(1, {from: user})
        //checking if it increased
        let abilityAfter = parseInt((await DIG.getNumAbilityInt(1, 0)).toString())
        assert.equal(
            abilityAfter - abilityBefore,
            1,
            "Increased on 1"
        )
    })

}
)