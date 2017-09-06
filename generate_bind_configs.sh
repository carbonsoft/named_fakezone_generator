#!/bin/bash

set -eu

file=$1
ip=$2
fakezoneroot=/opt/named_fakezone_generator/
zones=/etc/named.reductor.zones
hook=/etc/sysconfig/named_fakezone_generator
DOMAIN_TMPLT=$fakezoneroot/reductor_named_domain.tmplt

# удаляем сгенерированные в прошлый раз зоны, префикс чтобы не трогать чужие зоны при этом
cleanup() {
	> $zones
	mkdir -p /etc/named/
	find /etc/named/ -type f -name "reductor_*" -delete
	rm -f $file.processed
}

# с кириллическими доменами пока что проблема, вообще здесь избавляемся от дублирования из-за fqdn/www.
process_list() {
	sed 's/\.$//' | tr -d ' ' | sed -e 's/^www\.//' | python -u $fakezoneroot/idna_fix.py | sort -u
}

check_output() {
	if [ ! -s $1 ]; then
		echo "Empty $1, fail"
		exit 1
	fi

}

generate_zones() {
	while read domain; do
		echo 'zone "'${domain//_/-}'" { type master; file "/etc/named/reductor_zones.conf"; };'
	done > $zones
	m4 -Udnl -D__domain__=${NS_GLOBAL:-denypage.ru} -D__ip__=$ip $DOMAIN_TMPLT >> "/etc/named/reductor_zones.conf"

}

# стараемся залить данные "мягко", но сервер может лежать, тогда поднимаем его
# вообще спорный момент, в теории можно убрать || service named restart
apply_zones() {
	rndc reload || service named restart
}

main() {
	cleanup
	process_list < $file > $file.processed
	check_output $file.processed
	generate_zones < $file.processed
	apply_zones
}

[ -f $hook ] && . $hook
main
