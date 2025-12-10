FROM fedora:43

ARG EMSDK_VERSION=4.0.21
ARG GMP_VERSION=6.3.0
ARG GNUCOBOL_VERSION=3.2

SHELL ["/bin/bash", "-c"]
ENV SHELL=/bin/bash

# Download dependencies
RUN echo $'fastestmirror=True\n\
max_parallel_downloads=20' >> /etc/dnf/dnf.conf && \
    dnf -y update && \
    dnf -y install lzip xz gcc libatomic make f2c gnucobol git unzip python

RUN urls="\
https://gmplib.org/download/gmp/gmp-${GMP_VERSION}.tar.xz \
https://phoenixnap.dl.sourceforge.net/project/gnucobol/gnucobol/${GNUCOBOL_VERSION}/gnucobol-${GNUCOBOL_VERSION}.tar.lz \
https://www.netlib.org/f2c/libf2c.zip \
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
RUN source /root/.bashrc && \
    cd /usr/src && \
    lzip -d /usr/src/gnucobol-${GNUCOBOL_VERSION}.tar.lz && \
    tar -xf /usr/src/gnucobol-${GNUCOBOL_VERSION}.tar -C /usr/src && \
    cd /usr/src/gnucobol-${GNUCOBOL_VERSION} && \
    emconfigure /usr/src/gnucobol-${GNUCOBOL_VERSION}/configure --without-db --host none && \
    cd /usr/src/gnucobol-${GNUCOBOL_VERSION}/libcob && \
    emmake make -j`nproc` && \
    cp -f /usr/src/gnucobol-${GNUCOBOL_VERSION}/*.h /usr/share/emsdk/upstream/emscripten/cache/sysroot/include/ && \
    mkdir /usr/share/emsdk/upstream/emscripten/cache/sysroot/include/libcob && \
    cp /usr/src/gnucobol-${GNUCOBOL_VERSION}/libcob/*.h /usr/share/emsdk/upstream/emscripten/cache/sysroot/include/libcob && \
    cp /usr/src/gnucobol-${GNUCOBOL_VERSION}/libcob/*.def /usr/share/emsdk/upstream/emscripten/cache/sysroot/include/libcob && \
    cp /usr/src/gnucobol-${GNUCOBOL_VERSION}/libcob/.libs/* /usr/share/emsdk/upstream/emscripten/cache/sysroot/lib/wasm32-emscripten/

# Build and install libf2c
RUN mkdir /usr/src/libf2c && \
    cd /usr/src/libf2c && \
    unzip /usr/src/libf2c.zip && \
    cp /usr/src/libf2c/makefile.u /usr/src/libf2c/makefile && \
    sed -i 's/CC = cc/CC = emcc/g' /usr/src/libf2c/makefile && \
    sed -i 's/-DSkip_f2c_Undefs//g' /usr/src/libf2c/makefile && \
    sed -i 's/ld -r -x -o/#ld -r -x -o/g' /usr/src/libf2c/makefile && \
    sed -i 's/mv \$\*\.xxx \$\*\.o/#mv \$\*\.xxx \$\*\.o/g' /usr/src/libf2c/makefile && \
    sed -i 's/\.\/a\.out/node a.out.js/g' /usr/src/libf2c/makefile && \
    sed -i 's/rm -f a\.out/rm -f a\.out\.js a\.out\.wasm/g' /usr/src/libf2c/makefile && \
    sed -i 's/CFLAGS = -O/CFLAGS = /g' /usr/src/libf2c/makefile && \
    source /root/.bashrc && \
    emmake make -j`nproc` && \
    cp /usr/src/libf2c/*.a /usr/share/emsdk/upstream/emscripten/cache/sysroot/lib/wasm32-emscripten/ && \
    yes | cp -f /usr/src/libf2c/*.h /usr/share/emsdk/upstream/emscripten/cache/sysroot/include/

# Clean up
RUN rm -rf /usr/src/gmp-${GMP_VERSION} /usr/src/gnucobol-${GNUCOBOL_VERSION} /usr/src/libf2c

# Include demos
ADD demo1 /root/demo1
ADD demo2 /root/demo2

# Build both demos to make sure everything works
RUN source /root/.bashrc && \
    cd /root/demo1 && \
    ./demo.sh && \
    cd /root/demo2 && \
    ./demo.sh

WORKDIR /root
