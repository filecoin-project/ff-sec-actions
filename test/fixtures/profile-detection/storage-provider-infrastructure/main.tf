resource "docker_container" "boostd" {
  name  = "boostd"
  image = "filecoin/boost:2.4.0"

  env = [
    "FULLNODE_API_INFO=${var.fullnode_api_info}",
    "MINER_API_INFO=${var.miner_api_info}"
  ]
}
