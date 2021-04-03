
locals {
  tmp_dir     = "${path.cwd}/.tmp"
  role        = "Manager"
  bind        = var.cluster_name != ""
  cluster_type_file = "${local.tmp_dir}/cluster_type.out"
  cluster_type      = data.local_file.cluster_type.content
}

resource null_resource print_names {
  provisioner "local-exec" {
    command = "echo 'Sysdig instance: ${var.guid}'"
  }
}

resource "null_resource" "setup-ob-plugin" {
  provisioner "local-exec" {
    command = "${path.module}/scripts/setup-ob-plugin.sh"
  }
}

resource "null_resource" "sysdig_bind" {
  count = local.bind ? 1 : 0
  depends_on = [null_resource.setup-ob-plugin]

  triggers = {
    cluster_id  = var.cluster_id
    instance_id = var.guid
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/bind-instance.sh ${self.triggers.cluster_id} ${self.triggers.instance_id} ${var.access_key} ${var.private_endpoint}"

    environment = {
      SYNC = var.sync
    }
  }

  provisioner "local-exec" {
    when    = destroy
    command = "${path.module}/scripts/unbind-instance.sh ${self.triggers.cluster_id} ${self.triggers.instance_id}"
  }
}

resource null_resource create_tmp_dir {
  provisioner "local-exec" {
    command = "mkdir -p ${local.tmp_dir}"
  }
}

resource null_resource cluster_type {
  depends_on = [null_resource.create_tmp_dir]

  provisioner "local-exec" {
    command = "kubectl api-resources -o name | grep consolelink && echo -n 'ocp4' > ${local.cluster_type_file}"

    environment = {
      KUBECONFIG = var.cluster_config_file_path
    }
  }
}

data local_file cluster_type {
  depends_on = [null_resource.cluster_type]

  filename = local.cluster_type_file
}

resource "null_resource" "delete-consolelink" {
  count = local.bind ? 1 : 0

  provisioner "local-exec" {
    command = "kubectl api-resources -o name | grep consolelink && kubectl delete consolelink -l grouping=garage-cloud-native-toolkit -l app=sysdig || exit 0"

    environment = {
      KUBECONFIG = var.cluster_config_file_path
    }
  }
}

resource "helm_release" "sysdig" {
  count      = local.bind ? 1 : 0
  depends_on = [null_resource.sysdig_bind, null_resource.delete-consolelink]

  name              = "sysdig"
  chart             = "tool-config"
  namespace         = var.tools_namespace
  repository        = "https://ibm-garage-cloud.github.io/toolkit-charts/"
  timeout           = 1200
  force_update      = true
  replace           = true

  disable_openapi_validation = true

  set {
    name  = "displayName"
    value = "Sysdig"
  }

  set {
    name  = "url"
    value = "https://cloud.ibm.com/observe/monitoring"
  }

  set {
    name  = "applicationMenu"
    value = true
  }

  set {
    name  = "global.clusterType"
    value = local.cluster_type
  }
}