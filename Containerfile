FROM fedora:43

SHELL ["/bin/bash", "-c"]
ENV SHELL=/bin/bash

RUN dnf -y update
RUN dnf -y install lzip xz gcc libatomic make f2c gnucobol git unzip python
WORKDIR /usr/src
RUN curl --location https://gmplib.org/download/gmp/gmp-6.3.0.tar.xz --output gmp-6.3.0.tar.xz 
RUN curl --location https://phoenixnap.dl.sourceforge.net/project/gnucobol/gnucobol/3.2/gnucobol-3.2.tar.lz --output gnucobol-3.2.tar.lz 
RUN curl --location https://www.netlib.org/f2c/libf2c.zip --output libf2c.zip 

#emsdk
WORKDIR /usr/share/
RUN git clone https://github.com/emscripten-core/emsdk.git
WORKDIR /usr/share/emsdk
RUN ./emsdk install 4.0.21
RUN ./emsdk activate 4.0.21
RUN echo $'\n\
export EMSDK_NODE_VERSION="$(/usr/share/emsdk/emsdk list | sed -nE \'s/.+?node-(.+?)\s+?INSTALLED/\\1/p\' | sed \'s/-/_/\' | xargs echo)" \n\
export PATH="${PATH}:/usr/share/emsdk:/usr/share/emsdk/upstream/emscripten:/usr/share/emsdk/node/${EMSDK_NODE_VERSION}/bin" \n\
export EMSDK="/usr/share/emsdk" \n\
export EMSDK_NODE="/usr/share/emsdk/node/${EMSDK_NODE_VERSION}/bin/node"' > ~/.bashrc

#gmp
WORKDIR /usr/src
RUN tar -xf gmp-6.3.0.tar.xz
WORKDIR /usr/src/gmp-6.3.0
RUN mkdir build
WORKDIR /usr/src/gmp-6.3.0/build
RUN source ~/.bashrc; emconfigure ../configure --host none
RUN source ~/.bashrc; emmake make 
RUN mkdir /usr/libwasm
RUN yes | cp -f *.h /usr/share/emsdk/upstream/emscripten/cache/sysroot/include/
RUN cp .libs/* /usr/share/emsdk/upstream/emscripten/cache/sysroot/lib/wasm32-emscripten/

#gnucobol
WORKDIR /usr/src
RUN lzip -d gnucobol-3.2.tar.lz
RUN tar -xf gnucobol-3.2.tar
WORKDIR /usr/src/gnucobol-3.2
#RUN source ~/.bashrc; export CFLAGS='-I/usr/src/gmp-6.3.0/build'; export LDFLAGS='-L/usr/libwasm'; emconfigure ./configure --without-db --host none; cd libcob; emmake make
RUN source ~/.bashrc; emconfigure ./configure --without-db --host none; cd libcob; emmake make
RUN cp -f *.h /usr/share/emsdk/upstream/emscripten/cache/sysroot/include/
WORKDIR /usr/src/gnucobol-3.2/libcob
RUN mkdir /usr/share/emsdk/upstream/emscripten/cache/sysroot/include/libcob
RUN cp *.h /usr/share/emsdk/upstream/emscripten/cache/sysroot/include/libcob
RUN cp *.def /usr/share/emsdk/upstream/emscripten/cache/sysroot/include/libcob
RUN cp .libs/* /usr/share/emsdk/upstream/emscripten/cache/sysroot/lib/wasm32-emscripten/

#libf2c
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
RUN source ~/.bashrc; emmake make
RUN cp *.a /usr/share/emsdk/upstream/emscripten/cache/sysroot/lib/wasm32-emscripten/
RUN yes | cp -f *.h /usr/share/emsdk/upstream/emscripten/cache/sysroot/include/

#clean up
RUN rm -rf /usr/src/gmp-6.3.0
RUN rm -rf /usr/src/gnucobol-3.2
RUN rm -rf /usr/src/libf2c

WORKDIR /root

#get demos
ADD demo1 /root/demo1
ADD demo2 /root/demo2
