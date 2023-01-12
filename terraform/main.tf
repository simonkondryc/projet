resource "ovh_cloud_project_network_private" "private_network" {
  service_name = var.service_name 
  name         = "private_network_${var.instance_name}"
  regions      = var.region           
  provider     = ovh.ovh
  vlan_id      = var.vlan_id
}
 
resource "ovh_cloud_project_network_private_subnet" "subnetwork_gra" {
  network_id   = ovh_cloud_project_network_private.private_network.id
  service_name = var.service_name
  region       = element(var.region,0) 
  network      = var.vlan_dhcp_network
  start        = var.vlan_dhcp_start
  end          = var.vlan_dhcp_finish
  provider     = ovh.ovh
  no_gateway   = true
}

resource "ovh_cloud_project_network_private_subnet" "subnetwork_sbg" {
  network_id   = ovh_cloud_project_network_private.private_network.id
  service_name = var.service_name
  region       = element(var.region,1)
  network      = var.vlan_dhcp_network
  start        = var.vlan_dhcp_start
  end          = var.vlan_dhcp_finish
  provider     = ovh.ovh
  no_gateway   = true
}

resource "openstack_compute_keypair_v2" "test_keypair" {
  count      = length(var.region)
  provider   = openstack.ovh
  name       = "sshkey_${var.instance_name}_${count.index % 2 == 0 ? "gra" : "sbg" }"
  public_key = file("~/.ssh/id_rsa.pub")
  region     = element(var.region,count.index)
}

resource "openstack_compute_instance_v2" "front" {
  name        = "front_${var.instance_name}"
  provider    = openstack.ovh
  image_name  = var.image_name
  flavor_name = var.flavor_name
  region      = element(var.region,0)

  key_pair = openstack_compute_keypair_v2.test_keypair[0].name
  network {
    name       = "Ext-Net"
  }

  network {
    name      = ovh_cloud_project_network_private.private_network.name
    fixed_ip_v4 = "192.168.${var.vlan_id}.254"
    
  }
  depends_on = [ovh_cloud_project_network_private_subnet.subnetwork_gra]
}

resource "openstack_compute_instance_v2" "backend_gra" {
  count       = var.backend_number_of_instances
  name        = "backend_${var.instance_name}_gra_${count.index+2}"
  provider    = openstack.ovh
  image_name  = var.image_name
  flavor_name = var.flavor_name
  region      = element(var.region,0)

  key_pair = openstack_compute_keypair_v2.test_keypair[0].name
  
  network {
    name      = "Ext-Net"
  }
 
  network {
    name      = ovh_cloud_project_network_private.private_network.name
    fixed_ip_v4 = "192.168.${var.vlan_id}.${count.index+1}"
  }
  depends_on = [ovh_cloud_project_network_private_subnet.subnetwork_gra]
}


resource "openstack_compute_instance_v2" "backend_sbg" {
  count       = var.backend_number_of_instances
  name        = "backend_${var.instance_name}_sbg_${count.index+1}"                                             
  provider    = openstack.ovh 
  image_name  = var.image_name 
  flavor_name = var.flavor_name
  region      = element(var.region,1)

  key_pair = openstack_compute_keypair_v2.test_keypair[1].name

  network {
    name      = "Ext-Net"
  }
 
  network {
    name      = ovh_cloud_project_network_private.private_network.name
    fixed_ip_v4 = "192.168.${var.vlan_id}.${count.index+101}"
  } 
  depends_on = [ovh_cloud_project_network_private_subnet.subnetwork_sbg]
}

resource "ovh_cloud_project_database" "db_eductive17" {
  engine       = "mysql"
  flavor       = "db1-4"
  
  nodes {
    region = "GRA"
  }
  plan     = "essential"
  version  = "8"
}

resource "ovh_cloud_project_database_user" "eductive17" {
  service_name = ovh_cloud_project_database.db_eductive17.service_name
  engine       = ovh_cloud_project_database.db_eductive17.engine
  name         = "eductive17"
  cluster_id   = ovh_cloud_project_database.db_eductive17.id
}

output "db_username" {
  value = ovh_cloud_project_database_user.eductive17.name
}

output "db_password" {
  value     = "123?password!"
  sensitive = true
}

resource "ovh_cloud_project_database_database" "database" {
  service_name = ovh_cloud_project_database.db_eductive17.service_name
  cluster_id   = ovh_cloud_project_database.db_eductive17.id
  engine       = ovh_cloud_project_database.db_eductive17.engine
  name         = "wordpress_data"
  
}

resource "ovh_cloud_project_database_ip_restriction" "iprestriction_gra" {
  count        = var.backend_number_of_instances
  service_name = ovh_cloud_project_database.db_eductive17.service_name
  cluster_id   = ovh_cloud_project_database.db_eductive17.id
  engine       = ovh_cloud_project_database.db_eductive17.engine
  ip           = "${openstack_compute_instance_v2.backend_gra[count.index].access_ip_v4}/32"
}

resource "ovh_cloud_project_database_ip_restriction" "iprestriction_sbg" {
  count        = var.backend_number_of_instances
  service_name = ovh_cloud_project_database.db_eductive17.service_name
  cluster_id   = ovh_cloud_project_database.db_eductive17.id
  engine       = ovh_cloud_project_database.db_eductive17.engine
  ip           = "${openstack_compute_instance_v2.backend_sbg[count.index].access_ip_v4}/32"
}

resource "local_file" "inventory" {
  filename = "../ansible/inventory.yml"
  content  = templatefile("templates/inventory.tmpl",
    {
      db_name      = ovh_cloud_project_database_database.database.name
      db_hostname  = split("/",split("@",ovh_cloud_project_database.db_eductive17.endpoints[0].uri)[1])[0]
      db_username  = ovh_cloud_project_database_user.eductive17.name
      db_password  = ovh_cloud_project_database_user.eductive17.password
      front        = openstack_compute_instance_v2.front.access_ip_v4,
      backends_sbg = [for k, p in openstack_compute_instance_v2.backend_sbg: p.access_ip_v4],
      backends_gra = [for k, p in openstack_compute_instance_v2.backend_gra: p.access_ip_v4],
    }
  )
}
