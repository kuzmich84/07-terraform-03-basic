terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "0.61.0"
    }
  }
  backend "s3" {
    endpoint   = "storage.yandexcloud.net"
    bucket     = "kuchukov-terraform"
    region     = "ru-central1"
    key        = "terraform/my-terraform.tfstate"
    access_key = ""
    secret_key = ""

    skip_region_validation      = true
    skip_credentials_validation = true
  }
  required_version = ">= 0.13"
}


provider "yandex" {
  service_account_key_file = "key.json"
  cloud_id                 = var.yandex_cloud_id
  folder_id                = var.yandex_folder_id
  zone                     = var.yandex_zone
}

module "vpc" {
  source        = "hamnsk/vpc/yandex"
  version       = "0.5.0"
  description   = "managed by terraform"
  create_folder = length(var.yandex_folder_id) > 0 ? false : true
  yc_folder_id  = var.yandex_folder_id
  name          = terraform.workspace
  subnets       = local.vpc_subnets[terraform.workspace]
}


module "count" {
  source         = "../modules/instance"
  instance_count = local.news_instance_count[terraform.workspace]

  subnet_id     = module.vpc.subnet_ids[0]
  zone          = var.yandex_zone
  folder_id     = module.vpc.folder_id
  image         = "centos-7"
  platform_id   = "standard-v2"
  name          = "count"
  description   = "News App Demo"
  instance_role = "news,balancer"
  users         = "centos"
  cores         = local.news_cores[terraform.workspace]
  boot_disk     = "network-ssd"
  disk_size     = local.news_disk_size[terraform.workspace]
  nat           = "true"
  memory        = "2"
  core_fraction = "100"
  depends_on    = [
    module.vpc
  ]
}

module "for_each" {
  source         = "../modules/instance2"
  for_each = local.foreach_instance[terraform.workspace]

  subnet_id     = module.vpc.subnet_ids[0]
  zone          = var.yandex_zone
  folder_id     = module.vpc.folder_id
  image         = "centos-7"
  platform_id   = "standard-v2"
  name          = "${each.value}"
  description   = "News App Demo"
  instance_role = "news,balancer"
  users         = "centos"
  cores         = local.news_cores[terraform.workspace]
  boot_disk     = "network-ssd"
  disk_size     = local.news_disk_size[terraform.workspace]
  nat           = "true"
  memory        = "2"
  core_fraction = "100"
  depends_on    = [
    module.vpc
  ]
}



locals {
  news_cores = {
    stage = 2
    prod  = 2
  }
  news_disk_size = {
    stage = 20
    prod  = 40
  }
  news_instance_count = {
    stage = 1
    prod  = 2
  }
  foreach_instance = {
    stage = toset(["foreach1"])
    prod  = toset(["foreach1","foreach2"])
  }

  vpc_subnets = {
    stage = [
      {
        "v4_cidr_blocks" : [
          "10.128.0.0/24"
        ],
        "zone" : var.yandex_zone
      }
    ]
    prod = [
      {
        zone           = "ru-central1-a"
        v4_cidr_blocks = ["10.128.0.0/24"]
      },
      {
        zone           = "ru-central1-b"
        v4_cidr_blocks = ["10.129.0.0/24"]
      },
      {
        zone           = "ru-central1-c"
        v4_cidr_blocks = ["10.130.0.0/24"]
      }
    ]
  }
}



