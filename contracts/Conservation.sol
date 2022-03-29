// SPDX-License-Identifier: GPL-3.0

pragma experimental ABIEncoderV2;
pragma solidity 0.8.10;

import "../Rent/IRent.sol";
import "../../Utils/Owner.sol";
import "../../Digibytes/Interfaces/IBEP20.sol";
import "../../DigitalGolems/Interfaces/ICard.sol";
import "../Interfaces/IConservation.sol";

contract Conservation is Owner, IConservation {

    struct Preservation {
        uint256 whenPreserve;
        bool preservated;
        uint8 preservatedAbility;
    }
    mapping (uint256 => Preservation) golemToPreserve;
    uint256 preservePrice = 1 * 10**18; //DBT
    uint256 feedingPrice = 1 * 10**18;//DBT
    IBEP20 public DBT;
    ICard public card;
    IRent public rent;

    function setDBT(address _DBT) public isOwner {
        DBT = IBEP20(_DBT);
    }

    function setRent(address _rent) public isOwner {
        rent = IRent(_rent);
    }

    function setCard(address _card) public isOwner {
        card = ICard(_card);
    }

    function changePreservePrice(uint256 _newPrice) public isOwner {
        preservePrice = _newPrice;
        emit ChangePreservePrice(_newPrice);
    }

    function getPreservePrice() public view returns(uint256) {
        return preservePrice;
    }

    function changeFeedingPrice(uint256 _newPrice) public isOwner {
        feedingPrice = _newPrice;
        emit ChangeFeedingPrice(_newPrice);
    }

    function getFeedingPrice() public view returns(uint256) {
        return feedingPrice;
    }

    function feeding(uint256 _ID) external {
        DBT.transferFrom(msg.sender, address(this), feedingPrice);
        card.increaseNumAbilityAfterFeeding(_ID);
        emit Feeding(_ID);
    }

    //send it to preservation
    function preservation(uint256 _ID, uint8 _num) external onlyCardOwner(_ID) isOnRent(_ID) {
        require(golemToPreserve[_ID].preservated != true, "Already");
        require(msg.sender == card.cardOwner(_ID), "Not Owner");
        DBT.transferFrom(msg.sender, address(this), preservePrice);
        golemToPreserve[_ID].whenPreserve = block.timestamp;
        golemToPreserve[_ID].preservated = true;
        golemToPreserve[_ID].preservatedAbility = _num;
        emit Preserveted(golemToPreserve[_ID].whenPreserve, _ID);
    }

    //increase ability after 1 week
    function preserveIncrease(uint256 _ID) external {
        require(isPreservated(_ID) == true, "Wasnt preserved");
        require(block.timestamp > golemToPreserve[_ID].whenPreserve + 7 days, "Still preserve");
        require(msg.sender == card.cardOwner(_ID), "Not owner");
        golemToPreserve[_ID].preservated = false;
        card.increaseNumAbilityAfterPreservation(_ID, golemToPreserve[_ID].preservatedAbility);
        emit PreservetedIncreased(_ID, golemToPreserve[_ID].preservatedAbility);
    }

    function getPreserve(uint256 _ID) external view returns(uint256 timeWhenEnded) {
        require(golemToPreserve[_ID].preservated == true, "Card did not preserve");
        timeWhenEnded = golemToPreserve[_ID].whenPreserve + 7 days;
    }

    function isPreservated(uint256 _ID) public view returns(bool) {
        return golemToPreserve[_ID].preservated;
    }

    function mockTimePreservated(uint256 _ID, uint256 _time) public isOwner {
        golemToPreserve[_ID].whenPreserve = _time;
    }

    modifier onlyCardOwner(uint256 _ID) {
        require(msg.sender == card.cardOwner(_ID), "Only Owner");
        _;
    }

    modifier isOnRent(uint256 _cardID) {
      bool cardRentExist;
      uint256 cardItemID;
      (cardItemID, cardRentExist) = rent.getItemIDByCardID(_cardID);
      if (cardRentExist) {
        require(rent.isClosed(cardItemID), "Close your rent order");
      }
      _;
    }

}
