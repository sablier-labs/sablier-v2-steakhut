# Sablier V2 🤝 SteakHut

This repository contains a Forge script developed by the Sablier Labs team for SteakHut. The script batch creates
multiple Sablier streams, which will power SteakHut's
[$STEAK](https://snowtrace.io/token/0xb279f8DD152B99Ec1D84A489D32c35bC0C7F5674) token vesting campaign.

## Usage

Run the script like this, making sure to replace `ETH_FROM` with your wallet address:

```sh
# your address here
ETH_FROM=0x0000000000000000000000000000000000000000 \
forge script script/SteakHut.s.sol \
--broadcast \
--ledger \
--mnemonic-derivation-paths  "m/44'/60'/0'/0" \
--rpc-url avalanche \
--sig "run()" \
--verify \
--with-gas-price $(cast to-wei 25 gwei) \
-vvvv
```

## Notes

- Run `foundryup` to make sure you are running the latest version of Foundry
- The command above assumes that you are using a Ledger wallet connected to a computer via USB. If you wish to use a
  mnemonic instead, you can set it as a `$MNEMONIC` environment variable in a `.env` file. Check out the
  [`Base`](https://github.com/sablier-labs/v2-core/blob/d1157b49ed4bceeff0c4e437c9f723e88c134d3a/test/Base.t.sol)
  script.

## References

- [Sablier Docs](https://docs.sablier.com)

## Caveat Emptor

This is experimental software and is provided on an "as is" and "as available" basis. Sablier Labs does not give any
warranties and will not be liable for any loss, direct or indirect through continued use of this codebase.

## License

This repo is licensed under GPL 3.0 or later.
