FROM python:3.10-bullseye

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/miniconda/bin:$PATH" \
    OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1 \
    OMPI_ALLOW_RUN_AS_ROOT=1 \
    JAVA_TOOL_OPTIONS="-Dfile.encoding=UTF-8" \
    PROTTEST_HOME="/prottest3"

RUN apt-get update && apt-get install -y \
    unzip \
    python3 \
    python3-pip \
    cd-hit \
    ncbi-blast+ \
    hmmer \
    mafft \
    clustalw \
    muscle \
    wget \
    build-essential \
    phyml \
    git \
    ant

RUN git clone https://github.com/ddarriba/prottest3.git
RUN sed -i 's|statsFile = new File(workAlignment + STATS_FILE_SUFFIX + "txt")|statsFile = new File(workAlignment + STATS_FILE_SUFFIX + ".txt")|g' prottest3/src/main/java/es/uvigo/darwin/prottest/exe/PhyMLv3AminoAcidRunEstimator.java
RUN sed -i 's|treeFile = new File(workAlignment + TREE_FILE_SUFFIX + "txt")|treeFile = new File(workAlignment + TREE_FILE_SUFFIX + ".txt")|g' prottest3/src/main/java/es/uvigo/darwin/prottest/exe/PhyMLv3AminoAcidRunEstimator.java

WORKDIR /prottest3
RUN ant jar
RUN echo '#!/bin/bash\njava -jar /prottest3/dist/prottest-3.4.2.jar "$@"' > /prottest3/dist/prottest.sh

RUN chmod +x /prottest3/dist/prottest.sh
RUN ln -s /prottest3/dist/prottest.sh /usr/bin/prottest

WORKDIR /

RUN ln -s /usr/bin/phyml /prottest3/dist/bin/PhyML_3.0_linux64

RUN mkdir -p /opt/conda 
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /opt/conda/miniconda.sh 
RUN bash /opt/conda/miniconda.sh -b -p /opt/miniconda
RUN . /opt/miniconda/bin/activate
RUN conda init bash
RUN conda create -n consurf_env python=3.10 -y && \
    echo "conda activate consurf_env" >> ~/.bashrc

# Install Python modules
RUN /bin/bash -c "source ~/.bashrc"
RUN conda init bash
RUN /opt/miniconda/bin/conda run -n consurf_env pip3 install fpdf
RUN /opt/miniconda/bin/conda run -n consurf_env conda install biopython
RUN /opt/miniconda/bin/conda run -n consurf_env conda install -c conda-forge -c bioconda mmseqs2

# Download and configure jmodeltest2
RUN wget https://github.com/ddarriba/jmodeltest2/files/157117/jmodeltest-2.1.10.tar.gz && \
    tar -xvzf jmodeltest-2.1.10.tar.gz && \
    chmod +x jmodeltest-2.1.10/exe/phyml/PhyML_3.0_linux64 && \
    rm jmodeltest-2.1.10.tar.gz



# Configure GENERAL_CONSTANTS.py for jmodeltest2
ENV JMODELTEST2_PATH=/jmodeltest-2.1.10
RUN echo "JMODELTEST2 = \"$JMODELTEST2_PATH/jModelTest.jar\"" > GENERAL_CONSTANTS.py

# Add ChimeraX from outside and install it
ADD ucsf-chimerax_1.6.1ubuntu20.04_amd64.deb .
RUN apt-get install ./ucsf-chimerax_1.6.1ubuntu20.04_amd64.deb -y

# Install PyMOL
RUN /opt/miniconda/bin/conda run -n consurf_env conda install -c conda-forge -c schrodinger pymol-bundle

# Download and configure DejaVuSans.ttf
RUN wget https://www.fontsquirrel.com/fonts/download/dejavu-sans -O DejaVuSans.zip && \
    unzip DejaVuSans.zip && \
    mv DejaVuSans.ttf /usr/share/fonts/ && \
    rm DejaVuSans.zip
RUN echo "FONTS = \"/usr/share/fonts/DejaVuSans.ttf\"" >> GENERAL_CONSTANTS.py

# Download and install PRANK
RUN wget https://github.com/ariloytynoja/prank-msa/archive/refs/heads/master.zip -O prank.zip && \
    unzip prank.zip && \
    cd prank-msa-master/src && make && \
    chmod +x prank && \
    mv prank /usr/local/bin/ && \
    cd ../.. && rm -rf prank-msa-master prank.zip



# Set up entry point
WORKDIR /workspace
#RUN wget https://consurf.tau.ac.il/templates/stand_alone_consurf_1.04.tar.gz -O consurf.tar.gz
#RUN tar -xvzf consurf.tar.gz
#RUN rm consurf.tar.gz
COPY stand_alone_consurf /workspace/stand_alone_consurf
WORKDIR /workspace/stand_alone_consurf
RUN sed -i 's|prottest -log disabled -i %s -AICC -o %s -S 1 -JTT -LG -MtREV -Dayhoff -WAG -CpREV -threads 1|prottest -log disabled -i %s -AICC -o %s -S 1 -JTT -LG -MtREV -Dayhoff -WAG -CpREV -threads 2|g' stand_alone_consurf.py
RUN sed -i 's|/bentallab/programs/stand_alone_consurf/prank-msa-master/src|/usr/local/bin/prank|g' GENERAL_CONSTANTS.py
RUN sed -i 's|/bentallab/programs/dejavu-fonts-ttf-2.37/ttf/DejaVuSans.ttf|/usr/share/fonts/DejaVuSans.ttf|g' GENERAL_CONSTANTS.py
RUN sed -i 's|mafft --localpair --maxiterate 1000 --quiet|mafft --localpair --maxiterate 1000 --quiet --thread 5|g' stand_alone_consurf.py
RUN sed -i 's|jackhmmer --notextw -N %s --domE %s -E %s --incE %s --cpu 4|jackhmmer --notextw -N %s --domE %s -E %s --incE %s --cpu 20|g' stand_alone_consurf.py

CMD ["/bin/bash"]
