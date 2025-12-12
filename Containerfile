FROM fedora:43

LABEL org.opencontainers.image.source=https://github.com/piotrpdev/ancientwasm
LABEL org.opencontainers.image.licenses=MIT

ARG EMSDK_VERSION=4.0.21
ARG GMP_VERSION=6.3.0
ARG GNUCOBOL_NIGHTLY_VERSION=4.0-early-dev
ARG COBDOMINATE_SHA1=2daa7e2593415171aaf2708b0e27c6bf5a68b94b

SHELL ["/bin/bash", "-c"]
ENV SHELL=/bin/bash

RUN echo $'fastestmirror=True\n\
max_parallel_downloads=20' >> /etc/dnf/dnf.conf && \
    dnf -y update && \
    dnf -y install xz gcc glibc-devel gmp-devel libatomic make git python ctags diffutils

RUN urls="\
https://gmplib.org/download/gmp/gmp-${GMP_VERSION}.tar.xz \
https://ci.appveyor.com/api/projects/GitMensch/gnucobol-trunk/artifacts/gnucobol-${GNUCOBOL_NIGHTLY_VERSION}.tar.xz?job=Image:%20Ubuntu2204 \
" && \
    for url in $urls; do \
        echo "fetching $url"; \
        curl -L "$url" -O --output-dir /usr/src & \
    done && \
    wait

# Install and activate Emscripten SDK
RUN git -C /usr/share clone --depth=1 --branch main --single-branch https://github.com/emscripten-core/emsdk.git && \
    /usr/share/emsdk/emsdk install $EMSDK_VERSION && \
    /usr/share/emsdk/emsdk activate $EMSDK_VERSION && \
    echo $'\n\
export EMSDK_NODE_VERSION="$(/usr/share/emsdk/emsdk list | sed -nE \'s/.+?node-(.+?)\s+?INSTALLED/\\1/p\' | sed \'s/-/_/\' | xargs echo)" \n\
export PATH="${PATH}:/usr/share/emsdk:/usr/share/emsdk/upstream/emscripten:/usr/share/emsdk/node/${EMSDK_NODE_VERSION}/bin" \n\
export EMSDK="/usr/share/emsdk" \n\
export EMSDK_NODE="/usr/share/emsdk/node/${EMSDK_NODE_VERSION}/bin/node"' > /root/.bashrc

# Build and install GMP
RUN source /root/.bashrc && \
    tar -xf /usr/src/gmp-${GMP_VERSION}.tar.xz -C /usr/src && \
    mkdir /usr/src/gmp-${GMP_VERSION}/build && \
    cd /usr/src/gmp-${GMP_VERSION}/build && \
    emconfigure /usr/src/gmp-${GMP_VERSION}/configure --disable-assembly --host none && \
    emmake make -j`nproc` && \
    mkdir /usr/libwasm && \
    yes | cp -f /usr/src/gmp-${GMP_VERSION}/build/*.h /usr/share/emsdk/upstream/emscripten/cache/sysroot/include/ && \
    cp /usr/src/gmp-${GMP_VERSION}/build/.libs/* /usr/share/emsdk/upstream/emscripten/cache/sysroot/lib/wasm32-emscripten/

# Build and install GnuCOBOL
# TODO: Find out how to change COB_CONFIG_DIR during install instead of needing env var
RUN cd /usr/src && \
    tar -xf /usr/src/gnucobol-${GNUCOBOL_NIGHTLY_VERSION}.tar.xz -C /usr/src && \
    cd /usr/src/gnucobol-${GNUCOBOL_NIGHTLY_VERSION} && \
    echo "/usr/local/lib" > /etc/ld.so.conf.d/local.conf && \
    echo -e "\nldconfig" >> /root/.bashrc && \
    echo -e "\nexport COB_CONFIG_DIR=\"/usr/local/share/gnucobol/config/\"" >> /root/.bashrc && \
    /usr/src/gnucobol-${GNUCOBOL_NIGHTLY_VERSION}/configure CFLAGS='-std=gnu17 -fPIC -Wno-deprecated-non-prototype' --without-db && \
    make -j`nproc` && \
    make install -j`nproc`

RUN source /root/.bashrc && \
    cd /usr/src && \
    rm -rf /usr/src/gnucobol-${GNUCOBOL_NIGHTLY_VERSION} && \
    tar -xf /usr/src/gnucobol-${GNUCOBOL_NIGHTLY_VERSION}.tar.xz -C /usr/src && \
    cd /usr/src/gnucobol-${GNUCOBOL_NIGHTLY_VERSION} && \
    emconfigure /usr/src/gnucobol-${GNUCOBOL_NIGHTLY_VERSION}/configure --without-db --host none && \
    cd /usr/src/gnucobol-${GNUCOBOL_NIGHTLY_VERSION}/libcob && \
    emmake make -j`nproc` && \
    emmake make install -j`nproc` && \
    cp -f /usr/src/gnucobol-${GNUCOBOL_NIGHTLY_VERSION}/*.h /usr/share/emsdk/upstream/emscripten/cache/sysroot/include/ && \
    mkdir /usr/share/emsdk/upstream/emscripten/cache/sysroot/include/libcob && \
    cp /usr/src/gnucobol-${GNUCOBOL_NIGHTLY_VERSION}/libcob/*.h /usr/share/emsdk/upstream/emscripten/cache/sysroot/include/libcob && \
    cp /usr/src/gnucobol-${GNUCOBOL_NIGHTLY_VERSION}/libcob/*.def /usr/share/emsdk/upstream/emscripten/cache/sysroot/include/libcob && \
    cp /usr/src/gnucobol-${GNUCOBOL_NIGHTLY_VERSION}/libcob/.libs/* /usr/share/emsdk/upstream/emscripten/cache/sysroot/lib/wasm32-emscripten/

# Clean up
RUN rm -rf /usr/src/gmp-${GMP_VERSION} /usr/src/gnucobol-${GNUCOBOL_NIGHTLY_VERSION}

# Build both demos to make sure everything works
ADD demos /root/demos
RUN source /root/.bashrc && \
    cd /root/demos/demo1 && \
    ./demo.sh ; \
    cd /root/demos/demo2 && \
    ./demo.sh ; \
    exit 0

# Build and install CobDOMinate, then build the demo to make sure everything works
RUN source /root/.bashrc && \
    git -C /usr/src clone --branch main --single-branch https://github.com/BalakeKarbon/CobDOMinate.git && \
    cd /usr/src/CobDOMinate && \
    git reset --hard $COBDOMINATE_SHA1 && \
    sed -i -e 's,LIB_INSTALL_DIR =.*$,LIB_INSTALL_DIR = /usr/share/emsdk/upstream/emscripten/cache/sysroot/lib/wasm32-emscripten/,g' /usr/src/CobDOMinate/Makefile && \
    sed -i -e 's/emcc/emcc -Wno-deprecated-non-prototype/g' /usr/src/CobDOMinate/Makefile && \
    sed -i -e 's/_malloc,//g' /usr/src/CobDOMinate/Makefile && \
    sed -i -e 's/EXPORTED_FUNCTIONS=/EXPORTED_FUNCTIONS=_malloc,/g' /usr/src/CobDOMinate/Makefile && \
    emmake make -j`nproc` && \
    emmake make install -j`nproc` && \
    emmake make example -j`nproc`
