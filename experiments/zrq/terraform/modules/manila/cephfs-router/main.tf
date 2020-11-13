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
    version = "1.29"
    cloud = var.zrq_cloud_name
    }

resource "openstack_networking_router_v2" "zrq_ceph_router" {
    name                = lower("${var.zrq_cluster_name}-cluster-ceph-router")
    admin_state_up      = true
    external_network_id = data.openstack_networking_network_v2.zrq_internal_network.id
    }

resource "openstack_networking_port_v2" "zrq_ceph_router_port" {
    network_id = data.openstack_networking_network_v2.zrq_magnum_network.id
    }

resource "openstack_networking_router_interface_v2" "zrq_ceph_router_interface" {
    router_id = openstack_networking_router_v2.zrq_ceph_router.id
    port_id   = openstack_networking_port_v2.zrq_ceph_router_port.id
    }

resource "openstack_networking_router_route_v2" "zrq_ceph_router_route" {
    depends_on       = [openstack_networking_router_interface_v2.zrq_ceph_router_interface]
    router_id        = data.openstack_networking_router_v2.zrq_magnum_router.id
    destination_cidr = "10.206.0.0/16"
    next_hop         = openstack_networking_port_v2.zrq_ceph_router_port.all_fixed_ips[0]
    }




