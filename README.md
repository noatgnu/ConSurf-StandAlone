# Based on ConSurf Standalone version 1.0.4 (with fixes)

This is a Docker image for ConSurf Standalone, a tool for the analysis of evolutionary conservation in protein structures based on https://consurf.tau.ac.il/consurf_index.php and https://consurf.tau.ac.il/templates/stand_alone_consurf_1.04.tar.gz to be exact.

## Usage
```shell
docker run --rm -v $(pwd):/data -w /data noatgnu/consurf-alone:0.0.2 python stand_alone_consurf.py --seq /data/sequence.fasta --DB /data/protein.database.fasta --dir /data/output-folder
```
