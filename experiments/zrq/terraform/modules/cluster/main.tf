/*
 * <meta:header>
 *   <meta:licence>
 *     Copyright (c) 2020, ROE (http://www.roe.ac.uk/)
 *
 *     This information is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     This information is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *   </meta:licence>
 * </meta:header>
 *
 * Early experiments building my own modules.
 * Based on a set of examples from StackHPC.
 * https://github.com/RSE-Cambridge/iris-magnum/tree/master/terraform/examples
 * Added prefix to the names of objects and variables to see which are modifiable.
 *
 */

terraform {
    required_version = ">= 0.12, < 0.13"
    }

provider "openstack" {
    version = "~> 1.29"
    cloud = var.zrq_cloud_name
    }

resource "openstack_compute_keypair_v2" "zrq_keypair" {
    name       = var.zrq_keypair_name
    public_key = var.zrq_keypair_value
    }

resource "openstack_containerinfra_cluster_v1" "zrq_cluster" {
    name = var.zrq_cluster_name
    cluster_template_id = data.openstack_containerinfra_clustertemplate_v1.zrq_clustertemplate.id

    master_count = var.zrq_master_count
    node_count   = var.zrq_worker_count

    keypair       = openstack_compute_keypair_v2.zrq_keypair.id
    flavor        = var.zrq_worker_flavor_name
    master_flavor = var.zrq_master_flavor_name

    labels = merge(
        data.openstack_containerinfra_clustertemplate_v1.zrq_clustertemplate.labels,
            {
            min_node_count = var.zrq_worker_count
            max_node_count = var.zrq_max_worker_count
            }
        )
    }

resource "null_resource" "kubeconfig" {
    triggers = {
        kubeconfig = var.zrq_cluster_name
        }

    provisioner "local-exec" {
        command = "mkdir -p ~/.kube/${var.zrq_cluster_name}; openstack --os-cloud ${var.zrq_cloud_name} coe cluster config ${var.zrq_cluster_name} --dir ~/.kube/${var.zrq_cluster_name} --force;"
        }

    depends_on = [openstack_containerinfra_cluster_v1.zrq_cluster]
    }



