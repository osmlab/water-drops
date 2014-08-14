# usage: ./highways_intersect_buildings.sh <export> <drop>
# `export` and `drop` are optional

echo "
    CREATE TABLE _tmp_buildings AS
        SELECT id, tags, ST_makepolygon(linestring) as geom
        FROM ways
        WHERE ST_npoints(linestring) > 3
        AND ST_IsClosed(linestring)
        AND tags ? 'building'
        AND NOT tags ? 'layer'
        AND NOT tags ? 'bridge'
        AND NOT 'building=>no'::hstore <@ tags
        AND NOT 'building=>roof'::hstore <@ tags;
" | psql -U postgres -d osm

echo "
    CREATE INDEX _tmp_buildings_gist
    ON _tmp_buildings USING GIST(geom);
" | psql -U postgres -d osm

echo "
    DELETE from _tmp_buildings where st_isvalid(geom) = 'f';
" | psql -U postgres -d osm

# remove some obvious and non-obvious ways that are often attacked to buildings
echo "
    CREATE TABLE _tmp_highways AS
        SELECT id, linestring as geom
        FROM ways
        WHERE tags ? 'highway'
        AND NOT tags ? 'layer'
        AND NOT tags ? 'tunnel'
        AND NOT tags ? 'area'
        AND NOT 'highway=>footway'::hstore <@ tags
        AND NOT 'highway=>path'::hstore <@ tags
        AND NOT 'highway=>steps'::hstore <@ tags
        AND NOT 'highway=>living_street'::hstore <@ tags
        AND NOT 'highway=>pedestrian'::hstore <@ tags
        AND NOT 'highway=>construction'::hstore <@ tags
        AND NOT 'service=>driveway'::hstore <@ tags
        AND NOT 'service=>parking_aisle'::hstore <@ tags;
" | psql -U postgres -d osm

echo "
    CREATE INDEX _tmp_highways_gist
    ON _tmp_highways USING GIST(geom);
" | psql -U postgres -d osm

# the actual highways and buildings that intersect
echo "
    CREATE TABLE highway_intersects_building AS
        SELECT
            hwy.id as hwy,
            bldg.id as bldg
        FROM _tmp_highways as hwy, _tmp_buildings as bldg
        WHERE GeometryType(st_intersection(hwy.geom, bldg.geom)) = 'LINESTRING';
" | psql -U postgres -d osm

# drop temp tables
echo "
    DROP TABLE _tmp_buildings;
    DROP TABLE _tmp_highways;
" | psql -U postgres -d osm

if [ ! -x $1 ] && [ $1 == 'export' ]; then
    echo "
        COPY (select * from highway_intersects_building) to stdout DELIMITER ',' HEADER CSV;
    " | psql -U postgres -d osm > highway_intersects_building.csv

    echo "EXPORTED: highway_intersects_building.csv"
fi

if [ ! -x $2 ] && [ $2 == 'drop' ]; then
    echo "
        DROP TABLE highway_intersects_building;
    " | psql -U postgres -d osm

    echo "DROPPED: highway_intersects_building"
fi
