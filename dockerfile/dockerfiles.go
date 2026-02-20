package dockerfile

import _ "embed"

//go:embed cosmos/Dockerfile
var Cosmos []byte

//go:embed avalanche/Dockerfile
var Avalanche []byte

//go:embed avalanche/native.Dockerfile
var AvalancheNative []byte

//go:embed cosmos/native.Dockerfile
var CosmosNative []byte

//go:embed cosmos/local.Dockerfile
var CosmosLocal []byte

//go:embed cosmos/localcross.Dockerfile
var CosmosLocalCross []byte

//go:embed geth/Dockerfile
var Geth []byte

//go:embed geth/native.Dockerfile
var GethNative []byte

//go:embed geth/local.Dockerfile
var GethLocal []byte

//go:embed geth/localcross.Dockerfile
var GethLocalCross []byte

//go:embed imported/Dockerfile
var Imported []byte

//go:embed none/Dockerfile
var None []byte

//go:embed cargo/Dockerfile
var Cargo []byte

//go:embed cargo/native.Dockerfile
var CargoNative []byte

//go:embed go-build/Dockerfile
var GoBuild []byte

//go:embed go-build/native.Dockerfile
var GoBuildNative []byte
