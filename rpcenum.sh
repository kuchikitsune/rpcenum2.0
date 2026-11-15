#!/bin/bash

greenColour="\e[0;32m\033[1m"
endColour="\033[0m\e[0m"
redColour="\e[0;31m\033[1m"
blueColour="\e[0;34m\033[1m"
yellowColour="\e[0;33m\033[1m"
purpleColour="\e[0;35m\033[1m"
turquoiseColour="\e[0;36m\033[1m"
grayColour="\e[0;37m\033[1m"

# Temporales seguros (se asignan en main)
tmp_file=""
tmp_file2=""
tmp_file3=""

rpc_user=""
rpc_pass=""
rpc_hash=""
host_ip=""
enum_mode=""
output_dir=""

function ctrl_c(){
	echo -e "\n${yellowColour}[*]${endColour}${grayColour} Exiting...${endColour}"; sleep 1
	rm -f "$tmp_file" "$tmp_file2" "$tmp_file3" 2>/dev/null
	tput cnorm; exit 1
}

trap ctrl_c INT

function helpPanel(){
	echo -e "\n${yellowColour}[*]${endColour}${grayColour} Usage: rpcenum${endColour}"
	echo -e "\n\t${purpleColour}e)${endColour}${yellowColour} Enumeration Mode${endColour}"
	echo -e "\n\t\t${grayColour}DUsers${endColour}${redColour}       (Domain Users)${endColour}"
	echo -e "\t\t${grayColour}DUsersInfo${endColour}${redColour}   (Domain Users with info)${endColour}"
	echo -e "\t\t${grayColour}DAUsers${endColour}${redColour}      (Domain Admin Users)${endColour}"
	echo -e "\t\t${grayColour}DAUsersInfo${endColour}${redColour}  (Domain Admin Users with info)${endColour}"
	echo -e "\t\t${grayColour}DGroups${endColour}${redColour}      (Domain Groups)${endColour}"
	echo -e "\t\t${grayColour}PassPol${endColour}${redColour}      (Password Policy)${endColour}"
	echo -e "\t\t${grayColour}DomInfo${endColour}${redColour}      (Domain Info)${endColour}"
	echo -e "\t\t${grayColour}All${endColour}${redColour}          (All Modes)${endColour}"
	echo -e "\n\t${purpleColour}i)${endColour}${yellowColour} Host IP Address${endColour}"
	echo -e "\n\t${purpleColour}u)${endColour}${yellowColour} Username (default: empty = null session)${endColour}"
	echo -e "\n\t${purpleColour}p)${endColour}${yellowColour} Password (default: empty = null session)${endColour}"
	echo -e "\n\t${purpleColour}H)${endColour}${yellowColour} NT hash (Pass-the-Hash; requires -u)${endColour}"
	echo -e "\n\t${purpleColour}o)${endColour}${yellowColour} Output directory (optional; exports results)${endColour}"
	echo -e "\n\t${purpleColour}h)${endColour}${yellowColour} Show this help panel${endColour}"
	echo -e "\n${yellowColour}[*]${endColour}${grayColour} If no flags are provided, the script will prompt for input interactively.${endColour}\n"
	exit 1
}

function check_dependencies(){
	local missing=0
	for dep in rpcclient nmap awk column sed grep; do
		if ! command -v "$dep" &>/dev/null; then
			echo -e "${redColour}[!] Missing dependency: ${dep}${endColour}"
			missing=1
		fi
	done
	[ "$missing" -eq 1 ] && exit 1
}

function init_output(){
	if [ -n "$output_dir" ]; then
		mkdir -p "$output_dir" || { echo -e "${redColour}[!] Could not create output dir: $output_dir${endColour}"; exit 1; }
		echo -e "${yellowColour}[*]${endColour}${grayColour} Exporting results to: ${endColour}${greenColour}${output_dir}${endColour}"
	fi
}

function save_output(){
	# save_output <source_tmp_file> <dest_filename>
	if [ -n "$output_dir" ]; then
		cp "$1" "${output_dir}/$2"
		echo -e "${greenColour}[+]${endColour}${grayColour} Saved: ${output_dir}/$2${endColour}"
	fi
}

# Construye la credencial para rpcclient según user/pass/hash o null session
function rpcclient_cmd(){
	local target="$1"
	local cmd="$2"
	if [ -z "$rpc_user" ]; then
		rpcclient -U "" "$target" -c "$cmd" -N
	elif [ -n "$rpc_hash" ]; then
		rpcclient -U "${rpc_user}" --pw-nt-hash "$target" -c "$cmd" <<< "$rpc_hash"
	else
		rpcclient -U "${rpc_user}%${rpc_pass}" "$target" -c "$cmd"
	fi
}

function interactive_input(){
	echo -e "\n${turquoiseColour}╔══════════════════════════════════════╗${endColour}"
	echo -e "${turquoiseColour}║        rpcenum - Interactive Mode    ║${endColour}"
	echo -e "${turquoiseColour}╚══════════════════════════════════════╝${endColour}\n"

	# IP
	while [ -z "$host_ip" ]; do
		echo -ne "${purpleColour}[>]${endColour}${yellowColour} Target IP: ${endColour}"
		read host_ip
		if [[ ! "$host_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
			echo -e "${redColour}[!] Invalid IP, please try again.${endColour}"
			host_ip=""
		fi
	done

	# Username
	echo -ne "${purpleColour}[>]${endColour}${yellowColour} Username (press Enter for null session): ${endColour}"
	read rpc_user

	# Password / hash (only if a username was provided)
	if [ -n "$rpc_user" ]; then
		echo -ne "${purpleColour}[>]${endColour}${yellowColour} Use NT hash instead of password? [y/N]: ${endColour}"
		local use_hash=""
		read use_hash
		if [[ "$use_hash" =~ ^[yY]$ ]]; then
			echo -ne "${purpleColour}[>]${endColour}${yellowColour} NT hash: ${endColour}"
			read rpc_hash
		else
			echo -ne "${purpleColour}[>]${endColour}${yellowColour} Password (press Enter for empty): ${endColour}"
			read -s rpc_pass
			echo ""
		fi
	fi

	# Output dir (optional)
	echo -ne "${purpleColour}[>]${endColour}${yellowColour} Output directory (Enter to skip): ${endColour}"
	read output_dir

	# Enumeration
	echo -e "\n${yellowColour}[*]${endColour}${grayColour} Available modes:${endColour}"
	echo -e "  ${grayColour}1)${endColour} DUsers"
	echo -e "  ${grayColour}2)${endColour} DUsersInfo"
	echo -e "  ${grayColour}3)${endColour} DAUsers"
	echo -e "  ${grayColour}4)${endColour} DAUsersInfo"
	echo -e "  ${grayColour}5)${endColour} DGroups"
	echo -e "  ${grayColour}6)${endColour} PassPol"
	echo -e "  ${grayColour}7)${endColour} DomInfo"
	echo -e "  ${grayColour}8)${endColour} All"

	local mode_choice=""
	while [ -z "$enum_mode" ]; do
		echo -ne "\n${purpleColour}[>]${endColour}${yellowColour} Select mode [1-8]: ${endColour}"
		read mode_choice
		case $mode_choice in
			1) enum_mode="DUsers";;
			2) enum_mode="DUsersInfo";;
			3) enum_mode="DAUsers";;
			4) enum_mode="DAUsersInfo";;
			5) enum_mode="DGroups";;
			6) enum_mode="PassPol";;
			7) enum_mode="DomInfo";;
			8) enum_mode="All";;
			*) echo -e "${redColour}[!] Invalid option.${endColour}";;
		esac
	done

	echo -e "\n${yellowColour}[*]${endColour}${grayColour} Config: IP=${endColour}${greenColour}${host_ip}${endColour} | ${grayColour}User=${endColour}${greenColour}${rpc_user:-<null session>}${endColour} | ${grayColour}Mode=${endColour}${greenColour}${enum_mode}${endColour}\n"
}

function printTable(){
	local -r delimiter="${1}"
	local -r data="$(removeEmptyLines "${2}")"
	if [[ "${delimiter}" != '' && "$(isEmptyString "${data}")" = 'false' ]]; then
		local -r numberOfLines="$(wc -l <<< "${data}")"
		if [[ "${numberOfLines}" -gt '0' ]]; then
			local table=''
			local i=1
			for ((i = 1; i <= "${numberOfLines}"; i = i + 1)); do
				local line=''
				line="$(sed "${i}q;d" <<< "${data}")"
				local numberOfColumns='0'
				numberOfColumns="$(awk -F "${delimiter}" '{print NF}' <<< "${line}")"
				if [[ "${i}" -eq '1' ]]; then
					table="${table}$(printf '%s#+' "$(repeatString '#+' "${numberOfColumns}")")"
				fi
				table="${table}\n"
				local j=1
				for ((j = 1; j <= "${numberOfColumns}"; j = j + 1)); do
					table="${table}$(printf '#| %s' "$(cut -d "${delimiter}" -f "${j}" <<< "${line}")")"
				done
				table="${table}#|\n"
				if [[ "${i}" -eq '1' ]] || [[ "${numberOfLines}" -gt '1' && "${i}" -eq "${numberOfLines}" ]]; then
					table="${table}$(printf '%s#+' "$(repeatString '#+' "${numberOfColumns}")")"
				fi
			done
			if [[ "$(isEmptyString "${table}")" = 'false' ]]; then
				echo -e "${table}" | column -s '#' -t | awk '/^\+/{gsub(" ", "-", $0)}1'
			fi
		fi
	fi
}

function removeEmptyLines(){ local -r content="${1}"; echo -e "${content}" | sed '/^\s*$/d'; }
function repeatString(){
	local -r string="${1}"; local -r numberToRepeat="${2}"
	if [[ "${string}" != '' && "${numberToRepeat}" =~ ^[1-9][0-9]*$ ]]; then
		local -r result="$(printf "%${numberToRepeat}s")"; echo -e "${result// /${string}}"
	fi
}
function isEmptyString(){
	local -r string="${1}"
	if [[ "$(trimString "${string}")" = '' ]]; then echo 'true' && return 0; fi
	echo 'false' && return 1
}
function trimString(){ local -r string="${1}"; sed 's,^[[:blank:]]*,,' <<< "${string}" | sed 's,[[:blank:]]*$,,'; }

function extract_DUsers(){
	echo -e "\n${yellowColour}[*]${endColour}${grayColour} Enumerating Domain Users...${endColour}\n"
	domain_users=$(rpcclient_cmd "$1" "enumdomusers" | grep -oP '\[.*?\]' | grep -v 0x | tr -d '[]')
	echo "Users" > "$tmp_file"
	mapfile -t _users <<< "$domain_users"
	for user in "${_users[@]}"; do [ -n "$user" ] && echo "$user" >> "$tmp_file"; done
	echo -ne "${blueColour}"; printTable ' ' "$(cat "$tmp_file")"; echo -ne "${endColour}"

	if [ -n "$output_dir" ]; then
		printf '%s\n' "${_users[@]}" | sed '/^\s*$/d' > "${output_dir}/domain_users.txt"
		echo -e "\n${greenColour}[+]${endColour}${grayColour} Saved: ${output_dir}/domain_users.txt${endColour}"
	fi
	rm -f "$tmp_file"
}

function extract_DUsers_Info(){
	extract_DUsers "$1" > /dev/null 2>&1
	echo -e "\n${yellowColour}[*]${endColour}${grayColour} Listing domain users with description...${endColour}\n"
	mapfile -t _users <<< "$domain_users"
	for user in "${_users[@]}"; do
		[ -z "$user" ] && continue
		rpcclient_cmd "$1" "queryuser $user" | grep -E 'User Name|Description' | cut -d ':' -f 2-100 | sed 's/\t//' | tr '\n' ',' | sed 's/.$//' >> "$tmp_file"
		echo -e '\n' >> "$tmp_file"
	done
	echo "User,Description" > "$tmp_file2"
	cat "$tmp_file" | sed '/^\s*$/d' | while read user_representation; do
		if [ "$(echo $user_representation | awk '{print $2}' FS=',')" ]; then
			echo "$(echo $user_representation | awk '{print $1}' FS=','),$(echo $user_representation | awk '{print $2}' FS=',')" >> "$tmp_file2"
		fi
	done
	rm -f "$tmp_file"; mv "$tmp_file2" "$tmp_file"
	sleep 1; echo -ne "${blueColour}"; printTable ',' "$(cat "$tmp_file")"; echo -ne "${endColour}"
	save_output "$tmp_file" "domain_users_info.csv"
	rm -f "$tmp_file"
}

function extract_DAUsers(){
	echo -e "\n${yellowColour}[*]${endColour}${grayColour} Enumerating Domain Admin Users...${endColour}\n"
	rid_dagroup=$(rpcclient_cmd "$1" "enumdomgroups" | grep "Domain Admins" | awk 'NF{print $NF}' | grep -oP '\[.*?\]' | tr -d '[]')
	rid_dausers=$(rpcclient_cmd "$1" "querygroupmem $rid_dagroup" | awk '{print $1}' | grep -oP '\[.*?\]' | tr -d '[]')
	echo "DomainAdminUsers" > "$tmp_file"
	for da_user_rid in $rid_dausers; do
		rpcclient_cmd "$1" "queryuser $da_user_rid" | grep 'User Name' | awk 'NF{print $NF}' >> "$tmp_file"
	done
	echo -ne "${blueColour}"; printTable ' ' "$(cat "$tmp_file")"; echo -ne "${endColour}"
	save_output "$tmp_file" "domain_admins.txt"
	rm -f "$tmp_file"
}

function extract_DAUsers_Info(){
	echo -e "\n${yellowColour}[*]${endColour}${grayColour} Enumerating Domain Admin Users with description...${endColour}\n"
	rid_dagroup=$(rpcclient_cmd "$1" "enumdomgroups" | grep "Domain Admins" | awk 'NF{print $NF}' | grep -oP '\[.*?\]' | tr -d '[]')
	rid_dausers=$(rpcclient_cmd "$1" "querygroupmem $rid_dagroup" | awk '{print $1}' | grep -oP '\[.*?\]' | tr -d '[]')
	echo "DomainAdminUser,Description" > "$tmp_file"
	for da_user_rid in $rid_dausers; do
		rpcclient_cmd "$1" "queryuser $da_user_rid" \
			| grep -E 'User Name|Description' \
			| cut -d ':' -f 2- \
			| sed 's/^\s*//' \
			| tr '\n' ',' \
			| sed 's/,$//' >> "$tmp_file"
		echo "" >> "$tmp_file"
	done
	echo -ne "${blueColour}"; printTable ',' "$(cat "$tmp_file")"; echo -ne "${endColour}"
	save_output "$tmp_file" "domain_admins_info.csv"
	rm -f "$tmp_file"
}

function extract_DGroups(){
	echo -e "\n${yellowColour}[*]${endColour}${grayColour} Enumerating Domain Groups...${endColour}\n"
	rpcclient_cmd "$host_ip" "enumdomgroups" | grep -oP '\[.*?\]' | grep "0x" | tr -d '[]' >> "$tmp_file"
	echo "DomainGroup,Description" > "$tmp_file2"
	cat "$tmp_file" | while read rid_domain_groups; do
		rpcclient_cmd "$host_ip" "querygroup $rid_domain_groups" | grep -E 'Group Name|Description' | sed 's/\t//' > "$tmp_file3"
		group_name=$(cat "$tmp_file3" | grep "Group Name" | awk '{print $2}' FS=":")
		group_description=$(cat "$tmp_file3" | grep "Description" | awk '{print $2}' FS=":")
		echo "$(echo $group_name),$(echo $group_description)" >> "$tmp_file2"
	done
	rm -f "$tmp_file" "$tmp_file3" && mv "$tmp_file2" "$tmp_file"
	echo -ne "${blueColour}"; printTable ',' "$(cat "$tmp_file")"; echo -ne "${endColour}"
	save_output "$tmp_file" "domain_groups.csv"
	rm -f "$tmp_file"
}

function extract_PassPol(){
	echo -e "\n${yellowColour}[*]${endColour}${grayColour} Retrieving Password Policy...${endColour}\n"
	rpcclient_cmd "$host_ip" "getdompwinfo" > "$tmp_file"
	echo -ne "${blueColour}"; cat "$tmp_file"; echo -ne "${endColour}"
	save_output "$tmp_file" "password_policy.txt"
	rm -f "$tmp_file"
}

function extract_DomInfo(){
	echo -e "\n${yellowColour}[*]${endColour}${grayColour} Retrieving Domain Info...${endColour}\n"
	rpcclient_cmd "$host_ip" "querydominfo" > "$tmp_file"
	echo -ne "${blueColour}"; cat "$tmp_file"; echo -ne "${endColour}"
	save_output "$tmp_file" "domain_info.txt"
	rm -f "$tmp_file"
}

function extract_All(){
	extract_DomInfo "$1"
	extract_PassPol "$1"
	extract_DUsers "$1"
	extract_DUsers_Info "$1"
	extract_DAUsers "$1"
	extract_DAUsers_Info "$1"
	extract_DGroups "$1"
}

function beginEnumeration(){
	tput civis
	init_output

	# Chequeo de puertos SMB/RPC (445 moderno, 139 legacy)
	nmap -p445,139 --open -T4 -n "$host_ip" 2>/dev/null | grep -q open
	port_status=$?

	# Connection test
	rpcclient_cmd "$host_ip" "enumdomusers" > /dev/null 2>&1
	local rpc_status=$?

	if [ "$rpc_status" == "0" ]; then
		if [ "$port_status" == "0" ]; then
			case $enum_mode in
				DUsers)      extract_DUsers "$host_ip";;
				DUsersInfo)  extract_DUsers_Info "$host_ip";;
				DAUsers)     extract_DAUsers "$host_ip";;
				DAUsersInfo) extract_DAUsers_Info "$host_ip";;
				DGroups)     extract_DGroups "$host_ip";;
				PassPol)     extract_PassPol "$host_ip";;
				DomInfo)     extract_DomInfo "$host_ip";;
				All)         extract_All "$host_ip";;
				*)
					echo -e "\n${redColour}[!] Invalid option${endColour}"
					helpPanel
					;;
			esac
		else
			echo -e "\n${redColour}[!] Ports 445/139 appear to be closed on $host_ip${endColour}"
			tput cnorm; exit 0
		fi
	else
		echo -e "\n${redColour}[!] Error: Access denied. Check your credentials, hash or null session.${endColour}"
		tput cnorm; exit 0
	fi
	tput cnorm
}

# ---- Main ----
if [ "$(id -u)" != "0" ]; then
	echo -e "\n${redColour}[*] You need to run this script as root.${endColour}\n"
	exit 1
fi

check_dependencies

# Temporales únicos por instancia
tmp_file=$(mktemp /dev/shm/rpcenum.XXXXXX)
tmp_file2=$(mktemp /dev/shm/rpcenum.XXXXXX)
tmp_file3=$(mktemp /dev/shm/rpcenum.XXXXXX)

declare -i parameter_counter=0

while getopts ":e:i:u:p:H:o:h" arg; do
	case $arg in
		e) enum_mode=$OPTARG;  let parameter_counter+=1;;
		i) host_ip=$OPTARG;    let parameter_counter+=1;;
		u) rpc_user=$OPTARG;;
		p) rpc_pass=$OPTARG;;
		H) rpc_hash=$OPTARG;;
		o) output_dir=$OPTARG;;
		h) helpPanel;;
	esac
done

if [ $parameter_counter -lt 2 ]; then
	interactive_input
fi

beginEnumeration

rm -f "$tmp_file" "$tmp_file2" "$tmp_file3" 2>/dev/null
tput cnorm
