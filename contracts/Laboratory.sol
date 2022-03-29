// SPDX-License-Identifier: GPL-3.0

pragma experimental ABIEncoderV2;
pragma solidity 0.8.10;

import "../Interfaces/IAsset.sol";
import "../Interfaces/IPsychospheres.sol";
import "../Rent/IRent.sol";
import "../../Utils/Owner.sol";
import "../../Utils/ControlledAccess.sol";
import "../../Digibytes/Interfaces/IBEP20.sol";
import "../../DigitalGolems/Interfaces/IDigitalGolems.sol";
import "../../DigitalGolems/Card.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Laboratory is Owner, VRFConsumerBase, ControlledAccess {
    using Counters for Counters.Counter;

    Counters.Counter private combiningIds;
    // Counters.Counter private orders;

    bytes32 internal keyHash;
    uint256 internal fee;

    struct Order {
      address owner;
      uint16[] assets;
      uint16 generation;
      uint32 soil;
      bool canMint;
      bool ended;
    }
    Order[] orders;
    mapping (uint16 => uint16[]) generationNeedsAssets;
    uint16 generationAmount;
    mapping (bytes32 => uint256) requestIDToOrder;
    mapping (address => uint256) userToOrders;
    mapping (address => mapping(uint16 => uint16)) userToChance;
    uint256 chance50Price = 1 * 10**18; //DBT
    uint256 chance75Price = 2 * 10**18; //DBT
    IBEP20 public DBT;
    IDigitalGolems public DIG;
    IAsset public assetsContract;
    IPsychospheres public psycho;
    IRent public rent;

    event Combine(address to, uint16 generationID, uint16[] assetsIDs);
    event FalledCombine(address to, uint16 generationID, uint16[] assetsIDs);
    event BuyChance(address who, uint16 percent);
    event ChangeChancePrice(uint256 afterPrice, uint16 chance);

    function setDBT(address _DBT) public isOwner {
        DBT = IBEP20(_DBT);
    }

    function setDIG(address _DIG) public isOwner {
        DIG = IDigitalGolems(_DIG);
    }

    function setAssets(address _assets) public isOwner {
        assetsContract = IAsset(_assets);
    }

    function setPsycho(address _psycho) public isOwner {
        psycho = IPsychospheres(_psycho);
    }

    function setRent(address _rent) public isOwner {
        rent = IRent(_rent);
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
        generationNeedsAssets[0] = [0, 1, 2, 3, 4]; //0 generation
        //MAIN
        //base model Torso id - 0
        //base model Head id - 1
        //base model Left hand id - 2
        //base model Right hand id - 3
        //base model Legs id -4
        //OPTIONAL
        //Burning/smoking eyes id - 5
        generationNeedsAssets[1] = [0, 1, 2, 3, 4];//1 generation
        //MAIN
        //base model Torso id - 0
        //base model Head id - 1
        //base model Left hand id - 2
        //base model Right hand id - 3
        //base model Legs id -4
        generationNeedsAssets[2] = [0, 1, 2, 3, 4];//2 generation
        //MAIN
        //base model Torso id - 0
        //base model Head id - 1
        //base model Left hand id - 2
        //base model Right hand id - 3
        //base model Legs id -4
        //OPTIONAL
        //Burning/smoking eyes id - 5
        generationNeedsAssets[3] = [0, 1, 2, 3, 4, 6, 7, 8, 9];//3 generation
        //MAIN
        //base model Torso id - 0
        //base model Head id - 1
        //base model Left hand id - 2
        //base model Right hand id - 3
        //base model Legs id -4
        //Masks id - 6
        //Bib id - 7
        //Shoulder pads id -8
        //Belt id - 9
        generationNeedsAssets[4] = [0, 1, 2, 3, 4];//New generation
        //MAIN
        //base model Torso id - 0
        //base model Head id - 1
        //base model Left hand id - 2
        //base model Right hand id - 3
        //base model Legs id -4
        //OPTIONAL
        //Hind limbs/wings id - 10
        //Limbs on chest id - 11
        //Details on the head id - 12
        generationNeedsAssets[5] = [0, 1, 2, 3, 4];//Lost generation
        //MAIN
        //base model Torso id - 0
        //base model Head id - 1
        //base model Left hand id - 2
        //base model Right hand id - 3
        //base model Legs id -4
        //OPTIONAL
        //Nimbus id - 13
        generationAmount = 6;
    }

    function createGenerationNeedsAsset(uint16[] memory _assetsParts) public isOwner {
        generationNeedsAssets[generationAmount] = _assetsParts;
        generationAmount = generationAmount + 1;
    }

    //isOwner
    function updateGenerationNeedsAsset(uint16 generationID, uint16[] memory _assetsParts) public generationExist(generationID) isOwner {
        generationNeedsAssets[generationID] = _assetsParts;
    }

    function getGenerationNeedsAsset(uint16 generationID) public view generationExist(generationID) returns(uint16[] memory) {
        return generationNeedsAssets[generationID];
    }

    //WHEN ADDING ASSETS REQUIRED ADD IN SEQUENCE THAT IN generationNeedsAssets
    //IF IT POSSIBLE TO ADD OTHER ASSETS - IN RANDOM SEQUENCE
    function combiningGeneration(
        uint16 generationID,
        uint16[] memory assetsIDs,
        uint32 soil
    )
        external
        enoughAssets(generationID, assetsIDs)
        enoughSubstrat(soil)
    {
        orders.push(
          Order(
              msg.sender,
              assetsIDs,
              generationID,
              soil,
              false,
              false
          )
        );
        userToOrders[msg.sender] = userToOrders[msg.sender] + 1;
        uint256 id = orders.length - 1;
         //real random
        // require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK"); CHAINLINK
        // requestIDToGeneration[requestRandomness(keyHash, fee)] = generationID; CHAINLINK
        uint256 rand = uint256(keccak256(abi.encodePacked(block.timestamp)));
        bytes32 requestId = bytes32(keccak256(abi.encodePacked(block.timestamp)));
        requestIDToOrder[requestId] = id;
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
        Order memory _order = orders[requestIDToOrder[requestIdTest]];
        uint16 userChanceThisGeneration = userToChance[msg.sender][_order.generation];
        uint16[] memory assets = _order.assets;
        if (userChanceThisGeneration == 0) {
            chance = 25;
        } else {
            chance = userChanceThisGeneration;
        }
        //if rand is less than chance, we can mint
        if (((randomness % 100) + 1) < chance) {
            _order.canMint = true;
            orders[requestIDToOrder[requestIdTest]] = _order;
            for (uint16 i = 0; i < assets.length; i++) {
               assetsContract.deleteUserFromAsset(assets[i], msg.sender);
            }
            psycho.decreaseSubstrate(msg.sender, _order.soil);
            emit Combine(msg.sender, _order.generation, assets);
        } else {
            //deleting assets
            for (uint16 i = 0; i < assets.length; i++) {
                assetsContract.deleteUserFromAsset(assets[i], msg.sender);
            }
            emit FalledCombine(msg.sender, _order.generation, assets);
        }
    }

    function buyChance50(uint16 generationID) external {
        DBT.transferFrom(msg.sender, address(this), chance50Price);
        userToChance[msg.sender][generationID] = 50;
        emit BuyChance(msg.sender, 50);
    }

    function buyChance75(uint16 generationID) external {
        DBT.transferFrom(msg.sender, address(this), chance75Price);
        userToChance[msg.sender][generationID] = 75;
        emit BuyChance(msg.sender, 75);
    }

    function getUserToChance(uint16 generationID) public view returns(uint16) {
        return userToChance[msg.sender][generationID];
    }

    function buyChance100TEST(address user, uint16 generationID) external isOwner {
        userToChance[user][generationID] = 100;
        emit BuyChance(user, 100);
    }

    function buyChance1TEST(address user, uint16 generationID) external isOwner {
        userToChance[user][generationID] = 1;
        emit BuyChance(user, 1);
    }

    function award(
        uint256 orderID,
        string memory tokenURI,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    )
        public
        onlyValidMint(_v, _r, _s, tokenURI, orderID)
    {
        require(orders[orderID].owner == msg.sender, "Not your order");
        require(orders[orderID].canMint == true, "You cant mint");
        require(orders[orderID].ended == false, "This order already minted");
        combiningIds.increment();
        DIG.awardItemLaboratory(
            msg.sender,
            combiningIds.current()
        );
        orders[orderID].ended = true;
    }

    function getCanMint(uint256 orderID) public view returns(bool) {
        return orders[orderID].canMint;
    }

    function changeChance50Price(uint256 _newPrice) public isOwner {
        chance50Price = _newPrice;
        emit ChangeChancePrice(_newPrice, 50);
    }

    function changeChance75Price(uint256 _newPrice) public isOwner {
        chance75Price = _newPrice;
        emit ChangeChancePrice(_newPrice, 75);
    }

    function getChance50Price() public view returns(uint256) {
        return chance50Price;
    }

    function getChance75Price() public view returns(uint256) {
        return chance75Price;
    }

    function getUserOrders(address user) public view returns(Order[] memory) {
        Order[] memory userOrders = new Order[](userToOrders[user]);
        uint256 counter = 0;
        for (uint256 i = 0; i < orders.length; i++) {
            if (orders[i].owner == user) {
              userOrders[counter] = orders[i];
              counter++;
            }
        }
        return userOrders;
    }

    modifier enoughAssets(uint16 generationID, uint16[] memory _assetsIDs) {
        require(generationNeedsAssets[generationID].length <= _assetsIDs.length, "Not enough assets");
        uint16[] memory needsAssets = generationNeedsAssets[generationID]; //assets that need for this generation
        for (uint16 i = 0; i < generationNeedsAssets[generationID].length; i++) {
            uint16 part = assetsContract.getAssetPart(_assetsIDs[i]);
            //checking if part that generation needs
            //exist in users assets
            require(part == needsAssets[i], "Part of golem needs");
            require(assetsContract.assetToOwner(msg.sender, _assetsIDs[i]) != 0, "You not owner");
        }
        _;
    }

    modifier enoughSubstrat(uint32 _soil) {
        require(psycho.checkHasEnoughOneTypeOfSubstrate(msg.sender, _soil) == true, "Not enough substrate");
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

}
