VERSION 0.8

ARG UBUNTU_VERSION=20.04

linux-build:
    ARG UBUNTU_VERSION
    FROM DOCKERFILE -f docker/ci/linux-build.Dockerfile --build-arg UBUNTU_VERSION=$UBUNTU_VERSION .
    WORKDIR /workspace
    COPY . .
    RUN test -f /usr/lib/i386-linux-gnu/libssl.so
    RUN test -f /usr/lib/i386-linux-gnu/libcrypto.so
    RUN cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DFORCE_32_BIT=ON -DOPENSSL_SSL_LIBRARY=/usr/lib/i386-linux-gnu/libssl.so -DOPENSSL_CRYPTO_LIBRARY=/usr/lib/i386-linux-gnu/libcrypto.so -DCMAKE_POSITION_INDEPENDENT_CODE=ON
    RUN cmake --build build --parallel
    RUN scripts/ci/check-linux-mysql-symbols.sh
    RUN mkdir -p /artifacts/linux && cp build/src/mysql.so /artifacts/linux/mysql.so && cp build/src/a_mysql.inc /artifacts/linux/a_mysql.inc && cp "$(find build -type f -name 'libmariadb.so.3' | head -n 1)" /artifacts/linux/libmariadb.so.3
    SAVE ARTIFACT /artifacts/linux/mysql.so AS LOCAL dist/linux/mysql.so
    SAVE ARTIFACT /artifacts/linux/a_mysql.inc AS LOCAL dist/linux/a_mysql.inc
    SAVE ARTIFACT /artifacts/linux/libmariadb.so.3 AS LOCAL dist/linux/libmariadb.so.3

linux-package:
    ARG UBUNTU_VERSION
    FROM DOCKERFILE -f docker/ci/linux-build.Dockerfile --build-arg UBUNTU_VERSION=$UBUNTU_VERSION .
    WORKDIR /workspace
    COPY . .
    RUN test -f /usr/lib/i386-linux-gnu/libssl.so
    RUN test -f /usr/lib/i386-linux-gnu/libcrypto.so
    RUN cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DFORCE_32_BIT=ON -DOPENSSL_SSL_LIBRARY=/usr/lib/i386-linux-gnu/libssl.so -DOPENSSL_CRYPTO_LIBRARY=/usr/lib/i386-linux-gnu/libcrypto.so -DCMAKE_POSITION_INDEPENDENT_CODE=ON
    RUN cmake --build build --parallel
    RUN scripts/ci/check-linux-mysql-symbols.sh
    RUN cmake --build build --target package --parallel
    RUN set -- build/*.tar.gz && [ -e "$1" ] && PKG="$1" && tar -tzf "$PKG" | grep -E "^[^/]+/components/mysql\.so$" && tar -tzf "$PKG" | grep -E "^[^/]+/libmariadb\.so\.3$" && mkdir -p /artifacts && cp "$PKG" /artifacts/mysql-linux.tar.gz
    SAVE ARTIFACT /artifacts/mysql-linux.tar.gz AS LOCAL dist/mysql-linux.tar.gz

