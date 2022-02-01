const Laboratory = artifacts.require("Laboratory");
const GameContract = artifacts.require("Game")
const Inventory = artifacts.require("Inventory")
const DigitalGolems = artifacts.require("DigitalGolems")
const Digibytes = artifacts.require("Digibytes")
const AssetsContract = artifacts.require("Assets");
const Psychospheres = artifacts.require("Psychospheres")
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


contract('Lab combining', async (accounts)=>{
    let game;
    let lab;
    let assets;
    let DIG;
    let psycho;
    let DBT;
    let inventory;
    let psychoCombining = ["0","1","2","3"];
    let user = accounts[9];
    let owner = accounts[0];
    let things = ["1","2","8","10","110"]
    let resources = ["2","3","1","4"]
    let augment = ["3","2","6","0","8","0","6","9","1"]
    let someURLOfCombinedPicture = "someURL"
    before(async () => {
        //we will combine id 7 type of golem - gold
        //assets that we need
        //base model gold basis id - 19
        //base model gold hands id - 20
        //base model gold legs id - 21
        //base model gold head id - 22
        //base model gold background id -23
        lab = await Laboratory.new()
        game = await GameContract.new()
        inventory = await Inventory.new()
        assets = await AssetsContract.new()
        DIG = await DigitalGolems.new()
        DBT = await Digibytes.new()
        psycho = await Psychospheres.new()
        await game.setDBT(DBT.address, {from: owner})
        await game.setDIG(DIG.address, {from: owner})
        await game.setInventory(inventory.address, {from: owner})
        await game.setAssets(assets.address, {from: owner})
        await psycho.setGameContract(game.address)
        await psycho.setAssetsContract(assets.address)
        await psycho.setLabContract(lab.address)
        await DIG.setGameAddress(game.address, {from: owner})
        await DIG.setLabAddress(lab.address, {from: owner})
        await lab.setAssets(assets.address, {from: owner})
        await lab.setDBT(DBT.address, {from: owner})
        await lab.setDIG(DIG.address, {from: owner})
        await lab.setPsycho(psycho.address)
        await assets.setLab(lab.address)
        await psycho.addPsychosphereByOwner(user, 16, 0, {from: owner})
        //adding assets
        for (let i = 0; i < 5; i++) {
            await assets.addAssetByOwner(
                (i + 1).toString(),
                (19 + i).toString(),
                "someURL",
                "0",
                {from: owner}
            )
            await assets.addUserToAssetOwner(
                i.toString(),
                user,
                {from: owner}
            )
        }
    })

    it("Should combine gold golem", async ()=>{
        //check if we have 4 psycho and 4 substrat
        assert.isAtLeast(
            parseInt((await psycho.getPsychospheresCount(user)).toString()),
            4,
            "At least 4"
        )
        assert.isTrue(
            await psycho.checkHasEnoughOneTypeOfSubstrate(user, 0)
        )
        //getting user assets
        let userAssets = await assets.getAllUserAssets(user)
        let userAssetsToSend = []
        //change assets to string format
        for (let i = 0; i < userAssets.length; i++) {
            userAssetsToSend[i] = userAssets[i].toString()
        }
        //buying 100% chance (FOR TEST ONLY)
        await lab.buyChance100TEST(user, {from:owner})
        //combining
        await lab.combiningGeneration("7", userAssetsToSend, psychoCombining, "0",{from: user})
        //getting info can user mint or not
        let canMint = (await lab.getCanMint(user)).toString()
        //if he can
        if (canMint == "true") {
            const tokenURI = "https://ipfs.io/ipfs/QmUdTP3VBY5b9u1Bdc3AwKggQMg5TQyNXVfzgcUQKjdmRH";//вот отсюда
            //for valid mint
            //signed from server
            const message = web3.utils.soliditySha3(DIG.address, tokenURI, user);
            const sign = await web3.eth.sign(message, owner)
            const r = sign.substr(0, 66)
            const s = '0x' + sign.substr(66, 64);
            const v = web3.utils.toDecimal("0x" + (sign.substr(130,2) == 0 ? "1b" : "1c"));//до сюда, делается серваком
            const kindSeries = ["1", "7"]
            const rs = [r, s]
            //assets before award
            let assetsCountBefore = (await assets.getOwnerAssetCount(user)).toString()
            //awarding with sign
            await lab.award(
                tokenURI,
                7,
                userAssetsToSend,
                v,
                rs,
                kindSeries,
                ["0","1","2","3"], 
                "0",
                {from: user}
            )
            //checking if all good
            let nftCount = (await DIG.balanceOf(user)).toString()
            let cardCount = (await DIG.cardCount(user)).toString()
            let nftURI = (await DIG.tokenURI(1)).toString()
            let assetsCountAfter = (await assets.getOwnerAssetCount(user)).toString()
            assert.equal(nftCount, "1", "Minted nft")
            assert.equal(cardCount, "1", "Created Card")
            assert.equal(assetsCountBefore, "5", "Assets before award")
            assert.equal(assetsCountAfter, "0", "Assets after award")
            assert.equal(tokenURI, nftURI, "NFT URI")
            //check if we delete 4 psycho and 4 substrat
            assert.isAtMost(
                parseInt((await psycho.getPsychospheresCount(user)).toString()),
                16,
                "16 - 4"
            )
            assert.isFalse(
                await psycho.checkHasEnoughOneTypeOfSubstrate(user, 0)
            )
        }

    })

}
)