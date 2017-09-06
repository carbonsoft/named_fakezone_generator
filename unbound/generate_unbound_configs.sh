#!/bin/bash

set -eu

file=$1
ip=$2
shift 2

fakezoneroot=/opt/named_fakezone_generator/unbound
zones=/etc/unbound/local.d/reductor.conf
hook=/etc/sysconfig/unbound_fakezone_generator

# удаляем сгенерированные в прошлый раз зоны, префикс чтобы не трогать чужие зоны при этом
cleanup() {
	mkdir -p /etc/unbound/
	rm -f $file.processed
}

# с кириллическими доменами пока что проблема, вообще здесь избавляемся от дублирования из-за fqdn/www.
process_list() {
	sed 's/\.$//' | tr -d ' ' | sed -e 's/^www\.//' | python -u $fakezoneroot/../idna_fix.py | sort -u
}

# генерируем всё необходимое для блокировки одного конкретного домена
create_config() {
	local domain=$1
	local ip=$2
	echo 'local-zone: "'$domain'" redirect'
	echo 'local-data: "'$domain' A '$ip'"'
}

check_output() {
	if [ ! -s $1 ]; then
		echo "Empty $1, fail"
		exit 1
	fi

}

generate_zones() {
	while read domain; do
		create_config $domain $ip
	done

}

fast_unbound_reload() {
	local rc=0
	if ! $fakezoneroot/diff_load.sh $zones $file $ip; then
		echo fast_unbound_reload fail
		rc=1
	fi
	mv $zones.tmp $zones
	return $rc
}

# стараемся залить данные "мягко", но сервер может лежать, тогда поднимаем его
# вообще спорный момент, в теории можно убрать || service named restart
apply_zones() {
	fast_unbound_reload || unbound-control reload || service unbound restart
}

main() {
	cleanup
	process_list < $file > $file.processed
	check_output $file.processed
	generate_zones < $file.processed > $zones.tmp
	apply_zones
}

[ -f $hook ] && . $hook
"${@:-main}"
