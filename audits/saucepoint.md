### *Disclaimer*

Having minimal prior experience to auditing, the findings presented here should not be considered comphrehensive. The audit was completed December 02, 2022, and the code base was reviewed based on the November 29, 2022 version. Commit hash (4615ce4ce340c1bc8d0475f8a4103011179dd34e).

Failure to find any issues does not mean that the code is bug-free. The audit is not a guarantee of security, and the audit report is not a substitute for a thorough security review by a professional security auditor. The auditor, *saucepoint*, is not responsible or liable for any loss or damage caused by the use of this report.

# Scope:

The purpose of the audit is a peer review of the code. The primary focus will be:

1) identifying design flaws

2) identifying common, yet critical, vulnerabilities in smart contracts

2) identifying potential footguns

### Files in Scope

[Allowlist.sol](../src/Allowlist.sol)

[CantoNameService.sol](../src/CantoNameService.sol)

[ERC721.sol](../src/ERC721.sol)

[LinearVRGDA.sol](../src/LinearVRGDA.sol)


---

# `Allowlist.sol`

## Design Flaws
1) If `Allowlist's` purpose is to remove programmtic bots from interacting with the contracts, then I'm unsure if it solves the problem. If this is not the case, ignore this finding.
    - The contract is forcing an externally owned account (EOA) to sign a message and then submit it to the contract for verification. This process can be programmtically done by a bot. More so, the CAPTCHA/signature mechanism will actually slow down humans from interacting with the contract via their clients (web browser + wallet).
    - Bot preventation should be done with an admin signature. User solves captcha in the browser, user recieves an admin signature to provide to their contract calls. Contract then verifies that the admin signature is valid and not forged. The trade off is that the admin signatures remove trustlessness / permissionlessness from the contract

&nbsp;

```solidity
    // ********************** FIX THIS TO SUPPORT LEAP YEARS **************************
    reservationExpiry[msg.sender] = block.timestamp + 365 days;
```
2) Unnecessary to account for leap years. Would add complexity to the contract. Instead reservations should be set to expire a fixed 365 days. On the client, you should show the exact timestamp of when the reservation expires. In the event of a leap year, the expiration would occur 1 day earlier than expected. This is a minor inconvenience to the user, but would save a lot of gas and complexity in the contract.

&nbsp;

```solidity
    // If another name has been reserved, clear the old name's reserver before processing new name
    if (nameReservation[msg.sender] != 0) {
        nameReserver[nameReservation[msg.sender]] = address(0);
    }
```
3) Would consider adding an event here, so that the frontend (and other custom tooling) is aware of recently-available names

## Bugs

```solidity
    function computeDomainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("CAPTCHA"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
    }

    function _verify(uint8 _v, bytes32 _r, bytes32 _s) internal {
        address recoveredAddress = ecrecover(
            keccak256(abi.encodePacked("\x19\x01",
                DOMAIN_SEPARATOR(),
                keccak256(abi.encode(keccak256("CAPTCHA()"))))),
            _v,
            _r,
            _s
        );
    ...
```
1) Is the `computeDomainSeparator()'s "CAPTCHA"` supposed to be mismatched against `_verify()'s "CAPTCHA()"`?
    * You should test the signatures using `vm.sign()`[https://book.getfoundry.sh/cheatcodes/sign] (or [tutorial](https://book.getfoundry.sh/tutorials/testing-eip712))

## Footguns

```solidity
    constructor(uint256 _cutoff) {
        transferOwnership(msg.sender);
        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();
        cutoff = block.timestamp + _cutoff;
    }
```
The `constructor` should be documented so that it is clear the argument is an *offset of the current timestamp*. The variable name `_cutoff` incorrectly implies a more absolute time.


## Gas findings
1) Should probably move `uint256 cutoff` to the top of state-declarations. Followed by `mappings`. Would put events at the bottom of state-declarations. Packing the state variables into 32-byte slots will save on deployment gas (and storage-access gas, I think).

```
reservationExpiry[msg.sender] = block.timestamp + 365 days;
```
2) This can be `unchecked` since it will not overflow

```
emit Reserve(msg.sender, _tokenId, reservationExpiry[msg.sender]);
```
3) I would see if using a local variable `uint256 expiry = block.timestamp + 365 days;` would save gas instead of doing a storage read.

# `ERC721.sol`

## Design Flaws
1) My biggest gripe with the contract is it is seemingly a copy+paste of OZ's contracts with some slight modifications. For me, I found myself skimming over some parts since it seemed like standard ERC721 code. My suggestion here would be to inherit from OZ or solmate, and then override the functions that you need to modify. This would make the contract easier to understand & audit. Example of adding pre/post mint calls:

```solidity

import {ERC721} from "solmate/tokens/ERC721.sol";

contract CNSToken is ERC721 {
    constructor() ERC721("Canto Name", "CNS") {}

    function _mint(address to, uint256 tokenId) internal override {
        // pre mint logic
        _beforeTokenTransfer(tokenId);
        
        // mint logic handled by OZ (or solmate)
        super._mint(to, tokenId);
        
        // post mint logic
        _afterTokenTransfer(tokenId);
    }

    function _burn(uint256 tokenId) internal override {
        // pre burn logic
        _beforeTokenTransfer(tokenId);
        
        // burn logic handled by OZ (or solmate)
        super._burn(tokenId);
        
        // post burn logic
        _burnData(tokenId);
    }
}
```

## Bugs

## Footguns
```
    function _beforeTokenTransfer(uint256 tokenId) internal view {
        require(nameRegistry[tokenId].delegationExpiry < block.timestamp, "ERC721::_beforeTokenTransfer::TOKEN_DELEGATED");
    }
```
1) This requirement is a bit strange to me. If I delegate the name (token) to an address, I'm not seeing the business case for blocking 
actions such as burning or transferring. Could be wrong here, and maybe it adds a level of protection for the owner (it acts as a reminder that its being delegated at the moment)

## Gas findings

```solidity
    // Name data / URI(?) struct
    struct Name {
        string name;
        uint256 expiry;
        address delegate;
        uint256 delegationExpiry;
    }
```
1) You should pack this better. Might be worth entertaining a fixed name length. You could limit names to a max of 64 characters by using `bytes32[2]`, but probably adds some complexity on the client side. Example of better (but not perfect) packing:
```
    struct Name {
        uint256 expiry;
        uint256 delegationExpiry;
        address delegate;
        string name;
    }
```
(Also you can try considering uint40 for expirations, see [example](https://twitter.com/PaulRBerg/status/1591832937179250693))

&nbsp;

# `CantoNameService.sol`

## Design Flaws

## Bugs

1) Should burn logic update the VRGDA pricing? (i.e. decrementing `tokenCounts[_length].current--;`)



## Footguns

1) IIRC, `testFail*` in `CantoNameService.t.sol` can have mis-leading passes. You should actually use `vm.expectRevert("<revert string>")` in your tests to guarantee that tests are reverting on a specific condition.

2) I think you should move some of your `require` statements to `modifier` instead should improve readability & consistency. For example, defining & using a modifier like:

```
modifier approvedOrOwner(address caller, uint256 tokenId) {
    // Require owner/approved/operator
    require(_isApprovedOrOwner(caller, tokenId), "CantoNameService::delegateNameWithPrecision::NOT_APPROVED");

    _;
}
```

3) Both delegation (and extensions) occur via 2 patterns: term or precision. I can delegate my name for 2 terms or some precise timestamp. I'm willing to argue that delegate-by-term is unnecessary functionality because (1) delegating with a granualrity of years will probably won't be very popular and (2) delegating-by-year can be handled by delegate-by-precision, the client (web app) will handle the math. Therefore, supporting delegate-by-term adds complexity (& deployment costs) when its functionality can be captured by delegate-by-precision. 

## Gas findings

```solidity
    // Return string length, properly counts all Unicode characters
    function stringLength(string memory _string) public pure returns (uint256) {
        uint256 charCount; // Number of characters in _string regardless of char byte length

        // SAUCEPOINT: by default variables are init'd to 0.
        // explicitly setting to zero takes more gas IIRC
        uint256 charByteCount; // Number of bytes in char (a = 1, € = 3)
        uint256 byteLength = bytes(_string).length; // Total length of string in raw bytes

        // Determine how many bytes each character in string has
        // SAUCEPOINT: no need to set charCount = 0 again, its already set
        for (charCount; charByteCount < byteLength;) {
            bytes1 b = bytes(_string)[charByteCount]; // if tree uses first byte to determine length

            // SAUCEPOINT: character counter shouldnt overflow
            unchecked {
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

                // SAUCEPOINT: characters wont overflow, so can be in unchecked
                ++charCount;
            }
        }
        return charCount;
    }
```
Optimized the for-loop a bit. See [meme](https://twitter.com/saucepoint/status/1544525857733091329?s=20&t=Sci7OxZGkG2767t_d0YLcA)

**See other for-loops (i.e. some of the vrgda() functions). You can probably add `unchecked { ++i; }` to those loops**

&nbsp;

In general, one gas optimization trick is to find all `++` incrementers, and reasonably determine if they can overflow past `2**256-1` (max-uint). See `_incrementCounts(uint256 _length)` -- you can probably add `unchecked { }` blocks to your increments!

```solidity
    // Return address' primary name
    function getPrimary(address _target) public view returns (string memory) {
        uint256 tokenId = primaryName[_target];
        return nameRegistry[tokenId].name;
    }
```
`public` functions not used by the contract itself, should be `external`. Would check for other functions besides this one.


```solidity
    uint256 newDelegationExpiry = 
        block.timestamp + 
        (nameRegistry[_tokenId].delegationExpiry - block.timestamp) + 
        (_term * 365 days);
```
There's unnecessary math here which increases gas utilization. The current math (above) is doing: `A + B - A + C` (`A - A` cancels out anyway). You just need to add `term * 365` to the existing expiration.

&nbsp;

# `LinearVRGDA.sol`

## Design Flaws

I believe you're aware of this, but `vrgdaTest()` will be removed and you'll need a way for populating `LinearVRGDA.initData` (state variable). This can maybe be done with function arguments, but might be error prone. You could also consider hard-coding the VRGDA parameters in the constructor. In the case of setting the values on-deploy, you won't need the `initData` state.

## Footguns

The VRGDA implementation looks *okay* at first glance, but I think it would be best if you had explicit tests. You can reference the original VRGDA for values to use and assert. IIRC the original VRGDA implementation represents days as `wad` (`10 days = 10e18`), and the `int256` can be tricky at times. Testing that your fork works as intended will be important for familiarizing yourself on how VRGDAs are initially configured.