### Disclaimer

Having minimal prior experience to auditing, the findings presented here should not be considered comphrehensive. The audit was completed December 02, 2022, and the code base was reviewed based on the November 29, 2022 version. Commit hash (4615ce4ce340c1bc8d0475f8a4103011179dd34e).

Failure to find any issues does not mean that the code is bug-free. The audit is not a guarantee of security, and the audit report is not a substitute for a thorough security review by a professional security auditor. The auditor, saucepoint, is not responsible or responsible for any loss or damage caused by the use of this report.

# Scope:

The primary purpose of the audit is a peer review of the code. The primary focus will be:

1) identifying design flaws

2) identifying common, yet critical, vulnerabilities in smart contracts

2) identifying potential footguns

### Files in Scope

[Allowlist.sol](src/Allowlist.sol)

[CantoNameService.sol](src/CantoNameService.sol)

[ERC721.sol](src/ERC721.sol)

[LinearVRGDA.sol](src/LinearVRGDA.sol)


---

# `Allowlist.sol`

## Design Flaws
1) If `Allowlist's` purpose is to remove programmtic bots from interacting with the contracts, then I'm unsure if it solves the problem. If this is not the case, ignore this finding.
  - The contract is forcing an externally owned account (EOA) to sign a message and then submit it to the contract for verification. This process can be programmtically done by a bot. More so, the CAPTCHA/signature mechanism will actually slow down humans from interacting with the contract via their clients (web browser + wallet).
  - Bot preventation should be done with an admin signature. User solves captcha in the browser, user recieves an admin signature to provide to their contract calls. Contract then verifies that the admin signature is valid and not forged. The trade off is that the admin signatures remove trustlessness / permissionlessness from the contract

```solidity
    // ********************** FIX THIS TO SUPPORT LEAP YEARS **************************
    reservationExpiry[msg.sender] = block.timestamp + 365 days;
```
Unnecessary to account for leap years. Would add complexity to the contract. Instead reservations should be set to expire a fixed 365 days. On the client, you should show the exact timestamp of when the reservation expires. In the event of a leap year, the expiration would occur 1 day earlier than expected. This is a minor inconvenience to the user, but would save a lot of gas and complexity in the contract.

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

## Footguns

```solidity
    constructor(uint256 _cutoff) {
        transferOwnership(msg.sender);
        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();
        cutoff = block.timestamp + _cutoff;
    }
```
The `constructor` should be documented such that it is clear the argument is an offset of the current timestamp. The variable name `_cutoff` implies a more absolute time.

```solidity
    // If another name has been reserved, clear the old name's reserver before processing new name
    if (nameReservation[msg.sender] != 0) {
        nameReserver[nameReservation[msg.sender]] = address(0);
    }
```
Would consider adding an event here, so that the frontend (and other custom tooling) is aware of recently-available names

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
