MAIN    := main.zig
TARGET  := linux_bin
FLY_APP := protohacker-zig

build-linux:
	zig build-exe src/${MAIN} --name ${TARGET} -O ReleaseSmall -fstrip -static -target x86_64-linux

launch:
	fly launch --copy-config --local-only --name ${FLY_APP} \
		--no-deploy -r lhr && \
	fly ips allocate-v6 -a ${FLY_APP}

deploy-fly: build-linux
	fly deploy --local-only

deploy: deploy-fly clean

clean:
	- rm -f ${TARGET}
	- rm -f ${TARGET}.o
