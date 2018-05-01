#!/bin/sh
set -e
cd $(dirname $0)

#Usually set from the outside
: ${DOCKER_ARCH:="$(docker version -f '{{.Server.Arch}}')"}
# QEMU_ARCH #Not set means no qemu emulation
: ${TARGET_IMG:=""}
: ${TAG:="latest"}
: ${BUILD:="true"}
: ${PUSH:="true"}
: ${MANIFEST:="false"}
: ${ARCHS:=""}

#good defaults
: ${BASE:="alpine"}
: ${REPO:="angelnu/keepalived"}
: ${QEMU_VERSION:="v2.11.1"}



###############################

if [ "$BUILD" = true ] ; then
  echo "BUILDING DOCKER $REPO:$ARCH_TAG"
  
  #Prepare qemu
  mkdir -p qemu
  cd qemu
  if [ ! -f qemu-"$QEMU_ARCH"-static ]; then
    echo "Running in arch $DOCKER_ARCH with target arch $QEMU_ARCH"
    if [ -z "$QEMU_ARCH" ]; then
      touch qemu-"$QEMU_ARCH"-static
    else
      # Prepare qemu
      docker run --rm --privileged multiarch/qemu-user-static:register --reset
      curl -L -o qemu-"$QEMU_ARCH"-static.tar.gz https://github.com/multiarch/qemu-user-static/releases/download/"$QEMU_VERSION"/qemu-"$QEMU_ARCH"-static.tar.gz
      tar xzf qemu-"$QEMU_ARCH"-static.tar.gz
      rm qemu-"$QEMU_ARCH"-static.tar.gz
    fi
  fi
  cd ..

  #Build docker
  BASE=alpine
  if [ -n "$TARGET_IMG" ]; then
    BASE="$TARGET_IMG/$BASE"
  fi
  echo "Using base image: $BASE"
  docker build -t $REPO:$DOCKER_ARCH --build-arg BASE=$BASE --build-arg arch=$QEMU_ARCH .
fi

##############################

if [ "$PUSH" = true ] ; then
  echo "PUSHING TO DOCKER"
  docker push $REPO:$DOCKER_ARCH
fi

###############################

if [ "$MANIFEST" = true ] ; then
  echo "PUSHING MANIFEST for $ARCHS"
  
  for arch in $ARCHS; do
    echo
    echo "Pull ${REPO}:${TAG}-${arch}"
    docker pull ${REPO}:${TAG}-${arch}
    
    echo
    echo "Add ${REPO}:${TAG}-${arch} to manifest ${REPO}:${TAG}"
    docker manifest create --amend ${REPO}:${TAG} ${REPO}:${TAG}-${arch}
    docker manifest annotate       ${REPO}:${TAG} ${REPO}:${TAG}-${arch} --arch ${arch}
  done

  echo
  echo "Push manifest ${REPO}:${TAG}"
  docker manifest push ${REPO}:${TAG}
fi
