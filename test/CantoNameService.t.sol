// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";

import "../src/Allowlist.sol";
import "../src/CantoNameService.sol";

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

contract NonERC721Recipient {}

/*//////////////////////////////////////////////////////////////
            CANTO NAME SERVICE TESTS
//////////////////////////////////////////////////////////////*/

contract CNSTest is DSTestPlus {
    /*//////////////////////////////////////////////////////////////
                SETUP
    //////////////////////////////////////////////////////////////*/

    Allowlist list;
    CantoNameService cns;

    uint256 tokenId;
    uint256 length;
    uint256 price;
    string internal name = "test";

    // Allowlist needs to be deployed and its address passed to CantoNameService constructor
    function setUp() public {
        list = new Allowlist(30);
        cns = new CantoNameService(address(list));
        cns.vrgdaTest();

        tokenId = cns.nameToID("test");
        length = cns.stringLength("test");
        price = cns.priceName(length);
    }

    /*//////////////////////////////////////////////////////////////
                STANDARD TESTS
    //////////////////////////////////////////////////////////////*/

    function invariantMetadata() public {
        assertEq(cns.name(), "Canto Name Service");
        assertEq(cns.symbol(), "CNS");
    }

    function testUnsafeRegister() public {
        cns.unsafeRegister{value: price * 1 wei}(address(this), "test", 1);

        assertEq(cns.balanceOf(address(this)), 1);
        assertEq(cns.ownerOf(tokenId), address(this));
    }

    function testBurn() public {
        cns.unsafeRegister{value: price * 1 wei}(address(this), "test", 1);
        cns.burnName("test");

        assertEq(cns.balanceOf(address(this)), 0);

        hevm.expectRevert("ERC721: invalid token ID");
        assertEq(cns.ownerOf(tokenId), address(0));
    }

    function testApprove() public {
        address target = address(0xBEEF);

        cns.unsafeRegister{value: price * 1 wei}(address(this), "test", 1);

        cns.approveByName(target, "test");

        assertEq(cns.getApprovedByName("test"), target);
    }

    function testApproveAll() public {
        address target = address(0xBEEF);
        cns.setApprovalForAll(target, true);

        assertTrue(cns.isApprovedForAll(address(this), target));
    }

    function testApproveBurn() public {
        address target = address(0xBEEF);

        cns.unsafeRegister{value: price * 1 wei}(target, "test", 1);

        hevm.prank(target);
        cns.approveByName(address(this), "test");

        cns.burnName("test");

        assertEq(cns.balanceOf(target), 0);

        hevm.expectRevert("ERC721: invalid token ID");
        assertEq(cns.ownerOf(tokenId), address(0));

        hevm.expectRevert("ERC721: invalid token ID");
        assertEq(cns.getApproved(tokenId), address(0));
    }

    function testUnsafeTransferFrom() public {
        address from = address(0xBEEF);

        cns.unsafeRegister{value: price * 1 wei}(from, "test", 1);

        hevm.prank(from);
        cns.approveByName(address(this), "test");

        cns.transferFromByName(from, address(this), "test");

        assertEq(cns.getApprovedByName("test"), address(0));
        assertEq(cns.ownerOfByName("test"), address(this));
        assertEq(cns.balanceOf(address(this)), 1);
        assertEq(cns.balanceOf(from), 0);
    }

    function testUnsafeTransferFromSelf() public {
        address to = address(0xBEEF);

        cns.unsafeRegister{value: price * 1 wei}(address(this), "test", 1);

        cns.transferFromByName(address(this), to, "test");

        assertEq(cns.getApprovedByName("test"), address(0));
        assertEq(cns.ownerOfByName("test"), to);
        assertEq(cns.balanceOf(to), 1);
        assertEq(cns.balanceOf(address(this)), 0);
    }

    function testUnsafeTransferFromApproveAll() public {
        address from = address(0xABCD);
        address to = address(0xBEEF);

        cns.unsafeRegister{value: price * 1 wei}(from, "test", 1);

        hevm.prank(from);
        cns.setApprovalForAll(address(this), true);

        cns.transferFromByName(from, to, "test");

        assertEq(cns.getApprovedByName("test"), address(0));
        assertEq(cns.ownerOfByName("test"), to);
        assertEq(cns.balanceOf(to), 1);
        assertEq(cns.balanceOf(from), 0);
    }

    function testSafeTransferFromToEOA() public {
        address from = address(0xABCD);
        address to = address(0xBEEF);

        cns.unsafeRegister{value: price * 1 wei}(from, "test", 1);

        hevm.prank(from);
        cns.setApprovalForAll(address(this), true);

        cns.safeTransferFrom(from, to, tokenId);

        assertEq(cns.getApproved(tokenId), address(0));
        assertEq(cns.ownerOf(tokenId), to);
        assertEq(cns.balanceOf(to), 1);
        assertEq(cns.balanceOf(from), 0);
    }

    function testSafeTransferFromToERC721Recipient() public {
        address from = address(0xABCD);
        ERC721Recipient recipient = new ERC721Recipient();

        cns.unsafeRegister{value: price * 1 wei}(from, "test", 1);

        hevm.prank(from);
        cns.setApprovalForAll(address(this), true);

        cns.safeTransferFrom(from, address(recipient), tokenId);

        assertEq(cns.getApproved(tokenId), address(0));
        assertEq(cns.ownerOf(tokenId), address(recipient));
        assertEq(cns.balanceOf(address(recipient)), 1);
        assertEq(cns.balanceOf(from), 0);

        assertEq(recipient.operator(), address(this));
        assertEq(recipient.from(), from);
        assertEq(recipient.id(), tokenId);
        assertBytesEq(recipient.data(), "");
    }

    function testSafeTransferFromToERC721RecipientWithData() public {
        address from = address(0xABCD);
        ERC721Recipient recipient = new ERC721Recipient();

        cns.unsafeRegister{value: price * 1 wei}(from, "test", 1);

        hevm.prank(from);
        cns.setApprovalForAll(address(this), true);

        cns.safeTransferFrom(from, address(recipient), tokenId, "testing 123");

        assertEq(cns.getApproved(tokenId), address(0));
        assertEq(cns.ownerOf(tokenId), address(recipient));
        assertEq(cns.balanceOf(address(recipient)), 1);
        assertEq(cns.balanceOf(from), 0);

        assertEq(recipient.operator(), address(this));
        assertEq(recipient.from(), from);
        assertEq(recipient.id(), tokenId);
        assertBytesEq(recipient.data(), "testing 123");
    }

    function testSafeRegisterToEOA() public {
        address to = address(0xBEEF);

        cns.safeRegister{value: price * 1 wei}(to, "test", 1);

        assertEq(cns.ownerOf(tokenId), address(to));
        assertEq(cns.balanceOf(address(to)), 1);
    }

    function testSafeRegisterToERC721Recipient() public {
        ERC721Recipient to = new ERC721Recipient();

        cns.safeRegister{value: price * 1 wei}(address(to), "test", 1);

        assertEq(cns.ownerOf(tokenId), address(to));
        assertEq(cns.balanceOf(address(to)), 1);

        assertEq(to.operator(), address(this));
        assertEq(to.from(), address(0));
        assertEq(to.id(), tokenId);
        assertBytesEq(to.data(), "");
    }

    function testSafeRegisterToERC721RecipientWithData() public {
        ERC721Recipient to = new ERC721Recipient();

        cns.safeRegister{value: price * 1 wei}(address(to), "test", 1, "testing 123");

        assertEq(cns.ownerOf(tokenId), address(to));
        assertEq(cns.balanceOf(address(to)), 1);

        assertEq(to.operator(), address(this));
        assertEq(to.from(), address(0));
        assertEq(to.id(), tokenId);
        assertBytesEq(to.data(), "testing 123");
    }

    function testFailRegisterToZero() public {
        cns.unsafeRegister{value: price * 1 wei}(address(0), "test", 1);
    }

    function testFailDoubleRegister() public {
        address to = address(0xBEEF);

        cns.unsafeRegister{value: price * 1 wei}(to, "test", 1);
        cns.unsafeRegister{value: price * 1 wei}(to, "test", 1);
    }

    function testFailBurnUnregistered() public {
        cns.burnName("test");
    }

    function testFailDoubleBurn() public {
        cns.unsafeRegister{value: price * 1 wei}(address(this), "test", 1);

        cns.burnName("test");
        cns.burnName("test");
    }

    function testFailApproveUnregistered() public {
        cns.approveByName(address(0xBEEF), "test");
    }

    function testFailApproveUnauthorized() public {
        address to = address(0xCAFE);

        cns.unsafeRegister{value: price * 1 wei}(to, "test", 1);

        cns.approveByName(address(0xBEEF), "test");
    }

    function testFailTransferFromUnowned() public {
        cns.transferFromByName(address(0xFEED), address(0xBEEF), "test");
    }

    function testFailTransferFromWrongFrom() public {
        address to = address(0xCAFE);

        cns.unsafeRegister{value: price * 1 wei}(to, "test", 1);

        hevm.prank(to);
        cns.transferFromByName(address(0xFEED), address(0xBEEF), "test");
    }

    function testFailTransferFromToZero() public {
        cns.unsafeRegister{value: price * 1 wei}(address(this), "test", 1);

        cns.transferFromByName(address(this), address(0), "test");
    }

    function testFailTransferFromNotOwner() public {
        address to = address(0xCAFE);

        cns.unsafeRegister{value: price * 1 wei}(to, "test", 1);

        cns.transferFromByName(address(0xFEED), address(0xBEEF), "test");
    }

    function testFailSafeTransferFromToNonERC721Recipient() public {
        address to = address(new NonERC721Recipient());

        cns.unsafeRegister{value: price * 1 wei}(address(this), "test", 1);

        cns.safeTransferFromByName(address(this), to, "test");
    }

    function testFailSafeTransferFromToNonERC721RecipientWithData() public {
        address to = address(new NonERC721Recipient());

        cns.unsafeRegister{value: price * 1 wei}(address(this), "test", 1);

        cns.safeTransferFromByNameWithData(address(this), to, "test", "testing 123");
    }

    function testFailSafeTransferFromToRevertingERC721Recipient() public {
        address to = address(new RevertingERC721Recipient());

        cns.unsafeRegister{value: price * 1 wei}(address(this), "test", 1);

        cns.safeTransferFromByName(address(this), to, "test");
    }

    function testFailSafeTransferFromToRevertingERC721RecipientWithData() public {
        address to = address(new RevertingERC721Recipient());

        cns.unsafeRegister{value: price * 1 wei}(address(this), "test", 1);

        cns.safeTransferFromByNameWithData(address(this), to, "test", "testing 123");
    }

    function testFailSafeTransferFromToERC721RecipientWithWrongReturnData() public {
        address to = address(new WrongReturnDataERC721Recipient());

        cns.unsafeRegister{value: price * 1 wei}(address(this), "test", 1);

        cns.safeTransferFromByName(address(this), to, "test");
    }

    function testFailSafeTransferFromToERC721RecipientWithWrongReturnDataWithData() public {
        address to = address(new WrongReturnDataERC721Recipient());

        cns.unsafeRegister{value: price * 1 wei}(address(this), "test", 1);

        cns.safeTransferFromByNameWithData(address(this), to, "test", "testing 123");
    }

    function testFailSafeRegisterToNonERC721Recipient() public {
        address to = address(new NonERC721Recipient());

        cns.safeRegister{value: price * 1 wei}(to, "test", 1);
    }

    function testFailSafeRegisterToNonERC721RecipientWithData() public {
        address to = address(new NonERC721Recipient());

        cns.safeRegister{value: price * 1 wei}(to, "test", 1);
    }

    function testFailSafeRegisterToRevertingERC721Recipient() public {
        address to = address(new RevertingERC721Recipient());

        cns.safeRegister{value: price * 1 wei}(to, "test", 1);
    }

    function testFailSafeRegisterToRevertingERC721RecipientWithData() public {
        address to = address(new RevertingERC721Recipient());

        cns.safeRegister{value: price * 1 wei}(to, "test", 1);
    }

    function testFailSafeRegisterToERC721RecipientWithWrongReturnData() public {
        address to = address(new WrongReturnDataERC721Recipient());

        cns.safeRegister{value: price * 1 wei}(to, "test", 1);
    }

    function testFailSafeRegisterToERC721RecipientWithWrongReturnDataWithData() public {
        address to = address(new WrongReturnDataERC721Recipient());

        cns.safeRegister{value: price * 1 wei}(to, "test", 1);
    }

    function testFailBalanceOfZeroAddress() public view {
        cns.balanceOf(address(0));
    }

    function testFailOwnerOfUnregistered() public view {
        cns.ownerOf(tokenId);
    }

    /*//////////////////////////////////////////////////////////////
                ITERABLE TESTS
    //////////////////////////////////////////////////////////////*/

    function testUnsafeRegister(address _to, string memory _name) public {
        if (_to == address(0)) _to = address(0xBEEF);
        if (cns.stringLength(_name) == 0) _name = name;

        uint256 _length = cns.stringLength(_name);
        uint256 _price = cns.priceName(_length);

        cns.unsafeRegister{value: _price * 1 wei}(_to, _name, 1);

        assertEq(cns.balanceOf(_to), 1);
        assertEq(cns.ownerOfByName(_name), _to);
    }

    function testSafeRegister(address _to, string memory _name) public {
        if (_to == address(0)) _to = address(0xBEEF);
        if (cns.stringLength(_name) == 0) _name = name;

        uint256 _length = cns.stringLength(_name);
        uint256 _price = cns.priceName(_length);

        cns.safeRegister{value: _price * 1 wei}(_to, _name, 1);

        assertEq(cns.balanceOf(_to), 1);
        assertEq(cns.ownerOfByName(_name), _to);
    }

    function testBurn(address _to, string memory _name) public {
        if (_to == address(0)) _to = address(0xBEEF);
        if (cns.stringLength(_name) == 0) _name = name;

        uint256 _length = cns.stringLength(_name);
        uint256 _price = cns.priceName(_length);

        cns.unsafeRegister{value: _price * 1 wei}(_to, _name, 1);

        hevm.prank(_to);
        cns.burnName(_name);

        assertEq(cns.balanceOf(_to), 0);

        hevm.expectRevert("ERC721: invalid token ID");
        cns.ownerOfByName(_name);
    }

    function testApprove(address _to, string memory _name) public {
        if (_to == address(0) || _to == address(0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84)) {
            _to = address(0xBEEF);
        }
        if (cns.stringLength(_name) == 0) { _name = name; }

        uint256 _length = cns.stringLength(_name);
        uint256 _price = cns.priceName(_length);

        cns.unsafeRegister{value: _price * 1 wei}(_to, _name, 1);

        hevm.prank(_to);
        cns.approveByName(address(this), _name);

        assertEq(cns.getApprovedByName(_name), address(this));
    }

    function testApproveBurn(address _to, string memory _name) public {
        if (_to == address(0) || _to == address(0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84)) {
            _to = address(0xBEEF);
        }
        if (cns.stringLength(_name) == 0) _name = name;

        uint256 _length = cns.stringLength(_name);
        uint256 _price = cns.priceName(_length);

        cns.unsafeRegister{value: _price * 1 wei}(_to, _name, 1);

        hevm.prank(_to);
        cns.approveByName(address(this), _name);

        cns.burnName(_name);

        assertEq(cns.balanceOf(_to), 0);

        hevm.expectRevert("ERC721: invalid token ID");
        cns.ownerOfByName(_name);
    }

    function testApproveAll(address _to) public {
        cns.setApprovalForAll(_to, true);

        assertBoolEq(cns.isApprovedForAll(address(this), _to), true);
    }

    function testUnsafeTransferFrom(address _to, string memory _name) public {
        address from = address(0xABCD);

        if (_to == address(0) || _to == from) { _to = address(0xBEEF); }
        if (cns.stringLength(_name) == 0) { _name = name; }

        uint256 _length = cns.stringLength(_name);
        uint256 _price = cns.priceName(_length);

        cns.unsafeRegister{value: _price * 1 wei}(from, _name, 1);

        hevm.prank(from);
        cns.approveByName(address(this), _name);

        cns.transferFromByName(from, _to, _name);

        assertEq(cns.getApprovedByName(_name), address(0));
        assertEq(cns.ownerOfByName(_name), _to);
        assertEq(cns.balanceOf(_to), 1);
        assertEq(cns.balanceOf(from), 0);
    }

    function testTransferFromSelf(address _to, string memory _name) public {
        if (_to == address(0) || _to == address(this)) { _to = address(0xBEEF); }
        if (cns.stringLength(_name) == 0) { _name = name; }

        uint256 _length = cns.stringLength(_name);
        uint256 _price = cns.priceName(_length);

        cns.unsafeRegister{value: _price * 1 wei}(address(this), _name, 1);

        cns.transferFromByName(address(this), _to, _name);

        assertEq(cns.getApprovedByName(_name), address(0));
        assertEq(cns.ownerOfByName(_name), _to);
        assertEq(cns.balanceOf(_to), 1);
        assertEq(cns.balanceOf(address(this)), 0);
    }

    function testTransferFromApproveAll(address _to, string memory _name) public {
        address from = address(0xABCD);

        if (_to == address(0) || _to == from) { _to = address(0xBEEF); }
        if (cns.stringLength(_name) == 0) { _name = name; }

        uint256 _length = cns.stringLength(_name);
        uint256 _price = cns.priceName(_length);

        cns.unsafeRegister{value: _price * 1 wei}(from, _name, 1);

        hevm.prank(from);
        cns.setApprovalForAll(address(this), true);

        cns.transferFromByName(from, _to, _name);

        assertEq(cns.getApprovedByName(_name), address(0));
        assertEq(cns.ownerOfByName(_name), _to);
        assertEq(cns.balanceOf(_to), 1);
        assertEq(cns.balanceOf(from), 0);
    }

    function testSafeTransferFromToEOA(address _to, string memory _name) public {
        address from = address(0xABCD);

        if (_to == address(0) || _to == from) _to = address(0xBEEF);
        if (cns.stringLength(_name) == 0) _name = name;

        uint256 _length = cns.stringLength(_name);
        uint256 _price = cns.priceName(_length);

        if (uint256(uint160(_to)) <= 18 || _to.code.length > 0) return;

        cns.unsafeRegister{value: _price * 1 wei}(from, _name, 1);

        hevm.prank(from);
        cns.setApprovalForAll(address(this), true);

        cns.safeTransferFromByName(from, _to, _name);

        assertEq(cns.getApprovedByName(_name), address(0));
        assertEq(cns.ownerOfByName(_name), _to);
        assertEq(cns.balanceOf(_to), 1);
        assertEq(cns.balanceOf(from), 0);
    }

    function testSafeTransferFromToERC721Recipient(string memory _name) public {
        address from = address(0xABCD);
        ERC721Recipient recipient = new ERC721Recipient();

        if (cns.stringLength(_name) == 0) _name = name;

        uint256 _length = cns.stringLength(_name);
        uint256 _price = cns.priceName(_length);

        cns.unsafeRegister{value: _price * 1 wei}(from, _name, 1);

        hevm.prank(from);
        cns.setApprovalForAll(address(this), true);

        cns.safeTransferFromByName(from, address(recipient), _name);

        assertEq(cns.getApprovedByName(_name), address(0));
        assertEq(cns.ownerOfByName(_name), address(recipient));
        assertEq(cns.balanceOf(address(recipient)), 1);
        assertEq(cns.balanceOf(from), 0);

        assertEq(recipient.operator(), address(this));
        assertEq(recipient.from(), from);
        assertEq(recipient.id(), cns.nameToID(_name));
        assertBytesEq(recipient.data(), "");
    }

    function testSafeTransferFromToERC721RecipientWithData(string memory _name, bytes calldata _data) public {
        address from = address(0xABCD);
        ERC721Recipient recipient = new ERC721Recipient();

        if (cns.stringLength(_name) == 0) _name = name;

        uint256 _length = cns.stringLength(_name);
        uint256 _price = cns.priceName(_length);

        cns.unsafeRegister{value: _price * 1 wei}(from, _name, 1);

        hevm.prank(from);
        cns.setApprovalForAll(address(this), true);

        cns.safeTransferFromByNameWithData(from, address(recipient), _name, _data);

        assertEq(cns.getApprovedByName(_name), address(0));
        assertEq(cns.ownerOfByName(_name), address(recipient));
        assertEq(cns.balanceOf(address(recipient)), 1);
        assertEq(cns.balanceOf(from), 0);

        assertEq(recipient.operator(), address(this));
        assertEq(recipient.from(), from);
        assertEq(recipient.id(), cns.nameToID(_name));
        assertBytesEq(recipient.data(), _data);
    }

    function testSafeRegisterToEOA(address _to, string memory _name) public {
        if (_to == address(0) || _to == address(0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84)) {
            _to = address(0xBEEF);
        }

        if (cns.stringLength(_name) == 0) _name = name;

        uint256 _length = cns.stringLength(_name);
        uint256 _price = cns.priceName(_length);

        if (uint256(uint160(_to)) <= 18 || _to.code.length > 0) return;

        cns.safeRegister{value: _price * 1 wei}(_to, _name, 1);

        assertEq(cns.ownerOfByName(_name), address(_to));
        assertEq(cns.balanceOf(address(_to)), 1);
    }

    function testSafeMintToERC721Recipient(string memory _name) public {
        ERC721Recipient to = new ERC721Recipient();

        if (cns.stringLength(_name) == 0) _name = name;

        uint256 _length = cns.stringLength(_name);
        uint256 _price = cns.priceName(_length);

        cns.safeRegister{value: _price * 1 wei}(address(to), _name, 1);

        assertEq(cns.ownerOfByName(_name), address(to));
        assertEq(cns.balanceOf(address(to)), 1);

        assertEq(to.operator(), address(this));
        assertEq(to.from(), address(0));
        assertEq(to.id(), cns.nameToID(_name));
        assertBytesEq(to.data(), "");
    }

    function testSafeMintToERC721RecipientWithData(string memory _name, bytes calldata _data) public {
        ERC721Recipient to = new ERC721Recipient();

        if (cns.stringLength(_name) == 0) { _name = name; }

        uint256 _length = cns.stringLength(_name);
        uint256 _price = cns.priceName(_length);

        cns.safeRegister{value: _price * 1 wei}(address(to), _name, 1, _data);

        assertEq(cns.ownerOfByName(_name), address(to));
        assertEq(cns.balanceOf(address(to)), 1);

        assertEq(to.operator(), address(this));
        assertEq(to.from(), address(0));
        assertEq(to.id(), cns.nameToID(_name));
        assertBytesEq(to.data(), _data);
    }

    /*//////////////////////////////////////////////////////////////
                UNFINISHED
    //////////////////////////////////////////////////////////////*/

    /*

    function testFailMintToZero(uint256 id) public {
        cns._mint(address(0), id);
    }

    function testFailDoubleMint(uint256 id, address to) public {
        if (to == address(0)) to = address(0xBEEF);

        cns._mint(to, id);
        cns._mint(to, id);
    }

    function testFailBurnUnMinted(uint256 id) public {
        cns._burn(id);
    }

    function testFailDoubleBurn(uint256 id, address to) public {
        if (to == address(0)) to = address(0xBEEF);

        cns._mint(to, id);

        cns._burn(id);
        cns._burn(id);
    }

    function testFailApproveUnMinted(uint256 id, address to) public {
        cns.approve(to, id);
    }

    function testFailApproveUnAuthorized(
        address owner,
        uint256 id,
        address to
    ) public {
        if (owner == address(0) || owner == address(this)) owner = address(0xBEEF);

        cns._mint(owner, id);

        cns.approve(to, id);
    }

    function testFailTransferFromUnOwned(
        address from,
        address to,
        uint256 id
    ) public {
        cns.transferFrom(from, to, id);
    }

    function testFailTransferFromWrongFrom(
        address owner,
        address from,
        address to,
        uint256 id
    ) public {
        if (owner == address(0)) to = address(0xBEEF);
        if (from == owner) revert();

        cns._mint(owner, id);

        cns.transferFrom(from, to, id);
    }

    function testFailTransferFromToZero(uint256 id) public {
        cns._mint(address(this), id);

        cns.transferFrom(address(this), address(0), id);
    }

    function testFailTransferFromNotOwner(
        address from,
        address to,
        uint256 id
    ) public {
        if (from == address(this)) from = address(0xBEEF);

        cns._mint(from, id);

        cns.transferFrom(from, to, id);
    }

    function testFailSafeTransferFromToNonERC721Recipient(uint256 id) public {
        cns._mint(address(this), id);

        cns.safeTransferFrom(address(this), address(new NonERC721Recipient()), id);
    }

    function testFailSafeTransferFromToNonERC721RecipientWithData(uint256 id, bytes calldata data) public {
        cns._mint(address(this), id);

        cns.safeTransferFrom(address(this), address(new NonERC721Recipient()), id, data);
    }

    function testFailSafeTransferFromToRevertingERC721Recipient(uint256 id) public {
        cns._mint(address(this), id);

        cns.safeTransferFrom(address(this), address(new RevertingERC721Recipient()), id);
    }

    function testFailSafeTransferFromToRevertingERC721RecipientWithData(uint256 id, bytes calldata data) public {
        cns._mint(address(this), id);

        cns.safeTransferFrom(address(this), address(new RevertingERC721Recipient()), id, data);
    }

    function testFailSafeTransferFromToERC721RecipientWithWrongReturnData(uint256 id) public {
        cns._mint(address(this), id);

        cns.safeTransferFrom(address(this), address(new WrongReturnDataERC721Recipient()), id);
    }

    function testFailSafeTransferFromToERC721RecipientWithWrongReturnDataWithData(uint256 id, bytes calldata data)
        public
    {
        cns._mint(address(this), id);

        cns.safeTransferFrom(address(this), address(new WrongReturnDataERC721Recipient()), id, data);
    }

    function testFailSafeMintToNonERC721Recipient(uint256 id) public {
        cns.safeMint(address(new NonERC721Recipient()), id);
    }

    function testFailSafeMintToNonERC721RecipientWithData(uint256 id, bytes calldata data) public {
        cns.safeMint(address(new NonERC721Recipient()), id, data);
    }

    function testFailSafeMintToRevertingERC721Recipient(uint256 id) public {
        cns.safeMint(address(new RevertingERC721Recipient()), id);
    }

    function testFailSafeMintToRevertingERC721RecipientWithData(uint256 id, bytes calldata data) public {
        cns.safeMint(address(new RevertingERC721Recipient()), id, data);
    }

    function testFailSafeMintToERC721RecipientWithWrongReturnData(uint256 id) public {
        cns.safeMint(address(new WrongReturnDataERC721Recipient()), id);
    }

    function testFailSafeMintToERC721RecipientWithWrongReturnDataWithData(uint256 id, bytes calldata data) public {
        cns.safeMint(address(new WrongReturnDataERC721Recipient()), id, data);
    }

    function testFailOwnerOfUnminted(uint256 id) public view {
        cns.ownerOf(id);
    }

    function testAlphanumericStringLengthOne() public {
        string memory _string = "a";

        uint256 length = cns.stringLength(_string);
        assertEq(length, 1);
    }

    function testAlphanumericStringLengthTwo() public {
        string memory _string = "ab";

        uint256 length = cns.stringLength(_string);
        assertEq(length, 2);
    }

    function testAlphanumericStringLengthThree() public {
        string memory _string = "abc";

        uint256 length = cns.stringLength(_string);
        assertEq(length, 3);
    }

    function testAlphanumericStringLengthFour() public {
        string memory _string = "abcd";

        uint256 length = cns.stringLength(_string);
        assertEq(length, 4);
    }

    function testAlphanumericStringLengthFive() public {
        string memory _string = "abcde";

        uint256 length = cns.stringLength(_string);
        assertEq(length, 5);
    }

    function testAlphanumericStringLengthSix() public {
        string memory _string = "abcdef";

        uint256 length = cns.stringLength(_string);
        assertEq(length, 6);
    }

    function testAlphanumericStringLengthZero() public {
        string memory _string = "";

        uint256 length = cns.stringLength(_string);
        assertEq(length, 0);
    }

    // Should trigger Register and Tip event emissions as name is being overpaid for
    // Currently fails due to onERC721Received call
    // Unsure if it is due to the contract referencing it in _register() or here in the test
    function testSafeRegister() public {
        address recipient = address(1);
        string memory name = "a";
        uint256 term = 1;

        cns.safeRegister{ value: 2 ether }(recipient, name, term);
    }

    */
}
