FROM archlinux:latest

RUN pacman -Syu --noconfirm base-devel clang git wget bc

WORKDIR /build

COPY build.sh .
COPY config .

RUN chmod +x build.sh

ENTRYPOINT ["./build.sh"]