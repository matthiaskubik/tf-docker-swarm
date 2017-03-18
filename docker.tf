provider "ibmcloud" {
  ibmid              = "bpsprod@de.ibm.com"
  ibmid_password     = "STw4d0Mk9Xv5"
  softlayer_account_number ="1204953"

}

data "ibmcloud_infra_ssh_key" "mykey" {
    label = "${var.ssh_key_label}"
}

resource "ibmcloud_infra_virtual_guest" "manager" {
    hostname          = "docker-swarm-manager"
    domain            = "demo.com"
    os_reference_code = "UBUNTU_LATEST"
    datacenter        = "${var.datacenter}"
    cores             = 1
    memory            = 1024
    local_disk        = true

    ssh_key_ids = [
        "${data.ibmcloud_infra_ssh_key.mykey.id}"
    ]

    provisioner "remote-exec" {
        script = "docker.sh"
    }

    provisioner "local-exec" {
        command = "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${self.ipv4_address} 'docker swarm join-token -q worker' > token.txt"
    }
}

resource "ibmcloud_infra_virtual_guest" "worker" {
    count             = "${var.worker_count}"
    hostname          = "docker-swarm-worker${count.index}"
    domain            = "demo.com"
    os_reference_code = "UBUNTU_LATEST"
    datacenter        = "${var.datacenter}"
    cores             = 1
    memory            = 1024
    local_disk        = true

    ssh_key_ids = [
        "${data.ibmcloud_infra_ssh_key.mykey.id}"
    ]

    provisioner "remote-exec" {
        inline = [
            "apt-get update -y > /dev/null",
            "apt-get install docker.io curl -y",
            "curl -L http://bit.ly/2kuCjmp | bash -s",
            "ufw allow 2377/tcp",
            "ufw allow 4789/tcp",
            "ufw allow 7946/tcp",
            "docker swarm join --token ${trimspace(file("token.txt"))} ${ibmcloud_infra_virtual_guest.manager.ipv4_address}:2377"
        ]
    }
}
