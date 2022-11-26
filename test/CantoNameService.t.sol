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

/*//////////////////////////////////////////////////////////////
            CANTO NAME SERVICE TESTS
//////////////////////////////////////////////////////////////*/

contract CNSTest is DSTestPlus {

    Allowlist list;
    CantoNameService cns;

    // Allowlist needs to be deployed and its address passed to CantoNameService constructor
    function setUp() public {
        list = new Allowlist(30);
        cns = new CantoNameService(address(list));
        cns.vrgdaTest();
    }

    function invariantMetadata() public {
        assertEq(cns.name(), "Canto Name Service");
        assertEq(cns.symbol(), "CNS");
    }

    function testUnsafeRegister() public {
        uint256 tokenId = cns.nameToID("test");
        uint256 length = cns.stringLength("test");
        uint256 price = cns.priceName(length);

        cns.unsafeRegister{ value: price * 1 wei }(address(this), "test", 1);

        assertEq(cns.balanceOf(address(this)), 1);
        assertEq(cns.ownerOf(tokenId), address(this));
    }

    function testBurn() public {
        uint256 tokenId = cns.nameToID("test");
        uint256 length = cns.stringLength("test");
        uint256 price = cns.priceName(length);

        cns.unsafeRegister{ value: price * 1 wei }(address(this), "test", 1);
        cns.burnName("test");

        assertEq(cns.balanceOf(address(this)), 0);

        assertEq(cns.ownerOf(tokenId), address(0));
    }

    function testApprove() public {
        uint256 tokenId = cns.nameToID("test");
        uint256 length = cns.stringLength("test");
        uint256 price = cns.priceName(length);
        address target = address(0xBEEF);

        cns.unsafeRegister{ value: price * 1 wei }(address(this), "test", 1);

        cns.approve(target, tokenId);

        assertEq(cns.getApproved(tokenId), target);
    }

    function testApproveAll() public {
        address target = address(0xBEEF);
        cns.setApprovalForAll(target, true);

        assertTrue(cns.isApprovedForAll(address(this), target));
    }

    function testApproveBurn() public {
        uint256 tokenId = cns.nameToID("test");
        uint256 length = cns.stringLength("test");
        uint256 price = cns.priceName(length);
        address target = address(0xBEEF);

        cns.unsafeRegister{ value: price * 1 wei }(target, "test", 1);

        hevm.prank(target);
        cns.approve(address(this), tokenId);

        cns.burnName("test");

        assertEq(cns.balanceOf(target), 0);
        assertEq(cns.ownerOf(tokenId), address(0));

        hevm.expectRevert("ERC721::_requireMinted::NOT_MINTED");
        assertEq(cns.getApproved(tokenId), address(0));
    }

    /*//////////////////////////////////////////////////////////////
                UNFINISHED
    //////////////////////////////////////////////////////////////*/
    
    /*

    function testTransferFrom() public {
        address from = address(0xABCD);

        cns._mint(from, 1337);

        hevm.prank(from);
        cns.approve(address(this), 1337);

        cns.transferFrom(from, address(0xBEEF), 1337);

        assertEq(cns.getApproved(1337), address(0));
        assertEq(cns.ownerOf(1337), address(0xBEEF));
        assertEq(cns.balanceOf(address(0xBEEF)), 1);
        assertEq(cns.balanceOf(from), 0);
    }

    function testTransferFromSelf() public {
        cns._mint(address(this), 1337);

        cns.transferFrom(address(this), address(0xBEEF), 1337);

        assertEq(cns.getApproved(1337), address(0));
        assertEq(cns.ownerOf(1337), address(0xBEEF));
        assertEq(cns.balanceOf(address(0xBEEF)), 1);
        assertEq(cns.balanceOf(address(this)), 0);
    }

    function testTransferFromApproveAll() public {
        address from = address(0xABCD);

        cns._mint(from, 1337);

        hevm.prank(from);
        cns.setApprovalForAll(address(this), true);

        cns.transferFrom(from, address(0xBEEF), 1337);

        assertEq(cns.getApproved(1337), address(0));
        assertEq(cns.ownerOf(1337), address(0xBEEF));
        assertEq(cns.balanceOf(address(0xBEEF)), 1);
        assertEq(cns.balanceOf(from), 0);
    }

    function testSafeTransferFromToEOA() public {
        address from = address(0xABCD);

        cns._mint(from, 1337);

        hevm.prank(from);
        cns.setApprovalForAll(address(this), true);

        cns.safeTransferFrom(from, address(0xBEEF), 1337);

        assertEq(cns.getApproved(1337), address(0));
        assertEq(cns.ownerOf(1337), address(0xBEEF));
        assertEq(cns.balanceOf(address(0xBEEF)), 1);
        assertEq(cns.balanceOf(from), 0);
    }

    /*

    function testSafeTransferFromToERC721Recipient() public {
        address from = address(0xABCD);
        ERC721Recipient recipient = new ERC721Recipient();

        cns._mint(from, 1337);

        hevm.prank(from);
        cns.setApprovalForAll(address(this), true);

        cns.safeTransferFrom(from, address(recipient), 1337);

        assertEq(cns.getApproved(1337), address(0));
        assertEq(cns.ownerOf(1337), address(recipient));
        assertEq(cns.balanceOf(address(recipient)), 1);
        assertEq(cns.balanceOf(from), 0);

        assertEq(recipient.operator(), address(this));
        assertEq(recipient.from(), from);
        assertEq(recipient.id(), 1337);
        assertBytesEq(recipient.data(), "");
    }

    function testSafeTransferFromToERC721RecipientWithData() public {
        address from = address(0xABCD);
        ERC721Recipient recipient = new ERC721Recipient();

        cns._mint(from, 1337);

        hevm.prank(from);
        cns.setApprovalForAll(address(this), true);

        cns.safeTransferFrom(from, address(recipient), 1337, "testing 123");

        assertEq(cns.getApproved(1337), address(0));
        assertEq(cns.ownerOf(1337), address(recipient));
        assertEq(cns.balanceOf(address(recipient)), 1);
        assertEq(cns.balanceOf(from), 0);

        assertEq(recipient.operator(), address(this));
        assertEq(recipient.from(), from);
        assertEq(recipient.id(), 1337);
        assertBytesEq(recipient.data(), "testing 123");
    }

    function testSafeMintToEOA() public {
        cns.safeMint(address(0xBEEF), 1337);

        assertEq(cns.ownerOf(1337), address(address(0xBEEF)));
        assertEq(cns.balanceOf(address(address(0xBEEF))), 1);
    }

    function testSafeMintToERC721Recipient() public {
        ERC721Recipient to = new ERC721Recipient();

        cns.safeMint(address(to), 1337);

        assertEq(cns.ownerOf(1337), address(to));
        assertEq(cns.balanceOf(address(to)), 1);

        assertEq(to.operator(), address(this));
        assertEq(to.from(), address(0));
        assertEq(to.id(), 1337);
        assertBytesEq(to.data(), "");
    }

    function testSafeMintToERC721RecipientWithData() public {
        ERC721Recipient to = new ERC721Recipient();

        cns.safeMint(address(to), 1337, "testing 123");

        assertEq(cns.ownerOf(1337), address(to));
        assertEq(cns.balanceOf(address(to)), 1);

        assertEq(to.operator(), address(this));
        assertEq(to.from(), address(0));
        assertEq(to.id(), 1337);
        assertBytesEq(to.data(), "testing 123");
    }

    function testFailMintToZero() public {
        cns._mint(address(0), 1337);
    }

    function testFailDoubleMint() public {
        cns._mint(address(0xBEEF), 1337);
        cns._mint(address(0xBEEF), 1337);
    }

    function testFailBurnUnMinted() public {
        cns._burn(1337);
    }

    function testFailDoubleBurn() public {
        cns._mint(address(0xBEEF), 1337);

        cns._burn(1337);
        cns._burn(1337);
    }

    function testFailApproveUnMinted() public {
        cns.approve(address(0xBEEF), 1337);
    }

    function testFailApproveUnAuthorized() public {
        cns._mint(address(0xCAFE), 1337);

        cns.approve(address(0xBEEF), 1337);
    }

    function testFailTransferFromUnOwned() public {
        cns.transferFrom(address(0xFEED), address(0xBEEF), 1337);
    }

    function testFailTransferFromWrongFrom() public {
        cns._mint(address(0xCAFE), 1337);

        cns.transferFrom(address(0xFEED), address(0xBEEF), 1337);
    }

    function testFailTransferFromToZero() public {
        cns._mint(address(this), 1337);

        cns.transferFrom(address(this), address(0), 1337);
    }

    function testFailTransferFromNotOwner() public {
        cns._mint(address(0xFEED), 1337);

        cns.transferFrom(address(0xFEED), address(0xBEEF), 1337);
    }

    function testFailSafeTransferFromToNonERC721Recipient() public {
        cns._mint(address(this), 1337);

        cns.safeTransferFrom(address(this), address(new NonERC721Recipient()), 1337);
    }

    function testFailSafeTransferFromToNonERC721RecipientWithData() public {
        cns._mint(address(this), 1337);

        cns.safeTransferFrom(address(this), address(new NonERC721Recipient()), 1337, "testing 123");
    }

    function testFailSafeTransferFromToRevertingERC721Recipient() public {
        cns._mint(address(this), 1337);

        cns.safeTransferFrom(address(this), address(new RevertingERC721Recipient()), 1337);
    }

    function testFailSafeTransferFromToRevertingERC721RecipientWithData() public {
        cns._mint(address(this), 1337);

        cns.safeTransferFrom(address(this), address(new RevertingERC721Recipient()), 1337, "testing 123");
    }

    function testFailSafeTransferFromToERC721RecipientWithWrongReturnData() public {
        cns._mint(address(this), 1337);

        cns.safeTransferFrom(address(this), address(new WrongReturnDataERC721Recipient()), 1337);
    }

    function testFailSafeTransferFromToERC721RecipientWithWrongReturnDataWithData() public {
        cns._mint(address(this), 1337);

        cns.safeTransferFrom(address(this), address(new WrongReturnDataERC721Recipient()), 1337, "testing 123");
    }

    function testFailSafeMintToNonERC721Recipient() public {
        cns.safeMint(address(new NonERC721Recipient()), 1337);
    }

    function testFailSafeMintToNonERC721RecipientWithData() public {
        cns.safeMint(address(new NonERC721Recipient()), 1337, "testing 123");
    }

    function testFailSafeMintToRevertingERC721Recipient() public {
        cns.safeMint(address(new RevertingERC721Recipient()), 1337);
    }

    function testFailSafeMintToRevertingERC721RecipientWithData() public {
        cns.safeMint(address(new RevertingERC721Recipient()), 1337, "testing 123");
    }

    function testFailSafeMintToERC721RecipientWithWrongReturnData() public {
        cns.safeMint(address(new WrongReturnDataERC721Recipient()), 1337);
    }

    function testFailSafeMintToERC721RecipientWithWrongReturnDataWithData() public {
        cns.safeMint(address(new WrongReturnDataERC721Recipient()), 1337, "testing 123");
    }

    function testFailBalanceOfZeroAddress() public view {
        cns.balanceOf(address(0));
    }

    function testFailOwnerOfUnminted() public view {
        cns.ownerOf(1337);
    }

    function testMetadata(string memory name, string memory symbol) public {
        MockERC721 tkn = new MockERC721(name, symbol);

        assertEq(tkn.name(), name);
        assertEq(tkn.symbol(), symbol);
    }

    function testMint(address to, uint256 id) public {
        if (to == address(0)) to = address(0xBEEF);

        cns._mint(to, id);

        assertEq(cns.balanceOf(to), 1);
        assertEq(cns.ownerOf(id), to);
    }

    function testBurn(address to, uint256 id) public {
        if (to == address(0)) to = address(0xBEEF);

        cns._mint(to, id);
        cns._burn(id);

        assertEq(cns.balanceOf(to), 0);

        hevm.expectRevert("NOT_MINTED");
        cns.ownerOf(id);
    }

    function testApprove(address to, uint256 id) public {
        if (to == address(0)) to = address(0xBEEF);

        cns._mint(address(this), id);

        cns.approve(to, id);

        assertEq(cns.getApproved(id), to);
    }

    function testApproveBurn(address to, uint256 id) public {
        cns._mint(address(this), id);

        cns.approve(address(to), id);

        cns._burn(id);

        assertEq(cns.balanceOf(address(this)), 0);
        assertEq(cns.getApproved(id), address(0));

        hevm.expectRevert("NOT_MINTED");
        cns.ownerOf(id);
    }

    function testApproveAll(address to, bool approved) public {
        cns.setApprovalForAll(to, approved);

        assertBoolEq(cns.isApprovedForAll(address(this), to), approved);
    }

    function testTransferFrom(uint256 id, address to) public {
        address from = address(0xABCD);

        if (to == address(0) || to == from) to = address(0xBEEF);

        cns._mint(from, id);

        hevm.prank(from);
        cns.approve(address(this), id);

        cns.transferFrom(from, to, id);

        assertEq(cns.getApproved(id), address(0));
        assertEq(cns.ownerOf(id), to);
        assertEq(cns.balanceOf(to), 1);
        assertEq(cns.balanceOf(from), 0);
    }

    function testTransferFromSelf(uint256 id, address to) public {
        if (to == address(0) || to == address(this)) to = address(0xBEEF);

        cns._mint(address(this), id);

        cns.transferFrom(address(this), to, id);

        assertEq(cns.getApproved(id), address(0));
        assertEq(cns.ownerOf(id), to);
        assertEq(cns.balanceOf(to), 1);
        assertEq(cns.balanceOf(address(this)), 0);
    }

    function testTransferFromApproveAll(uint256 id, address to) public {
        address from = address(0xABCD);

        if (to == address(0) || to == from) to = address(0xBEEF);

        cns._mint(from, id);

        hevm.prank(from);
        cns.setApprovalForAll(address(this), true);

        cns.transferFrom(from, to, id);

        assertEq(cns.getApproved(id), address(0));
        assertEq(cns.ownerOf(id), to);
        assertEq(cns.balanceOf(to), 1);
        assertEq(cns.balanceOf(from), 0);
    }

    function testSafeTransferFromToEOA(uint256 id, address to) public {
        address from = address(0xABCD);

        if (to == address(0) || to == from) to = address(0xBEEF);

        if (uint256(uint160(to)) <= 18 || to.code.length > 0) return;

        cns._mint(from, id);

        hevm.prank(from);
        cns.setApprovalForAll(address(this), true);

        cns.safeTransferFrom(from, to, id);

        assertEq(cns.getApproved(id), address(0));
        assertEq(cns.ownerOf(id), to);
        assertEq(cns.balanceOf(to), 1);
        assertEq(cns.balanceOf(from), 0);
    }

    function testSafeTransferFromToERC721Recipient(uint256 id) public {
        address from = address(0xABCD);

        ERC721Recipient recipient = new ERC721Recipient();

        cns._mint(from, id);

        hevm.prank(from);
        cns.setApprovalForAll(address(this), true);

        cns.safeTransferFrom(from, address(recipient), id);

        assertEq(cns.getApproved(id), address(0));
        assertEq(cns.ownerOf(id), address(recipient));
        assertEq(cns.balanceOf(address(recipient)), 1);
        assertEq(cns.balanceOf(from), 0);

        assertEq(recipient.operator(), address(this));
        assertEq(recipient.from(), from);
        assertEq(recipient.id(), id);
        assertBytesEq(recipient.data(), "");
    }

    function testSafeTransferFromToERC721RecipientWithData(uint256 id, bytes calldata data) public {
        address from = address(0xABCD);
        ERC721Recipient recipient = new ERC721Recipient();

        cns._mint(from, id);

        hevm.prank(from);
        cns.setApprovalForAll(address(this), true);

        cns.safeTransferFrom(from, address(recipient), id, data);

        assertEq(cns.getApproved(id), address(0));
        assertEq(cns.ownerOf(id), address(recipient));
        assertEq(cns.balanceOf(address(recipient)), 1);
        assertEq(cns.balanceOf(from), 0);

        assertEq(recipient.operator(), address(this));
        assertEq(recipient.from(), from);
        assertEq(recipient.id(), id);
        assertBytesEq(recipient.data(), data);
    }

    function testSafeMintToEOA(uint256 id, address to) public {
        if (to == address(0)) to = address(0xBEEF);

        if (uint256(uint160(to)) <= 18 || to.code.length > 0) return;

        cns.safeMint(to, id);

        assertEq(cns.ownerOf(id), address(to));
        assertEq(cns.balanceOf(address(to)), 1);
    }

    function testSafeMintToERC721Recipient(uint256 id) public {
        ERC721Recipient to = new ERC721Recipient();

        cns.safeMint(address(to), id);

        assertEq(cns.ownerOf(id), address(to));
        assertEq(cns.balanceOf(address(to)), 1);

        assertEq(to.operator(), address(this));
        assertEq(to.from(), address(0));
        assertEq(to.id(), id);
        assertBytesEq(to.data(), "");
    }

    function testSafeMintToERC721RecipientWithData(uint256 id, bytes calldata data) public {
        ERC721Recipient to = new ERC721Recipient();

        cns.safeMint(address(to), id, data);

        assertEq(cns.ownerOf(id), address(to));
        assertEq(cns.balanceOf(address(to)), 1);

        assertEq(to.operator(), address(this));
        assertEq(to.from(), address(0));
        assertEq(to.id(), id);
        assertBytesEq(to.data(), data);
    }

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