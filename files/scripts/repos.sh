#!/usr/bin/env bash
dnf config-manager --set-enabled crb
dnf install -y epel-release
curl --retry 3 -Lo "/etc/yum.repos.d/compose.repo" "https://gitlab.com/redhat/centos-stream/containers/bootc/-/raw/c${MAJOR_VERSION_NUMBER}s/cs.repo"
sed -i \
	-e "s@- (BaseOS|AppStream)@& - Compose@" \
	-e "s@\(baseos\|appstream\)@&-compose@" \
	/etc/yum.repos.d/compose.repo
cat /etc/yum.repos.d/compose.repo
