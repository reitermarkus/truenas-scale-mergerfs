#!/usr/bin/env bash

set -euo pipefail

mergerfs_version="${MERGERFS_VERSION-2.40.2}"

apt-get update

if ! mergerfs --version 2>/dev/null | grep --quiet "${mergerfs_version}"; then
  deb="$(mktemp)"
  curl -fsSL "https://github.com/trapexit/mergerfs/releases/download/${mergerfs_version}/mergerfs_${mergerfs_version}.debian-bullseye_amd64.deb" -o "${deb}"
  dpkg -i "${deb}"
  rm "${deb}"
fi

apt-get install --no-install-recommends --yes python3-xattr xattr

install_mergerfs_tool() {
  local tool_name="${1}"

  if ! "${tool_name}" --help &>/dev/null; then
    curl -fsSL "https://github.com/trapexit/mergerfs-tools/raw/HEAD/src/${tool_name}" -o "/usr/bin/${tool_name}"
    chmod +x "/usr/bin/${tool_name}"
  fi
}

install_mergerfs_tool mergerfs.balance
install_mergerfs_tool mergerfs.consolidate
install_mergerfs_tool mergerfs.ctl
install_mergerfs_tool mergerfs.dedup
install_mergerfs_tool mergerfs.dup
install_mergerfs_tool mergerfs.fsck
install_mergerfs_tool mergerfs.mktrash

if [[ -z "${MOUNTPOINT}" ]] || [[ -z "${SUB_MOUNTPOINTS}" ]]; then
  exit
fi

mountpoint="${MOUNTPOINT}"
sub_mountpoints="${SUB_MOUNTPOINTS}"

mount_unit="$(systemd-escape -p --suffix=mount "${mountpoint}")"
service_unit="$(systemd-escape -p --suffix=service "${mountpoint}")"
fs_name="$(basename "${mountpoint}")"

tee "/etc/systemd/system/${mount_unit}" << EOF
[Unit]
Description="MergerFS '${fs_name}' file system."
After=zfs-mount.service
Requires=zfs-mount.service
Before=local-fs.target

[Mount]
What=${sub_mountpoints}
Where=${mountpoint}
Type=fuse.mergerfs
Options=allow_other,use_ino,cache.files=partial,dropcacheonclose=true,category.create=rand,func.open=rand,ignorepponrename=true,minfreespace=64G,moveonenospc=mfs,fsname=${fs_name}

[Install]
WantedBy=multi-user.target
EOF

systemctl enable --now "${mount_unit}"

if [[ -z "${NFS_USER}" ]]; then
  exit
fi

user="${NFS_USER}"

nfs_export_script="/etc/nfs-export-${fs_name}.sh"
tee "${nfs_export_script}" << EOF
#!/usr/bin/env bash

set -euo pipefail

if mountpoint -q '${mountpoint}' && ! grep --quiet '${mountpoint}' /etc/exports; then
  {
    echo '"${mountpoint}"\'
    echo '    *(sec=sys,rw,anonuid=$(id -u "${user}"),anongid=$(id -g "${user}"),all_squash,no_subtree_check,fsid=2)'
  } >> /etc/exports

  /usr/sbin/exportfs -r
fi
EOF
chmod +x "${nfs_export_script}"

mkdir -p '/etc/systemd/system/nfs-server.service.d'
tee '/etc/systemd/system/nfs-server.service.d/override.conf' << EOF
[Service]
ExecStartPre='${nfs_export_script}'
ExecReload='${nfs_export_script}'
EOF

systemctl daemon-reload
systemctl reload nfs-server
