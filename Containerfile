FROM fedora:43

SHELL ["/bin/bash", "-c"]
ENV SHELL=/bin/bash

# Download dependencies
RUN echo $'fastestmirror=True\n\
max_parallel_downloads=20' >> /etc/dnf/dnf.conf
RUN dnf -y update && dnf -y install lzip xz gcc make f2c gnucobol git unzip python

WORKDIR /usr/src
RUN urls="\
https://gmplib.org/download/gmp/gmp-6.3.0.tar.xz \
https://phoenixnap.dl.sourceforge.net/project/gnucobol/gnucobol/3.2/gnucobol-3.2.tar.lz \
https://www.netlib.org/f2c/libf2c.zip \
" && \
    for url in $urls; do \
        echo "fetching $url"; \
        curl -L "$url" -O -s & \
    done && \
    wait

# Install and activate Emscripten SDK
WORKDIR /usr/share/
RUN git clone --depth=1 --branch main --single-branch https://github.com/emscripten-core/emsdk.git

WORKDIR /usr/share/emsdk
RUN ./emsdk install 4.0.6 # >4.0.6 causes linking issues
RUN ./emsdk activate 4.0.6
ENV PATH="${PATH}:/usr/share/emsdk:/usr/share/emsdk/upstream/emscripten"
ENV EMSDK="/usr/share/emsdk"

# Build and install GMP
WORKDIR /usr/src
RUN tar -xf gmp-6.3.0.tar.xz

WORKDIR /usr/src/gmp-6.3.0
RUN mkdir build

WORKDIR /usr/src/gmp-6.3.0/build
RUN emconfigure ../configure --disable-assembly --host none
RUN emmake make -j`nproc`
RUN mkdir /usr/libwasm
RUN yes | cp -f *.h /usr/share/emsdk/upstream/emscripten/cache/sysroot/include/
RUN cp .libs/* /usr/share/emsdk/upstream/emscripten/cache/sysroot/lib/wasm32-emscripten/

# Build and install GnuCOBOL
WORKDIR /usr/src
RUN lzip -d gnucobol-3.2.tar.lz
RUN tar -xf gnucobol-3.2.tar

WORKDIR /usr/src/gnucobol-3.2
#RUN ["/bin/bash", "-c", "export CFLAGS='-I/usr/src/gmp-6.3.0/build'; export LDFLAGS='-L/usr/libwasm'; emconfigure ./configure --without-db --host none; cd libcob; emmake make"]
RUN ["/bin/bash", "-c", "emconfigure ./configure --without-db --host none; cd libcob; emmake make -j`nproc`"]
RUN cp -f *.h /usr/share/emsdk/upstream/emscripten/cache/sysroot/include/

WORKDIR /usr/src/gnucobol-3.2/libcob
RUN mkdir /usr/share/emsdk/upstream/emscripten/cache/sysroot/include/libcob
RUN cp *.h /usr/share/emsdk/upstream/emscripten/cache/sysroot/include/libcob
RUN cp *.def /usr/share/emsdk/upstream/emscripten/cache/sysroot/include/libcob
RUN cp .libs/* /usr/share/emsdk/upstream/emscripten/cache/sysroot/lib/wasm32-emscripten/

# Build and install libf2c
WORKDIR /usr/src
RUN mkdir libf2c

WORKDIR /usr/src/libf2c
RUN unzip /usr/src/libf2c.zip
RUN cp makefile.u makefile
RUN sed -i 's/CC = cc/CC = emcc/g' makefile
RUN sed -i 's/-DSkip_f2c_Undefs//g' makefile
RUN sed -i 's/ld -r -x -o/#ld -r -x -o/g' makefile
RUN sed -i 's/mv \$\*\.xxx \$\*\.o/#mv \$\*\.xxx \$\*\.o/g' makefile
RUN sed -i 's/\.\/a\.out/node a.out.js/g' makefile
RUN sed -i 's/rm -f a\.out/rm -f a\.out\.js a\.out\.wasm/g' makefile
RUN sed -i 's/CFLAGS = -O/CFLAGS = /g' makefile

RUN echo $'\n\
export EMSDK_NODE_VERSION="$(/usr/share/emsdk/emsdk list | sed -nE \'s/.+?node-(.+?)\s+?INSTALLED/\\1/p\' | sed \'s/-/_/\' | xargs echo)" \n\
export PATH="${PATH}:/usr/share/emsdk/node/${EMSDK_NODE_VERSION}/bin" \n\
export EMSDK_NODE="/usr/share/emsdk/node/${EMSDK_NODE_VERSION}/bin/node"' > ~/.bashrc

RUN source ~/.bashrc && emmake make -j`nproc`
RUN cp *.a /usr/share/emsdk/upstream/emscripten/cache/sysroot/lib/wasm32-emscripten/
RUN yes | cp -f *.h /usr/share/emsdk/upstream/emscripten/cache/sysroot/include/

# Clean up
RUN rm -rf /usr/src/gmp-6.3.0 /usr/src/gnucobol-3.2 /usr/src/libf2c

# Include demos
WORKDIR /root
ADD demo1 /root/demo1
ADD demo2 /root/demo2

# Build both demos to make sure everything works
WORKDIR /root/demo1
RUN source ~/.bashrc && ./demo.sh

WORKDIR /root/demo2
RUN source ~/.bashrc && ./demo.sh

