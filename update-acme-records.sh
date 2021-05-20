#!/bin/bash
# author: Kevin Pham
# automates ACME validation for Akamai
# 1. fetch all pending CPS ACME validation DNS records
# 2. fetch all zone files 
# 3. update zone files with new ACME validation TXT records 
# 4. upload the new zone files
#
# usage: 
# ./validate.sh <comment>

set -e

comment="$@"
[[ $comment -eq "" ]] && comment="ACME validation"

RD=`tput setaf 1`
GR=`tput setaf 2`
CY=`tput setaf 6`
NC=`tput sgr0`
#NC=`tput setaf 7`


echo -e "${GR}[+] checking dependencies${NC}"
akamai --version || echo -e "${RD}[-] please install akamai cli${NC}"
akamai cps --version || echo -e "${RD}[-] please install akamai CPS module${NC}"
akamai dns --version || echo -e "${RD}[-] please install akamai dns module${NC}"

echo -e "${GR}[+] fetching all CNs with pending cert changes${NC}"
CNs=$(akamai cps list | grep 'dv san' | grep '*Yes*' | cut -f3 -d'|' | awk '{print $1}')

rawRecords=""
for CN in ${CNs}; do
	echo -e "${GR}[+] fetching all ACME validation records for ${CN}${NC}"
	rawRecords=$(echo -e "$rawRecords\\n$(akamai cps status --cn "$CN" --validation-type dns 2>&1 | grep Awaiting)")
	echo -e "${GR}[+] got $(echo "$rawRecords" | wc -l) new records ${NC}"
done
#echo "$rawRecords"

echo -e "${GR}[+] fetching all zones...${NC}"
zones=$(akamai dns list-zoneconfig --summary | grep ACTIVE | awk '{print $1}')

echo -e "${GR}[+] deleting old zonefiles...${NC}"
[[ -e "./zonefiles" ]] && rm -rf "./zonefiles"
mkdir zonefiles

for zone in ${zones}; do
	[[ $(echo "$rawRecords" | grep $zone) ]] || continue

	echo -e "${GR}[+] fetching zone file for $zone ${NC}"
	akamai dns retrieve-zoneconfig $zone -dns --output "./zonefiles/${zone}.zone.tmp2"

	echo -e "${GR}[+] incrementing SOA serial for zonefile: $zone ${NC}"
	awk 'BEGIN{ OFS="\t" } /SOA/{$7=$7+1} 1' "./zonefiles/${zone}.zone.tmp2" > "./zonefiles/${zone}.zone.tmp"

	echo -e "${GR}[+] deleting old acme records for $zone ${NC}"
	grep -v "_acme-challenge." "./zonefiles/${zone}.zone.tmp" > "./zonefiles/${zone}.zone"

	echo -e "${GR}[+] adding new acme records for $zone ${NC}"
	echo "$rawRecords"  \
		| grep $zone \
		| awk  '{print "_acme-challenge." $2 ".\t" "60\t" "IN\t" "TXT\t" $7}' \
		>> "./zonefiles/${zone}.zone"

	echo -e "${GR}[+] validating changes for zonefile: $zone ${NC}" 
	[[ -e ./zonefiles/${zone}.zone ]] || exit 1 
	[[ -e ./zonefiles/${zone}.zone.tmp ]] || exit 1 
	comm <(sort ./zonefiles/${zone}.zone) <(sort ./zonefiles/${zone}.zone.tmp) -3 \
		| grep -v 'SOA' \
		| grep -vq '_acme-challenge.'  \
		&& echo -e "${RD}[-] error generating zonefile $zone ${NC}" && exit 1

        echo "${GR}[+] uploading zonefile: ./zonefiles/${zone}.zone ${NC}"
        akamai dns update-zoneconfig $zone -dns -file ./zonefiles/${zone}.zone --comment $comment
done

echo -e "${GR}[+] done!"

exit 0



