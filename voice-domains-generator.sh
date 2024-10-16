#!/bin/sh

default_regions="russia bucharest finland frankfurt madrid milan rotterdam stockholm warsaw"

regions="${1:-$default_regions}"

total_domains=15000

kill -sighup $(pgrep dnsmasq) 2> /dev/null || echo "Куда же подевался наш dnsmasq?"

check_domain() {
    domain=$1
    region=$2
    directory="./regions/$region"

    mkdir -p "$directory"

    ip=$(dig A +short "$domain" | grep -Evi "(warning|timed out|no servers|mismatch)")

    [ -n "$ip" ] && {
        echo "$domain: $ip" >> "$directory/$region-voice-resolved"
        echo "$domain" >> "$directory/$region-voice-domains"
        echo "$ip" >> "$directory/$region-voice-ip"
        echo "add unblock $ip" >> "$directory/$region-voice-ipset"
    }
}

all_ip_list="./discord-voice-ip-list"
all_ipset_list="./discord-voice-ipset-list"
all_domains_list="./discord-voice-domains-list"

> "$all_ip_list"
> "$all_ipset_list"
> "$all_domains_list"

for region in $regions; do
    echo "\nГенерируем и резолвим домены для региона: $region"
    directory="./regions/$region"

    [ -z "$directory" ] && {
        echo 'Чуть не сделали rm -rf /*'
        exit 1
    }
    rm -rf "${directory:?}"/*

    start_time=$(date +%s)
    start_date=$(date +'%d.%m.%Y в %H:%M:%S')

    resolved_count=0

   for i in $(seq 1 "$total_domains"); do
       check_domain "${region}${i}.discord.gg" "$region"
       resolved_count=$((resolved_count + 1))

       printf "\rПрогресс: $(( (resolved_count * 100) / total_domains ))%%"
   done

   sort "$directory/$region-voice-ip" 2> /dev/null >> "$all_ip_list"
   sort "$directory/$region-voice-ipset" 2> /dev/null >> "$all_ipset_list"
   sort "$directory/$region-voice-domains" 2> /dev/null >> "$all_domains_list"

   end_time=$(date +%s)
   execution_time=$((end_time - start_time))
   domains_resolved=$(wc -l < "$directory"/"$region"-voice-resolved)

   echo ""
   echo "Успех!"
   echo "Время запуска: $start_date"
   echo "Время выполнения: $(date -ud "@$execution_time" +'%H:%M:%S')"
   echo "Доменов зарезолвили: $domains_resolved"
done

   ip_count=$(wc -l < "$all_ip_list")
   echo "\nСписок "$all_ip_list" обновлён, зарезолвили $ip_count адреса(ов)\n"
