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



