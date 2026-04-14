#!/bin/bash

# Author: Marcelo Vázquez (aka S4vitar)
# Modified: interactive credential input + authenticated RPC support

#Colours
greenColour="\e[0;32m\033[1m"
endColour="\033[0m\e[0m"
redColour="\e[0;31m\033[1m"
blueColour="\e[0;34m\033[1m"
yellowColour="\e[0;33m\033[1m"
purpleColour="\e[0;35m\033[1m"
turquoiseColour="\e[0;36m\033[1m"
grayColour="\e[0;37m\033[1m"

declare -r tmp_file="/dev/shm/tmp_file"
declare -r tmp_file2="/dev/shm/tmp_file2"
declare -r tmp_file3="/dev/shm/tmp_file3"

# Globals para credenciales
rpc_user=""
rpc_pass=""
host_ip=""
enum_mode=""

function ctrl_c(){
	echo -e "\n${yellowColour}[*]${endColour}${grayColour} Exiting...${endColour}"; sleep 1
	rm -f $tmp_file $tmp_file2 $tmp_file3 2>/dev/null
	tput cnorm; exit 1
}

trap ctrl_c INT

function helpPanel(){
	echo -e "\n${yellowColour}[*]${endColour}${grayColour} Uso: rpcenum${endColour}"
	echo -e "\n\t${purpleColour}e)${endColour}${yellowColour} Enumeration Mode${endColour}"
	echo -e "\n\t\t${grayColour}DUsers${endColour}${redColour}     (Domain Users)${endColour}"
	echo -e "\t\t${grayColour}DUsersInfo${endColour}${redColour}  (Domain Users with info)${endColour}"
	echo -e "\t\t${grayColour}DAUsers${endColour}${redColour}     (Domain Admin Users)${endColour}"
	echo -e "\t\t${grayColour}DGroups${endColour}${redColour}     (Domain Groups)${endColour}"
	echo -e "\t\t${grayColour}All${endColour}${redColour}         (All Modes)${endColour}"
	echo -e "\n\t${purpleColour}i)${endColour}${yellowColour} Host IP Address${endColour}"
	echo -e "\n\t${purpleColour}u)${endColour}${yellowColour} Username (default: empty = null session)${endColour}"
	echo -e "\n\t${purpleColour}p)${endColour}${yellowColour} Password (default: empty = null session)${endColour}"
	echo -e "\n\t${purpleColour}h)${endColour}${yellowColour} Show this help panel${endColour}"
	echo -e "\n${yellowColour}[*]${endColour}${grayColour} Si no pasas flags, el script pedirá los datos de forma interactiva.${endColour}\n"
	exit 1
}

# Construye el string de autenticación para rpcclient
function rpc_auth(){
	if [ -z "$rpc_user" ]; then
		echo '-U "" -N'
	else
		echo "-U \"${rpc_user}%${rpc_pass}\""
	fi
}

# Wrapper para rpcclient con credenciales dinámicas
function rpcclient_cmd(){
	local target="$1"
	local cmd="$2"
	if [ -z "$rpc_user" ]; then
		rpcclient -U "" "$target" -c "$cmd" -N
	else
		rpcclient -U "${rpc_user}%${rpc_pass}" "$target" -c "$cmd"
	fi
}

# ─────────────────────────────────────────────
# Input interactivo si no se pasaron flags
# ─────────────────────────────────────────────
function interactive_input(){
	echo -e "\n${turquoiseColour}╔══════════════════════════════════════╗${endColour}"
	echo -e "${turquoiseColour}║        rpcenum - Interactive Mode    ║${endColour}"
	echo -e "${turquoiseColour}╚══════════════════════════════════════╝${endColour}\n"

	# IP
	while [ -z "$host_ip" ]; do
		echo -ne "${purpleColour}[>]${endColour}${yellowColour} Target IP: ${endColour}"
		read host_ip
		if [[ ! "$host_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
			echo -e "${redColour}[!] IP inválida, intenta de nuevo.${endColour}"
			host_ip=""
		fi
	done

	# Usuario
	echo -ne "${purpleColour}[>]${endColour}${yellowColour} Username (Enter para null session): ${endColour}"
	read rpc_user

	# Contraseña (solo si hay usuario)
	if [ -n "$rpc_user" ]; then
		echo -ne "${purpleColour}[>]${endColour}${yellowColour} Password (Enter para vacío): ${endColour}"
		read -s rpc_pass
		echo ""
	fi

	# Modo de enumeración
	echo -e "\n${yellowColour}[*]${endColour}${grayColour} Modos disponibles:${endColour}"
	echo -e "  ${grayColour}1)${endColour} DUsers"
	echo -e "  ${grayColour}2)${endColour} DUsersInfo"
	echo -e "  ${grayColour}3)${endColour} DAUsers"
	echo -e "  ${grayColour}4)${endColour} DGroups"
	echo -e "  ${grayColour}5)${endColour} All"

	local mode_choice=""
	while [ -z "$enum_mode" ]; do
		echo -ne "\n${purpleColour}[>]${endColour}${yellowColour} Selecciona modo [1-5]: ${endColour}"
		read mode_choice
		case $mode_choice in
			1) enum_mode="DUsers";;
			2) enum_mode="DUsersInfo";;
			3) enum_mode="DAUsers";;
			4) enum_mode="DGroups";;
			5) enum_mode="All";;
			*) echo -e "${redColour}[!] Opción inválida.${endColour}";;
		esac
	done

	echo -e "\n${yellowColour}[*]${endColour}${grayColour} Config: IP=${endColour}${greenColour}${host_ip}${endColour} | ${grayColour}User=${endColour}${greenColour}${rpc_user:-<null session>}${endColour} | ${grayColour}Mode=${endColour}${greenColour}${enum_mode}${endColour}\n"
}

# ─────────────────────────────────────────────
# Funciones de enumeración (usan rpcclient_cmd)
# ─────────────────────────────────────────────
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
	echo "Users" > $tmp_file && for user in $domain_users; do echo "$user" >> $tmp_file; done
	echo -ne "${blueColour}"; printTable ' ' "$(cat $tmp_file)"; echo -ne "${endColour}"
	rm -f $tmp_file
}

function extract_DUsers_Info(){
	extract_DUsers $1 > /dev/null 2>&1
	echo -e "\n${yellowColour}[*]${endColour}${grayColour} Listing domain users with description...${endColour}\n"
	for user in $domain_users; do
		rpcclient_cmd "$1" "queryuser $user" | grep -E 'User Name|Description' | cut -d ':' -f 2-100 | sed 's/\t//' | tr '\n' ',' | sed 's/.$//' >> $tmp_file
		echo -e '\n' >> $tmp_file
	done
	echo "User,Description" > $tmp_file2
	cat $tmp_file | sed '/^\s*$/d' | while read user_representation; do
		if [ "$(echo $user_representation | awk '{print $2}' FS=',')" ]; then
			echo "$(echo $user_representation | awk '{print $1}' FS=','),$(echo $user_representation | awk '{print $2}' FS=',')" >> $tmp_file2
		fi
	done
	rm -f $tmp_file; mv $tmp_file2 $tmp_file
	sleep 1; echo -ne "${blueColour}"; printTable ',' "$(cat $tmp_file)"; echo -ne "${endColour}"
	rm -f $tmp_file
}

function extract_DAUsers(){
	echo -e "\n${yellowColour}[*]${endColour}${grayColour} Enumerating Domain Admin Users...${endColour}\n"
	rid_dagroup=$(rpcclient_cmd "$1" "enumdomgroups" | grep "Domain Admins" | awk 'NF{print $NF}' | grep -oP '\[.*?\]' | tr -d '[]')
	rid_dausers=$(rpcclient_cmd "$1" "querygroupmem $rid_dagroup" | awk '{print $1}' | grep -oP '\[.*?\]' | tr -d '[]')
	echo "DomainAdminUsers" > $tmp_file
	for da_user_rid in $rid_dausers; do
		rpcclient_cmd "$1" "queryuser $da_user_rid" | grep 'User Name' | awk 'NF{print $NF}' >> $tmp_file
	done
	echo -ne "${blueColour}"; printTable ' ' "$(cat $tmp_file)"; echo -ne "${endColour}"
	rm -f $tmp_file
}

function extract_DGroups(){
	echo -e "\n${yellowColour}[*]${endColour}${grayColour} Enumerating Domain Groups...${endColour}\n"
	rpcclient_cmd "$host_ip" "enumdomgroups" | grep -oP '\[.*?\]' | grep "0x" | tr -d '[]' >> $tmp_file
	echo "DomainGroup,Description" > $tmp_file2
	cat $tmp_file | while read rid_domain_groups; do
		rpcclient_cmd "$host_ip" "querygroup $rid_domain_groups" | grep -E 'Group Name|Description' | sed 's/\t//' > $tmp_file3
		group_name=$(cat $tmp_file3 | grep "Group Name" | awk '{print $2}' FS=":")
		group_description=$(cat $tmp_file3 | grep "Description" | awk '{print $2}' FS=":")
		echo "$(echo $group_name),$(echo $group_description)" >> $tmp_file2
	done
	rm -f $tmp_file $tmp_file3 && mv $tmp_file2 $tmp_file
	echo -ne "${blueColour}"; printTable ',' "$(cat $tmp_file)"; echo -ne "${endColour}"
	rm -f $tmp_file
}

function extract_All(){
	extract_DUsers $1
	extract_DUsers_Info $1
	extract_DAUsers $1
	extract_DGroups $1
}

function beginEnumeration(){
	tput civis
	nmap -p139 --open -T5 -v -n $host_ip 2>/dev/null | grep open > /dev/null 2>&1 && port_status=$?

	# Test de conexión
	rpcclient_cmd "$host_ip" "enumdomusers" > /dev/null 2>&1
	local rpc_status=$?

	if [ "$rpc_status" == "0" ]; then
		if [ "$port_status" == "0" ]; then
			case $enum_mode in
				DUsers)     extract_DUsers $host_ip;;
				DUsersInfo) extract_DUsers_Info $host_ip;;
				DAUsers)    extract_DAUsers $host_ip;;
				DGroups)    extract_DGroups $host_ip;;
				All)        extract_All $host_ip;;
				*)
					echo -e "\n${redColour}[!] Opción no válida${endColour}"
					helpPanel
					exit 1
					;;
			esac
		else
			echo -e "\n${redColour}[!] El puerto 139 parece cerrado en $host_ip${endColour}"
			tput cnorm; exit 0
		fi
	else
		echo -e "\n${redColour}[!] Error: Acceso denegado. Verifica credenciales o null session.${endColour}"
		tput cnorm; exit 0
	fi
}

# ─────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────
if [ "$(echo $UID)" != "0" ]; then
	echo -e "\n${redColour}[*] Necesitas ejecutar el script como root.${endColour}\n"
	exit 1
fi

declare -i parameter_counter=0

while getopts ":e:i:u:p:h" arg; do
	case $arg in
		e) enum_mode=$OPTARG;  let parameter_counter+=1;;
		i) host_ip=$OPTARG;    let parameter_counter+=1;;
		u) rpc_user=$OPTARG;;
		p) rpc_pass=$OPTARG;;
		h) helpPanel;;
	esac
done

# Si no se pasaron los flags obligatorios (-e y -i), modo interactivo
if [ $parameter_counter -lt 2 ]; then
	interactive_input
fi

beginEnumeration
tput cnorm