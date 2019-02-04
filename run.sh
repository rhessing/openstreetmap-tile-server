#!/bin/bash

if [ "$#" -ne 1 ]; then
    echo "usage: <import|run>"
    echo "commands:"
    echo "    import: Set up the database and import /data.osm.pbf"
    echo "    run: Runs Apache and renderd to serve tiles at /tile/{z}/{x}/{y}.png"
    echo ""
    echo ""
    echo "environment variables:"
    echo "    CREATEUSER: set this to true if you want the image to create the user, default: false"
    echo "                CREATEUSER env option is only available for an external DB, for a local DB this will always be true"
    echo "                Note: CREATEUSER is not used for the run command"
    echo ""
    echo "    CREATEDB: set this to true if you want the image to create the DB, default: false"
    echo "              CREATEDB env option is only available for an external DB, for a local DB this will always be true"
    echo "              Note: CREATEDB is not used for the run command"
    echo ""
    echo "    CACHESIZE: defines the cache size used during import, default: 2GB"
    echo "              Note: CACHESIZE is not used for the run command"
    echo ""
    echo "    LOCAL: Import the data into the PGSQL instance within this image, default: true"
    echo "           Please note: when LOCAL=false please use --network host command if you want to access a PGSQL instance"
    echo "                        running natively on the docker host, not required if the PGSQL instance runs inside docker"
    echo ""
    echo "    THREADS: defines number of threads used for importing / tile rendering, default: 4"
    echo "    PGDATABASE: defines the name of the DB, default: gis"
    echo "    PGHOST: defines the DB host IP, default: 127.0.0.1"
    echo "    PGPORT: defines the DB port, default: 5432"
    echo "    PGUSER: defines the DB username, default: renderer"
    echo "    PGPASS: defines the DB password, by default this variable is not set"
    exit 1
fi

LOCAL = ${LOCAL:-true}
CREATEDB = ${CREATEDB:-false}
CREATEUSER = ${CREATEDB:-false}
CACHESIZE = ${CACHESIZE:-2048}
THREADS = ${THREADS:-4}

export PGDATABASE = ${PGDATABASE:-gis}
export PGHOST = ${PGHOST:-127.0.0.1}
export PGPORT = ${PGPORT:-5432}
export PGUSER = ${PGUSER:-renderer}

if [ ! -z "${PGPASS}" ] ; then
    sudo -u postgres echo "${PGHOST}:${PGPORT}:${PGDATABASE}:${PGUSER}:${PGPASS}" > ~/.pgpass
    sudo -u postgres chmod 0600 ~/.pgpass
fi

if [ "${LOCAL}" = false ] ; then
    nc -N ${PGHOST} ${PGPORT} < /dev/null
    if [ $? -eq 1 ]; then
        >&2 echo "Could not connect to the specified PGSQL instance: ${PGHOST}:${PGPORT}! Terminating."
        exit 1;
    fi
fi

if [ "$1" = "import" ]; then

    # Download Luxembourg as sample if no data is provided
    if [ ! -f /data.osm.pbf ]; then
        echo "WARNING: No import file at /data.osm.pbf, so importing Luxembourg as example..."
        wget -nv http://download.geofabrik.de/europe/luxembourg-latest.osm.pbf -O /data.osm.pbf
    fi

    # If OOTB is not set then simply run out of the box,
    # the env varaible requires to be set to false to
    # allow for a real no brainer ;-)
    if [ "${LOCAL}" = true ] ; then
        # Initialize PostgreSQL
        service postgresql start
        sudo -u postgres createuser ${PGUSER}
        sudo -u postgres createdb -E UTF8 -O ${PGUSER} ${PGDATABASE}
        sudo -u postgres psql -d ${PGDATABASE} -c "CREATE EXTENSION postgis;"
        sudo -u postgres psql -d ${PGDATABASE} -c "CREATE EXTENSION hstore;"
        sudo -u postgres psql -d ${PGDATABASE} -c "ALTER TABLE geometry_columns OWNER TO ${PGUSER};"
        sudo -u postgres psql -d ${PGDATABASE} -c "ALTER TABLE spatial_ref_sys OWNER TO ${PGUSER};"

        # Import data
        sudo -u renderer osm2pgsql --database ${PGDATABASE} \
                                   --username ${PGUSER} \
                                   --create \
                                   --slim -G \
                                   --hstore \
                                   --tag-transform-script /home/renderer/src/openstreetmap-carto/openstreetmap-carto.lua \
                                   -C ${CACHESIZE} \
                                   --number-processes ${THREADS} \
                                   -S /home/renderer/src/openstreetmap-carto/openstreetmap-carto.style \
                                   /data.osm.pbf
    else
        # CREATE the DB and set the correct settings if required
        if [ "${CREATEUSER}" = true ] ; then
            sudo -u postgres createuser ${PGUSER}
        fi
        
        # CREATE the DB and set the correct settings if required
        if [ "${CREATEDB}" = true ] ; then
            sudo -u postgres createdb -w -E UTF8 -O ${PGUSER} ${PGDATABASE}
            sudo -u postgres psql -d ${PGDATABASE} -w -c "CREATE EXTENSION postgis;"
            sudo -u postgres psql -d ${PGDATABASE} -w -c "CREATE EXTENSION hstore;"
            sudo -u postgres psql -d ${PGDATABASE} -w -c "ALTER TABLE geometry_columns OWNER TO ${PGUSER};"
            sudo -u postgres psql -d ${PGDATABASE} -w -c "ALTER TABLE spatial_ref_sys OWNER TO ${PGUSER};"
        fi

        # What is -G doing????
        sudo -u renderer osm2pgsql --database ${PGDATABASE} \
                                   --username ${PGUSER} \
                                   --host ${PGHOST} \
                                   --port ${PGPORT} \
                                   --create \
                                   --slim -G \
                                   --hstore \
                                   --tag-transform-script /home/renderer/src/openstreetmap-carto/openstreetmap-carto.lua \
                                   -C ${CACHESIZE} \
                                   --number-processes ${THREADS} \
                                   -S /home/renderer/src/openstreetmap-carto/openstreetmap-carto.style \
                                   /data.osm.pbf
    fi
    
    exit 0
fi

if [ "$1" = "run" ]; then
    # Initialize PostgreSQL if local is true
    if [ "${LOCAL}" = true ] ; then
        service postgresql start
    fi
    
    # Initialize Apache
    service apache2 restart

    # Configure renderd threads
    sed -i -E "s/num_threads=[0-9]+/num_threads=${THREADS}/g" /usr/local/etc/renderd.conf

    # Run
    sudo -u renderer renderd -f -c /usr/local/etc/renderd.conf

    exit 0
fi

echo "invalid command"
exit 1
