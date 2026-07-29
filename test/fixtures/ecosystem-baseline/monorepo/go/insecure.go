package fixture

import "crypto/tls"

func insecure() *tls.Config {
	// ruleid: filecoin.go.insecure-tls-verification
	return &tls.Config{InsecureSkipVerify: true}
}
