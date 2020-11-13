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
 *
 */

terraform {
    required_version = ">= 0.12, < 0.13"
    }

module "sshkeys" {
    source = "./modules/sshkeys"
    }

module "cluster" {
    source = "./modules/cluster"

    zrq_cloud_name   = var.zrq_cloud_name
    zrq_cluster_name = var.zrq_cluster_name

    zrq_keypair_name  = "${var.zrq_cluster_name}-keypair"
    zrq_keypair_value = module.sshkeys.zrq_keypair_value

    zrq_master_count = var.zrq_master_count
    zrq_worker_count = var.zrq_worker_count
    zrq_max_worker_count = var.zrq_max_worker_count

    zrq_master_flavor_name = var.zrq_master_flavor_name
    zrq_worker_flavor_name = var.zrq_worker_flavor_name

    zrq_cluster_template_name = var.zrq_cluster_template_name

    }

