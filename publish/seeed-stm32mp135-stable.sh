#!/bin/bash -e

time=$(date +%Y-%m-%d)
DIR="$PWD"

# server
<<COMMENT
ssh_svr=192.168.1.78
ssh_user="cxn@${ssh_svr}"
server_dir="/home/public/share/stm32mp135"
COMMENT

rev=$(git rev-parse HEAD)
branch=$(git describe --contains --all HEAD)
this_name=$0

# Use outer net 
# export apt_proxy=localhost:3142/

keep_net_alive () {
	while : ; do
		sleep 15
		echo "log: [Running: ${this_name}]"
	done
}

kill_net_alive() {
	[ -e /proc/$KEEP_NET_ALIVE_PID ] && {
		# TODO
		# sudo rm -rf ./deploy/ || true
		sudo kill $KEEP_NET_ALIVE_PID
	}
	return 0;
}

trap "kill_net_alive;" EXIT

build_and_upload_image () {
	full_name=${target_name}-${image_name}-${size}
	echo "***BUILDING***: ${config_name}: ${full_name}.img"

	# To prevent rebuilding:
	# export FULL_REBUILD=
	FULL_REBUILD=${FULL_REBUILD-1}
	if [ -n "${FULL_REBUILD}" -o ! -e "deploy/${image_name}.tar" ]; then
		./RootStock-NG.sh -c ${config_name}
	fi

	if [ -d ./deploy/${image_name} ] ; then
		cd ./deploy/${image_name}/
		echo "debug: [./stm32mp135_setup_sdcard.sh ${options}]"
		sudo ./stm32mp135_setup_sdcard.sh ${options}

		if [ -f ${full_name}.img ] ; then
			me=`whoami`
			sudo chown ${me}.${me} ${full_name}.img
			if [ -f "${full_name}.img.xz.job.txt" ]; then
				sudo chown ${me}.${me} ${full_name}.img.xz.job.txt
			fi

			sync ; sync ; sleep 5

			bmaptool create -o ${full_name}.bmap ${full_name}.img

			xz -T0 -k -f -z -3 -v -v --verbose ${full_name}.img || true
			sha256sum ${full_name}.img.xz > ${full_name}.img.xz.sha256sum

# don't need to upload the .img to server
<<COMMENT
			#upload:
			ssh ${ssh_user} mkdir -p ${server_dir}
			echo "debug: [rsync -e ssh -av ./${full_name}.img.xz ${ssh_user}:${server_dir}/]"
			rsync -e ssh -av ./${full_name}.bmap ${ssh_user}:${server_dir}/ || true
			rsync -e ssh -av ./${full_name}.img.xz ${ssh_user}:${server_dir}/ || true
			if [ -f "${full_name}.img.xz.job.txt" ]; then
				rsync -e ssh -av ./${full_name}.img.xz.job.txt ${ssh_user}:${server_dir}/ || true
			fi
			rsync -e ssh -av ./${full_name}.img.xz.sha256sum ${ssh_user}:${server_dir}/ || true
			ssh ${ssh_user} "bash -c \"chmod a+r ${server_dir}/${full_name}.*\""
COMMENT
			#cleanup:
			cd ../../

			# TODO
			# sudo rm -rf ./deploy/ || true
		else
			echo "***ERROR***: Could not find ${full_name}.img"
		fi
	else
		echo "***ERROR***: Could not find ./deploy/${image_name}"
	fi
}

keep_net_alive & KEEP_NET_ALIVE_PID=$!
echo "pid: [${KEEP_NET_ALIVE_PID}]"

# Console STM32MP135 image
##Debian 10:
#image_name="${deb_distribution}-${release}-${image_type}-${deb_arch}-${time}"
image_name="debian-buster-console-armhf-${time}"
size="2gb"
target_name="stm32mp135"
options="--img-2gb ${target_name}-${image_name} --dtb stm32mp135 --force-device-tree stm32mp135f-dk.dtb --enable-uboot-cape-overlays"
config_name="seeed-stm32mp135-debian-buster-console-v5.10"
build_and_upload_image

kill_net_alive

