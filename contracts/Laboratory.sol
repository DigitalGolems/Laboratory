// SPDX-License-Identifier: GPL-3.0

pragma experimental ABIEncoderV2;
pragma solidity 0.8.10;

import "../Assets.sol";
import "../Psychospheres.sol";
import "../Rent/Rent.sol";
import "../../Utils/Owner.sol";
import "../../Digibytes/Digibytes.sol";
import "../../DigitalGolems/DigitalGolems.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

contract Laboratory is Owner, VRFConsumerBase {
    bytes32 internal keyHash;
    uint256 internal fee;

    mapping (uint16 => uint16[]) generationNeedsAssets;
    mapping (bytes32 => uint16) requestIDToGeneration;
    mapping (address => uint16) userToChance;
    mapping (address => bool) userCanMint;
    mapping (uint256 => uint256) whenPreserve;
    mapping (uint256 => bool) preservated;
    uint256 chancePrice = 1 * 10**18; //DBT
    uint256 preservePrice = 1 * 10**18; //DBT
    uint256 feedingPrice = 1 * 10**18;//DBT
    Digibytes public DBT;
    DigitalGolems public DIG;
    Assets public assetsContract;
    Psychospheres public psycho;
    Rent public rent;

    event Combine(address to, uint16 generationID, uint16[] assetsIDs);
    event FalledCombine(address to, uint16 generationID, uint16[] assetsIDs);
    event BuyChance(address who, uint16 percent);
    event Feeding(uint256 cardID);
    event Preserveted(uint256 when, uint256 cardID);
    event PreservetedIncreased(uint256 cardID, uint8 num);
    event ChangeChancePrice(uint256 afterPrice);
    event ChangePreservePrice(uint256 afterPrice);

    function setDBT(address _DBT) public isOwner {
        DBT = Digibytes(_DBT);
    }

    function setDIG(address _DIG) public isOwner {
        DIG = DigitalGolems(_DIG);
    }

    function setAssets(address _assets) public isOwner {
        assetsContract = Assets(_assets);
    }

    function setPsycho(address _psycho) public isOwner {
        psycho = Psychospheres(_psycho);
    }

    function setRent(address _rent) public isOwner {
        rent = Rent(_rent);
    }

    constructor () 
        VRFConsumerBase(
            0xa555fC018435bef5A13C6c6870a9d4C11DEC329C, // VRF Coordinator
            0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06  // LINK Token
        )
    {
        keyHash = 0xcaf3c3727e033261d383b315559476f48034c13b18f8cafed4d871abe5049186; //BST TEST
        fee = 0.1 * 10 ** 18; // 0.1 LINK (Varies by network) //BST TEST
        // DBT = Digibytes(_DBT);
        // DIG = DigitalGolems(_DIG);
        generationNeedsAssets[0] = [0, 1, 2, 3, 4, 5];
        //base model basis id - 0
        //base model hands id - 1
        //base model legs id - 2
        //base model head id - 3
        //base model background id -4
        //armor id - 5
        generationNeedsAssets[1] = [0, 1, 2, 3, 4, 5, 6];
        //base model basis id - 0
        //base model hands id - 1
        //base model legs id - 2
        //base model head id - 3
        //base model background id -4
        //armor id - 5
        //gold inclusions id -6
        generationNeedsAssets[2] = [0, 1, 2, 3, 4, 6, 7, 8];//7 и 8 необязательно
        //base model basis id - 0
        //base model hands id - 1
        //base model legs id - 2
        //base model head id - 3
        //base model background id -4
        //gold inclusions id -6
        //additional limbs from the chest id - 7
        //accessories on the head id -8
        generationNeedsAssets[3] = [0, 1, 2, 3, 4, 6, 7, 9];//7 необязательно
         //base model basis id - 0
        //base model hands id - 1
        //base model legs id - 2
        //base model head id - 3
        //base model background id -4
        //gold inclusions id -6
        //additional limbs from the chest id - 7
        //wings id - 9
        generationNeedsAssets[4] = [0, 1, 2, 3, 4, 6, 7, 9, 10];
         //base model basis id - 0
        //base model hands id - 1
        //base model legs id - 2
        //base model head id - 3
        //base model background id -4
        //gold inclusions id -6
        //additional limbs from the chest id - 7
        //РАЗДЕЛЬНЫЕ РУКИ НЕ ПОНЯЛ ЧТО
        //wings id - 9
        //eyes id - 10
        generationNeedsAssets[5] = [0, 1, 2, 3, 4, 6, 11];
         //base model basis id - 0
        //base model hands id - 1
        //base model legs id - 2
        //base model head id - 3
        //base model background id -4
        //gold inclusions id -6
        //mask id - 11
        generationNeedsAssets[6] = [13, 14, 15, 16, 17, 18];
        //base model elements basis id - 13
        //base model elements hands id - 14
        //base model elements legs id - 15
        //base model elements head id - 16
        //base model elements background id -17
        //wings elements id - 18
        generationNeedsAssets[7] = [19, 20, 21, 22, 23]; //остальные из золота необязательны но возомжны
        //base model gold basis id - 19
        //base model gold hands id - 20
        //base model gold legs id - 21
        //base model gold head id - 22
        //base model gold background id -23
    }
    //isOwner
    function addGenerationNeedsAsset(uint16 generationID, uint16[] memory _assetsParts) public generationExist(generationID) isOwner {
        generationNeedsAssets[generationID] = _assetsParts;
    }

    //isOwner
    function deleteGenerationNeedsAsset(uint16 generationID) public isOwner {
        for (uint16 i = 0; i < generationNeedsAssets[generationID].length; i++) {
            generationNeedsAssets[generationID][i] = 0;
        }
    }    

    //WHEN ADDING ASSETS REQUIRED ADD IN SEQUENCE THAT IN generationNeedsAssets
    //IF IT POSSIBLE TO ADD OTHER ASSETS - IN RANDOM SEQUENCE
    function combiningGeneration(
        uint16 generationID, 
        uint16[] memory _assetsIDs,
        uint256[] memory _psychoIDs,
        uint32 soil
    ) 
        external
        enoughAssets(generationID, _assetsIDs)
        enoughPsychoAndSubstrat(_psychoIDs, soil)
    {
         //real random
        // require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK"); CHAINLINK
        // requestIDToGeneration[requestRandomness(keyHash, fee)] = generationID; CHAINLINK
        uint256 rand = uint256(keccak256(abi.encodePacked(block.timestamp)));
        bytes32 requestId = bytes32(keccak256(abi.encodePacked(block.timestamp)));
        requestIDToGeneration[requestId] = generationID;
        fulfillRandomnessTest(requestId, rand);
    }

    /**
     * Callback function used by VRF Coordinator
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
    //     uint16 chance = 0;
    //     if (userToChance[msg.sender] == 0) {
    //         chance = 25;
    //     } else {
    //         chance = userToChance[msg.sender];
    //     }
    //     //if rand is less than chance, we can mint
    //     if ((randomness % 100) < chance) {
    //         userCanMint[msg.sender] = true;
    //         emit Combine(msg.sender, requestIDToGeneration[requestId], generationNeedsAssets[requestIDToGeneration[requestId]]);
    //     } else {//deleting assets
    //         for (uint16 i = 0; i < generationNeedsAssets[requestIDToGeneration[requestId]].length; i++) {
    //             assetsContract.deleteUserFromAsset(generationNeedsAssets[requestIDToGeneration[requestId]][i], msg.sender);
    //         }
    //         emit FalledCombine(msg.sender, requestIDToGeneration[requestId], generationNeedsAssets[requestIDToGeneration[requestId]]);
    //     }
    }

    function fulfillRandomnessTest(bytes32 requestIdTest, uint256 randomness) internal {
        uint16 chance = 0;
        if (userToChance[msg.sender] == 0) {
            chance = 25;
        } else {
            chance = userToChance[msg.sender];
        }
        //if rand is less than chance, we can mint
        if ((randomness % 100) < chance) {
            userCanMint[msg.sender] = true;
            emit Combine(msg.sender, requestIDToGeneration[requestIdTest], generationNeedsAssets[requestIDToGeneration[requestIdTest]]);
        } else {
            //deleting assets
            for (uint16 i = 0; i < generationNeedsAssets[requestIDToGeneration[requestIdTest]].length; i++) {
                assetsContract.deleteUserFromAsset(generationNeedsAssets[requestIDToGeneration[requestIdTest]][i], msg.sender);
            }
            emit FalledCombine(msg.sender, requestIDToGeneration[requestIdTest], generationNeedsAssets[requestIDToGeneration[requestIdTest]]);
        }
    }

    function buyChance50() external notEnoughDBT(chancePrice) {
        userToChance[msg.sender] = 50;
        DBT.transferFrom(msg.sender, address(this), chancePrice);
        emit BuyChance(msg.sender, 50);
    }
    function buyChance75() external notEnoughDBT(chancePrice){
        userToChance[msg.sender] = 75;
        DBT.transferFrom(msg.sender, address(this), chancePrice);
        emit BuyChance(msg.sender, 75);
    }

    function buyChance100TEST(address user) external isOwner {
        userToChance[user] = 100;
        emit BuyChance(user, 100);
    }

    function award(
        string memory tokenURI, 
        uint16 generationID, 
        uint16[] memory _assets,
        uint8 _v,
        bytes32[] memory rs,
        uint8[] memory kindSeries,//вот тут другой тип
        uint256[] memory _psychoIDs,
        uint32 soil
    ) 
        public 
        enoughAssets(generationID, _assets) 
        enoughPsychoAndSubstrat(_psychoIDs, soil) 
    {
        require(userCanMint[msg.sender] == true, "You cant mint");
        DIG.awardItem(
            msg.sender, 
            tokenURI, 
            _v, 
            rs[0],
            rs[1], 
            kindSeries
        );
        for (uint16 i = 0; i < _assets.length; i++) {
           assetsContract.deleteUserFromAsset(_assets[i], msg.sender);
        }
        psycho.decreasePsychosphere(msg.sender, _psychoIDs);
        psycho.decreaseSubstrate(msg.sender, soil);
        userCanMint[msg.sender] == false;
    }

    function getCanMint(address user) public view returns(bool) {
        return userCanMint[user];
    }

    function changeChancePrice(uint16 _newPrice) public isOwner {
        chancePrice = _newPrice;
        emit ChangeChancePrice(_newPrice);
    }

    function getChancePrice() public view returns(uint256) {
        return chancePrice * 10**18;
    }

    function changePreservePrice(uint16 _newPrice) public isOwner {
        preservePrice = _newPrice;
        emit ChangePreservePrice(_newPrice);
    }

    function getPreservePrice() public view returns(uint256) {
        return preservePrice * 10**18;
    }

    function feeding(uint256 _ID) external notEnoughDBT(feedingPrice) onlyOwnerOrRenter(_ID){
        DBT.transferFrom(msg.sender, address(this), feedingPrice);
        DIG.increaseNumAbilityAfterFeeding(_ID);
        emit Feeding(_ID);
    }

    function preservation(uint256 _ID) external notEnoughDBT(preservePrice) onlyOwnerOrRenter(_ID) {
        require(preservated[_ID] != true, "Already");
        require(msg.sender == DIG.ownerOf(_ID), "Not Owner");
        DBT.transferFrom(msg.sender, address(this), preservePrice);
        whenPreserve[_ID] = block.timestamp;
        preservated[_ID] = true;
        emit Preserveted(whenPreserve[_ID], _ID);
    }
    
    function preserveIncrease(uint256 _ID, uint8 _num) external{
        require(isPreservated(_ID) == true, "Wasnt preserved");
        require(block.timestamp > whenPreserve[_ID] + 7 days, "Still preserve");
        require(msg.sender == DIG.ownerOf(_ID), "Not owner");
        preservated[_ID] == false;
        DIG.increaseNumAbilityAfterPreservation(_ID, _num);
        emit PreservetedIncreased(_ID, _num);
    }

    function isPreservated(uint256 _ID) public view returns(bool) {
        return preservated[_ID];
    }

    function mockTimePreservated(uint256 _ID, uint256 _time) public isOwner {
        whenPreserve[_ID] = _time;
    }


    modifier enoughAssets(uint16 generationID, uint16[] memory _assetsIDs) {
        require(generationNeedsAssets[generationID].length <= _assetsIDs.length, "Not enough assets");
        uint16[] memory needsAssets = generationNeedsAssets[generationID]; //assets that need for this generation
        for (uint16 i = 0; i < generationNeedsAssets[generationID].length; i++) {
            uint16 part = assetsContract.getAssetPart(_assetsIDs[i]);
            //checking if part that generation needs
            //exist in users assets
            require(part == needsAssets[i], "You dont have some part of golem");
            require(assetsContract.assetToOwner(msg.sender, _assetsIDs[i]) != 0, "You not owner of some asset");
        }
        _;
    }

    modifier enoughPsychoAndSubstrat(uint256[] memory _psychoIDs, uint32 _soil) {
        for (uint256 i = 0; i < _psychoIDs.length; i++) {
            require(psycho.getPsychospheresOwner(_psychoIDs[i]) == msg.sender, "Not owner of psycho");
            require(psycho.checkHasEnoughOneTypeOfSubstrate(msg.sender, _soil) == true, "Not enough substrate");
        }
        _;
    }

    modifier generationExist(uint16 generationID) {
        bool flag;
        for (uint16 i = 0; i < generationNeedsAssets[generationID].length; i++) {
            if (generationNeedsAssets[generationID][i] == 0) {
                flag = true;
            } else {
                flag = false;
            }
        }
        require(flag != true);
        _;
    }

    modifier notEnoughDBT(uint256 _price) {
        require(DBT.balanceOf(msg.sender) >= _price, "Balance too small");
        require(DBT.allowance(msg.sender, address(this)) >= _price, "DBT not allowed");
        _;
    }

    modifier onlyOwnerOrRenter(uint256 _ID) {
        require(
            (msg.sender == DIG.ownerOf(_ID))
            ||
            (rent.getUserRenter(rent.getItemIDByCardID(_ID)) == msg.sender),
            "Only Owner or Renter");
        _;
    }

}