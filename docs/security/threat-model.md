# Threat Model

## Threat actors

- network attacker
- Internet attacker
- stolen device
- compromised device
- compromised administrator
- compromised Backoffice
- database compromise
- storage compromise
- dependency/supply-chain compromise
- malicious insider

## Protected assets

- message plaintext
- private keys
- group secrets
- attachment keys
- sessions
- admin credentials
- location data
- security events
- audit records

## Goals

- confidentiality
- integrity
- authentication
- authorization
- device revocation
- replay protection
- minimal metadata
- administrative accountability
- recoverability

## Residual risks

No software system is absolutely secure.

A compromised endpoint may expose plaintext after decryption. Recipients can copy information outside the application.
