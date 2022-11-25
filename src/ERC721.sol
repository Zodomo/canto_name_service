// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC721/ERC721.sol)

pragma solidity ^0.8.17;

import "openzeppelin-contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/token/ERC721/IERC721Receiver.sol";
import "openzeppelin-contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "openzeppelin-contracts/utils/Address.sol";
import "openzeppelin-contracts/utils/Context.sol";
import "openzeppelin-contracts/utils/Strings.sol";
import "openzeppelin-contracts/utils/introspection/ERC165.sol";

/**
 * Based on OZ Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard,
 * including the Metadata extension, but not including the Enumerable extension, which is available separately
 * as {ERC721Enumerable}.
 */
contract ERC721 is Context, ERC165, IERC721, IERC721Metadata {
    using Address for address;
    using Strings for uint256;

    /*//////////////////////////////////////////////////////////////
                GENERAL STORAGE
    //////////////////////////////////////////////////////////////*/

    // Token name ("Canto Name Service")
    string private _name;

    // Token symbol ("CNS")
    string private _symbol;

    // Mapping from token ID to owner address
    mapping(uint256 => address) private _owners;

    // Mapping owner address to token count
    mapping(address => uint256) private _balances;

    // Mapping from token ID to approved address
    // Individual approval for control of one token for one address
    // Only one single address approval can be valid at once
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    // Operators have control over all tokens owned by an address until revoked
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /*//////////////////////////////////////////////////////////////
                CNS STORAGE
    //////////////////////////////////////////////////////////////*/

    // Name data / URI(?) struct
    struct Name {
        string name;
        uint256 expiry;
        address delegate;
        uint256 delegationExpiry;
    }

    // Name data storage / registry
    mapping(uint256 => Name) public nameRegistry;

    // Primary name storage, one tokenId per address
    mapping(address => uint256) public primaryName;
    // Inverse name lookup tokenId to address
    mapping(uint256 => address) public currentPrimary;

    /*//////////////////////////////////////////////////////////////
                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    // Initializes the contract by setting a `name` and a `symbol` to the token collection.
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /*//////////////////////////////////////////////////////////////
                ERC165 LOGIC
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /*//////////////////////////////////////////////////////////////
                ERC721 METADATA
    //////////////////////////////////////////////////////////////*/

    // Outputs ERC721 name
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    // Outputs ERC721 symbol
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /*//////////////////////////////////////////////////////////////
                TOKEN URI
    //////////////////////////////////////////////////////////////*/

    // Token URI is currently just the tokenId
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireMinted(tokenId);

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overridden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /*//////////////////////////////////////////////////////////////
                GENERAL INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/

    // Returns name owner even if zero address
    function _ownerOf(uint256 tokenId) internal view virtual returns (address) {
        return _owners[tokenId];
    }

    // Checks if token exists (only does if minted, no longer after burn)
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    /**
     * @dev Reverts if the `tokenId` has not been minted yet.
     */
    function _requireMinted(uint256 tokenId) internal view virtual {
        require(_exists(tokenId), "NOT_MINTED");
    }

    /*//////////////////////////////////////////////////////////////
                APPROVAL INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits an {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits an {ApprovalForAll} event.
     */
    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        require(owner != operator, "NOT_OPERATOR");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    // Checks if sender is approved via all means to manage the token
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        address owner = ERC721.ownerOf(tokenId);
        return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender);
    }

    /*//////////////////////////////////////////////////////////////
                PUBLIC ERC721 FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // Displays owner's balance of tokens
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ZERO_ADDRESS");
        return _balances[owner];
    }

    // Displays owner of any token
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _ownerOf(tokenId);
        require(owner != address(0), "NOT_MINTED");
        return owner;
    }

    // Sets single address approval for a specific token
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ERC721.ownerOf(tokenId);
        require(to != owner, "SELF_APPROVE");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "NOT_APPROVED"
        );

        _approve(to, tokenId);
    }

    // Sets operator for all of msg.sender's tokens
    function setApprovalForAll(address operator, bool approved) public virtual override {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    // Retrieve current address approval for a specific token
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        _requireMinted(tokenId);

        return _tokenApprovals[tokenId];
    }

    // Check if address is an operator for owner's tokens
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    // Process requests without msg.data through one function
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    // Process transfers with safe recipient logic
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "NOT_APPROVED");
        _safeTransfer(from, to, tokenId, data);
    }

    // Transfer token without regard for ERC721 compatibility
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "NOT_APPROVED");

        _transfer(from, to, tokenId);
    }

    /*//////////////////////////////////////////////////////////////
                SAFE INTERNAL TRANSFER/MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("INVALID_RECIPIENT");
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, data), "UNSAFE_TRANSFER");
    }

    // Process requests without msg.data through one function
    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    /**
     * @dev Safely mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal virtual {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, data),
            "UNSAFE_TRANSFER"
        );
    }

    /*//////////////////////////////////////////////////////////////
                INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 tokenId) internal virtual {
        // Require token not have valid, non-expired ownership
        // Can't check for generic ownership as tokens expire but don't wipe data when they do
        require(nameRegistry[tokenId].expiry < block.timestamp, "NOT_AVAILABLE");
        // Prevent mints to zero address
        require(to != address(0x0), "ZERO_ADDRESS");

        address from = _ownerOf(tokenId);

        _beforeTokenTransfer(from, to, tokenId, 1);

        unchecked {
            // Will not overflow unless all 2**256 token ids are minted to the same owner.
            // Given that tokens are minted one by one, it is impossible in practice that
            // this ever happens. Might change if we allow batch minting.
            // The ERC fails to describe this case.
            _balances[to] += 1;
        }

        // If expired name, reduce prior owner's name balance count
        if (from != address(0x0)) {
            unchecked {
                _balances[from] -= 1;
            }
        }

        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

        _afterTokenTransfer(from, to, tokenId, 1);
    }

    // Burn data that normally wouldn't get wiped in transfers
    function _burnData(uint256 tokenId) internal virtual {
        nameRegistry[tokenId].name = "";
        nameRegistry[tokenId].expiry = 0;
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     * This is an internal function that does not check if the sender is authorized to operate on the token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        address owner = ERC721.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId, 1);

        // Update ownership in case tokenId was transferred by `_beforeTokenTransfer` hook
        owner = ERC721.ownerOf(tokenId);

        // Clear approvals
        delete _tokenApprovals[tokenId];

        unchecked {
            // Cannot overflow, as that would require more tokens to be burned/transferred
            // out than the owner initially received through minting and transferring in.
            _balances[owner] -= 1;
        }
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);

        // Burn data that normally wouldn't get wiped in transfers
        _burnData(tokenId);
        
        _afterTokenTransfer(owner, address(0), tokenId, 1);
    }

    /*//////////////////////////////////////////////////////////////
                INTERNAL TRANSFER LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        require(ERC721.ownerOf(tokenId) == from, "INCORRECT_OWNER");
        require(to != address(0), "ZERO_ADDRESS");

        _beforeTokenTransfer(from, to, tokenId, 1);

        // Check that tokenId was not transferred by `_beforeTokenTransfer` hook
        require(ERC721.ownerOf(tokenId) == from, "INCORRECT_OWNER");

        // Clear approvals from the previous owner
        delete _tokenApprovals[tokenId];

        unchecked {
            // `_balances[from]` cannot overflow for the same reason as described in `_burn`:
            // `from`'s balance is the number of token held, which is at least one before the current
            // transfer.
            // `_balances[to]` could overflow in the conditions described in `_mint`. That would require
            // all 2**256 token ids to be minted, which in practice is impossible.
            _balances[from] -= 1;
            _balances[to] += 1;
        }
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

        _afterTokenTransfer(from, to, tokenId, 1);
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting and burning.
     * All registrar-specific security parameters are enforced here
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s tokens will be transferred to `to`.
     * - When `from` is zero, the tokens will be minted for `to`.
     * - When `to` is zero, ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     * - `batchSize` is non-zero.
     *
     * Imposed conditions / actions:
     *
     * - Token must not be actively delegated
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal virtual {
        require(nameRegistry[tokenId].delegationExpiry < block.timestamp, "TOKEN_DELEGATED");
    }

    /**
     * @dev Hook that is called after any token transfer. This includes minting and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s tokens were transferred to `to`.
     * - When `from` is zero, the tokens were minted for `to`.
     * - When `to` is zero, ``from``'s tokens were burned.
     * - `from` and `to` are never both zero.
     * - `batchSize` is non-zero.
     *
     * Imposed conditions / actions:
     *
     * - Wipe token approval, delegate, delegation expiry, and primary name assignment
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal virtual {
        delete _tokenApprovals[tokenId];
        nameRegistry[tokenId].delegate = address(0x0); // Clear delegate address
        nameRegistry[tokenId].delegationExpiry = 0; // Clear delegation expiry
        primaryName[currentPrimary[tokenId]] = 0; // Wipe primary address' primary name
        currentPrimary[tokenId] = address(0x0); // Reset inverse lookup
    }
}
