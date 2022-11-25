// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ERC721.sol";
import "./LinearVRGDA.sol";
import "openzeppelin-contracts/access/Ownable.sol";
import "openzeppelin-contracts/security/ReentrancyGuard.sol";

contract CantoNameService is ERC721("Canto Name Service", "CNS"), LinearVRGDA, Ownable, ReentrancyGuard {

    /*//////////////////////////////////////////////////////////////
                EVENTS
    //////////////////////////////////////////////////////////////*/

    // Announce contract withdrawals
    event Withdraw(address indexed recipient, uint256 indexed value);
    // Announce payable function overpayments as tips
    event Tip(address indexed tipper, uint256 indexed tip);

    /*//////////////////////////////////////////////////////////////
                LIBRARY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // Converts string name to uint256 tokenId
    function nameToID(string memory _name) public pure returns (uint256) {
        return (uint256(keccak256(abi.encodePacked(_name))));
    }

    // Return name owner address
    function getNameOwner(string memory _name) public view returns (address) {
        uint256 tokenId = nameToID(_name);
        return ownerOf(tokenId);
    }

    // Return string length, properly counts all Unicode characters
    function stringLength(string memory _string) public pure returns (uint256) {
        uint256 charCount; // Number of characters in _string regardless of char byte length
        uint256 charByteCount = 0; // Number of bytes in char (a = 1, € = 3)
        uint256 byteLength = bytes(_string).length; // Total length of string in raw bytes

        // Determine how many bytes each character in string has
        for (charCount = 0; charByteCount < byteLength; charCount++) {
            bytes1 b = bytes(_string)[charByteCount]; // if tree uses first byte to determine length
            if (b < 0x80) {
                charByteCount += 1;
            } else if (b < 0xE0) {
                charByteCount += 2;
            } else if (b < 0xF0) {
                charByteCount += 3;
            } else if (b < 0xF8) {
                charByteCount += 4;
            } else if (b < 0xFC) {
                charByteCount += 5;
            } else {
                charByteCount += 6;
            }
        }
        return charCount;
    }

    // Returns proper VRGDA price for name based off string length
    // _length parameter directly calls corresponding VRGDA via getVRGDAPrice()
    function priceName(uint256 _length) public view returns (uint256) {
        uint256 price;
        if (_length == 1) {
            price = _getVRGDAPrice(_length, vrgdaCounts.one);
        } else if (_length == 2) {
            price = _getVRGDAPrice(_length, vrgdaCounts.two);
        } else if (_length == 3) {
            price = _getVRGDAPrice(_length, vrgdaCounts.three);
        } else if (_length == 4) {
            price = _getVRGDAPrice(_length, vrgdaCounts.four);
        } else if (_length == 5) {
            price = _getVRGDAPrice(_length, vrgdaCounts.five);
        } else {
            price = 1 ether;
        }
        return price;
    }

    // Increments the proper counters based on string length
    function _incrementCounts(uint256 _length) internal {
        if (_length == 1) {
            vrgdaCounts._one++;
            vrgdaCounts.one++;
        } else if (_length == 2) {
            vrgdaCounts._two++;
            vrgdaCounts.two++;
        } else if (_length == 3) {
            vrgdaCounts._three++;
            vrgdaCounts.three++;
        } else if (_length == 4) {
            vrgdaCounts._four++;
            vrgdaCounts.four++;
        } else if (_length == 5) {
            vrgdaCounts._five++;
            vrgdaCounts.five++;
        } else if (_length >= 6) {
            vrgdaCounts._extra++;
        } else {
            revert("ZERO_CHARACTERS");
        }
    }

    // Return total number of names sold
    function totalNamesSold() public view returns (uint256) {
        return (
            vrgdaCounts._one + vrgdaCounts._two + vrgdaCounts._three + 
                vrgdaCounts._four + vrgdaCounts._five + vrgdaCounts._extra
        );
    }

    /*//////////////////////////////////////////////////////////////
                MINT LOGIC
    //////////////////////////////////////////////////////////////*/

    // Expired names will be minted again, internal logic blocks mints of current names
    // Recipient checking is processed with safe call
    function safeRegister(address _to, string memory _name, uint256 _term) public payable {
        // Generate tokenId from name string
        uint256 tokenId = nameToID(_name);
        // Calculate name character length
        uint256 length = stringLength(_name);
        // Calculate price based off name length
        uint256 price = priceName(length);

        // Require valid name
        require(length > 0, "MISSING_NAME");
        // Require price is fully paid
        require(msg.value >= price * _term, "INSUFFICIENT_PAYMENT");

        // Call critical safe mint logic
        _safeMint(_to, tokenId);

        // Increment counts for VRGDA logic
        _incrementCounts(length);

        // Calculate overpayment tip if any and announce
        if (msg.value > price * _term) {
            emit Tip(msg.sender, msg.value - (price * _term));
        }

        // Populate name struct data
        nameRegistry[tokenId].name = _name;
        // ********************** FIX THIS TO SUPPORT LEAP YEARS **************************
        nameRegistry[tokenId].expiry = block.timestamp + (_term * 365 days);
    }

    // Expired names will be minted again, internal logic blocks mints of current names
    // Recipient checking is not processed with this call
    function unsafeRegister(address _to, string memory _name, uint256 _term) public payable {
        // Generate tokenId from name string
        uint256 tokenId = nameToID(_name);
        // Calculate name character length
        uint256 length = stringLength(_name);
        // Calculate price based off name length
        uint256 price = priceName(length);

        // Require valid name
        require(length > 0, "MISSING_NAME");
        // Require price is fully paid
        require(msg.value >= price * _term, "INSUFFICIENT_PAYMENT");

        // Call critical mint logic
        _mint(_to, tokenId);

        // Increment counts for VRGDA logic
        _incrementCounts(length);

        // Calculate overpayment tip if any and announce
        if (msg.value > price * _term) {
            emit Tip(msg.sender, msg.value - (price * _term));
        }

        // Populate name struct data
        nameRegistry[tokenId].name = _name;
        // ********************** FIX THIS TO SUPPORT LEAP YEARS **************************
        nameRegistry[tokenId].expiry = block.timestamp + (_term * 365 days);
    }

    /*//////////////////////////////////////////////////////////////
                BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    // burnName function call using name
    function burnName(string memory _name) public {
        // Generate tokenId from name string
        uint256 tokenId = nameToID(_name);
        burnName(tokenId);
    }

    // Only owner can burn if name is undelegated
    function burnName(uint256 tokenId) public {
        require(msg.sender == ERC721.ownerOf(tokenId), "NOT_OWNER");
        _burn(tokenId);
    }

    /*//////////////////////////////////////////////////////////////
                RENEW LOGIC
    //////////////////////////////////////////////////////////////*/

    // Internal renewal logic
    function _renew(uint256 _tokenId, uint256 _term) internal {
        // Name must not be expired to be renewed
        require(nameRegistry[_tokenId].expiry >= block.timestamp, "NAME_EXPIRED");

        // Calculate new expiry timestamp
        // ********************** FIX THIS TO SUPPORT LEAP YEARS **************************
        uint256 renewalTime = (_term * 365 days);
        // Extend expiry by renewalTime
        nameRegistry[_tokenId].expiry += renewalTime;
    }

    // renewName function that handles name string instead of tokenId
    function renewName(string memory _name, uint256 _term) public payable {
        // Generate name ID
        uint256 tokenId = nameToID(_name);
        renewName(tokenId, _term);
    }

    // Primary renewal function that calls all renewal logic
    // Payment must be sufficient before renewal logic executes
    // Anyone can renew for anyone else
    function renewName(uint256 _tokenId, uint256 _term) public payable {
        // Retrieve name string
        string memory name = nameRegistry[_tokenId].name;
        // Calculate name string character length
        uint256 length = stringLength(name);
        // Use name character length to calculate current price
        uint256 price = priceName(length);

        // Require msg.value meets or exceeds renewal cost
        require(msg.value >= (price * _term), "INSUFFICIENT_PAYMENT");

        // Execute internal renewal logic
        _renew(_tokenId, _term);

        // Calculate overpayment tip if any and announce
        if (msg.value > price * _term) {
            emit Tip(msg.sender, msg.value - (price * _term));
        }
    }

    /*//////////////////////////////////////////////////////////////
                PRIMARY NAME LOGIC
    //////////////////////////////////////////////////////////////*/

    // Set primary name
    // Allow owner to call only if undelegated
    function setPrimary(uint256 tokenId) public {
        // Only owner or valid delegate can call
        require((msg.sender == ERC721.ownerOf(tokenId) &&
                nameRegistry[tokenId].delegationExpiry < block.timestamp) || 
            (msg.sender == nameRegistry[tokenId].delegate && 
                nameRegistry[tokenId].delegationExpiry > block.timestamp));

        // Set primary name data
        primaryName[msg.sender] = tokenId;
        currentPrimary[tokenId] = msg.sender;
    }

    // Return address' primary name
    function getPrimary(address _target) public view returns (string memory) {
        uint256 tokenId = primaryName[_target];
        return nameRegistry[tokenId].name;
    }

    /*//////////////////////////////////////////////////////////////
                DELEGATION LOGIC
    //////////////////////////////////////////////////////////////*/

    // Internal delegation logic
    // _expiry requires exact timestamp
    function _delegate(uint256 _tokenId, address delegate_, uint256 _expiry) internal {
        // Require delegation term not meet or exceed owner's expiry
        require(nameRegistry[_tokenId].expiry > _expiry, "OWNERSHIP_EXPIRY");
        // Require not already delegated
        require(nameRegistry[_tokenId].delegationExpiry < block.timestamp, "DELEGATION_ACTIVE");

        // Set delegate address 
        nameRegistry[_tokenId].delegate = delegate_;
        // Save delegation expiry timestamp
        nameRegistry[_tokenId].delegationExpiry = _expiry;

        // If used as primary by owner, clear
        if (primaryName[ERC721.ownerOf(_tokenId)] == _tokenId) {
            primaryName[currentPrimary[_tokenId]] = 0; // Wipe primary address' primary name
            currentPrimary[_tokenId] = address(0x0); // Reset inverse lookup
        }
    }

    // Pass call with string through to primary logic
    function delegateName(string memory _name, address delegate_, uint256 _term) public {
        // Generate name ID
        uint256 tokenId = nameToID(_name);
        delegateName(tokenId, delegate_, _term);
    }

    // Allow owner, approved, or operator to delegate a name for a specific term in years
    function delegateName(uint256 _tokenId, address delegate_, uint256 _term) public {
        // Require owner/approved/operator
        require(_isApprovedOrOwner(msg.sender, _tokenId), "NOT_APPROVED");

        // Calculate expiry timestamp
        // ********************** FIX THIS TO SUPPORT LEAP YEARS **************************
        uint256 delegationExpiry = block.timestamp + (_term * 365 days);

        _delegate(_tokenId, delegate_, delegationExpiry);
    }

    // Pass call with string through to primary logic
    function delegateNameWithPrecision(string memory _name, address delegate_, uint256 _expiry) public {
        uint256 tokenId = nameToID(_name);
        delegateNameWithPrecision(tokenId, delegate_, _expiry);
    }

    // Process delegation with precise expiry timestamp if yearly term is too imprecise
    function delegateNameWithPrecision(uint256 _tokenId, address delegate_, uint256 _expiry) public {
        // Require owner/approved/operator
        require(_isApprovedOrOwner(msg.sender, _tokenId), "NOT_APPROVED");

        _delegate(_tokenId, delegate_, _expiry);
    }

    // Internal delegation logic
    function _extend(uint256 _tokenId, uint256 _newExpiry) internal {
        // Require new delegation expiry not meet or exceed owner's expiry
        require(nameRegistry[_tokenId].expiry > _newExpiry, "OWNERSHIP_EXPIRY");
        // Require existing delegation to extend
        require(nameRegistry[_tokenId].delegationExpiry >= block.timestamp, "DELEGATION_INACTIVE");

        nameRegistry[_tokenId].delegationExpiry = _newExpiry;
    }

    // Pass call with string through to primary logic
    function extendDelegation(string memory _name, uint256 _term) public {
        uint256 tokenId = nameToID(_name);
        extendDelegation(tokenId, _term);
    }

    // Extend name delegation
    function extendDelegation(uint256 _tokenId, uint256 _term) public {
        // Require owner/approved/operator
        require(_isApprovedOrOwner(msg.sender, _tokenId), "NOT_APPROVED");

        // Calculate expiry timestamp
        // ********************** FIX THIS TO SUPPORT LEAP YEARS **************************
        uint256 newDelegationExpiry = 
            block.timestamp + 
            (nameRegistry[_tokenId].delegationExpiry - block.timestamp) + 
            (_term * 365 days);

        _extend(_tokenId, newDelegationExpiry);
    }

    // Pass call with string through to primary logic
    function extendDelegationWithPrecision(string memory _name, uint256 _newExpiry) public {
        uint256 tokenId = nameToID(_name);
        extendDelegationWithPrecision(tokenId, _newExpiry);
    }

    function extendDelegationWithPrecision(uint256 _tokenId, uint256 _newExpiry) public {
        // Require owner/approved/operator
        require(_isApprovedOrOwner(msg.sender, _tokenId), "NOT_APPROVED");

        _extend(_tokenId, _newExpiry);
    }

    /*//////////////////////////////////////////////////////////////
                PAYMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // Payment handling functions if we need them
    // ***************** Currently allows withdrawal to anyone ***********************
    function withdraw() public {
        (bool success,) = msg.sender.call{value: address(this).balance}("");
        require(success);
        emit Withdraw(msg.sender, address(this).balance);
    }

    receive() external payable {}
    fallback() external payable {}
}