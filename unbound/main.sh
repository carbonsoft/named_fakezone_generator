#!/bin/bash

set -eu

SYSCONFIG=/etc/sysconfig/named_fakezone_generator
if [ -f $SYSCONFIG ]; then
	. $SYSCONFIG
fi
REDUCTOR_IP="${REDUCTOR_IP:-10.0.0.1}"
REDUCTOR_VERSION="${REDUCTOR_VERSION:-8}"

LOCKFILE=/tmp/fakezone_generator.lock
exec 3>$LOCKFILE

if ! flock -w 60 -x 3; then
	echo "Не удалось захватить lock fakezone_generator"
	exit 1
fi

# чтобы scp не спрашивал пароль нужно создать ssh-ключи и закинуть их с помощью ssh-copy-id на carbon reductor
if [ "$REDUCTOR_VERSION" == '7' ]; then
	scp root@$REDUCTOR_IP:/usr/local/Reductor/userinfo/config /tmp/reductor.config
	scp root@$REDUCTOR_IP:/usr/local/Reductor/lists/https.resolv /tmp/reductor.https.resolv
else
	[ "$REDUCTOR_VERSION" != '8' ] && echo "WARNING: Неизвестная версия Carbon Reductor $REDUCTOR_VERSION, считаем что 8"
	scp root@$REDUCTOR_IP:/app/reductor/cfg/config /tmp/reductor.config
	scp root@$REDUCTOR_IP:/app/reductor/var/lib/reductor/lists/tmp/domains.all /tmp/reductor.https.resolv
fi

. /tmp/reductor.config

/opt/named_fakezone_generator/unbound/generate_unbound_configs.sh /tmp/reductor.https.resolv "${filter['dns_ip']}"
flock -u 3
