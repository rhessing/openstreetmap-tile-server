# openstreetmap-tile-server

This container allows you to easily set up an OpenStreetMap PNG tile server given a `.osm.pbf` file. It is based on the great work done by [Overv](https://github.com/Overv/openstreetmap-tile-server) and uses the default OpenStreetMap style.

The project from [Overv](https://github.com/Overv/openstreetmap-tile-server) has been forked and adjusted to enable the use of an external PostgreSQL database server.

The following environment variables can be added to allow for an connection to an external PostgreSQL database server:

    CREATEUSER: set this to true if you want the image to create the user, default: false
                CREATEUSER env option is only available for an external DB, for a local DB this will always be true
                Note: CREATEUSER is not used for the run command

    CREATEDB: set this to true if you want the image to create the DB, default: false
              CREATEDB env option is only available for an external DB, for a local DB this will always be true
              Note: CREATEDB is not used for the run command

    CACHESIZE: defines the cache size used during import. Size in MB, default: 2048
               Note: CACHESIZE is not used for the run command
           
    LOCAL: Import the data into the PGSQL instance within this image, default: true
           Please note: when LOCAL=false please use --network host command if you want to access a PGSQL instance
           running natively on the docker host, not required if the PGSQL instance runs inside docker
 
    THREADS: defines number of threads used for importing / tile rendering, default: 4
    PGDATABASE: defines the name of the DB, default: gis
    PGHOST: defines the DB host IP, default: 127.0.0.1
    PGPORT: defines the DB port, default: 5432
    PGUSER: defines the DB username, default: renderer
    PGPASS: defines the DB password, by default this variable is not set
    PROXY: defines the proxy to be used for downloading the fallback data file, by default this variable is not set


If no environment variables are added it will work exactly the same as the container from Overv.

## Setting up the server

First create a Docker volume to hold the PostgreSQL database that will contain the OpenStreetMap data:

    docker volume create openstreetmap-data

Next, download an .osm.pbf extract from geofabrik.de for the region that you're interested in. You can then start importing it into PostgreSQL by running a container and mounting the file as `/data.osm.pbf`. For example:

    docker run -v /absolute/path/to/luxembourg.osm.pbf:/data.osm.pbf -v openstreetmap-data:/var/lib/postgresql/10/main overv/openstreetmap-tile-server import

If the container exits without errors, then your data has been successfully imported and you are now ready to run the tile server.

## Running the server

Run the server like this:

    docker run -p 80:80 -v openstreetmap-data:/var/lib/postgresql/10/main -d overv/openstreetmap-tile-server run

Your tiles will now be available at http://localhost/tile/{z}/{x}/{y}.png. If you open `http://localhost/` in your browser, you should be able to see the tiles served by your own machine. Note that it will initially quite a bit of time to render the larger tiles for the first time.

## Preserving rendered tiles

Tiles that have already been rendered will be stored in `/var/lib/mod_tile`. To make sure that this data survives container restarts, you should create another volume for it:

    docker volume create openstreetmap-rendered-tiles
    docker run -p 80:80 -v openstreetmap-data:/var/lib/postgresql/10/main -v openstreetmap-rendered-tiles:/var/lib/mod_tile -d overv/openstreetmap-tile-server run

## Performance tuning

The import and tile serving processes use 4 threads by default, but this number can be changed by setting the `THREADS` environment variable. For example:

    docker run -p 80:80 -e THREADS=24 -v openstreetmap-data:/var/lib/postgresql/10/main -d overv/openstreetmap-tile-server run

## License

```
Copyright 2018 Alexander Overvoorde

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
