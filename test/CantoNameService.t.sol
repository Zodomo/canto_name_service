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

    uint256 tokenId;
    uint256 length;
    uint256 price;

    // Allowlist needs to be deployed and its address passed to CantoNameService constructor
    function setUp() public {
        list = new Allowlist(30);
        cns = new CantoNameService(address(list));
        cns.vrgdaTest();

        tokenId = cns.nameToID("test");
        length = cns.stringLength("test");
        price = cns.priceName(length);
    }

    function invariantMetadata() public {
        assertEq(cns.name(), "Canto Name Service");
        assertEq(cns.symbol(), "CNS");
    }

    function testUnsafeRegister() public {
        cns.unsafeRegister{ value: price * 1 wei }(address(this), "test", 1);

        assertEq(cns.balanceOf(address(this)), 1);
        assertEq(cns.ownerOf(tokenId), address(this));
    }

    function testBurn() public {
        cns.unsafeRegister{ value: price * 1 wei }(address(this), "test", 1);
        cns.burnName("test");

        assertEq(cns.balanceOf(address(this)), 0);

        hevm.expectRevert("ERC721::_requireMinted::NOT_MINTED");
        assertEq(cns.ownerOf(tokenId), address(0));
    }

    function testApprove() public {
        address target = address(0xBEEF);

        cns.unsafeRegister{ value: price * 1 wei }(address(this), "test", 1);

        cns.approve(target, "test");

        assertEq(cns.getApproved(tokenId), target);
    }

    function testApproveAll() public {
        address target = address(0xBEEF);
        cns.setApprovalForAll(target, true);

        assertTrue(cns.isApprovedForAll(address(this), target));
    }

    function testApproveBurn() public {
        address target = address(0xBEEF);

        cns.unsafeRegister{ value: price * 1 wei }(target, "test", 1);

        hevm.prank(target);
        cns.approve(address(this), tokenId);

        cns.burnName("test");

        assertEq(cns.balanceOf(target), 0);

        hevm.expectRevert("ERC721::_requireMinted::NOT_MINTED");
        assertEq(cns.ownerOf(tokenId), address(0));

        hevm.expectRevert("ERC721::_requireMinted::NOT_MINTED");
        assertEq(cns.getApproved(tokenId), address(0));
    }

    function testUnsafeTransferFrom() public {
        address from = address(0xBEEF);

        cns.unsafeRegister{ value: price * 1 wei }(from, "test", 1);

        hevm.prank(from);
        cns.approve(address(this), tokenId);

        cns.transferFrom(from, address(this), tokenId);

        assertEq(cns.getApproved(tokenId), address(0));
        assertEq(cns.ownerOf(tokenId), address(this));
        assertEq(cns.balanceOf(address(this)), 1);
        assertEq(cns.balanceOf(from), 0);
    }

    function testUnsafeTransferFromSelf() public {
        address to = address(0xBEEF);

        cns.unsafeRegister{ value: price * 1 wei }(address(this), "test", 1);

        cns.transferFrom(address(this), to, tokenId);

        assertEq(cns.getApproved(tokenId), address(0));
        assertEq(cns.ownerOf(tokenId), to);
        assertEq(cns.balanceOf(to), 1);
        assertEq(cns.balanceOf(address(this)), 0);
    }

    function testUnsafeTransferFromApproveAll() public {
        address from = address(0xABCD);
        address to = address(0xBEEF);

        cns.unsafeRegister{ value: price * 1 wei }(from, "test", 1);

        hevm.prank(from);
        cns.setApprovalForAll(address(this), true);

        cns.transferFrom(from, to, tokenId);

        assertEq(cns.getApproved(tokenId), address(0));
        assertEq(cns.ownerOf(tokenId), to);
        assertEq(cns.balanceOf(to), 1);
        assertEq(cns.balanceOf(from), 0);
    }

    function testSafeTransferFromToEOA() public {
        address from = address(0xABCD);
        address to = address(0xBEEF);

        cns.unsafeRegister{ value: price * 1 wei }(from, "test", 1);

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

        cns.unsafeRegister{ value: price * 1 wei }(from, "test", 1);

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

        cns.unsafeRegister{ value: price * 1 wei }(from, "test", 1);

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

        cns.safeRegister{ value: price * 1 wei }(to, "test", 1);

        assertEq(cns.ownerOf(tokenId), address(to));
        assertEq(cns.balanceOf(address(to)), 1);
    }

    function testSafeRegisterToERC721Recipient() public {
        ERC721Recipient to = new ERC721Recipient();

        cns.safeRegister{ value: price * 1 wei }(address(to), "test", 1);

        assertEq(cns.ownerOf(tokenId), address(to));
        assertEq(cns.balanceOf(address(to)), 1);

        assertEq(to.operator(), address(this));
        assertEq(to.from(), address(0));
        assertEq(to.id(), tokenId);
        assertBytesEq(to.data(), "");
    }

    function testSafeRegisterToERC721RecipientWithData() public {
        ERC721Recipient to = new ERC721Recipient();

        cns.safeRegister{ value: price * 1 wei }(address(to), "test", 1, "testing 123");

        assertEq(cns.ownerOf(tokenId), address(to));
        assertEq(cns.balanceOf(address(to)), 1);

        assertEq(to.operator(), address(this));
        assertEq(to.from(), address(0));
        assertEq(to.id(), tokenId);
        assertBytesEq(to.data(), "testing 123");
    }

    function testFailRegisterToZero() public {
        cns.unsafeRegister{ value: price * 1 wei }(address(0), "test", 1);
    }

    function testFailDoubleRegister() public {
        address to = address(0xBEEF);

        cns.unsafeRegister{ value: price * 1 wei }(to, "test", 1);
        cns.unsafeRegister{ value: price * 1 wei }(to, "test", 1);
    }

    function testFailBurnUnregistered() public {
        cns.burnName("test");
    }

    function testFailDoubleBurn() public {
        cns.unsafeRegister{ value: price * 1 wei }(address(this), "test", 1);

        cns.burnName("test");
        cns.burnName("test");
    }

    function testFailApproveUnregistered() public {
        cns.approve(address(0xBEEF), "test");
    }

    function testFailApproveUnAuthorized() public {
        address to = address(0xCAFE);

        cns.unsafeRegister{ value: price * 1 wei }(to, "test", 1);

        cns.approve(address(0xBEEF), "test");
    }

    function testFailTransferFromUnOwned() public {
        cns.transferFrom(address(0xFEED), address(0xBEEF), "test");
    }

    function testFailTransferFromWrongFrom() public {
        address to = address(0xCAFE);

        cns.unsafeRegister{ value: price * 1 wei }(to, "test", 1);

        hevm.prank(to);
        cns.transferFrom(address(0xFEED), address(0xBEEF), "test");
    }

    function testFailTransferFromToZero() public {
        cns.unsafeRegister{ value: price * 1 wei }(address(this), "test", 1);

        cns.transferFrom(address(this), address(0), "test");
    }

    function testFailTransferFromNotOwner() public {
        address to = address(0xCAFE);

        cns.unsafeRegister{ value: price * 1 wei }(to, "test", 1);

        cns.transferFrom(address(0xFEED), address(0xBEEF), "test");
    }

    function testFailSafeTransferFromToNonERC721Recipient() public {
        address to = address(new NonERC721Recipient());

        cns.unsafeRegister{ value: price * 1 wei }(address(this), "test", 1);

        cns.safeTransferFrom(address(this), to, "test");
    }

    function testFailSafeTransferFromToNonERC721RecipientWithData() public {
        address to = address(new NonERC721Recipient());

        cns.unsafeRegister{ value: price * 1 wei }(address(this), "test", 1);

        cns.safeTransferFrom(address(this), to, "test", "testing 123");
    }

    function testFailSafeTransferFromToRevertingERC721Recipient() public {
        address to = address(new RevertingERC721Recipient());

        cns.unsafeRegister{ value: price * 1 wei }(address(this), "test", 1);

        cns.safeTransferFrom(address(this), to, "test");
    }

    function testFailSafeTransferFromToRevertingERC721RecipientWithData() public {
        address to = address(new RevertingERC721Recipient());

        cns.unsafeRegister{ value: price * 1 wei }(address(this), "test", 1);

        cns.safeTransferFrom(address(this), to, "test", "testing 123");
    }

    function testFailSafeTransferFromToERC721RecipientWithWrongReturnData() public {
        address to = address(new WrongReturnDataERC721Recipient());

        cns.unsafeRegister{ value: price * 1 wei }(address(this), "test", 1);

        cns.safeTransferFrom(address(this), to, "test");
    }

    function testFailSafeTransferFromToERC721RecipientWithWrongReturnDataWithData() public {
        address to = address(new WrongReturnDataERC721Recipient());

        cns.unsafeRegister{ value: price * 1 wei }(address(this), "test", 1);

        cns.safeTransferFrom(address(this), to, "test", "testing 123");
    }

    function testFailSafeRegisterToNonERC721Recipient() public {
        address to = address(new NonERC721Recipient());

        cns.safeRegister{ value: price * 1 wei }(to, "test", 1);
    }

    function testFailSafeRegisterToNonERC721RecipientWithData() public {
        address to = address(new NonERC721Recipient());

        cns.safeRegister{ value: price * 1 wei }(to, "test", 1, "testing 123");
    }

    function testFailSafeRegisterToRevertingERC721Recipient() public {
        address to = address(new RevertingERC721Recipient());

        cns.safeRegister{ value: price * 1 wei }(to, "test", 1);
    }

    function testFailSafeRegisterToRevertingERC721RecipientWithData() public {
        address to = address(new RevertingERC721Recipient());

        cns.safeRegister{ value: price * 1 wei }(to, "test", 1, "testing 123");
    }

    function testFailSafeRegisterToERC721RecipientWithWrongReturnData() public {
        address to = address(new WrongReturnDataERC721Recipient());

        cns.safeRegister{ value: price * 1 wei }(to, "test", 1);
    }

    function testFailSafeRegisterToERC721RecipientWithWrongReturnDataWithData() public {
        address to = address(new WrongReturnDataERC721Recipient());

        cns.safeRegister{ value: price * 1 wei }(to, "test", 1, "testing 123");
    }

    function testFailBalanceOfZeroAddress() public view {
        cns.balanceOf(address(0));
    }

    function testFailOwnerOfUnregistered() public view {
        cns.ownerOf(tokenId);
    }

    /*//////////////////////////////////////////////////////////////
                UNFINISHED
    //////////////////////////////////////////////////////////////*/
    
    /*

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