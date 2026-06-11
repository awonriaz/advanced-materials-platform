// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MaterialPassport {
    struct Passport {
        string lotId;
        string materialType;
        string supplier;
        string originCountry;
        string documentHash;
        uint256 createdAt;
        bool exists;
    }

    mapping(string => Passport) private passports;
    event PassportCreated(string indexed lotId, string materialType, string supplier, string documentHash);
    event CustodyEvent(string indexed lotId, string actor, string location, string eventHash);

    function createPassport(
        string calldata lotId,
        string calldata materialType,
        string calldata supplier,
        string calldata originCountry,
        string calldata documentHash
    ) external {
        require(!passports[lotId].exists, "passport exists");
        passports[lotId] = Passport(lotId, materialType, supplier, originCountry, documentHash, block.timestamp, true);
        emit PassportCreated(lotId, materialType, supplier, documentHash);
    }

    function addCustodyEvent(string calldata lotId, string calldata actor, string calldata location, string calldata eventHash) external {
        require(passports[lotId].exists, "missing passport");
        emit CustodyEvent(lotId, actor, location, eventHash);
    }

    function readPassport(string calldata lotId) external view returns (Passport memory) {
        require(passports[lotId].exists, "missing passport");
        return passports[lotId];
    }
}
