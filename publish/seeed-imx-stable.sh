#!/bin/bash -e

time=$(date +%Y-%m-%d)
DIR="$PWD"

ssh_svr=192.168.13.13
ssh_user="seeeder@${ssh_svr}"
rev=$(git rev-parse HEAD)
branch=$(git describe --contains --all HEAD)
server_dir="/home/public/share/stm32mp1"
this_name=$0

export apt_proxy=localhost:3142/

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
	echo "***BUILDING***: ${config_name}: ${target_name}-${image_name}-${size}.img"

	# To prevent rebuilding:
	# export FULL_REBUILD=
	FULL_REBUILD=${FULL_REBUILD-1}
	if [ -n "${FULL_REBUILD}" -o ! -e "deploy/${image_name}.tar" ]; then
		./RootStock-NG.sh -c ${config_name}
	fi

	if [ -d ./deploy/${image_name} ] ; then
		cd ./deploy/${image_name}/
		echo "debug: [./setup_sdcard.sh ${options}]"
		sudo ./setup_sdcard.sh ${options}

		if [ -f ${target_name}-${image_name}-${size}.img ] ; then
			me=`whoami`
			sudo chown ${me}.${me} ${target_name}-${image_name}-${size}.img
			if [ -f "${target_name}-${image_name}-${size}.img.xz.job.txt" ]; then
				sudo chown ${me}.${me} ${target_name}-${image_name}-${size}.img.xz.job.txt
			fi

			sync ; sync ; sleep 5

			bmaptool create -o ${target_name}-${image_name}-${size}.bmap ${target_name}-${image_name}-${size}.img

			xz -T0 -z -3 -v -v --verbose ${target_name}-${image_name}-${size}.img
			sha256sum ${target_name}-${image_name}-${size}.img.xz > ${target_name}-${image_name}-${size}.img.xz.sha256sum

			#upload:
			ssh ${ssh_user} mkdir -p ${server_dir}
			rsync -e ssh -av ./${target_name}-${image_name}-${size}.bmap ${ssh_user}:${server_dir}/
			rsync -e ssh -av ./${target_name}-${image_name}-${size}.img.xz ${ssh_user}:${server_dir}/
			if [ -f "${target_name}-${image_name}-${size}.img.xz.job.txt" ]; then
				rsync -e ssh -av ./${target_name}-${image_name}-${size}.img.xz.job.txt ${ssh_user}:${server_dir}/
			fi
			rsync -e ssh -av ./${target_name}-${image_name}-${size}.img.xz.sha256sum ${ssh_user}:${server_dir}/

			#cleanup:
			cd ../../

			# TODO
			# sudo rm -rf ./deploy/ || true
		else
			echo "***ERROR***: Could not find ${target_name}-${image_name}-${size}.img"
		fi
	else
		echo "***ERROR***: Could not find ./deploy/${image_name}"
	fi
}

keep_net_alive & KEEP_NET_ALIVE_PID=$!
echo "pid: [${KEEP_NET_ALIVE_PID}]"

# Console STM32MP1 image
##Debian 10:
#image_name="${deb_distribution}-${release}-${image_type}-${deb_arch}-${time}"
image_name="debian-buster-console-armhf-${time}"
size="2gb"
target_name="stm32mp1"
options="--img-2gb ${target_name}-${image_name} --hostname stm32mp1 --dtb stm32mp1"
config_name="seeed-debian-buster-console-v4.19"
build_and_upload_image

kill_net_alive

