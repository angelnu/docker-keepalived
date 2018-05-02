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

if [ "x$TAG" = "xlatest" ]; then
  ALIAS_ARCH_TAG="${TAG}-${DOCKER_ARCH}"
  ORG_TAG="$TAG"
  TAG="$(git describe --always --dirty --tags || echo 0.1)"
fi
: ${ARCH_TAG:="${TAG}-${DOCKER_ARCH}"}


###############################

if [ "$BUILD" = true ] ; then
  echo "BUILDING DOCKER $REPO:$ARCH_TAG"

  #Prepare qemu
  mkdir -p qemu
  cd qemu

  if [ -z "$QEMU_ARCH" ]; then
    echo "Building without qemu"
    touch qemu-"$QEMU_ARCH"-static
  else
    # Prepare qemu
    echo "Building docker for arch $DOCKER_ARCH using qemu arch $QEMU_ARCH"
    if [ ! -f qemu-"$QEMU_ARCH"-static ]; then
      docker run --rm --privileged multiarch/qemu-user-static:register --reset
      curl -L -o qemu-"$QEMU_ARCH"-static.tar.gz https://github.com/multiarch/qemu-user-static/releases/download/"$QEMU_VERSION"/qemu-"$QEMU_ARCH"-static.tar.gz
      tar xzf qemu-"$QEMU_ARCH"-static.tar.gz
      rm qemu-"$QEMU_ARCH"-static.tar.gz
    fi
  fi
  cd ..

  #Build docker
  if [ -n "$TARGET_IMG" ]; then
    BASE="$TARGET_IMG/$BASE"
  fi
  echo "Building $REPO:$ARCH_TAG using base image $BASE and qemu arch $QEMU_ARCH"
  docker build -t $REPO:$ARCH_TAG --build-arg BASE=$BASE --build-arg arch=$QEMU_ARCH .
  
  if [ -n "$ALIAS_ARCH_TAG" ] ; then
    docker tag $REPO:$ARCH_TAG $REPO:${ALIAS_ARCH_TAG}
  fi
  
fi

##############################

if [ "$PUSH" = true ] ; then
  echo "PUSHING TO DOCKER: $REPO:$ARCH_TAG"
  docker push $REPO:$ARCH_TAG
  
  if [ -n "$ALIAS_ARCH_TAG" ] ; then
    echo "PUSHING TO DOCKER: $REPO:${ALIAS_ARCH_TAG}"
    docker push $REPO:${ALIAS_ARCH_TAG}
  fi
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
  
  if [ -n "$ALIAS_ARCH_TAG" ] ; then
    for arch in $ARCHS; do
      echo
      echo "Pull ${REPO}:${ORG_TAG}-${arch}"
      docker pull ${REPO}:${ORG_TAG}-${arch}

      echo
      echo "Add ${REPO}:${ORG_TAG}-${arch} to manifest ${REPO}:${ORG_TAG}"
      docker manifest create --amend ${REPO}:${ORG_TAG} ${REPO}:${ORG_TAG}-${arch}
      docker manifest annotate       ${REPO}:${ORG_TAG} ${REPO}:${ORG_TAG}-${arch} --arch ${arch}
    done

    echo
    echo "Push manifest ${REPO}:${ORG_TAG}"
    docker manifest push ${REPO}:${ORG_TAG}
  fi
  
fi
