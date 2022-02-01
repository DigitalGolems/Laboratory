const GameContract = artifacts.require("Game");
const DigitalGolems = artifacts.require("DigitalGolems")
const AssetsContract = artifacts.require("Assets");
const Laboratory = artifacts.require("Laboratory");
const Inventory = artifacts.require("Inventory")
const Digibytes = artifacts.require("Digibytes")
const Psychospheres = artifacts.require("Psychospheres")
const Store = artifacts.require("Store")
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


contract('Lab feeding', async (accounts)=>{
    let game;
    let inventory;
    let psycho;
    let store;
    let lab;
    let DIG;
    let DBT;
    let assets;
    let user = accounts[9];
    let owner = accounts[0];
    let things = ["1","2","8","10","110"]
    let resources = ["2","3","1","4"]
    let augment = ["3","2","6","0","8","0","6","9","1"]
    let abilities = [];
    const psychospheres = ["2", "3"]
    before(async () => {
        game = await GameContract.new()
        inventory = await Inventory.new()
        assets = await AssetsContract.new()
        psycho = await Psychospheres.new()
        lab = await Laboratory.new()
        store = await Store.new()
        DIG = await DigitalGolems.new()
        DBT = await Digibytes.new()
        // await game.setDBT(DBT.address, {from: owner})
        await game.setDIG(DIG.address, {from: owner})
        await game.setInventory(inventory.address, {from: owner})
        await game.setAssets(assets.address, {from: owner})
        await game.setPsycho(psycho.address, {from: owner})
        await inventory.setStoreContract(store.address)
        await inventory.setGameContract(game.address)
        await psycho.setGameContract(game.address)
        await DIG.setGameAddress(game.address, {from: owner})
        await DIG.setLabAddress(lab.address, {from: owner})
        await lab.setAssets(assets.address, {from: owner})
        await lab.setDIG(DIG.address, {from: owner})
        await lab.setDBT(DBT.address, {from: owner})
        await assets.setGame(game.address)
        await assets.setLab(lab.address)   
        await DBT.transfer(user, web3.utils.toWei("2"))
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
        await game.sessionResult(
            things,
            resources,
            augment,
            psychospheres,
            "1",
            user,
            {from: user}
        )
    })

    
    it("Should be decreased abilities and then ok", async ()=>{
        //after session we decreased abilities on 1
        for (let i = 0; i < await DIG.getAmountOfNumAbilities(); i++) {
            if (abilities[i] != 0) {
                assert.equal(
                    //abilities before
                    parseInt(abilities[i].toString()),
                    //abilities after + 1, (+1) because we decreased on 1
                    parseInt((await DIG.getNumAbilityInt(1, i)).toString()) + 1,
                    "Decreased ability"
                    )
            } else {
                //abilities that equals 0 didnt change
                assert.equal(
                    parseInt(abilities[i].toString()),
                    parseInt((await DIG.getNumAbilityInt(1, i)).toString()),
                    "Zero ability"
                    )
            }
        }
        //feeding golem to increase abilities
        await DBT.approve(lab.address, web3.utils.toWei("1"), {from: user})
        await lab.feeding(1, {from: user})
        //checking if it like before session result
        for (let i = 0; i < await DIG.getAmountOfNumAbilities(); i++) {
            assert.equal(
                //abilities before
                parseInt(abilities[i].toString()),
                //abilities after
                parseInt((await DIG.getNumAbilityInt(1, i)).toString()),
                "Increased ability"
                )
        }
        //feeding golem another one to increase abilities
        await DBT.approve(lab.address, web3.utils.toWei("1"), {from: user})
        await lab.feeding(1, {from: user})
        //checking if it like before session result because we cant feed more than initial values
        for (let i = 0; i < await DIG.getAmountOfNumAbilities(); i++) {
            assert.equal(
                //abilities before
                parseInt(abilities[i].toString()),
                //abilities after
                parseInt((await DIG.getNumAbilityInt(1, i)).toString()),
                "Increased ability"
                )
        }
    })

}
)