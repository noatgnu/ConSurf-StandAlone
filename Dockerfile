FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1 \
    OMPI_ALLOW_RUN_AS_ROOT=1 \
    JAVA_TOOL_OPTIONS="-Dfile.encoding=UTF-8" \
    PROTTEST_HOME="/prottest3"

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.10 \
    python3.10-dev \
    python3-pip \
    python3.10-venv \
    unzip \
    cd-hit \
    ncbi-blast+ \
    hmmer \
    mafft \
    clustalw \
    wget \
    build-essential \
    phyml \
    git \
    ant \
    libglew2.2 \
    libglfw3 \
    libfreetype6 \
    && ln -sf /usr/bin/python3.10 /usr/bin/python3 \
    && ln -sf /usr/bin/python3.10 /usr/bin/python \
    && rm -rf /var/lib/apt/lists/*

RUN wget -q https://www.drive5.com/muscle/muscle_src_3.8.1551.tar.gz && \
    mkdir muscle_src && tar -xzf muscle_src_3.8.1551.tar.gz -C muscle_src && \
    cd muscle_src && make && mv muscle /usr/local/bin/ && \
    cd / && rm -rf muscle_src muscle_src_3.8.1551.tar.gz

RUN git clone https://github.com/ddarriba/prottest3.git && \
    sed -i 's|statsFile = new File(workAlignment + STATS_FILE_SUFFIX + "txt")|statsFile = new File(workAlignment + STATS_FILE_SUFFIX + ".txt")|g' prottest3/src/main/java/es/uvigo/darwin/prottest/exe/PhyMLv3AminoAcidRunEstimator.java && \
    sed -i 's|treeFile = new File(workAlignment + TREE_FILE_SUFFIX + "txt")|treeFile = new File(workAlignment + TREE_FILE_SUFFIX + ".txt")|g' prottest3/src/main/java/es/uvigo/darwin/prottest/exe/PhyMLv3AminoAcidRunEstimator.java && \
    sed -i 's/target="1.6"/target="1.7"/; s/source="1.6"/source="1.7"/' prottest3/build.xml

WORKDIR /prottest3
RUN ant jar
RUN printf '#!/bin/bash\njava --add-opens java.base/java.lang=ALL-UNNAMED --add-opens java.base/java.util=ALL-UNNAMED --add-opens java.base/java.io=ALL-UNNAMED --add-opens java.base/java.util.concurrent=ALL-UNNAMED -jar /prottest3/dist/prottest-3.4.2.jar "$@"\n' > /prottest3/dist/prottest.sh && \
    chmod +x /prottest3/dist/prottest.sh && \
    ln -s /prottest3/dist/prottest.sh /usr/bin/prottest

WORKDIR /

RUN pip3 install uv && \
    uv pip install --system fpdf biopython pymol-open-source

RUN wget -q https://github.com/soedinglab/MMseqs2/releases/download/18-8cc5c/mmseqs-linux-avx2.tar.gz && \
    tar -xzf mmseqs-linux-avx2.tar.gz && \
    mv mmseqs/bin/mmseqs /usr/local/bin/ && \
    rm -rf mmseqs mmseqs-linux-avx2.tar.gz

RUN wget https://github.com/ddarriba/jmodeltest2/files/157117/jmodeltest-2.1.10.tar.gz && \
    tar -xzf jmodeltest-2.1.10.tar.gz && \
    chmod +x jmodeltest-2.1.10/exe/phyml/PhyML_3.0_linux64 && \
    rm jmodeltest-2.1.10.tar.gz

RUN ln -s /jmodeltest-2.1.10/exe/phyml/PhyML_3.0_linux64 /prottest3/dist/bin/PhyML_3.0_linux64

ENV JMODELTEST2_PATH=/jmodeltest-2.1.10
RUN echo "JMODELTEST2 = \"$JMODELTEST2_PATH/jModelTest.jar\"" > GENERAL_CONSTANTS.py

ADD ucsf-chimerax_1.11.1ubuntu22.04_amd64.deb .
RUN apt-get update && apt-get install -y ./ucsf-chimerax_1.11.1ubuntu22.04_amd64.deb && \
    rm ucsf-chimerax_1.11.1ubuntu22.04_amd64.deb && \
    rm -rf /var/lib/apt/lists/*

RUN wget https://www.fontsquirrel.com/fonts/download/dejavu-sans -O DejaVuSans.zip && \
    unzip DejaVuSans.zip && \
    mv DejaVuSans.ttf /usr/share/fonts/ && \
    rm DejaVuSans.zip
RUN echo "FONTS = \"/usr/share/fonts/DejaVuSans.ttf\"" >> GENERAL_CONSTANTS.py

RUN wget https://github.com/ariloytynoja/prank-msa/archive/refs/heads/master.zip -O prank.zip && \
    unzip prank.zip && \
    cd prank-msa-master/src && make && \
    chmod +x prank && \
    mv prank /usr/local/bin/ && \
    cd ../.. && rm -rf prank-msa-master prank.zip

WORKDIR /workspace
COPY stand_alone_consurf /workspace/stand_alone_consurf
WORKDIR /workspace/stand_alone_consurf
RUN sed -i 's|prottest -log disabled -i %s -AICC -o %s -S 1 -JTT -LG -MtREV -Dayhoff -WAG -CpREV -threads 1|prottest -log disabled -i %s -AICC -o %s -S 1 -JTT -LG -MtREV -Dayhoff -WAG -CpREV -threads 2|g' stand_alone_consurf.py
RUN sed -i 's|/bentallab/programs/stand_alone_consurf/prank-msa-master/src|/usr/local/bin|g' GENERAL_CONSTANTS.py
RUN sed -i 's|/bentallab/programs/dejavu-fonts-ttf-2.37/ttf/DejaVuSans.ttf|/usr/share/fonts/DejaVuSans.ttf|g' GENERAL_CONSTANTS.py
RUN sed -i 's|mafft --localpair --maxiterate 1000 --quiet|mafft --localpair --maxiterate 1000 --quiet --thread 5|g' stand_alone_consurf.py
RUN sed -i 's|jackhmmer --notextw -N %s --domE %s -E %s --incE %s --cpu 4|jackhmmer --notextw -N %s --domE %s -E %s --incE %s --cpu 20|g' stand_alone_consurf.py

CMD ["/bin/bash"]
