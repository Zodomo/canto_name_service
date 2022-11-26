// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";

// import {DSInvariantTest} from "./utils/DSInvariantTest.sol";

// import {MockERC721} from "./utils/mocks/MockERC721.sol";

import "../src/Allowlist.sol";
import "../src/CantoNameService.sol";

contract ERC721Recipient is ERC721TokenReceiver {
    address public operator;
    address public from;
    uint256 public id;
    bytes public data;

    function onERC721Received(
        address _operator,
        address _from,
        uint256 _id,
        bytes calldata _data
    ) public virtual override returns (bytes4) {
        operator = _operator;
        from = _from;
        id = _id;
        data = _data;

        return ERC721TokenReceiver.onERC721Received.selector;
    }
}

contract RevertingERC721Recipient is ERC721TokenReceiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) public virtual override returns (bytes4) {
        revert(string(abi.encodePacked(ERC721TokenReceiver.onERC721Received.selector)));
    }
}

contract WrongReturnDataERC721Recipient is ERC721TokenReceiver {
    function onERC721Received(
        address,
        address,
        uint256, 
        bytes calldata
    ) public virtual override returns (bytes4) {
        return 0xCAFEBEEF;
    }
}

contract NonERC721Recipient {}

contract CNSTest is DSTestPlus {
    Allowlist list;
    CantoNameService token;

    // Allowlist needs to be deployed and its address passed to CantoNameService constructor
    function setUp() public {
        list = new Allowlist(30);
        token = new CantoNameService(address(list));
        token.vrgdaTest();
    }

    function invariantMetadata() public {
        assertEq(token.name(), "Canto Name Service");
        assertEq(token.symbol(), "CNS");
    }

    function testAlphanumericStringLengthOne() public {
        string memory _string = "a";

        uint256 length = token.stringLength(_string);
        assertEq(length, 1);
    }

    function testAlphanumericStringLengthTwo() public {
        string memory _string = "ab";

        uint256 length = token.stringLength(_string);
        assertEq(length, 2);
    }

    function testAlphanumericStringLengthThree() public {
        string memory _string = "abc";

        uint256 length = token.stringLength(_string);
        assertEq(length, 3);
    }

    function testAlphanumericStringLengthFour() public {
        string memory _string = "abcd";

        uint256 length = token.stringLength(_string);
        assertEq(length, 4);
    }

    function testAlphanumericStringLengthFive() public {
        string memory _string = "abcde";

        uint256 length = token.stringLength(_string);
        assertEq(length, 5);
    }

    function testAlphanumericStringLengthSix() public {
        string memory _string = "abcdef";

        uint256 length = token.stringLength(_string);
        assertEq(length, 6);
    }

    function testAlphanumericStringLengthZero() public {
        string memory _string = "";

        uint256 length = token.stringLength(_string);
        assertEq(length, 0);
    }

    // Should trigger Register and Tip event emissions as name is being overpaid for
    // Currently fails due to onERC721Received call
    // Unsure if it is due to the contract referencing it in _register() or here in the test
    function testSafeRegister() public {
        address recipient = address(1);
        string memory name = "a";
        uint256 term = 1;

        token.safeRegister{ value: 2 ether }(recipient, name, term);
    }
}