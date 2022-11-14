// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {DSTestPlus} from "./utils/DSTestPlus.sol";
// import {DSInvariantTest} from "./utils/DSInvariantTest.sol";

// import {MockERC721} from "./utils/mocks/MockERC721.sol";

// import {ERC721} from "../src/ERC721.sol";
import {CantoNameService} from "../src/CantoNameService.sol";

import {ERC721TokenReceiver} from "../src/ERC721.sol";

contract ERC721Recipient is ERC721TokenReceiver {
    address public operator;
    address public from;
    uint256 public id;
    bytes public data;

    function onERC721Received(address _operator, address _from, uint256 _id, bytes calldata _data)
        public
        virtual
        override
        returns (bytes4)
    {
        operator = _operator;
        from = _from;
        id = _id;
        data = _data;

        return ERC721TokenReceiver.onERC721Received.selector;
    }
}

contract RevertingERC721Recipient is ERC721TokenReceiver {
    function onERC721Received(address, address, uint256, bytes calldata) public virtual override returns (bytes4) {
        revert(string(abi.encodePacked(ERC721TokenReceiver.onERC721Received.selector)));
    }
}

contract WrongReturnDataERC721Recipient is ERC721TokenReceiver {
    function onERC721Received(address, address, uint256, bytes calldata) public virtual override returns (bytes4) {
        return 0xCAFEBEEF;
    }
}

contract CNSTest is DSTestPlus {
    CantoNameService token;

    function setUp() public {
        token = new CantoNameService();
    }

    function invariantMetadata() public {
        assertEq(token.name(), "Canto Name Service");
        assertEq(token.symbol(), "CNS");
    }

    function testStringLengthOne() public {
        string memory _string = "a";

        uint256 length = token.stringLength(_string);
        assertEq(length, 1);
    }

    function testStringLengthTwo() public {
        string memory _string = "ab";

        uint256 length = token.stringLength(_string);
        assertEq(length, 2);
    }

    function testStringLengthThree() public {
        string memory _string = "abc";

        uint256 length = token.stringLength(_string);
        assertEq(length, 3);
    }

    function testStringLengthFour() public {
        string memory _string = "abcd";

        uint256 length = token.stringLength(_string);
        assertEq(length, 4);
    }

    function testStringLengthFive() public {
        string memory _string = "abcde";

        uint256 length = token.stringLength(_string);
        assertEq(length, 5);
    }

    function testStringLengthSix() public {
        string memory _string = "abcdef";

        uint256 length = token.stringLength(_string);
        assertEq(length, 6);
    }

    function testStringLengthZero() public {
        string memory _string = "";

        uint256 length = token.stringLength(_string);
        assertEq(length, 0);
    }

    // This test fails because of a bug in _register()
    // if a name hasn't been registered no NFT has been minted so ownerOf() will revert
    // I recommend splitting out the mint function from _register() and calling it in _register() after doing the CNS register checks
    // I also think there should be a separate transferName function that calls _register() and then transfers the NFT as well as a registerNewName function that mints a new name to simplify the logic

    function testSafeRegister() public {
        string memory _name = "a";
        uint256 _term = 1;

        token.safeRegister(_name, _term);
    }
}